//
//  DCDiskCacheEntity.m
//  HOUND_Mac
//
//  Created by Derek Chen on 13-7-4.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import "DCDiskCacheEntity.h"

@interface DCDiskCacheEntity () {
}

@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) NSString *uuid;
@property (nonatomic, assign) CFTimeInterval accessTime;
@property (nonatomic, assign) NSUInteger fileSize;
@property (nonatomic, assign, getter = isCompressed) BOOL compressed;

@end

@implementation DCDiskCacheEntity

@synthesize accessTime = _accessTime;
@synthesize uuid = _uuid;
@synthesize fileSize = _fileSize;
@synthesize key = _key;
@synthesize compressed = _compressed;
@synthesize dirty = _dirty;

#pragma mark - DCDiskCacheEntity - Public method
- (id)initWithKey:(NSString *)key uuid:(NSString *)uuid accessTime:(CFTimeInterval)accessTime fileSize:(NSUInteger)fileSize compressed:(BOOL)compressed {
    @synchronized(self) {
        self = [super init];
        if (self) {
            self.key = key;
            self.uuid = uuid;
            self.accessTime = accessTime;
            self.fileSize = fileSize;
            self.compressed = compressed;
        }
        return self;
    }
}

- (void)dealloc {
    do {
        @synchronized(self) {
            self.uuid = nil;
            self.key = nil;
        }
        SAFE_ARC_SUPER_DEALLOC();
    } while (NO);
}

- (void)registerAccess {
    do {
        @synchronized(self) {
            self.accessTime = CFAbsoluteTimeGetCurrent();
            self.dirty = YES;
        }
    } while (NO);
}

@end
