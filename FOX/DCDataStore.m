//
//  DCDataStore.m
//  TestApp4CoreData
//
//  Created by Derek Chen on 13-6-4.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import "DCDataStore.h"
#import "DCDataStoreReader.h"
#import "DCDataStoreWriter.h"

@interface DCDataStore () <DCDataStoreOperatorDataSource> {
    NSMutableArray *_threadReaderPool;
    NSUInteger _lastUsingThreadReaderIndex;
    DCDataStoreReader *_mainThreadReader;
    DCDataStoreWriter *_writer;
}

@property (nonatomic, SAFE_ARC_PROP_STRONG) NSMutableArray *threadReaderPool;
@property (atomic, assign) NSUInteger lastUsingThreadReaderIndex;
@property (nonatomic, SAFE_ARC_PROP_STRONG, readonly) DCDataStoreReader *mainThreadReader;
@property (nonatomic, SAFE_ARC_PROP_STRONG, readonly) DCDataStoreWriter *writer;

+ (NSString *)archivePath;

- (BOOL)initDataStore;
- (NSURL *)url;
- (void)cleanThreadReaderPool;
- (void)mergeContextChanges:(NSNotification *)aNotification;

- (void)increaseThreadReaderPoolTo:(NSUInteger)anThreadReaderCount;
- (void)decreaseThreadReaderPoolTo:(NSUInteger)anThreadReaderCount;

- (BOOL)saveWriterSynchronous:(BOOL)isSync;

@end

@implementation DCDataStore

@synthesize dataSource = _dataSource;
@synthesize model = _model;
@synthesize coordinator = _coordinator;
@synthesize threadReaderPool = _threadReaderPool;
@synthesize lastUsingThreadReaderIndex = _lastUsingThreadReaderIndex;
@synthesize mainThreadReader = _mainThreadReader;
@synthesize writer = _writer;

#pragma mark - DCDataStore - Public method
+ (NSString *)defaultUUID {
    NSString *result = nil;
    do {
        result = [[NSURL fileURLWithPath:[DCDataStore archivePath]] absoluteString];
    } while (NO);
    return result;
}

+ (NSString *)archivePath {
    NSString *result = nil;
    do {
        NSArray *documentDirectories = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentDirectory = [documentDirectories objectAtIndex:0];
        result = [documentDirectory stringByAppendingPathComponent:DATASTORE_FILENAME_DEFAULT];
    } while (NO);
    return result;
}

- (id)initWithDataSource:(id<DCDataStoreDataSource>)aDataSource {
    @synchronized(self) {
        self = [super init];
        if (self) {
            _dataSource = aDataSource;
            
            if ([self initDataStore]) {
                [self cleanThreadReaderPool];
                self.threadReaderPool = [NSMutableArray array];
                
                _mainThreadReader = [[DCDataStoreReader alloc] initWithDataSource:self];
                
                _writer = [[DCDataStoreWriter alloc] initWithDataSource:self];
                
                [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mergeContextChanges:) name:NSManagedObjectContextDidSaveNotification object:nil];
            } else {
                _dataSource = nil;
                DCLog_Error(@"DCDataStore init error");
            }
        }
        return self;
    }
}

- (void)dealloc {
    do {
        @synchronized(self) {
            [[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextDidSaveNotification object:nil];
            
            [self cleanThreadReaderPool];
            
            SAFE_ARC_SAFERELEASE(_mainThreadReader);
            
            if (_writer) {
                [self saveWriterSynchronous:YES];
            }
            SAFE_ARC_SAFERELEASE(_writer);
            
            SAFE_ARC_SAFERELEASE(_coordinator);
            SAFE_ARC_SAFERELEASE(_model);
        }
        SAFE_ARC_SUPER_DEALLOC();
    } while (NO);
}

- (BOOL)initDataStore {
    BOOL result = NO;
    do {        
        SAFE_ARC_SAFERELEASE(_coordinator);
        SAFE_ARC_SAFERELEASE(_model);
        
        _model = [NSManagedObjectModel mergedModelFromBundles:nil];
        SAFE_ARC_RETAIN(_model);
        if (self.dataSource && [self.dataSource respondsToSelector:@selector(dataStore:initModel:)]) {
            [self.dataSource dataStore:self initModel:self.model];
        }
        
        _coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:_model];
        NSError *error = nil;
        if (![_coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:[self url] options:nil error:&error]) {
            [NSException raise:@"DCDataStoreManager error" format:@"Reason: %@", [error localizedDescription]];
        }
        
        result = YES;
    } while (NO);
    return result;
}

- (NSUInteger)threadReaderCount {
    NSUInteger result = 0;
    do {
        if (!self.threadReaderPool) {
            break;
        }
        @synchronized(self) {
            result = [self.threadReaderPool count];
        }
    } while (NO);
    return result;
}

- (void)setThreadReaderCount:(NSUInteger)anThreadReaderCount {
    do {
        if (anThreadReaderCount == 0) {
            break;
        }
        @synchronized(self) {
            if ([self.threadReaderPool count] > anThreadReaderCount) {
                [self decreaseThreadReaderPoolTo:anThreadReaderCount];
                
                self.lastUsingThreadReaderIndex = [self.threadReaderPool count];
            } else if ([self.threadReaderPool count] < anThreadReaderCount) {
                [self increaseThreadReaderPoolTo:anThreadReaderCount];
            }
        }
    } while (NO);
}

- (DCDataStoreReader *)queryReader {
    DCDataStoreReader *result = nil;
    do {
        @synchronized(self) {
            if (!self.mainThreadReader) {
                break;
            }
            
            BOOL find = NO;
            BOOL isMainThread = [[NSThread currentThread] isMainThread];
            
            if (isMainThread) {
                if (!self.mainThreadReader.busy) {
                    result = self.mainThreadReader;
                    find = YES;
                }
                
                if (find) {
                    break;
                }
            }
            
            if (!self.threadReaderPool || [self.threadReaderPool count] == 0) {
                break;
            }
            
            for (DCDataStoreReader *reader in self.threadReaderPool) {
                if (!reader.busy) {
                    result = reader;
                    find = YES;
                    break;
                }
            }
            
            if (find) {
                break;
            }
            
            if ([self.threadReaderPool count] != 0) {
                ++self.lastUsingThreadReaderIndex;
                NSUInteger idx = self.lastUsingThreadReaderIndex < [self.threadReaderPool count] ? self.lastUsingThreadReaderIndex : 0;
                result = [self.threadReaderPool objectAtIndex:idx];
                find = YES;
                self.lastUsingThreadReaderIndex = idx;
            } else if (self.mainThreadReader) {
                result = self.mainThreadReader;
                find = YES;
            }
            
            if (find) {
                break;
            }
        }
    } while (NO);
    return result;
}

- (DCDataStoreWriter *)queryWriter {
    DCDataStoreWriter *result = nil;
    do {
        @synchronized(self) {
            if (!self.writer) {
                break;
            }
            
            result = self.writer;
        }
    } while (NO);
    return result;
}

- (BOOL)syncSave {
    BOOL result = YES;
    do {
        @synchronized(self) {
            result = [self saveWriterSynchronous:NO];
        }
    } while (NO);
    return result;
}

- (BOOL)asyncSave {
    BOOL result = YES;
    do {
        @synchronized(self) {
            result = [self saveWriterSynchronous:YES];
        }
    } while (NO);
    return result;
}

- (NSString *)uuid {
    NSString *result = nil;
    do {
        result = [[self url] absoluteString];
    } while (NO);
    return result;
}

#pragma mark - DCDataStore - Private method
- (NSURL *)url {
    NSURL *result = nil;
    do {
        if (self.dataSource && [self.dataSource respondsToSelector:@selector(urlForDataStore:)]) {
            result = [self.dataSource urlForDataStore:self];
        } else {
            result = [NSURL fileURLWithPath:[DCDataStore archivePath]];
        }
    } while (NO);
    return result;
}

- (void)cleanThreadReaderPool {
    do {
        @synchronized(self) {
            if (self.threadReaderPool) {                
                [self.threadReaderPool removeAllObjects];
                self.threadReaderPool = nil;
            }
            
            self.lastUsingThreadReaderIndex = 0;
        }
    } while (NO);
}

- (void)mergeContextChanges:(NSNotification *)aNotification {
    do {
        if (!aNotification) {
            break;
        }
        
        @synchronized(self) {
            BOOL allowMerge = NO;
            NSManagedObjectContext *context = (NSManagedObjectContext *)aNotification.object;
            if ([context isEqual:self.writer.context]) {
                allowMerge = YES;
                break;
            }
            
            if (allowMerge) {
                [self.mainThreadReader mergeContextChanges:aNotification];
                
                for (DCDataStoreReader *reader in self.threadReaderPool) {
                    [reader mergeContextChanges:aNotification];
                }
            }
        }
    } while (NO);
}

- (void)increaseThreadReaderPoolTo:(NSUInteger)anThreadReaderCount {
    do {
        @synchronized(self) {
            NSUInteger diff = anThreadReaderCount - [self.threadReaderPool count];
            for (; diff > 0; --diff) {
                DCDataStoreReader *reader = [[DCDataStoreReader alloc] initWithDataSource:self];
                SAFE_ARC_AUTORELEASE(reader);
                
                [self.threadReaderPool addObject:reader];
            }
        }
    } while (NO);
}

- (void)decreaseThreadReaderPoolTo:(NSUInteger)anThreadReaderCount {
    do {
        @synchronized(self) {
            NSUInteger diff = [self.threadReaderPool count] - anThreadReaderCount;
            NSUInteger decreaseCount = 0;
            NSUInteger idx = 0;
            while (idx < [self.threadReaderPool count] && decreaseCount < diff) {
                DCDataStoreReader *reader = [self.threadReaderPool objectAtIndex:idx];
                if (!reader.busy) {
                    [self.threadReaderPool removeObjectAtIndex:idx];
                    ++decreaseCount;
                } else {
                    ++idx;
                }
            }
        }
    } while (NO);
}

- (BOOL)saveWriterSynchronous:(BOOL)isSync {
    BOOL result = YES;
    do {
        if (!self.writer) {
            break;
        }
        @synchronized(self) {
            NSError *err = nil;
            if (isSync) {
                if (![self.writer syncSave:&err]) {
                    result = NO;
                }
            } else {
                if (![self.writer asyncSave:&err]) {
                    result = NO;
                }
            }
        }
    } while (NO);
    return result;
}

#pragma mark - DCDataStore - DCDataStoreOperatorDataSource
- (NSManagedObjectModel *)managedObjectModel {
    return self.model;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    return self.coordinator;
}

@end
