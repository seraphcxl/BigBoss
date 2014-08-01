//
//  DCCoreDataDiskCache.h
//  HOUND_Mac
//
//  Created by Derek Chen on 13-7-4.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DCCoreDataDiskCacheIndex;

@interface DCCoreDataDiskCache : NSObject {
@protected
    NSCache *_inMemoryCache;
}

@property (atomic, assign, readonly, getter = isReady) BOOL ready;
@property (nonatomic, assign) NSUInteger memoryCacheSize;
@property (nonatomic, assign) NSUInteger diskCacheSize;
@property (nonatomic, assign) float trimDiskCacheLevel;
@property (nonatomic, readonly) dispatch_queue_t fileQueue;
@property (nonatomic, SAFE_ARC_PROP_STRONG, readonly) DCCoreDataDiskCacheIndex *cacheIndex;

DEFINE_SINGLETON_FOR_HEADER(DCCoreDataDiskCache)

- (void)initWithCachePath:(NSString *)cachePath;

- (NSData *)dataForURL:(NSURL *)dataURL;

- (void)setData:(NSData *)data forURL:(NSURL *)url;
- (void)setDataArray:(NSArray *)dataArray forURLArray:(NSArray *)urlArray;

- (void)removeDataForUrl:(NSURL *)url;
- (void)removeDataForURLArray:(NSArray *)urlArray;

@end
