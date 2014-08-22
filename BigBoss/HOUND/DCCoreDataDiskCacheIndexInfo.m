//
//  DCCoreDataDiskCacheIndexInfo.m
//  BigBoss
//
//  Created by Derek Chen on 8/22/14.
//  Copyright (c) 2014 Derek Chen. All rights reserved.
//

#import "DCCoreDataDiskCacheIndexInfo.h"

@implementation DCCoreDataDiskCacheIndexInfo

@synthesize uuid = _uuid;
@synthesize compressed = _compressed;

- (void)dealloc {
    do {
        @synchronized(self) {
            self.uuid = nil;
        }
        SAFE_ARC_SUPER_DEALLOC();
    } while (NO);
}

@end
