//
//  DCDiskCacheIndex.m
//  HOUND_Mac
//
//  Created by Derek Chen on 13-7-4.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import "DCDiskCacheIndex.h"
#import "DCDiskCacheEntity.h"

const float DCDiskCacheIndexTrimLevel_Low = 0.8f;
const float DCDiskCacheIndexTrimLevel_Middle = 0.6f;
const float DCDiskCacheIndexTrimLevel_High = 0.4f;

#define CHECK_SQLITE(res, expectedResult, db) { \
    int result = (res); \
    if (result != expectedResult) { \
        DCLog_Error(@"FBCacheIndex: Expecting result %d, actual %d", expectedResult, result); \
        if (db) { \
            DCLog_Error(@"FBCacheIndex: SQLite error: %s", sqlite3_errmsg(db)); \
        } \
        NSCAssert(NO, @""); \
    } \
}

#define CHECK_SQLITE_SUCCESS(res, db) CHECK_SQLITE(res, SQLITE_OK, db)
#define CHECK_SQLITE_DONE(res, db) CHECK_SQLITE(res, SQLITE_DONE, db)

// Number of entries cached to memory
static const NSInteger kDefaultCacheCountLimit = 500;

static NSString* const cacheFilename = @"DiskCacheIndex.db";
static const char* schema =
"CREATE TABLE IF NOT EXISTS cache_index "
"(uuid TEXT, key TEXT PRIMARY KEY, access_time REAL, file_size INTEGER)";

static const char* insertQuery =
"INSERT INTO cache_index VALUES (?, ?, ?, ?)";

static const char* updateQuery =
"UPDATE cache_index "
"SET uuid=?, access_time=?, file_size=? "
"WHERE key=?";

static const char* selectByKeyQuery =
"SELECT uuid, key, access_time, file_size FROM cache_index WHERE key = ?";

static const char* selectByKeyFragmentQuery =
"SELECT uuid, key, access_time, file_size FROM cache_index WHERE key LIKE ?";

static const char* selectExcludingKeyFragmentQuery =
"SELECT uuid, key, access_time, file_size FROM cache_index WHERE key NOT LIKE ?";

static const char* selectStorageSizeQuery =
"SELECT SUM(file_size) FROM cache_index";

static const char* deleteEntryQuery =
"DELETE FROM cache_index WHERE key=?";

static const char* trimQuery =
"CREATE TABLE trimmed AS "
"SELECT uuid, key, access_time, file_size, running_total "
"FROM ( "
"SELECT a1.uuid, a1.key, a1.access_time, "
"a1.file_size, SUM(a2.file_size) running_total "
"FROM cache_index a1, cache_index a2 "
"WHERE a1.access_time > a2.access_time OR "
"(a1.access_time = a2.access_time AND a1.uuid = a2.uuid) "
"GROUP BY a1.uuid ORDER BY a1.access_time) rt "
"WHERE rt.running_total <= ?";

#pragma mark - C Helpers

static void initializeStatement(sqlite3 *database, sqlite3_stmt **statement, const char *statementText) {
    if (*statement == nil) {
        CHECK_SQLITE_SUCCESS(sqlite3_prepare_v2(database, statementText, -1, statement, nil), database);
    } else {
        CHECK_SQLITE_SUCCESS(sqlite3_reset(*statement), database);
    }
}

static void releaseStatement(sqlite3_stmt *statement, sqlite3 *database)
{
    if (statement) {
        CHECK_SQLITE_SUCCESS(sqlite3_finalize(statement), database);
    }
}

@interface DCDiskCacheIndex() <NSCacheDelegate> {
}

- (DCDiskCacheEntity *)_entryForKey:(NSString *)key;
- (void)_fetchCurrentDiskUsage;
- (DCDiskCacheEntity *)_readEntryFromDatabase:(NSString *)key;
- (NSMutableArray *) _readEntriesFromDatabase: (NSString *)keyFragment excludingFragment:(BOOL)exclude;
- (DCDiskCacheEntity *)_createCacheEntityInfo:(sqlite3_stmt *)selectStatement;
- (void)_removeEntryFromDatabaseForKey:(NSString *)key;
- (void)_trimDatabase;
- (void)_updateEntryInDatabaseForKey:(NSString *)key entry:(DCDiskCacheEntity *)entry;
- (void)_writeEntryInDatabase:(DCDiskCacheEntity *)entry;

@end

@implementation DCDiskCacheIndex

@synthesize delegate = _delegate;
@synthesize currentDiskUsage = _currentDiskUsage;
@synthesize diskCapacity = _diskCapacity;
@synthesize databaseQueue = _databaseQueue;
@synthesize trimLevel = _trimLevel;

#pragma mark - DCDiskCacheIndex - Public method
- (id)initWithCacheFolder:(NSString *)folderPath {
    @synchronized(self) {
        if (!folderPath || folderPath.length == 0) {
            return nil;
        }
        
        self = [super init];
        if (self) {
            NSString *cacheDBFullPath = [folderPath stringByAppendingPathComponent:cacheFilename];
            
            dispatch_queue_t lowPriQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
            _databaseQueue = dispatch_queue_create("Data Cache queue", DISPATCH_QUEUE_SERIAL);
            dispatch_set_target_queue(_databaseQueue, lowPriQueue);
            
            __block BOOL success = YES;
            
            // TODO: This is really bad if higher layers are going to be
            // multi-threaded.  And this has to be unblocked.
            dispatch_sync(_databaseQueue, ^{
                success = (sqlite3_open_v2(cacheDBFullPath.UTF8String, &_database, (SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE), nil) == SQLITE_OK);
                if (success) {
                    success = (sqlite3_exec(_database, schema, nil, nil, nil) == SQLITE_OK);
                }
            });
            
            if (!success) {
                SAFE_ARC_RELEASE(self);
                return nil;
            }
            
            // Get disk usage asynchronously
            dispatch_async(_databaseQueue, ^{
                @synchronized(self) {
                    [self _fetchCurrentDiskUsage];
                }
            });
            
            _cachedEntries = [[NSCache alloc] init];
            _cachedEntries.delegate = self;
            _cachedEntries.countLimit = kDefaultCacheCountLimit;
            
            self.trimLevel = DCDiskCacheIndexTrimLevel_Middle;
        }
        
        return self;
    }
}

- (void)dealloc {
    do {
        @synchronized(self) {
            if (_databaseQueue) {
                // Copy these locally so we don't capture self in the block
                sqlite3 * const db = _database;
                sqlite3_stmt * const is = _insertStatement;
                sqlite3_stmt * const sbks = _selectByKeyStatement;
                sqlite3_stmt * const sbkfs = _selectByKeyFragmentStatement;
                sqlite3_stmt * const sekfs = _selectExcludingKeyFragmentStatement;
                sqlite3_stmt * const rbks = _removeByKeyStatement;
                sqlite3_stmt * const ts = _trimStatement;
                sqlite3_stmt * const us = _updateStatement;
                dispatch_async(_databaseQueue, ^{
                    @synchronized(self) {
                        releaseStatement(is, nil);
                        releaseStatement(sbks, nil);
                        releaseStatement(sbkfs, nil);
                        releaseStatement(sekfs, nil);
                        releaseStatement(rbks, nil);
                        releaseStatement(ts, nil);
                        releaseStatement(us, nil);
                        
                        CHECK_SQLITE_SUCCESS(sqlite3_close(db), nil);
                    }
                });
                
                SAFE_ARC_DISPATCHQUEUERELEASE(_databaseQueue);
            }
            
            _cachedEntries.delegate = nil;
            SAFE_ARC_SAFERELEASE(_cachedEntries);
        }
        SAFE_ARC_SUPER_DEALLOC();
    } while (NO);
}

- (NSUInteger)entryCacheCountLimit {
    NSUInteger result = 0;
    do {
        @synchronized(self) {
            if (_cachedEntries) {
                result = _cachedEntries.countLimit;
            }
        }
    } while (NO);
    return result;
}

- (void)setEntryCacheCountLimit:(NSUInteger)entryCacheCountLimit {
    do {
        @synchronized(self) {
            if (_cachedEntries) {
                _cachedEntries.countLimit = entryCacheCountLimit;
            }
        }
    } while (NO);
}

- (NSString *)fileNameForKey:(NSString *)key {
    NSString *result = nil;
    do {
        if (!key || key.length == 0) {
            break;
        }
        @synchronized(self) {
            DCDiskCacheEntity *entryInfo = [self _entryForKey:key];
            [entryInfo registerAccess];
            if (entryInfo) {
                result = entryInfo.uuid;
                SAFE_ARC_RETAIN(result);
                SAFE_ARC_AUTORELEASE(result);
            }
        }
    } while (NO);
    return result;
}

- (NSString *)storeFileForKey:(NSString *)key withData:(NSData *)data {
    NSString *result = nil;
    do {
        if (!key || key.length == 0 || !data) {
            break;
        }
        
        CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
        NSString *uuidString = (__bridge NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
        CFRelease(uuid);
        
        @synchronized(self) {
            DCDiskCacheEntity *entry = [[DCDiskCacheEntity alloc] initWithKey:key uuid:uuidString accessTime:0 fileSize:data.length];
            [entry registerAccess];
            dispatch_async(_databaseQueue, ^{
                @synchronized(self) {
                    [self _writeEntryInDatabase:entry];
                    
                    _currentDiskUsage += data.length;
                    if (_currentDiskUsage > _diskCapacity) {
                        [self _trimDatabase];
                    }
                }
            });
            
            [self.delegate cacheIndex:self writeFileWithName:uuidString data:data];
            
            [_cachedEntries setObject:entry forKey:key];
            SAFE_ARC_AUTORELEASE(entry);
            
            result = uuidString;
            SAFE_ARC_AUTORELEASE(result);
        }
    } while (NO);
    return result;
}

- (void)removeEntryForKey:(NSString *)key {
    do {
        if (!key || key.length == 0) {
            break;
        }
        @synchronized(self) {
            DCDiskCacheEntity *entry = [self _entryForKey:key];
            entry.dirty = NO; // Removing, so no need to flush to disk
            
            NSInteger spaceSaved = entry.fileSize;
            [_cachedEntries removeObjectForKey:key];
            
            dispatch_async(_databaseQueue, ^{
                @synchronized(self) {
                    [self _removeEntryFromDatabaseForKey:key];
                    if (_currentDiskUsage >= spaceSaved) {
                        _currentDiskUsage -= spaceSaved;
                    } else {
                        NSAssert(NO, @"Our disk usage is out of whack");
                        // This means current disk usage is out of whack - let's re-read
                        [self _fetchCurrentDiskUsage];
                    };
                    
                    [self.delegate cacheIndex:self deleteFileWithName:entry.uuid];
                }
            });
        }
    } while (NO);
}

- (void)removeEntries:(NSString *)keyFragment excludingFragment:(BOOL)exclude {
    do {
        if (!keyFragment || keyFragment.length == 0) {
            break;
        }
        @synchronized(self) {
            __block NSMutableArray *entries = nil;
            
            dispatch_sync(_databaseQueue, ^{
                entries = [self _readEntriesFromDatabase:keyFragment excludingFragment:exclude];
            });
            
            for (DCDiskCacheEntity *entry in entries) {
                if ([_cachedEntries objectForKey:entry.key] == nil) {
                    // Adding to the cache since the call to removeEntryForKey will look for the entry and
                    // try to retrieve it from the DB which will in turn add it to the cache anyways. So
                    // pre-emptively adding it to the in memory cache saves some DB roundtrips.
                    //
                    // This is only done for NSCache entries that don't already exist since replacing the
                    // old one with the new one will trigger willEvictObject which will try and perform
                    // a DB write. Since the write is async, we might end up in a weird state.
                    [_cachedEntries setObject:entry forKey:entry.key];
                }
                
                [self removeEntryForKey:entry.key];
            }
        }
    } while (NO);
}

#pragma mark - DCDiskCacheIndex - Private method
- (void)_updateEntryInDatabaseForKey:(NSString *)key entry:(DCDiskCacheEntity *)entry {
    do {
        if (!key || key.length == 0 || !entry) {
            break;
        }
        @synchronized(self) {
            initializeStatement(_database, &_updateStatement, updateQuery);
            
            CHECK_SQLITE_SUCCESS(sqlite3_bind_text(_updateStatement, 1, entry.uuid.UTF8String, (int)entry.uuid.length, nil), _database);
            
            CHECK_SQLITE_SUCCESS(sqlite3_bind_double(_updateStatement, 2, entry.accessTime), _database);
            
            CHECK_SQLITE_SUCCESS(sqlite3_bind_int(_updateStatement, 3, (int)entry.fileSize), _database);
            
            CHECK_SQLITE_SUCCESS(sqlite3_bind_text(_updateStatement, 4, entry.key.UTF8String, (int)entry.key.length, nil), _database);
            
            CHECK_SQLITE_DONE(sqlite3_step(_updateStatement), _database);
            
            entry.dirty = NO;
        }
    } while (NO);
}

- (void)_writeEntryInDatabase:(DCDiskCacheEntity *)entry {
    do {
        if (!entry) {
            break;
        }
        @synchronized(self) {
            DCDiskCacheEntity *existing = [self _readEntryFromDatabase:entry.key];
            if (existing) {
                
                // Entry already exists - update the entry
                [self _updateEntryInDatabaseForKey:existing.key entry:entry];
                
                if (![existing.uuid isEqualToString:entry.uuid]) {
                    // The files have changed.  Schedule a delete for existing file
                    [self.delegate cacheIndex:self deleteFileWithName:existing.uuid];
                }
                break;
            }
            
            initializeStatement(_database, &_insertStatement, insertQuery);
            CHECK_SQLITE_SUCCESS(sqlite3_bind_text(_insertStatement, 1, entry.uuid.UTF8String, (int)entry.uuid.length, nil), _database);
            
            CHECK_SQLITE_SUCCESS(sqlite3_bind_text(_insertStatement, 2, entry.key.UTF8String, (int)entry.key.length, nil), _database);
            
            CHECK_SQLITE_SUCCESS(sqlite3_bind_double(_insertStatement, 3, entry.accessTime), _database);
            
            CHECK_SQLITE_SUCCESS(sqlite3_bind_int(_insertStatement, 4, (int)entry.fileSize), _database);
            
            CHECK_SQLITE_DONE(sqlite3_step(_insertStatement), _database);
            
            entry.dirty = NO;
        }
    } while (NO);
}

- (DCDiskCacheEntity *)_readEntryFromDatabase:(NSString *)key {
    DCDiskCacheEntity *result = nil;
    do {
        if (!key || key.length == 0) {
            break;
        }
        @synchronized(self) {
            initializeStatement(_database, &_selectByKeyStatement, selectByKeyQuery);
            
            CHECK_SQLITE_SUCCESS(sqlite3_bind_text(_selectByKeyStatement, 1, key.UTF8String, (int)key.length, nil), _database);
            
            result = [self _createCacheEntityInfo:_selectByKeyStatement];
        }
    } while (NO);
    return result;
    
    
}

- (NSMutableArray *) _readEntriesFromDatabase:(NSString *)keyFragment excludingFragment:(BOOL)exclude {
    NSMutableArray *result = nil;
    do {
        if (!keyFragment || keyFragment.length == 0) {
            break;
        }
        @synchronized(self) {
            sqlite3_stmt *selectStatement = nil;
            const char *query = NULL;
            if (exclude) {
                selectStatement = _selectExcludingKeyFragmentStatement;
                query = selectExcludingKeyFragmentQuery;
            } else {
                selectStatement = _selectByKeyFragmentStatement;
                query = selectByKeyFragmentQuery;
            }
            
            initializeStatement(_database, &selectStatement, query);
            NSString *wildcardKeyFragment = [NSString stringWithFormat:@"%%%@%%", keyFragment];
            
            CHECK_SQLITE_SUCCESS(sqlite3_bind_text(selectStatement, 1, wildcardKeyFragment.UTF8String, (int)wildcardKeyFragment.length, nil), _database);
            
            result = [[NSMutableArray alloc] init];
            SAFE_ARC_AUTORELEASE(result);
            
            DCDiskCacheEntity *entry = nil;
            while ((entry = [self _createCacheEntityInfo:selectStatement]) != nil) {
                [result addObject:entry];
            }
        }
    } while (NO);
    return result;
}

- (DCDiskCacheEntity *)_createCacheEntityInfo:(sqlite3_stmt *)selectStatement {
    DCDiskCacheEntity *result = nil;
    do {
        if (!selectStatement) {
            break;
        }
        @synchronized(self) {
            if (sqlite3_step(selectStatement) != SQLITE_ROW) {
                break;
            }
            const unsigned char *uuidStr = sqlite3_column_text(selectStatement, 0);
            const unsigned char *key = sqlite3_column_text(selectStatement, 1);
            CFTimeInterval accessTime = sqlite3_column_double(selectStatement, 2);
            NSUInteger fileSize = sqlite3_column_int(selectStatement, 3);
            
            result = [[DCDiskCacheEntity alloc] initWithKey:[NSString stringWithCString:(const char *)key encoding:NSUTF8StringEncoding] uuid:[NSString stringWithCString:(const char *)uuidStr encoding:NSUTF8StringEncoding] accessTime:accessTime fileSize:fileSize];
            SAFE_ARC_AUTORELEASE(result);
        }
    } while (NO);
    return result;
}

- (void)_fetchCurrentDiskUsage {
    do {
        @synchronized(self) {            
            sqlite3_stmt* sizeStatement = nil;
            initializeStatement(_database, &sizeStatement, selectStorageSizeQuery);
            
            CHECK_SQLITE(sqlite3_step(sizeStatement), SQLITE_ROW, _database);
            _currentDiskUsage = sqlite3_column_int(sizeStatement, 0);
            releaseStatement(sizeStatement, _database);
        }
    } while (NO);
}

- (DCDiskCacheEntity *)_entryForKey:(NSString *)key {
    __block DCDiskCacheEntity *result = nil;
    do {
        if (!key || key.length == 0) {
            break;
        }
        @synchronized(self) {
            result = [_cachedEntries objectForKey:key];
            if (result == nil) {
                // TODO: This is really bad if higher layers are going to be
                // multi-threaded.  And this has to be unblocked.
                dispatch_sync(_databaseQueue, ^{
                    result = [self _readEntryFromDatabase:key];
                });
                
                if (result) {
                    [_cachedEntries setObject:result forKey:key];
                }
            }
        }
    } while (NO);
    return result;
}

- (void)_removeEntryFromDatabaseForKey:(NSString *)key {
    do {
        if (!key || key.length == 0) {
            break;
        }
        @synchronized(self) {
            initializeStatement(_database, &_removeByKeyStatement, deleteEntryQuery);
            CHECK_SQLITE_SUCCESS(sqlite3_bind_text(_removeByKeyStatement, 1, key.UTF8String, (int)key.length, nil), _database);
            
            CHECK_SQLITE_DONE(sqlite3_step(_removeByKeyStatement), _database);
        }
    } while (NO);
}

- (void)_dropTrimmingTable {
    do {
        @synchronized(self) {
            sqlite3_stmt *trimCleanStatement = nil;
            
            static const char *trimDropQuery = "DROP TABLE IF EXISTS trimmed";
            initializeStatement(_database, &trimCleanStatement, trimDropQuery);
            
            CHECK_SQLITE_DONE(sqlite3_step(trimCleanStatement), _database);
            releaseStatement(trimCleanStatement, _database);
        }
    } while (NO);
}

- (void)_flushOrphanedFiles {
    // TODO: #1001434
}

// Trimming of cache entries based on LRU eviction policy.
// All the computations are done at the DB level, as follows:
// - create a temporary table 'trimmed', which computes which records need
//   purging, based on access time and running total of file size
// - iterate over 'trimmed', clear in-memory cache, queue data files for
//   deletion on a background queue
// - batch-remove these entries from the index
// - drop the temporary 'trimmed' table.
- (void)_trimDatabase {
    do {
        @synchronized(self) {
            NSAssert(_currentDiskUsage > _diskCapacity, @"");
            if (_currentDiskUsage <= _diskCapacity) {
                break;
            }
            
            [self _dropTrimmingTable];
            initializeStatement(_database, &_trimStatement, trimQuery);
            CHECK_SQLITE_SUCCESS(sqlite3_bind_int(_trimStatement, 1, _currentDiskUsage - _diskCapacity * self.trimLevel), _database);
            
            CHECK_SQLITE_DONE(sqlite3_step(_trimStatement), _database);
            
            // Need to re-prep this statement as it's bound to the temporary table
            // and can be stored between trims
            static const char *trimSelectQuery = "SELECT uuid, key, file_size FROM trimmed";
            
            sqlite3_stmt *trimSelectStatement = nil;
            initializeStatement(_database, &trimSelectStatement, trimSelectQuery);
            
            NSUInteger spaceCleaned = 0;
            while (sqlite3_step(trimSelectStatement) == SQLITE_ROW) {
                const unsigned char *uuidStr = sqlite3_column_text(trimSelectStatement, 0);
                const unsigned char *keyStr = sqlite3_column_text(trimSelectStatement, 1);
                spaceCleaned += sqlite3_column_int(trimSelectStatement, 2);
                
                // Remove in-memory cache entry if present
                NSString *key = [NSString stringWithCString:(const char *)keyStr encoding:NSUTF8StringEncoding];
                
                NSString *uuid = [NSString stringWithCString:(const char *)uuidStr encoding:NSUTF8StringEncoding];
                
                DCDiskCacheEntity *entry = [_cachedEntries objectForKey:key];
                entry.dirty = NO;
                [_cachedEntries removeObjectForKey:key];
                
                // Delete the file
                [self.delegate cacheIndex:self deleteFileWithName:uuid];
            }
            
            releaseStatement(trimSelectStatement, _database);
            
            // Batch remove statement
            sqlite3_stmt *trimCleanStatement = nil;
            static const char *trimCleanQuery = "DELETE FROM cache_index WHERE key IN (SELECT key from trimmed)";
            
            initializeStatement(_database, &trimCleanStatement, trimCleanQuery);
            CHECK_SQLITE_DONE(sqlite3_step(trimCleanStatement), _database);
            
            releaseStatement(trimCleanStatement, _database);
            trimCleanStatement = nil;
            
            _currentDiskUsage -= spaceCleaned;
            NSAssert(_currentDiskUsage <= _diskCapacity, @"");
            
            // Okay to drop the trimming table
            [self _dropTrimmingTable];
            [self _flushOrphanedFiles];
        }
    } while (NO);
}

#pragma mark - DCDiskCacheIndex - NSCacheDelegate
- (void)cache:(NSCache *)cache willEvictObject:(id)obj {
    do {
        if (!cache || !obj) {
            break;
        }
        DCDiskCacheEntity *entryInfo = (DCDiskCacheEntity *)obj;
        if (entryInfo.dirty) {
            dispatch_async(_databaseQueue, ^{
                @synchronized(self) {
                    [self _writeEntryInDatabase:entryInfo];
                }
            });
        }
    } while (NO);
}

@end
