//
//  DCDataStoreOperator.h
//  TestApp4CoreData
//
//  Created by Derek Chen on 13-5-28.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeARC.h"
#import <CoreData/CoreData.h>

@protocol DCDataStoreTaskDataSource <NSObject>

- (NSManagedObjectModel *)managedObjectModel;
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator;
- (NSManagedObjectContext *)managedObjectContext;

@end

@protocol DCDataStoreOperatorDataSource <NSObject>

- (NSManagedObjectModel *)managedObjectModel;
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator;

@end

@interface DCDataStoreOperator : NSObject {
    
@private
    __unsafe_unretained id<DCDataStoreOperatorDataSource> _dataSource;
    NSManagedObjectContext *_context;
    BOOL _busy;
    
    dispatch_queue_t _queue;
}

@property (unsafe_unretained, readonly) id<DCDataStoreOperatorDataSource> dataSource;
@property (SAFE_ARC_PROP_STRONG, readonly) NSManagedObjectContext *context;
@property (atomic, unsafe_unretained, readonly, getter = isBusy) BOOL busy;

- (id)initWithDataSource:(id<DCDataStoreOperatorDataSource>)aDataSource;
- (void)mergeContextChanges:(NSNotification *)aNotification;

- (void)doTask:(void (^)(id<DCDataStoreTaskDataSource> taskDataSource))aBlock;

- (BOOL)syncSave:(NSError **)anError;
- (BOOL)asyncSave:(NSError **)anError;

@end
