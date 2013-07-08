//
//  DCDataStoreReader.m
//  FOX_Mac
//
//  Created by Derek Chen on 13-6-27.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import "DCDataStoreReader.h"

@implementation DCDataStoreReader

#pragma mark - DCDataStoreReader - Public method
- (id)initWithDataSource:(id<DCDataStoreOperatorDataSource>)aDataSource {
    @synchronized(self) {
        if (!aDataSource || ![aDataSource respondsToSelector:@selector(managedObjectModel)] || ![aDataSource respondsToSelector:@selector(persistentStoreCoordinator)]) {
            return nil;
        }
        
        self = [super init];
        if (self) {
            [_context setUndoManager:nil];
        }
        return self;
    }
}

- (BOOL)syncSave:(NSError **)anError {
    BOOL result = NO;
    do {
        DCLog_Error(@"DCDataStoreReader not allow syncSave:");
    } while (NO);
    return result;
}

- (BOOL)asyncSave:(NSError **)anError {
    BOOL result = NO;
    do {
        DCLog_Error(@"DCDataStoreReader not allow asyncSave:");
    } while (NO);
    return result;
}

@end
