//
//  DCDataStore.m
//  TestApp4CoreData
//
//  Created by Derek Chen on 13-6-4.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import "DCDataStore.h"
#import "DCDataStoreOperator.h"

@interface DCDataStore () <DCDataStoreOperatorDataSource> {
}

@property (SAFE_ARC_PROP_STRONG) NSMutableArray *operatorPool;
@property (atomic, unsafe_unretained) NSUInteger lastUsingOperatorIndex;
@property (nonatomic, SAFE_ARC_PROP_STRONG, readonly) DCDataStoreOperator *mainThreadOperator;

+ (NSString *)archivePath;

- (BOOL)initDataStore;
- (NSURL *)url;
- (void)cleanOperatorPool;
- (void)mergeContextChanges:(NSNotification *)aNotification;

- (void)increaseOperatorPoolTo:(NSUInteger)anOperatorCount;
- (void)decreaseOperatorPoolTo:(NSUInteger)anOperatorCount;

- (BOOL)saveMainThreadOperatorSynchronous:(BOOL)isSync;
- (BOOL)saveAllOperatorInPoolSynchronous:(BOOL)isSync;

@end

@implementation DCDataStore

@synthesize dataSource = _dataSource;
@synthesize model = _model;
@synthesize coordinator = _coordinator;
@synthesize operatorPool = _operatorPool;
@synthesize lastUsingOperatorIndex = _lastUsingOperatorIndex;
@synthesize mainThreadOperator = _mainThreadOperator;

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
            
            [self cleanOperatorPool];
            self.operatorPool = [NSMutableArray array];
            
            [self initDataStore];
            
            _mainThreadOperator = [[DCDataStoreOperator alloc] initWithDataSource:self];
            
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mergeContextChanges:) name:NSManagedObjectContextDidSaveNotification object:nil];
        }
        return self;
    }
}

- (void)dealloc {
    do {
        @synchronized(self) {
            [[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextDidSaveNotification object:nil];
            
            [self cleanOperatorPool];
            
            if (_mainThreadOperator) {
                [self saveMainThreadOperatorSynchronous:YES];
                SAFE_ARC_SAFERELEASE(_mainThreadOperator);
            }
            
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
        if (self.dataSource && [self.dataSource respondsToSelector:@selector(dataStoreManager:initModel:)]) {
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

- (NSUInteger)operatorCount {
    NSUInteger result = 0;
    do {
        if (!self.operatorPool) {
            break;
        }
        @synchronized(self) {
            result = [self.operatorPool count];
        }
    } while (NO);
    return result;
}

- (void)setOperatorCount:(NSUInteger)anOperatorCount {
    do {
        if (anOperatorCount == 0) {
            break;
        }
        @synchronized(self) {
            if ([self.operatorPool count] > anOperatorCount) {
                [self decreaseOperatorPoolTo:anOperatorCount];
                
                self.lastUsingOperatorIndex = [self.operatorPool count];
            } else if ([self.operatorPool count] < anOperatorCount) {
                [self increaseOperatorPoolTo:anOperatorCount];
            }
        }
    } while (NO);
}

- (DCDataStoreOperator *)queryOperator {
    DCDataStoreOperator *result = nil;
    do {
        if (!self.operatorPool) {
            break;
        }
        @synchronized(self) {
            if (!self.mainThreadOperator && [self.operatorPool count] == 0) {
                break;
            }
            
            BOOL find = NO;
            
            if ([[NSThread currentThread] isMainThread]) {
                if (!self.mainThreadOperator.busy) {
                    result = self.mainThreadOperator;
                    find = YES;
                }
                
                if (find) {
                    break;
                }
            }
            
            for (DCDataStoreOperator *operator in self.operatorPool) {
                if (!operator.busy) {
                    result = operator;
                    find = YES;
                    break;
                }
            }
            
            if (find) {
                break;
            }
            
            if ([self.operatorPool count] != 0) {
                ++self.lastUsingOperatorIndex;
                NSUInteger idx = self.lastUsingOperatorIndex < [self.operatorPool count] ? self.lastUsingOperatorIndex : 0;
                result = [self.operatorPool objectAtIndex:idx];
                find = YES;
                self.lastUsingOperatorIndex = idx;
            } else if (self.mainThreadOperator) {
                result = self.mainThreadOperator;
                find = YES;
            }
            
            if (find) {
                break;
            }
        }
    } while (NO);
    return result;
}

- (BOOL)syncSaveAllOperator {
    BOOL result = YES;
    do {
        @synchronized(self) {
            result = [self saveMainThreadOperatorSynchronous:NO];
            if (result) {
                result = [self saveAllOperatorInPoolSynchronous:NO];
            }
        }
    } while (NO);
    return result;
}

- (BOOL)asyncSaveAllOperator {
    BOOL result = YES;
    do {
        @synchronized(self) {
            result = [self saveMainThreadOperatorSynchronous:YES];
            if (result) {
                result = [self saveAllOperatorInPoolSynchronous:YES];
            }
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
        if (self.dataSource && [self.dataSource respondsToSelector:@selector(urlForDataStoreManager:)]) {
            result = [self.dataSource urlForDataStore:self];
        } else {
            result = [NSURL fileURLWithPath:[DCDataStore archivePath]];
        }
    } while (NO);
    return result;
}

- (void)cleanOperatorPool {
    do {
        @synchronized(self) {
            if (self.operatorPool) {
                [self saveAllOperatorInPoolSynchronous:YES];
                
                [self.operatorPool removeAllObjects];
                self.operatorPool = nil;
            }
            
            self.lastUsingOperatorIndex = 0;
        }
    } while (NO);
}

- (void)mergeContextChanges:(NSNotification *)aNotification {
    do {
        if (!aNotification || !self.operatorPool) {
            break;
        }
        @synchronized(self) {
            BOOL allowMerge = NO;
            NSManagedObjectContext *context = (NSManagedObjectContext *)aNotification.object;
            for (DCDataStoreOperator *operator in self.operatorPool) {
                if ([context isEqual:operator.context]) {
                    allowMerge = YES;
                    break;
                }
            }
            
            if (allowMerge) {
                for (DCDataStoreOperator *operator in self.operatorPool) {
                    if (![context isEqual:operator.context]) {
                        [operator mergeContextChanges:aNotification];
                    }
                }
            }
        }
    } while (NO);
}

- (void)increaseOperatorPoolTo:(NSUInteger)anOperatorCount {
    do {
        @synchronized(self) {
            NSUInteger diff = anOperatorCount - [self.operatorPool count];
            for (; diff > 0; --diff) {
                DCDataStoreOperator *operator = [[DCDataStoreOperator alloc] initWithDataSource:self];
                SAFE_ARC_AUTORELEASE(operator);
                
                [self.operatorPool addObject:operator];
            }
        }
    } while (NO);
}

- (void)decreaseOperatorPoolTo:(NSUInteger)anOperatorCount {
    do {
        @synchronized(self) {
            NSUInteger diff = [self.operatorPool count] - anOperatorCount;
            NSUInteger decreaseCount = 0;
            NSUInteger idx = 0;
            while (idx < [self.operatorPool count] && decreaseCount < diff) {
                DCDataStoreOperator *operator = [self.operatorPool objectAtIndex:idx];
                if (!operator.busy) {
                    [self.operatorPool removeObjectAtIndex:idx];
                    ++decreaseCount;
                } else {
                    ++idx;
                }
            }
        }
    } while (NO);
}

- (BOOL)saveMainThreadOperatorSynchronous:(BOOL)isSync {
    BOOL result = YES;
    do {
        if (!self.mainThreadOperator) {
            break;
        }
        @synchronized(self) {
            NSError *err = nil;
            if (isSync) {
                if (![self.mainThreadOperator syncSave:&err]) {
                    result = NO;
                }
            } else {
                if (![self.mainThreadOperator asyncSave:&err]) {
                    result = NO;
                }
            }
        }
    } while (NO);
    return result;
}

- (BOOL)saveAllOperatorInPoolSynchronous:(BOOL)isSync {
    BOOL result = YES;
    do {
        @synchronized(self) {
            if (self.operatorPool) {
                for (DCDataStoreOperator *operator in self.operatorPool) {
                    NSError *err = nil;
                    if (isSync) {
                        if (![operator syncSave:&err]) {
                            result = NO;
                        }
                    } else {
                        if (![operator asyncSave:&err]) {
                            result = NO;
                        }
                    }
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
