//
//  DCDiskCache.h
//  HOUND_Mac
//
//  Created by Derek Chen on 13-7-4.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DCSafeARC.h"
#import "DCSingletonTemplate.h"

@class DCDiskCacheIndex;

@interface DCDiskCache : NSObject {
@protected
    NSCache *_inMemoryCache;
    DCDiskCacheIndex *_cacheIndex;
    NSString *_dataCachePath;
    
    dispatch_queue_t _fileQueue;
}

@property (atomic, assign, readonly, getter = isReady) BOOL ready;
@property (nonatomic, assign) NSUInteger memoryCacheSize;
@property (nonatomic, assign) NSUInteger diskCacheSize;
@property (nonatomic, assign) float trimDiskCacheLevel;
@property (nonatomic, readonly) dispatch_queue_t fileQueue;

DEFINE_SINGLETON_FOR_HEADER(DCDiskCache)

- (void)initWithCachePath:(NSString *)cachePath;
- (NSData *)dataForURL:(NSURL *)dataURL;
- (void)setData:(NSData *)data forURL:(NSURL *)url;
- (void)removeDataForUrl:(NSURL *)url;

@end
