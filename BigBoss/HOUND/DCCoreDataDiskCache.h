//
//  DCCoreDataDiskCache.h
//  HOUND_Mac
//
//  Created by Derek Chen on 13-7-4.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DCSafeARC.h"
#import "DCSingletonTemplate.h"

@class DCCoreDataDiskCacheIndex;

@interface DCCoreDataDiskCache : NSObject {
}

@property (nonatomic, assign, readonly, getter = isReady) BOOL ready;
@property (nonatomic, assign, getter = isCompressed) BOOL compressed;
@property (nonatomic, readonly) dispatch_queue_t fileQueue;
@property (nonatomic, strong, readonly) DCCoreDataDiskCacheIndex *cacheIndex;
@property (nonatomic, strong, readonly) NSCache *inMemoryCache;

DEFINE_SINGLETON_FOR_HEADER(DCCoreDataDiskCache)

- (void)initWithCachePath:(NSString *)cachePath;

- (NSData *)dataForURL:(NSURL *)dataURL;

- (void)setData:(NSData *)data forURL:(NSURL *)url;
- (void)setDataArray:(NSArray *)dataArray forURLArray:(NSArray *)urlArray;

- (void)removeDataForUrl:(NSURL *)url;
- (void)removeDataForURLArray:(NSArray *)urlArray;

- (NSUInteger)memoryCacheSize;
- (void)setMemoryCacheSize:(NSUInteger)memoryCacheSize;

- (NSUInteger)diskCacheSize;
- (void)setDiskCacheSize:(NSUInteger)diskCacheSize;

- (float)trimDiskCacheLevel;
- (void)setTrimDiskCacheLevel:(float)trimDiskCacheLevel;

@end
