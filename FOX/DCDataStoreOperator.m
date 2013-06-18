//
//  DCDataStoreOperator.m
//  TestApp4CoreData
//
//  Created by Derek Chen on 13-5-28.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import "DCDataStoreOperator.h"
#import <AvailabilityMacros.h>

@interface DCDataStoreOperator () <DCDataStoreTaskDataSource> {
}

- (BOOL)save:(NSError **)anError synchronous:(BOOL)isSync;

@end

@implementation DCDataStoreOperator

@synthesize dataSource = _dataSource;
@synthesize context = _context;
@synthesize busy = _busy;

#pragma mark - DCDataStoreOperator - Public method
- (id)initWithDataSource:(id<DCDataStoreOperatorDataSource>)aDataSource {
    @synchronized(self) {
        if (!aDataSource || ![aDataSource respondsToSelector:@selector(managedObjectModel)] || ![aDataSource respondsToSelector:@selector(persistentStoreCoordinator)]) {
            return nil;
        }
        
        self = [super init];
        if (self) {
            SAFE_ARC_SAFERELEASE(_context);
            
            _dataSource = aDataSource;
            
            _context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
            [_context setPersistentStoreCoordinator:[self.dataSource persistentStoreCoordinator]];
            [_context setUndoManager:nil];
            [_context setStalenessInterval:0.0];
            [_context setMergePolicy:NSOverwriteMergePolicy];
            
            _queue = dispatch_queue_create([[NSString stringWithFormat:@"DCDSO.%@", self] UTF8String], NULL);
            
            _busy = NO;
        }
        return self;
    }
}

- (void)dealloc {
    do {
        @synchronized(self) {
            NSError *err = nil;
            [self syncSave:&err];
            
            if (_queue) {
                SAFE_ARC_DISPATCHQUEUERELEASE(_queue);
                _queue = 0x00;
            }
        }
        SAFE_ARC_SUPER_DEALLOC();
    } while (NO);
}

- (void)mergeContextChanges:(NSNotification *)aNotification {
    do {
        if (!aNotification || !self.context) {
            break;
        }
        dispatch_async(_queue, ^() {
            _busy = YES;
            [self.context mergeChangesFromContextDidSaveNotification:aNotification];
            _busy = NO;
        });
    } while (NO);
}

- (void)doTask:(void (^)(id<DCDataStoreTaskDataSource>))aBlock {
    SAFE_ARC_RETAIN(self);
    do {
        dispatch_sync(_queue, ^() {
            _busy = YES;
            aBlock(self);
            _busy = NO;
        });
    } while (NO);
    SAFE_ARC_RELEASE(self);
}

- (BOOL)syncSave:(NSError **)anError {
    return [self save:anError synchronous:YES];
}

- (BOOL)asyncSave:(NSError **)anError {
    return [self save:anError synchronous:NO];
}

#pragma mark - DCDataStoreOperator - Private method
- (BOOL)save:(NSError **)anError synchronous:(BOOL)isSync {
    __block BOOL result = NO;
    do {
        if (!self.context || !anError) {
            break;
        }
        if (isSync) {
            dispatch_sync(_queue, ^() {
                _busy = YES;
                if ([self.context hasChanges]) {
                    result = [self.context save:anError];
                    if (*anError) {
                        NSLog(@"DCDataStoreOperator sync save error: %@", [*anError localizedDescription]);
                    }
                } else {
                    result = YES;
                }
                _busy = NO;
            });
        } else {
            dispatch_async(_queue, ^() {
                _busy = YES;
                if ([self.context hasChanges]) {
                    [self.context save:anError];
                    if (*anError) {
                        NSLog(@"DCDataStoreOperator async save error: %@", [*anError localizedDescription]);
                    }
                }
                _busy = NO;
            });
            result = YES;
        }
    } while (NO);
    return result;
}

#pragma mark - DCDataStoreOperator - DCDataStoreTaskDataSource
- (NSManagedObjectModel *)managedObjectModel {
    NSManagedObjectModel *result = nil;
    do {
        if (self.dataSource && [self.dataSource respondsToSelector:@selector(managedObjectModel)]) {
            result = [self.dataSource managedObjectModel];
        }
    } while (NO);
    return result;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    NSPersistentStoreCoordinator *result = nil;
    do {
        if (self.dataSource && [self.dataSource respondsToSelector:@selector(persistentStoreCoordinator)]) {
            result = [self.dataSource persistentStoreCoordinator];
        }
    } while (NO);
    return result;
}

- (NSManagedObjectContext *)managedObjectContext {
    NSManagedObjectContext *result = nil;
    do {
        if (self.context) {
            result = self.context;
        }
    } while (NO);
    return result;
}

@end
