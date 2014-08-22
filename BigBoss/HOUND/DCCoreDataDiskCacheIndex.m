//
//  DCCoreDataDiskCacheIndex.m
//  HOUND_Mac
//
//  Created by Derek Chen on 13-7-4.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import "DCCoreDataDiskCacheIndex.h"
#import "DCCoreDataDiskCacheEntity.h"
#import "DCCoreDataStore.h"
#import "DCCoreDataStoreManager.h"
#import "DCCoreDataDiskCacheIndexInfo.h"

const float DCCoreDataDiskCacheIndexTrimLevel_Low = 0.8f;
const float DCCoreDataDiskCacheIndexTrimLevel_Middle = 0.6f;
const float DCCoreDataDiskCacheIndexTrimLevel_High = 0.4f;

@interface DCCoreDataDiskCacheIndex () {
}

@property (nonatomic, assign) NSUInteger currentDiskUsage;
@property (nonatomic, copy) NSString *dataStoreUUID;

- (NSEntityDescription *)_dataDiskCacheEntity;
- (DCCoreDataStore *)_dataStore;
- (void)_trimDataStore;
- (NSArray *)fetchEntitiesFormContext:(NSManagedObjectContext *)context model:(NSManagedObjectModel *)model forKey:(NSString *)key;

@end

@implementation DCCoreDataDiskCacheIndex
@synthesize fileDelegate = _fileDelegate;
@synthesize currentDiskUsage = _currentDiskUsage;
@synthesize diskCapacity = _diskCapacity;
@synthesize trimLevel = _trimLevel;
@synthesize dataStoreUUID = _dataStoreUUID;

#pragma mark - DCDataDiskCacheIndex - Public method

- (id)initWithDataStoreUUID:(NSString *)dataStoreUUID andFileDelegate:(id<DCCoreDataDiskCacheIndexFileDelegate>)fileDelegate {
    @synchronized(self) {
        if (!dataStoreUUID || dataStoreUUID.length == 0 || !fileDelegate) {
            return nil;
        }
        self = [super init];
        if (self) {
            self.dataStoreUUID = dataStoreUUID;
            self.fileDelegate = fileDelegate;
            self.trimLevel = DCCoreDataDiskCacheIndexTrimLevel_Middle;
            
            DCCoreDataStore *dataStore = [[DCCoreDataStore alloc] initWithQueryPSCURLBlock:^NSURL *{
                NSURL *result = nil;
                do {
                    if (!_dataStoreUUID) {
                        break;
                    }
                    result = [NSURL fileURLWithPath:_dataStoreUUID];
                } while (NO);
                return result;
            } configureEntityBlock:^(NSManagedObjectModel *aModel) {
                do {
                    if (!aModel) {
                        break;
                    }
                    [aModel setEntities:[NSArray arrayWithObjects:[self _dataDiskCacheEntity], nil]];
                } while (NO);
            } andContextCacheLimit:4];
            
            [[DCCoreDataStoreManager sharedDCCoreDataStoreManager] addDataStore:dataStore];
        }
        return self;
    }
}

- (void)dealloc {
    do {
        @synchronized(self) {
            self.fileDelegate = nil;
            
            [[DCCoreDataStoreManager sharedDCCoreDataStoreManager] removeDataStoreByURL:_dataStoreUUID];
            
            self.dataStoreUUID = nil;
        }
        SAFE_ARC_SUPER_DEALLOC();
    } while (NO);
}

- (DCCoreDataDiskCacheIndexInfo *)dataIndexInfoForKey:(NSString *)key {
    __block DCCoreDataDiskCacheIndexInfo *result = nil;
    do {
        if (!key || key.length == 0) {
            break;
        }
        DCCoreDataStore *dataStore = [self _dataStore];
        if (!dataStore) {
            break;
        }
        __block BOOL taskResult = NO;
        [dataStore syncAction:^(NSManagedObjectModel *model, NSManagedObjectContext *moc, BOOL *shouldCacheContext, NSError *__autoreleasing *err) {
            do {
                if (!model || !moc) {
                    break;
                }
                NSArray *fetchResult = [self fetchEntitiesFormContext:moc model:model forKey:key];
                if ([fetchResult count] != 1) {
                    NSAssert(0, @"[fetchResult count] != 1");
                }
                DCCoreDataDiskCacheEntity *dataEntity = [fetchResult objectAtIndex:0];
                result = [[DCCoreDataDiskCacheIndexInfo alloc] init];
                result.uuid = dataEntity.uuid;
                result.compressed = [dataEntity.compressed boolValue];
                
                (*shouldCacheContext) = YES;
                
                taskResult = YES;
            } while (NO);
        } withConfigureBlock:nil];
        
        if (!taskResult) {
            result = nil;
            break;
        }
    } while (NO);
    return result;
}

- (NSString *)storeData:(NSData *)data forKey:(NSString *)key {
    NSString *result = nil;
    do {
        if (!data || !key || key.length == 0) {
            break;
        }
        NSString *uuid = [NSObject createUniqueStrByUUID];
        DCCoreDataStore *dataStore = [self _dataStore];
        if (!dataStore) {
            break;
        }
        
        BOOL shouldCompressData = NO;
        @synchronized(self) {
            if (_fileDelegate && [_fileDelegate respondsToSelector:@selector(cacheIndexShouldCompressData:)]) {
                shouldCompressData = [_fileDelegate cacheIndexShouldCompressData:self];
            }
        }
        
        __block BOOL taskResult = NO;
        __block NSString *willDeleteUUIDStr = nil;
        __block NSUInteger willDeleteDataSize = 0;
        [dataStore syncAction:^(NSManagedObjectModel *model, NSManagedObjectContext *moc, BOOL *shouldCacheContext, NSError *__autoreleasing *err) {
            do {
                if (!model || !moc) {
                    break;
                }
                DCCoreDataDiskCacheEntity *dataEntity = nil;
                NSArray *fetchResult = [self fetchEntitiesFormContext:moc model:model forKey:key];
                NSInteger fetchResultCount = [fetchResult count];
                if (fetchResultCount== 1) {
                    dataEntity = [fetchResult objectAtIndex:0];
                    
                    willDeleteUUIDStr = [dataEntity.uuid copy];
                    willDeleteDataSize = [dataEntity.dataSize unsignedIntegerValue];
                    
                    dataEntity.uuid = uuid;
                    dataEntity.dataSize = [NSNumber numberWithUnsignedInteger:data.length];
                    dataEntity.compressed = [NSNumber numberWithBool:shouldCompressData];
                    [dataEntity registerAccess];
                } else if (fetchResultCount == 0) {
                    dataEntity = [NSEntityDescription insertNewObjectForEntityForName:@"DCDataDiskCacheEntity" inManagedObjectContext:moc];
                    dataEntity.uuid = uuid;
                    dataEntity.key = key;
                    dataEntity.dataSize = [NSNumber numberWithUnsignedInteger:data.length];
                    dataEntity.compressed = [NSNumber numberWithBool:shouldCompressData];
                    [dataEntity registerAccess];
                } else {
                    NSAssert(0, @"[fetchResult count] > 1");
                    break;
                }
                
                NSError *err = nil;
                if (![moc save:&err]) {
                    DCLog_Error(@"[writer syncSave:&err] err:%@", [err localizedDescription]);
                    break;
                }
                
                (*shouldCacheContext) = NO;
                
                taskResult = YES;
            } while (NO);
        } withConfigureBlock:nil];
        
        if (!taskResult) {
            break;
        }
        
        @synchronized(self) {
            _currentDiskUsage -= willDeleteDataSize;
            
            if (_fileDelegate && [_fileDelegate respondsToSelector:@selector(cacheIndex:deleteFileWithUUID:)]) {
                [_fileDelegate cacheIndex:self deleteFileWithUUID:willDeleteUUIDStr];
            }
            
            _currentDiskUsage += data.length;
            
            if (_fileDelegate && [_fileDelegate respondsToSelector:@selector(cacheIndex:writeFileWithUUID:data:compress:)]) {
                [_fileDelegate cacheIndex:self writeFileWithUUID:uuid data:data compress:shouldCompressData];
            }
            
            if (_currentDiskUsage > _diskCapacity) {
                [self _trimDataStore];
            }
        }
        
        result = [uuid copy];
    } while (NO);
    return result;
}

- (NSArray *)storeDataArray:(NSArray *)dataArray forKeyArray:(NSArray *)keyArray {
    NSArray *result = nil;
    do {
        if (!dataArray || !keyArray || [dataArray count] != [keyArray count] || [keyArray count] == 0) {
            break;
        }
        DCCoreDataStore *dataStore = [self _dataStore];
        if (!dataStore) {
            break;
        }
        
        BOOL shouldCompressData = NO;
        @synchronized(self) {
            if (_fileDelegate && [_fileDelegate respondsToSelector:@selector(cacheIndexShouldCompressData:)]) {
                shouldCompressData = [_fileDelegate cacheIndexShouldCompressData:self];
            }
        }
        
        __block BOOL taskResult = NO;
        __block NSMutableArray *tmpUUIDAry = [NSMutableArray array];
        __block NSMutableArray *willDeleteUUIDStrAry = [NSMutableArray array];
        __block NSUInteger willAddDataSize = 0;
        __block NSUInteger willDeleteDataSize = 0;
        [dataStore syncAction:^(NSManagedObjectModel *model, NSManagedObjectContext *moc, BOOL *shouldCacheContext, NSError *__autoreleasing *err) {
            do {
                if (!model || !moc) {
                    break;
                }
                
                NSUInteger count = [keyArray count];
                for (NSUInteger idx = 0; idx < count; ++idx) {
                    taskResult = NO;
                    
                    NSData *data = [dataArray objectAtIndex:idx];
                    NSString *key = [keyArray objectAtIndex:idx];
                    if (!data || !key || key.length == 0) {
                        break;
                    }
                    NSString *uuid = [NSObject createUniqueStrByUUID];
                    DCCoreDataDiskCacheEntity *dataEntity = nil;
                    NSArray *fetchResult = [self fetchEntitiesFormContext:moc model:model forKey:key];
                    NSInteger fetchResultCount = [fetchResult count];
                    if (fetchResultCount== 1) {
                        dataEntity = [fetchResult objectAtIndex:0];
                        
                        [willDeleteUUIDStrAry addObject:dataEntity.uuid];
                        willDeleteDataSize += [dataEntity.dataSize unsignedIntegerValue];
                        
                        dataEntity.uuid = uuid;
                        dataEntity.dataSize = [NSNumber numberWithUnsignedInteger:data.length];
                        dataEntity.compressed = [NSNumber numberWithBool:shouldCompressData];
                        [dataEntity registerAccess];
                    } else if (fetchResultCount == 0) {
                        dataEntity = [NSEntityDescription insertNewObjectForEntityForName:@"DCDataDiskCacheEntity" inManagedObjectContext:moc];
                        dataEntity.uuid = uuid;
                        dataEntity.key = key;
                        dataEntity.dataSize = [NSNumber numberWithUnsignedInteger:data.length];
                        dataEntity.compressed = [NSNumber numberWithBool:shouldCompressData];
                        [dataEntity registerAccess];
                    } else {
                        NSAssert(0, @"[fetchResult count] > 1");
                        break;
                    }
                    
                    willAddDataSize += data.length;
                    [tmpUUIDAry addObject:uuid];
                    
                    taskResult = YES;
                }
                if (taskResult) {
                    NSError *err = nil;
                    if (![moc save:&err]) {
                        DCLog_Error(@"[writer syncSave:&err] err:%@", [err localizedDescription]);
                        break;
                    }
                }
                
                (*shouldCacheContext) = NO;
                
            } while (NO);
        } withConfigureBlock:nil];
        
        if (!taskResult) {
            break;
        }
        
        @synchronized(self) {
            _currentDiskUsage -= willDeleteDataSize;
            
            if (_fileDelegate && [_fileDelegate respondsToSelector:@selector(cacheIndex:deleteFileWithUUID:)]) {
                for (NSString *willDeleteUUIDStr in willDeleteUUIDStrAry) {
                    [_fileDelegate cacheIndex:self deleteFileWithUUID:willDeleteUUIDStr];
                }
            }
            
            _currentDiskUsage += willAddDataSize;
            
            if (_fileDelegate && [_fileDelegate respondsToSelector:@selector(cacheIndex:writeFileWithUUID:data:compress:)]) {
                NSUInteger count = [keyArray count];
                for (NSUInteger idx = 0; idx < count; ++idx) {
                    NSData *data = [dataArray objectAtIndex:idx];
                    NSString *uuidStr = [tmpUUIDAry objectAtIndex:idx];
                    
                    [_fileDelegate cacheIndex:self writeFileWithUUID:uuidStr data:data compress:shouldCompressData];
                }
            }
            
            if (_currentDiskUsage > _diskCapacity) {
                [self _trimDataStore];
            }
        }
        
        result = tmpUUIDAry;
    } while (NO);
    return result;
}

- (void)removeEntryForKey:(NSString *)key {
    do {
        if (!key || key.length == 0) {
            break;
        }
        DCCoreDataStore *dataStore = [self _dataStore];
        if (!dataStore) {
            break;
        }
        __block NSUInteger dataSize = 0;
        __block NSString *willDeleteUUIDStr = nil;
        __block BOOL taskResult = NO;
        [dataStore syncAction:^(NSManagedObjectModel *model, NSManagedObjectContext *moc, BOOL *shouldCacheContext, NSError *__autoreleasing *err) {
            do {
                if (!model || !moc) {
                    break;
                }
                NSArray *fetchResult = [self fetchEntitiesFormContext:moc model:model forKey:key];
                if ([fetchResult count] != 1) {
                    NSAssert(0, @"[fetchResult count] != 1");
                }
                DCCoreDataDiskCacheEntity *dataEntity = [fetchResult objectAtIndex:0];
                dataSize = [dataEntity.dataSize unsignedIntegerValue];
                willDeleteUUIDStr = [dataEntity.uuid copy];
                [moc deleteObject:dataEntity];
                NSError *err = nil;
                if (![moc save:&err]) {
                    DCLog_Error(@"[writer syncSave:&err] err:%@", [err localizedDescription]);
                    break;
                }
                
                (*shouldCacheContext) = NO;
                
                taskResult = YES;
            } while (NO);
        } withConfigureBlock:nil];
        
        if (!taskResult) {
            break;
        }
        @synchronized(self) {
            if (_fileDelegate && [_fileDelegate respondsToSelector:@selector(cacheIndex:deleteFileWithUUID:)]) {
                [_fileDelegate cacheIndex:self deleteFileWithUUID:willDeleteUUIDStr];
            }
            
            NSAssert(_currentDiskUsage - dataSize >= 0, @"_currentDiskUsage - dataSize < 0");
            _currentDiskUsage -= dataSize;
        }
    } while (NO);
}

- (void)removeEntryForKeyArray:(NSArray *)keyArray {
    do {
        if (!keyArray || [keyArray count] == 0) {
            break;
        }
        DCCoreDataStore *dataStore = [self _dataStore];
        if (!dataStore) {
            break;
        }
        __block NSUInteger dataSize = 0;
        __block NSMutableArray *willDeleteUUIDStrAry = [NSMutableArray array];
        __block BOOL taskResult = NO;
        [dataStore syncAction:^(NSManagedObjectModel *model, NSManagedObjectContext *moc, BOOL *shouldCacheContext, NSError *__autoreleasing *err) {
            do {
                if (!model || !moc) {
                    break;
                }
                
                for (NSString *key in keyArray) {
                    taskResult = NO;
                    if (!key || key.length == 0) {
                        break;
                    }
                    NSArray *fetchResult = [self fetchEntitiesFormContext:moc model:model forKey:key];
                    if ([fetchResult count] != 1) {
                        NSAssert(0, @"[fetchResult count] != 1");
                    }
                    DCCoreDataDiskCacheEntity *dataEntity = [fetchResult objectAtIndex:0];
                    dataSize += [dataEntity.dataSize unsignedIntegerValue];
                    [willDeleteUUIDStrAry addObject:dataEntity.uuid];
                    [moc deleteObject:dataEntity];
                    
                    taskResult = YES;
                }
                
                if (taskResult) {
                    NSError *err = nil;
                    if (![moc save:&err]) {
                        DCLog_Error(@"[writer syncSave:&err] err:%@", [err localizedDescription]);
                        break;
                    }
                }
                
                (*shouldCacheContext) = NO;
                
            } while (NO);
        } withConfigureBlock:^(NSManagedObjectContext *moc, NSError *__autoreleasing *err) {
            do {
                if (!moc) {
                    break;
                }
                //                    [[moc undoManager] disableUndoRegistration];
            } while (NO);
        }];
        
        if (!taskResult) {
            break;
        }
        @synchronized(self) {
            if (_fileDelegate && [_fileDelegate respondsToSelector:@selector(cacheIndex:deleteFileWithUUID:)]) {
                for (NSString *willDeleteUUIDStr in willDeleteUUIDStrAry) {
                    [_fileDelegate cacheIndex:self deleteFileWithUUID:willDeleteUUIDStr];
                }
            }
            
            NSAssert(_currentDiskUsage - dataSize >= 0, @"_currentDiskUsage - dataSize < 0");
            _currentDiskUsage -= dataSize;
        }
    } while (NO);
}

#pragma mark - DCDataDiskCacheIndex - Private method
- (NSEntityDescription *)_dataDiskCacheEntity {
    NSEntityDescription *result = nil;
    do {
        @synchronized(self) {
            NSAttributeDescription *uuidAttrDesc = [[NSAttributeDescription alloc] init];
            [uuidAttrDesc setName:@"uuid"];
            [uuidAttrDesc setAttributeType:NSStringAttributeType];
            [uuidAttrDesc setOptional:NO];
            
            NSAttributeDescription *keyAttrDesc = [[NSAttributeDescription alloc] init];
            [keyAttrDesc setName:@"key"];
            [keyAttrDesc setAttributeType:NSStringAttributeType];
            [keyAttrDesc setOptional:NO];
            
            NSAttributeDescription *accessTimeAttrDesc = [[NSAttributeDescription alloc] init];
            [accessTimeAttrDesc setName:@"accessTime"];
            [accessTimeAttrDesc setAttributeType:NSDateAttributeType];
            [accessTimeAttrDesc setOptional:NO];
            
            NSAttributeDescription *dataSizeAttrDesc = [[NSAttributeDescription alloc] init];
            [dataSizeAttrDesc setName:@"dataSize"];
            [dataSizeAttrDesc setAttributeType:NSInteger64AttributeType];
            [dataSizeAttrDesc setOptional:NO];
            
            NSAttributeDescription *compressedAttrDesc = [[NSAttributeDescription alloc] init];
            [compressedAttrDesc setName:@"compressed"];
            [compressedAttrDesc setAttributeType:NSInteger64AttributeType];
            [compressedAttrDesc setOptional:NO];
            
            NSArray *properties = [NSArray arrayWithObjects:uuidAttrDesc, keyAttrDesc, accessTimeAttrDesc, dataSizeAttrDesc, compressedAttrDesc, nil];
            result = [[NSEntityDescription alloc] init];
            [result setName:@"DCDataDiskCacheEntity"];
            [result setManagedObjectClassName:@"DCDataDiskCacheEntity"];
            [result setProperties:properties];
        }
    } while (NO);
    return result;
}

- (DCCoreDataStore *)_dataStore {
    DCCoreDataStore *result = nil;
    do {
        if (!_dataStoreUUID) {
            break;
        }
        result = [[DCCoreDataStoreManager sharedDCCoreDataStoreManager] getDataSource:_dataStoreUUID];
    } while (NO);
    return result;
}

- (void)_trimDataStore {
    do {
        @synchronized(self) {
            NSAssert(_currentDiskUsage > _diskCapacity, @"_currentDiskUsage <= _diskCapacity in _trimDataStore");
            if (_currentDiskUsage <= _diskCapacity) {
                break;
            }
        }
        
        DCCoreDataStore *dataStore = [self _dataStore];
        if (!dataStore) {
            break;
        }
        NSUInteger targetDiskCapacity = _diskCapacity * _trimLevel;
        __block NSUInteger currentDiskUsageForBlock = _currentDiskUsage;
        __block NSMutableArray *willDeleteUUIDAry = [NSMutableArray array];
        __block BOOL taskResult = NO;
        [dataStore syncAction:^(NSManagedObjectModel *model, NSManagedObjectContext *moc, BOOL *shouldCacheContext, NSError *__autoreleasing *err) {
            do {
                if (!model || !moc) {
                    break;
                }
                NSPredicate* predicate = [NSPredicate predicateWithFormat:@""];
                NSDictionary *entities = [model entitiesByName];
                NSEntityDescription *entity = [entities valueForKey:@"DCDataDiskCacheEntity"];
                NSSortDescriptor *accessTimeSortDesc = [NSSortDescriptor sortDescriptorWithKey:@"accessTime" ascending:NO comparator:^NSComparisonResult(id obj1, id obj2) {
                    NSDate *left = (NSDate *)obj1;
                    NSDate *right = (NSDate *)obj2;
                    return [left compare:right];
                }];
                NSSortDescriptor *dataSizeSortDesc = [NSSortDescriptor sortDescriptorWithKey:@"dataSize" ascending:YES comparator:^NSComparisonResult(id obj1, id obj2) {
                    NSNumber *left = (NSNumber *)obj1;
                    NSNumber *right = (NSNumber *)obj2;
                    return [left compare:right];
                }];
                NSFetchRequest *fetch = [[NSFetchRequest alloc] init];
                [fetch setEntity:entity];
                [fetch setPredicate:predicate];
                [fetch setSortDescriptors:[NSArray arrayWithObjects:accessTimeSortDesc, dataSizeSortDesc, nil]];
                NSArray *fetchResult = [moc executeFetchRequest:fetch error:nil];
                NSInteger idx = 0;
                do {
                    if (currentDiskUsageForBlock <= targetDiskCapacity) {
                        break;
                    }
                    DCCoreDataDiskCacheEntity *dataEntity = [fetchResult objectAtIndex:idx];
                    currentDiskUsageForBlock -= [dataEntity.dataSize unsignedIntegerValue];
                    NSString *willDeleteUUIDStr = [dataEntity.uuid copy];
                    [willDeleteUUIDAry addObject:willDeleteUUIDStr];
                    [moc deleteObject:dataEntity];
                } while (currentDiskUsageForBlock > targetDiskCapacity);
                NSError *err = nil;
                if (![moc save:&err]) {
                    DCLog_Error(@"[writer syncSave:&err] err:%@", [err localizedDescription]);
                    break;
                }
                
                (*shouldCacheContext) = NO;
                
                taskResult = YES;
            } while (NO);
        } withConfigureBlock:nil];
        
        if (!taskResult) {
            break;
        }
        @synchronized(self) {
            if (_fileDelegate && [_fileDelegate respondsToSelector:@selector(cacheIndex:deleteFileWithUUID:)]) {
                for (NSString *willDeleteUUIDStr in willDeleteUUIDAry) {
                    [_fileDelegate cacheIndex:self deleteFileWithUUID:willDeleteUUIDStr];
                }
            }
            _currentDiskUsage = currentDiskUsageForBlock;
        }
    } while (NO);
}

- (NSArray *)fetchEntitiesFormContext:(NSManagedObjectContext *)context model:(NSManagedObjectModel *)model forKey:(NSString *)key {
    NSArray *result = nil;
    do {
        if (!context || !model || !key || key.length == 0) {
            break;
        }
        NSPredicate* predicate = [NSPredicate predicateWithFormat:@"key == %@", key];
        NSDictionary *entities = [model entitiesByName];
        NSEntityDescription *entity = [entities valueForKey:@"DCDataDiskCacheEntity"];
        NSFetchRequest *fetch = [[NSFetchRequest alloc] init];
        [fetch setEntity:entity];
        [fetch setPredicate:predicate];
        result = [context executeFetchRequest:fetch error:nil];
    } while (NO);
    return result;
}

@end
