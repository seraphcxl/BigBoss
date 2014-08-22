//
//  DCDiskCache.m
//  HOUND_Mac
//
//  Created by Derek Chen on 13-7-4.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import "DCDiskCache.h"
#import "DCDiskCacheIndex.h"
#import "DCDiskCacheEntity.h"
#import "DCCommonConstants.h"
#import "DCLogger.h"

static const NSUInteger kMaxDataInMemorySize = DC_MEMSIZE_MB(2);  // 2MB
static const NSUInteger kMaxDiskCacheSize = DC_MEMSIZE_MB(20);  // 20MB

static NSString * const kDiskCachePath = @"DCDiskCache";

@interface DCDiskCache () <DCDiskCacheIndexFileDelegate> {
}

@property (nonatomic, assign, getter = isReady) BOOL ready;
@property (nonatomic) dispatch_queue_t fileQueue;
@property (nonatomic, copy) NSString *dataCachePath;
@property (nonatomic, strong) DCDiskCacheIndex *cacheIndex;
@property (nonatomic, strong) NSCache *inMemoryCache;

- (BOOL)_doesFileExist:(NSString *)name;

@end

@implementation DCDiskCache

@synthesize ready = _ready;
@synthesize compressed = _compressed;
@synthesize dataCachePath = _dataCachePath;
@synthesize fileQueue = _fileQueue;
@synthesize cacheIndex = _cacheIndex;
@synthesize inMemoryCache = _inMemoryCache;

#pragma mark - DCDiskCache - Public method
DEFINE_SINGLETON_FOR_CLASS(DCDiskCache)

- (id)init {
    @synchronized(self) {
        self = [super init];
        if (self) {
            self.ready = NO;
            self.compressed = NO;
        }
        return self;
    }
}

- (void)dealloc {
    do {
        @synchronized(self) {
            if (_fileQueue) {
                SAFE_ARC_DISPATCHQUEUERELEASE(_fileQueue);
            }
            self.fileQueue = nil;
            
            self.cacheIndex = nil;
            self.dataCachePath = nil;
            self.inMemoryCache = nil;
            self.compressed = NO;
            self.ready = NO;
        }
        SAFE_ARC_SUPER_DEALLOC();
    } while (NO);
}

- (void)initWithCachePath:(NSString *)cachePath {
    do {
        @synchronized(self) {
            if (cachePath && cachePath.length > 0) {
                self.dataCachePath = cachePath;
            } else {
                NSArray *cacheList = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
                NSString *defaultCacheFolderPath = [cacheList objectAtIndex:0];
                self.dataCachePath = [defaultCacheFolderPath stringByAppendingPathComponent:kDiskCachePath];
            }
            
            [[NSFileManager defaultManager] createDirectoryAtPath:_dataCachePath withIntermediateDirectories:YES attributes:nil error:nil];
            
            dispatch_queue_t bgPriQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
            NSString *queueName = [NSString stringWithFormat:@"DCDiskCacheFileQueue_%@", [NSObject createMemoryID:self]];
            self.fileQueue = dispatch_queue_create([queueName UTF8String], DISPATCH_QUEUE_SERIAL);
            dispatch_set_target_queue(_fileQueue, bgPriQueue);
            
            self.cacheIndex = [[DCDiskCacheIndex alloc] initWithCacheFolder:_dataCachePath];
            _cacheIndex.diskCapacity = kMaxDiskCacheSize;
            _cacheIndex.trimLevel = DCDiskCacheIndexTrimLevel_Middle;
            _cacheIndex.delegate = self;
            
            self.inMemoryCache = [[NSCache alloc] init];
            _inMemoryCache.totalCostLimit = kMaxDataInMemorySize;
            
            self.ready = YES;
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
                    _inMemoryCache.totalCostLimit = maxAllowSize;
                } else {
                    _inMemoryCache.totalCostLimit = memoryCacheSize;
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
            if (!_inMemoryCache || !_cacheIndex || !_dataCachePath) {
                break;
            }
            // TODO: Synchronize this across threads
            @try {
                result = (NSData *)[_inMemoryCache objectForKey:dataURL];
                DCDiskCacheEntity *entity = [_cacheIndex entryForKey:dataURL.absoluteString];
                NSString *fileName = entity.uuid;
                if (result == nil && fileName != nil) {
                    // Not in-memory, on-disk only, read in
                    if ([self _doesFileExist:fileName]) {
                        NSString *cachePath = [_dataCachePath stringByAppendingPathComponent:fileName];
                        
                        NSData *tmpData = [NSData dataWithContentsOfFile:cachePath options:(NSDataReadingMappedAlways | NSDataReadingUncached) error:nil];
                        
                        if (entity.isCompressed) {
                            NSError *err = nil;
                            result = [tmpData decompressByGZipWithError:&err];
                            if (err) {
                                NSLog(@"%@", [err localizedDescription]);
                                break;
                            }
                        } else {
                            result = tmpData;
                        }
                        
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
            if (!_inMemoryCache || !_cacheIndex) {
                break;
            }
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
            if (!_inMemoryCache || !_cacheIndex) {
                break;
            }
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
            if (!_dataCachePath) {
                break;
            }
            NSString *filePath = [_dataCachePath stringByAppendingPathComponent:name];
            result = [[NSFileManager defaultManager] fileExistsAtPath:filePath];
        }
    } while (NO);
    return result;
}

#pragma mark - DCDiskCache - DCDiskCacheIndexFileDelegate
- (void)cacheIndex:(DCDiskCacheIndex *)cacheIndex writeFileWithName:(NSString *)name data:(NSData *)data compress:(BOOL)shouldCompress {
    do {
        if (!cacheIndex || !name || name.length == 0 || !data) {
            break;
        }
        NSData *tmpData = data;
        if (shouldCompress) {
            NSError *err = nil;
            tmpData = [data compressByGZipWithError:&err];
            if (err) {
                NSLog(@"%@", [err localizedDescription]);
                break;
            }
        }
        @synchronized(self) {
            if (!_fileQueue || !_dataCachePath) {
                break;
            }
            NSString *filePath = [_dataCachePath stringByAppendingPathComponent:name];
            dispatch_async(_fileQueue, ^{
                [tmpData writeToFile:filePath atomically:YES];
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
            if (!_fileQueue || !_dataCachePath) {
                break;
            }
            NSString *filePath = [_dataCachePath stringByAppendingPathComponent:name];
            dispatch_async(_fileQueue, ^{
                NSError *err = nil;
                if (![[NSFileManager defaultManager] removeItemAtPath:filePath error:&err]) {
                    DCLog_Error(@"Remove file error. FilePath:%@ Errpr:%@", filePath, [err localizedDescription]);
                }
            });
        }
    } while (NO);
    
}

- (BOOL)cacheIndex:(DCDiskCacheIndex *)cacheIndex shouldCompressFileWithName:(NSString *)name {
    BOOL result = NO;
    do {
        if (!cacheIndex || !name || name.length == 0) {
            break;
        }
        result = _compressed;
    } while (NO);
    return result;
}
@end
