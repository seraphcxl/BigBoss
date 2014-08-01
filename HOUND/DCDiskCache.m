//
//  DCDiskCache.m
//  HOUND_Mac
//
//  Created by Derek Chen on 13-7-4.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import "DCDiskCache.h"
#import "DCDiskCacheIndex.h"

static const NSUInteger kMaxDataInMemorySize = DC_MEMSIZE_MB(1);  // 1MB
static const NSUInteger kMaxDiskCacheSize = DC_MEMSIZE_MB(10);  // 10MB

static NSString * const kDiskCachePath = @"DCDiskCache";

@interface DCDiskCache () <DCDiskCacheIndexFileDelegate> {
}

@property (nonatomic, copy) NSString *dataCachePath;

- (BOOL)_doesFileExist:(NSString *)name;

@end

@implementation DCDiskCache

@synthesize ready = _ready;
@synthesize dataCachePath = _dataCachePath;
@synthesize fileQueue = _fileQueue;

#pragma mark - DCDiskCache - Public method
DEFINE_SINGLETON_FOR_CLASS(DCDiskCache)

- (id)init {
    @synchronized(self) {
        self = [super init];
        if (self) {
            _ready = NO;
        }
        return self;
    }
}

- (void)dealloc {
    do {
        @synchronized(self) {
            if (self.fileQueue) {
                SAFE_ARC_DISPATCHQUEUERELEASE(_fileQueue);
            }
            
            SAFE_ARC_SAFERELEASE(_cacheIndex);
            SAFE_ARC_SAFERELEASE(_dataCachePath);
            SAFE_ARC_SAFERELEASE(_inMemoryCache);
            
            _ready = NO;
        }
        SAFE_ARC_SUPER_DEALLOC();
    } while (NO);
}

- (void)initWithCachePath:(NSString *)cachePath {
    do {
        @synchronized(self) {
            if (cachePath && cachePath.length > 0) {
                _dataCachePath = [cachePath copy];
            } else {
                NSArray *cacheList = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
                NSString *defaultCacheFolderPath = [cacheList objectAtIndex:0];
                _dataCachePath = [[defaultCacheFolderPath stringByAppendingPathComponent:kDiskCachePath] copy];
            }
            
            [[NSFileManager defaultManager] createDirectoryAtPath:_dataCachePath withIntermediateDirectories:YES attributes:nil error:nil];
            
            dispatch_queue_t bgPriQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
            _fileQueue = dispatch_queue_create("DCDiskCacheFileQueue", DISPATCH_QUEUE_SERIAL);
            dispatch_set_target_queue(self.fileQueue, bgPriQueue);
            
            _cacheIndex = [[DCDiskCacheIndex alloc] initWithCacheFolder:_dataCachePath];
            _cacheIndex.diskCapacity = kMaxDiskCacheSize;
            _cacheIndex.trimLevel = DCDiskCacheIndexTrimLevel_Middle;
            _cacheIndex.delegate = self;
            
            _inMemoryCache = [[NSCache alloc] init];
            _inMemoryCache.totalCostLimit = kMaxDataInMemorySize;
            
            _ready = YES;
        }
    } while (NO);
}

- (NSUInteger)memoryCacheSize {
    NSUInteger result = 0;
    do {
        @synchronized(self) {
            if (_inMemoryCache) {
                result = _inMemoryCache.totalCostLimit;
            }
        }
    } while (NO);
    return result;
}

- (void)setMemoryCacheSize:(NSUInteger)memoryCacheSize {
    do {
        @synchronized(self) {
            if (_inMemoryCache) {
                NSUInteger maxAllowSize = [self diskCacheSize] / 10;
                if (memoryCacheSize > maxAllowSize) {
                    _inMemoryCache.countLimit = maxAllowSize;
                } else {
                    _inMemoryCache.countLimit = memoryCacheSize;
                }
            }
        }
    } while (NO);
}

- (NSUInteger)diskCacheSize {
    NSUInteger result = 0;
    do {
        @synchronized(self) {
            if (_cacheIndex) {
                result = _cacheIndex.diskCapacity;
            }
        }
    } while (NO);
    return result;
}

- (void)setDiskCacheSize:(NSUInteger)diskCacheSize {
    do {
        @synchronized(self) {
            if (_cacheIndex) {
                _cacheIndex.diskCapacity = diskCacheSize;
            }
        }
    } while (NO);
}

- (float)trimDiskCacheLevel {
    float result = 0;
    do {
        @synchronized(self) {
            if (_cacheIndex) {
                result = _cacheIndex.trimLevel;
            }
        }
    } while (NO);
    return result;
}

- (void)setTrimDiskCacheLevel:(float)trimDiskCacheLevel {
    do {
        @synchronized(self) {
            if (_cacheIndex) {
                _cacheIndex.trimLevel = trimDiskCacheLevel;
            }
        }
    } while (NO);
}

- (NSData *)dataForURL:(NSURL *)dataURL {
    NSData *result = nil;
    do {
        if (!dataURL) {
            break;
        }
        @synchronized(self) {
            // TODO: Synchronize this across threads
            @try {
                result = (NSData *)[_inMemoryCache objectForKey:dataURL];
                NSString *fileName = [_cacheIndex fileNameForKey:dataURL.absoluteString];
                
                if (result == nil && fileName != nil) {
                    // Not in-memory, on-disk only, read in
                    if ([self _doesFileExist:fileName]) {
                        NSString *cachePath = [self.dataCachePath stringByAppendingPathComponent:fileName];
                        
                        result = [NSData dataWithContentsOfFile:cachePath options:(NSDataReadingMappedAlways | NSDataReadingUncached) error:nil];
                        
                        if (result) {
                            // It is possible that the file doesn't exist
                            [_inMemoryCache setObject:result forKey:dataURL cost:result.length];
                        }
                    }
                }
            } @catch (NSException *exception) {
                result = nil;
                DCLog_Error(@"DCDiskCache error: %@", exception.reason);
            } @finally {
                ;
            }
        }
    } while (NO);
    return result;
}

- (void)removeDataForUrl:(NSURL *)url {
    do {
        if (!url) {
            break;
        }
        @synchronized(self) {
            // TODO: Synchronize this across threads
            @try {
                [_inMemoryCache removeObjectForKey:url];
                [_cacheIndex removeEntryForKey:url.absoluteString];
            } @catch (NSException *exception) {
                DCLog_Error(@"DCDiskCache error: %@", exception.reason);
            }
        }
    } while (NO);
}

- (void)setData:(NSData *)data forURL:(NSURL *)url {
    do {
        if (!data || !url) {
            break;
        }
        @synchronized(self) {
            // TODO: Synchronize this across threads
            @try {
                [_cacheIndex storeFileForKey:url.absoluteString withData:data];
                
                [_inMemoryCache setObject:data forKey:url cost:data.length];
            } @catch (NSException *exception) {
                DCLog_Error(@"DCDiskCache error: %@", exception.reason);
            }
        }
    } while (NO);
}

#pragma mark - DCDiskCache - Private method
- (BOOL)_doesFileExist:(NSString *)name {
    BOOL result = NO;
    do {
        if (!name || name.length == 0) {
            break;
        }
        @synchronized(self) {
            NSString *filePath = [self.dataCachePath stringByAppendingPathComponent:name];
            result = [[NSFileManager defaultManager] fileExistsAtPath:filePath];
        }
    } while (NO);
    return result;
}

#pragma mark - DCDiskCache - DCDiskCacheIndexFileDelegate
- (void)cacheIndex:(DCDiskCacheIndex *)cacheIndex writeFileWithName:(NSString *)name data:(NSData *)data {
    do {
        if (!cacheIndex || !name || name.length == 0 || !data) {
            break;
        }
        @synchronized(self) {
            NSString *filePath = [self.dataCachePath stringByAppendingPathComponent:name];
            dispatch_async(self.fileQueue, ^{
                [data writeToFile:filePath atomically:YES];
            });
        }
    } while (NO);
}

- (void)cacheIndex:(DCDiskCacheIndex *)cacheIndex deleteFileWithName:(NSString *)name {
    do {
        if (!cacheIndex || !name || name.length == 0) {
            break;
        }
        @synchronized(self) {
            NSString *filePath = [self.dataCachePath stringByAppendingPathComponent:name];
            dispatch_async(self.fileQueue, ^{
                NSError *err = nil;
                if (![[NSFileManager defaultManager] removeItemAtPath:filePath error:&err]) {
                    DCLog_Error(@"Remove file error. FilePath:%@ Errpr:%@", filePath, [err localizedDescription]);
                }
            });
        }
    } while (NO);
    
}
@end
