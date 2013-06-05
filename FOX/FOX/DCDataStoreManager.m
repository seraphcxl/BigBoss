//
//  DCDataStoreManager.m
//  TestApp4CoreData
//
//  Created by Derek Chen on 13-5-28.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import "DCDataStoreManager.h"
#import "DCDataStore.h"

@interface DCDataStoreManager () {
}

- (void)cleanDataStorePool;

@end

@implementation DCDataStoreManager

@synthesize dataStorePool = _dataStorePool;

#pragma mark - DCDataStoreManager - Public method
DEFINE_SINGLETON_FOR_CLASS(DCDataStoreManager);

- (id)init {
    @synchronized(self) {
        self = [super init];
        if (self) {
            [self cleanDataStorePool];
            
            _dataStorePool = [NSMutableDictionary dictionary];
            SAFE_ARC_RETAIN(_dataStorePool);
        }
        return self;
    }
}

- (void)dealloc {
    do {
        @synchronized(self) {
            [self cleanDataStorePool];
        }
        SAFE_ARC_SUPER_DEALLOC();
    } while (NO);
}

- (void)addDataStore:(DCDataStore *)aDataStore {
    do {
        if (!aDataStore || !self.dataStorePool) {
            break;
        }
        @synchronized(self) {
            [self.dataStorePool setValue:aDataStore forKey:[aDataStore uuid]];
        }
    } while (NO);
}

- (void)removeDataStore:(DCDataStore *)aDataStore {
    do {
        if (!aDataStore || !self.dataStorePool) {
            break;
        }
        @synchronized(self) {
            [self.dataStorePool removeObjectForKey:[aDataStore uuid]];
        }
    } while (NO);
}

- (void)removeAllDataStores {
    do {
        if (!self.dataStorePool) {
            break;
        }
        @synchronized(self) {
            [self.dataStorePool removeAllObjects];
        }
    } while (NO);
}

- (DCDataStore *)getDataSource:(NSString *)aUUID {
    DCDataStore *result = nil;
    do {
        if (!aUUID || !self.dataStorePool) {
            break;
        }
        @synchronized(self) {
            result = [self.dataStorePool objectForKey:aUUID];
        }
    } while (NO);
    return result;
}

#pragma mark - DCDataStoreManager - Private method
- (void)cleanDataStorePool {
    do {
        @synchronized(self) {
            if (_dataStorePool) {
                [self removeAllDataStores];
                SAFE_ARC_SAFERELEASE(_dataStorePool);
            }
        }
    } while (NO);
}

@end
