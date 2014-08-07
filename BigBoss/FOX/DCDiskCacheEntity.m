//
//  DCDiskCacheEntity.m
//  HOUND_Mac
//
//  Created by Derek Chen on 13-7-4.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import "DCDiskCacheEntity.h"

@implementation DCDiskCacheEntity

@synthesize accessTime = _accessTime;
@synthesize uuid = _uuid;
@synthesize fileSize = _fileSize;
@synthesize key = _key;
@synthesize dirty = _dirty;

#pragma mark - DCDiskCacheEntity - Public method
- (id)initWithKey:(NSString *)key uuid:(NSString *)uuid accessTime:(CFTimeInterval)accessTime fileSize:(NSUInteger)fileSize {
    @synchronized(self) {
        self = [super init];
        if (self) {
            _key = [key copy];
            _uuid = [uuid copy];
            _accessTime = accessTime;
            _fileSize = fileSize;
        }
        return self;
    }
}

- (void)dealloc {
    do {
        @synchronized(self) {
            SAFE_ARC_SAFERELEASE(_uuid);
            SAFE_ARC_SAFERELEASE(_key);
        }
        SAFE_ARC_SUPER_DEALLOC();
    } while (NO);
}

- (void)registerAccess {
    do {
        @synchronized(self) {
            _accessTime = CFAbsoluteTimeGetCurrent();
            _dirty = YES;
        }
    } while (NO);
}

@end
