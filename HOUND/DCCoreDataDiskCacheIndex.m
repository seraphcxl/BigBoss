//
//  DCCoreDataDiskCacheIndex.m
//  HOUND_Mac
//
//  Created by Derek Chen on 13-7-4.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import "DCCoreDataDiskCacheIndex.h"
#import "DCDataStoreManager.h"
#import "DCDataStoreOperator.h"
#import "DCCoreDataDiskCacheEntity.h"
#import "DCDataStoreReader.h"
#import "DCDataStoreWriter.h"

const float DCCoreDataDiskCacheIndexTrimLevel_Low = 0.8f;
const float DCCoreDataDiskCacheIndexTrimLevel_Middle = 0.6f;
const float DCCoreDataDiskCacheIndexTrimLevel_High = 0.4f;

@interface DCCoreDataDiskCacheIndex () {
}

- (NSEntityDescription *)_dataDiskCacheEntity;
- (DCDataStore *)_dataStore;
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
            _dataStoreUUID = [dataStoreUUID copy];
            _fileDelegate = fileDelegate;
            self.trimLevel = DCCoreDataDiskCacheIndexTrimLevel_Middle;
            
            DCDataStore *dataStore = [[DCDataStore alloc] initWithDataSource:self];
            SAFE_ARC_AUTORELEASE(dataStore);
            
            [[DCDataStoreManager sharedDCDataStoreManager] addDataStore:dataStore];
        }
        return self;
    }
}

- (void)dealloc {
    do {
        @synchronized(self) {
            [[DCDataStoreManager sharedDCDataStoreManager] removeDataStore:[self _dataStore]];
            
            SAFE_ARC_SAFERELEASE(_dataStoreUUID);
            
            _fileDelegate = nil;
        }
        SAFE_ARC_SUPER_DEALLOC();
    } while (NO);
}

- (NSString *)dataUUIDForKey:(NSString *)key {
    __block NSString *result = nil;
    do {
        if (!key || key.length == 0) {
            break;
        }
        @synchronized(self) {
            DCDataStore *dataStore = [self _dataStore];
            if (!dataStore) {
                break;
            }
            DCDataStoreReader *reader = [dataStore queryReader];
            if (!reader) {
                break;
            }
            __block BOOL taskResult = NO;
            [reader doTask:^(id<DCDataStoreTaskDataSource> taskDataSource) {
                NSManagedObjectModel *model = [taskDataSource managedObjectModel];
                NSManagedObjectContext *context = [taskDataSource managedObjectContext];
                
                NSArray *fetchResult = [self fetchEntitiesFormContext:context model:model forKey:key];
                if ([fetchResult count] != 1) {
                    NSAssert(0, @"[fetchResult count] != 1");
                }
                DCCoreDataDiskCacheEntity *dataEntity = [fetchResult objectAtIndex:0];
                result = [dataEntity.uuid copy];
                SAFE_ARC_AUTORELEASE(result);
                taskResult = YES;
            }];
            if (!taskResult) {
                result = nil;
                break;
            }
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
        CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
        NSString *uuidStr = (__bridge NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
        CFRelease(uuid);
        @synchronized(self) {
            DCDataStore *dataStore = [self _dataStore];
            if (!dataStore) {
                break;
            }
            DCDataStoreWriter *writer = [dataStore queryWriter];
            if (!writer) {
                break;
            }
            __block BOOL taskResult = NO;
            __block NSString *willDeleteUUIDStr = nil;
            __block NSUInteger willDeleteDataSize = 0;
            [writer doTask:^(id<DCDataStoreTaskDataSource> taskDataSource) {
                do {
                    NSManagedObjectModel *model = [taskDataSource managedObjectModel];
                    NSManagedObjectContext *context = [taskDataSource managedObjectContext];
                    DCCoreDataDiskCacheEntity *dataEntity = nil;
                    NSArray *fetchResult = [self fetchEntitiesFormContext:context model:model forKey:key];
                    NSInteger fetchResultCount = [fetchResult count];
                    if (fetchResultCount== 1) {
                        dataEntity = [fetchResult objectAtIndex:0];
                        
                        willDeleteUUIDStr = [dataEntity.uuid copy];
                        SAFE_ARC_AUTORELEASE(willDeleteUUIDStr);
                        willDeleteDataSize = [dataEntity.dataSize unsignedIntegerValue];
                        
                        dataEntity.uuid = uuidStr;
                        dataEntity.dataSize = [NSNumber numberWithUnsignedInteger:data.length];
                        [dataEntity registerAccess];
                    } else if (fetchResultCount == 0) {
                        dataEntity = [NSEntityDescription insertNewObjectForEntityForName:@"DCDataDiskCacheEntity" inManagedObjectContext:context];
                        dataEntity.uuid = uuidStr;
                        dataEntity.key = key;
                        dataEntity.dataSize = [NSNumber numberWithUnsignedInteger:data.length];
                        [dataEntity registerAccess];
                    } else {
                        NSAssert(0, @"[fetchResult count] > 1");
                        break;
                    }
                    
                    NSError *err = nil;
                    if (![context save:&err]) {
                        DCLog_Error(@"[writer syncSave:&err] err:%@", [err localizedDescription]);
                        break;
                    }
                    taskResult = YES;
                } while (NO);
            }];
            if (!taskResult) {
                break;
            }
            _currentDiskUsage -= willDeleteDataSize;
            
            if (self.fileDelegate && [self.fileDelegate respondsToSelector:@selector(cacheIndex:deleteFileWithUUID:)]) {
                [self.fileDelegate cacheIndex:self deleteFileWithUUID:willDeleteUUIDStr];
            }
            
            _currentDiskUsage += data.length;
            
            if (self.fileDelegate && [self.fileDelegate respondsToSelector:@selector(cacheIndex:writeFileWithUUID:data:)]) {
                [self.fileDelegate cacheIndex:self writeFileWithUUID:uuidStr data:data];
            }
            
            if (self.currentDiskUsage > self.diskCapacity) {
                [self _trimDataStore];
            }
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
            DCDataStore *dataStore = [self _dataStore];
            if (!dataStore) {
                break;
            }
            DCDataStoreWriter *writer = [dataStore queryWriter];
            if (!writer) {
                break;
            }
            __block NSUInteger dataSize = 0;
            __block NSString *willDeleteUUIDStr = nil;
            __block BOOL taskResult = NO;
            [writer doTask:^(id<DCDataStoreTaskDataSource> taskDataSource) {
                do {
                    NSManagedObjectModel *model = [taskDataSource managedObjectModel];
                    NSManagedObjectContext *context = [taskDataSource managedObjectContext];
                    
                    NSArray *fetchResult = [self fetchEntitiesFormContext:context model:model forKey:key];
                    if ([fetchResult count] != 1) {
                        NSAssert(0, @"[fetchResult count] != 1");
                    }
                    DCCoreDataDiskCacheEntity *dataEntity = [fetchResult objectAtIndex:0];
                    dataSize = [dataEntity.dataSize unsignedIntegerValue];
                    willDeleteUUIDStr = [dataEntity.uuid copy];
                    SAFE_ARC_AUTORELEASE(willDeleteUUIDStr);
                    [context deleteObject:dataEntity];
                    NSError *err = nil;
                    if (![context save:&err]) {
                        DCLog_Error(@"[writer syncSave:&err] err:%@", [err localizedDescription]);
                        break;
                    }
                    taskResult = YES;
                } while (NO);
            }];
            if (!taskResult) {
                break;
            }
            
            if (self.fileDelegate && [self.fileDelegate respondsToSelector:@selector(cacheIndex:deleteFileWithUUID:)]) {
                [self.fileDelegate cacheIndex:self deleteFileWithUUID:willDeleteUUIDStr];
            }
            NSAssert(self.currentDiskUsage - dataSize >= 0, @"self.currentDiskUsage - dataSize < 0");
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
            SAFE_ARC_AUTORELEASE(uuidAttrDesc);
            [uuidAttrDesc setName:@"uuid"];
            [uuidAttrDesc setAttributeType:NSStringAttributeType];
            [uuidAttrDesc setOptional:NO];
            
            NSAttributeDescription *keyAttrDesc = [[NSAttributeDescription alloc] init];
            SAFE_ARC_AUTORELEASE(keyAttrDesc);
            [keyAttrDesc setName:@"key"];
            [keyAttrDesc setAttributeType:NSStringAttributeType];
            [keyAttrDesc setOptional:NO];
            
            NSAttributeDescription *accessTimeAttrDesc = [[NSAttributeDescription alloc] init];
            SAFE_ARC_AUTORELEASE(accessTimeAttrDesc);
            [accessTimeAttrDesc setName:@"accessTime"];
            [accessTimeAttrDesc setAttributeType:NSDateAttributeType];
            [accessTimeAttrDesc setOptional:NO];
            
            NSAttributeDescription *dataSizeAttrDesc = [[NSAttributeDescription alloc] init];
            SAFE_ARC_AUTORELEASE(dataSizeAttrDesc);
            [dataSizeAttrDesc setName:@"dataSize"];
            [dataSizeAttrDesc setAttributeType:NSInteger64AttributeType];
            [dataSizeAttrDesc setOptional:NO];
            
            NSArray *properties = [NSArray arrayWithObjects:uuidAttrDesc, keyAttrDesc, accessTimeAttrDesc, dataSizeAttrDesc, nil];
            result = [[NSEntityDescription alloc] init];
            SAFE_ARC_AUTORELEASE(result);
            [result setName:@"DCDataDiskCacheEntity"];
            [result setManagedObjectClassName:@"DCDataDiskCacheEntity"];
            [result setProperties:properties];
        }
    } while (NO);
    return result;
}

- (DCDataStore *)_dataStore {
    DCDataStore *result = nil;
    do {
        if (!self.dataStoreUUID) {
            break;
        }
        result = [[DCDataStoreManager sharedDCDataStoreManager] getDataSource:self.dataStoreUUID];
    } while (NO);
    return result;
}

- (void)_trimDataStore {
    do {
        @synchronized(self) {
            NSAssert(self.currentDiskUsage > self.diskCapacity, @"self.currentDiskUsage <= self.diskCapacity in _trimDataStore");
            if (self.currentDiskUsage <= self.diskCapacity) {
                break;
            }
            DCDataStore *dataStore = [self _dataStore];
            if (!dataStore) {
                break;
            }
            DCDataStoreWriter *writer = [dataStore queryWriter];
            if (!writer) {
                break;
            }
            NSUInteger targetDiskCapacity = self.diskCapacity * self.trimLevel;
            __block NSUInteger currentDiskUsageForBlock = self.currentDiskUsage;
            __block NSMutableArray *willDeleteUUIDAry = [NSMutableArray array];
            __block BOOL taskResult = NO;
            [writer doTask:^(id<DCDataStoreTaskDataSource> taskDataSource) {
                do {
                    NSManagedObjectModel *model = [taskDataSource managedObjectModel];
                    NSManagedObjectContext *context = [taskDataSource managedObjectContext];
                    
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
                    SAFE_ARC_AUTORELEASE(fetch);
                    [fetch setEntity:entity];
                    [fetch setPredicate:predicate];
                    [fetch setSortDescriptors:[NSArray arrayWithObjects:accessTimeSortDesc, dataSizeSortDesc, nil]];
                    NSArray *fetchResult = [context executeFetchRequest:fetch error:nil];
                    NSInteger idx = 0;
                    do {
                        if (currentDiskUsageForBlock <= targetDiskCapacity) {
                            break;
                        }
                        DCCoreDataDiskCacheEntity *dataEntity = [fetchResult objectAtIndex:idx];
                        currentDiskUsageForBlock -= [dataEntity.dataSize unsignedIntegerValue];
                        NSString *willDeleteUUIDStr = [dataEntity.uuid copy];
                        SAFE_ARC_AUTORELEASE(willDeleteUUIDStr);
                        [willDeleteUUIDAry addObject:willDeleteUUIDStr];
                        [context deleteObject:dataEntity];
                    } while (currentDiskUsageForBlock > targetDiskCapacity);
                    NSError *err = nil;
                    if (![context save:&err]) {
                        DCLog_Error(@"[writer syncSave:&err] err:%@", [err localizedDescription]);
                        break;
                    }
                    taskResult = YES;
                } while (NO);
            }];
            if (!taskResult) {
                break;
            }
            
            if (self.fileDelegate && [self.fileDelegate respondsToSelector:@selector(cacheIndex:deleteFileWithUUID:)]) {
                for (NSString *willDeleteUUIDStr in willDeleteUUIDAry) {
                    [self.fileDelegate cacheIndex:self deleteFileWithUUID:willDeleteUUIDStr];
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
        @synchronized(self) {
            NSPredicate* predicate = [NSPredicate predicateWithFormat:@"key == %@", key];
            NSDictionary *entities = [model entitiesByName];
            NSEntityDescription *entity = [entities valueForKey:@"DCDataDiskCacheEntity"];
            NSFetchRequest *fetch = [[NSFetchRequest alloc] init];
            SAFE_ARC_AUTORELEASE(fetch);
            [fetch setEntity:entity];
            [fetch setPredicate:predicate];
            result = [context executeFetchRequest:fetch error:nil];
        }
    } while (NO);
    return result;
}

#pragma mark - DCDataDiskCacheIndex - DCDataStoreDataSource
- (NSURL *)urlForDataStore:(DCDataStore *)dataStore {
    NSURL *result = nil;
    do {
        if (!dataStore) {
            break;
        }
        result = [NSURL fileURLWithPath:self.dataStoreUUID];
    } while (NO);
    return result;
}

- (void)dataStore:(DCDataStore *)dataStore initModel:(NSManagedObjectModel *)model {
    do {
        if (!dataStore || !model) {
            break;
        }
        [model setEntities:[NSArray arrayWithObjects:[self _dataDiskCacheEntity], nil]];
    } while (NO);
}

@end
