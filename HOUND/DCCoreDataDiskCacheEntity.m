//
//  DCCoreDataDiskCacheEntity.m
//  HOUND_Mac
//
//  Created by Derek Chen on 13-7-4.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import "DCCoreDataDiskCacheEntity.h"

@implementation DCCoreDataDiskCacheEntity

@dynamic accessTime;
@dynamic dataSize;
@dynamic key;
@dynamic uuid;

#pragma mark - DCCoreDataDiskCacheEntity - Public method
- (void)registerAccess {
    do {
        @synchronized(self) {
            self.accessTime = [NSDate date];
        }
    } while (NO);
}

@end
