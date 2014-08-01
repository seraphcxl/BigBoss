//
//  DCCoreDataDiskCache.m
//  HOUND_Mac
//
//  Created by Derek Chen on 13-7-4.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import "DCCoreDataDiskCache.h"
#import "DCCoreDataDiskCacheIndex.h"

static NSString* const defaultDataStoreUUID = @"CDDiskCacheIndex.db";
static const NSUInteger kMaxCDDataInMemorySize = DC_MEMSIZE_MB(1);  // 1MB
static const NSUInteger kMaxCDDiskCacheSize = DC_MEMSIZE_MB(10);  // 10MB

static NSString * const kCDDiskCachePath = @"DCCDDiskCache";

@interface DCCoreDataDiskCache () <DCCoreDataDiskCacheIndexFileDelegate> {
}

@property (nonatomic, copy) NSString *dataCachePath;

- (BOOL)_doesFileExist:(NSString *)uuid;

@end

@implementation DCCoreDataDiskCache

@synthesize ready = _ready;
@synthesize fileQueue = _fileQueue;
@synthesize cacheIndex = _cacheIndex;
@synthesize dataCachePath = _dataCachePath;

#pragma mark - DCCoreDataDiskCache - Public method
DEFINE_SINGLETON_FOR_CLASS(DCCoreDataDiskCache)

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
                NSString *defaultCacheFolderPath = [[cacheList objectAtIndex:0] stringByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier]];
                _dataCachePath = [[defaultCacheFolderPath stringByAppendingPathComponent:kCDDiskCachePath] copy];
            }
            
            [[NSFileManager defaultManager] createDirectoryAtPath:_dataCachePath withIntermediateDirectories:YES attributes:nil error:nil];
            
            dispatch_queue_t bgPriQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
            _fileQueue = dispatch_queue_create("DCCoreDataDiskCacheFileQueue", DISPATCH_QUEUE_SERIAL);
            dispatch_set_target_queue(self.fileQueue, bgPriQueue);
            
            NSString *cacheIndexPath = [self.dataCachePath stringByAppendingPathComponent:defaultDataStoreUUID];
            _cacheIndex = [[DCCoreDataDiskCacheIndex alloc] initWithDataStoreUUID:cacheIndexPath andFileDelegate:self];
            self.cacheIndex.diskCapacity = kMaxCDDiskCacheSize;
            self.cacheIndex.trimLevel = DCCoreDataDiskCacheIndexTrimLevel_Middle;
            
            _inMemoryCache = [[NSCache alloc] init];
            _inMemoryCache.totalCostLimit = kMaxCDDataInMemorySize;
            
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
            if (self.cacheIndex) {
                result = self.cacheIndex.diskCapacity;
            }
        }
    } while (NO);
    return result;
}

- (void)setDiskCacheSize:(NSUInteger)diskCacheSize {
    do {
        @synchronized(self) {
            if (self.cacheIndex) {
                self.cacheIndex.diskCapacity = diskCacheSize;
            }
        }
    } while (NO);
}

- (float)trimDiskCacheLevel {
    float result = 0;
    do {
        @synchronized(self) {
            if (self.cacheIndex) {
                result = self.cacheIndex.trimLevel;
            }
        }
    } while (NO);
    return result;
}

- (void)setTrimDiskCacheLevel:(float)trimDiskCacheLevel {
    do {
        @synchronized(self) {
            if (self.cacheIndex) {
                self.cacheIndex.trimLevel = trimDiskCacheLevel;
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
                NSString *fileName = [self.cacheIndex dataUUIDForKey:dataURL.absoluteString];
                
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
                DCLog_Error(@"DCCoreDataDiskCache error: %@", exception.reason);
            } @finally {
                ;
            }
        }
    } while (NO);
    return result;
}

- (void)setData:(NSData *)data forURL:(NSURL *)url {
    do {
        if (!data || !url) {
            break;
        }
        @synchronized(self) {
            // TODO: Synchronize this across threads
            @try {
                NSString *uuid = [self.cacheIndex storeData:data forKey:url.absoluteString];
                DCLog_Debug(@"DCCoreDataDiskCache setData:forURL: uuid:%@", uuid);
                
                [_inMemoryCache setObject:data forKey:url cost:data.length];
            } @catch (NSException *exception) {
                DCLog_Error(@"DCCoreDataDiskCache error: %@", exception.reason);
            }
        }
    } while (NO);
}

- (void)setDataArray:(NSArray *)dataArray forURLArray:(NSArray *)urlArray {
    do {
        if (!dataArray || !urlArray || [dataArray count] != [urlArray count] || [urlArray count] == 0) {
            break;
        }
        @synchronized(self) {
            // TODO: Synchronize this across threads
            @try {
                NSMutableArray *urlStrAry = [NSMutableArray array];
                for (NSURL *url in urlArray) {
                    [urlStrAry addObject:url.absoluteString];
                }
                NSArray *uuidAry = [self.cacheIndex storeDataArray:dataArray forKeyArray:urlStrAry];
                DCLog_Debug(@"DCCoreDataDiskCache storeDataArray:forKeyArray: uuidAry:%@", uuidAry);
                
                NSUInteger count = [urlArray count];
                for (NSUInteger idx = 0; idx < count; ++idx) {
                    NSData *data = [dataArray objectAtIndex:idx];
                    NSURL *url = [urlArray objectAtIndex:idx];
                    
                    [_inMemoryCache setObject:data forKey:url cost:data.length];
                }
            } @catch (NSException *exception) {
                DCLog_Error(@"DCCoreDataDiskCache error: %@", exception.reason);
            }
        }
    } while (NO);
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
                [self.cacheIndex removeEntryForKey:url.absoluteString];
            } @catch (NSException *exception) {
                DCLog_Error(@"DCCoreDataDiskCache error: %@", exception.reason);
            }
        }
    } while (NO);
}

- (void)removeDataForURLArray:(NSArray *)urlArray {
    do {
        if (!urlArray || [urlArray count] == 0) {
            break;
        }
        @synchronized(self) {
            // TODO: Synchronize this across threads
            @try {
                NSMutableArray *urlStrAry = [NSMutableArray array];
                for (NSURL *url in urlArray) {
                    [_inMemoryCache removeObjectForKey:url];
                    [urlStrAry addObject:url.absoluteString];
                }
                
                [self.cacheIndex removeEntryForKeyArray:urlStrAry];
            } @catch (NSException *exception) {
                DCLog_Error(@"DCCoreDataDiskCache error: %@", exception.reason);
            }
        }
    } while (NO);
}

#pragma mark - DCCoreDataDiskCache - Private method
- (BOOL)_doesFileExist:(NSString *)uuid {
    BOOL result = NO;
    do {
        if (!uuid || uuid.length == 0) {
            break;
        }
        @synchronized(self) {
            NSString *filePath = [self.dataCachePath stringByAppendingPathComponent:uuid];
            result = [[NSFileManager defaultManager] fileExistsAtPath:filePath];
        }
    } while (NO);
    return result;
}

#pragma mark - DCCoreDataDiskCache - DCCoreDataDiskCacheIndexFileDelegate
- (void)cacheIndex:(DCCoreDataDiskCacheIndex *)cacheIndex writeFileWithUUID:(NSString *)uuid data:(NSData *)data {
    do {
        if (!cacheIndex || !uuid || uuid.length == 0 || !data) {
            break;
        }
        @synchronized(self) {
            NSString *filePath = [self.dataCachePath stringByAppendingPathComponent:uuid];
            dispatch_async(self.fileQueue, ^{
                [data writeToFile:filePath atomically:YES];
            });
        }
    } while (NO);
}

- (void)cacheIndex:(DCCoreDataDiskCacheIndex *)cacheIndex deleteFileWithUUID:(NSString *)uuid {
    do {
        if (!cacheIndex || !uuid || uuid.length == 0) {
            break;
        }
        @synchronized(self) {
            NSString *filePath = [self.dataCachePath stringByAppendingPathComponent:uuid];
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
