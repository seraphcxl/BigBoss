//
//  DCDataStore.h
//  TestApp4CoreData
//
//  Created by Derek Chen on 13-6-4.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeARC.h"
#import <CoreData/CoreData.h>

#define DATASTORE_FILENAME_DEFAULT @"DataStore.data"

@class DCDataStore;
@class DCDataStoreOperator;

@protocol DCDataStoreDataSource <NSObject>

- (NSURL *)urlForDataStore:(DCDataStore *)dataStore;
- (void)dataStore:(DCDataStore *)dataStore initModel:(NSManagedObjectModel *)model;

@end

@interface DCDataStore : NSObject {
    
@private
    __unsafe_unretained id<DCDataStoreDataSource> _dataSource;
    NSManagedObjectModel *_model;
    NSPersistentStoreCoordinator *_coordinator;
}

@property (atomic, unsafe_unretained, readonly) id<DCDataStoreDataSource> dataSource;
@property (nonatomic, SAFE_ARC_PROP_STRONG, readonly) NSManagedObjectModel *model;
@property (nonatomic, SAFE_ARC_PROP_STRONG, readonly) NSPersistentStoreCoordinator *coordinator;

+ (NSString *)defaultUUID;

- (id)initWithDataSource:(id<DCDataStoreDataSource>)aDataSource;
- (NSString *)uuid;
- (NSUInteger)operatorCount;
- (void)setOperatorCount:(NSUInteger)anOperatorCount;

- (DCDataStoreOperator *)queryOperator;

- (BOOL)syncSaveAllOperator;
- (BOOL)asyncSaveAllOperator;

@end
