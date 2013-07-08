//
//  DCDataStoreWriter.m
//  FOX_Mac
//
//  Created by Derek Chen on 13-6-27.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import "DCDataStoreWriter.h"

@implementation DCDataStoreWriter

#pragma mark - DCDataStoreWriter - Public method
- (id)initWithDataSource:(id<DCDataStoreOperatorDataSource>)aDataSource {
    @synchronized(self) {
        if (!aDataSource || ![aDataSource respondsToSelector:@selector(managedObjectModel)] || ![aDataSource respondsToSelector:@selector(persistentStoreCoordinator)]) {
            return nil;
        }
        
        self = [super init];
        if (self) {
            ;
        }
        return self;
    }
}

- (void)mergeContextChanges:(NSNotification *)aNotification {
    do {
        DCLog_Error(@"DCDataStoreWriter not allow mergeContextChanges:");
    } while (NO);
}

@end
