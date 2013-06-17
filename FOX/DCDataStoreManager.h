//
//  DCDataStoreManager.h
//  TestApp4CoreData
//
//  Created by Derek Chen on 13-5-28.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DCSafeARC.h"
#import "DCSingletonTemplate.h"
#import <CoreData/CoreData.h>

@class DCDataStore;

@interface DCDataStoreManager : NSObject {
    
@private
    NSMutableDictionary *_dataStorePool;
}

@property (atomic, SAFE_ARC_PROP_STRONG, readonly) NSMutableDictionary *dataStorePool;  // key:(NSString *) value:(DCDataStore *)

DEFINE_SINGLETON_FOR_HEADER(DCDataStoreManager);

- (void)addDataStore:(DCDataStore *)aDataStore;
- (void)removeDataStore:(DCDataStore *)aDataStore;
- (void)removeAllDataStores;
- (DCDataStore *)getDataSource:(NSString *)aUUID;

@end
