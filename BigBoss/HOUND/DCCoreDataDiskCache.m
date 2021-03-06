//
//  DCCoreDataDiskCache.m
//  HOUND_Mac
//
//  Created by Derek Chen on 13-7-4.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import "DCCoreDataDiskCache.h"
#import "DCCommonConstants.h"
#import "DCLogger.h"
#import "DCCoreDataDiskCacheIndex.h"
#import "DCCoreDataDiskCacheIndexInfo.h"

static NSString* const kDCCoreDataDiskCache_DefaultDataStoreUUID = @"CDDiskCacheIndex.db";
static const NSUInteger kDCCoreDataDiskCache_InMemorySizeToDoskSizeFactor = 10;
static const NSUInteger kDCCoreDataDiskCache_MaxCDDataInMemorySize = DC_MEMSIZE_MB(2);  // 2MB
static const NSUInteger kDCCoreDataDiskCache_MaxCDDiskCacheSize = DC_MEMSIZE_MB(kDCCoreDataDiskCache_MaxCDDataInMemorySize * 10);  // 20MB

static NSString * const kCDDiskCachePath = @"DCCDDiskCache";

@interface DCCoreDataDiskCache () <DCCoreDataDiskCacheIndexFileDelegate> {
}

@property (nonatomic, assign, getter = isReady) BOOL ready;
@property (nonatomic) dispatch_queue_t fileQueue;
@property (nonatomic, strong) DCCoreDataDiskCacheIndex *cacheIndex;
@property (nonatomic, strong) NSCache *inMemoryCache;

@property (nonatomic, copy) NSString *dataCachePath;

- (BOOL)_doesFileExist:(NSString *)uuid;

@end

@implementation DCCoreDataDiskCache

@synthesize ready = _ready;
@synthesize compressed = _compressed;
@synthesize fileQueue = _fileQueue;
@synthesize cacheIndex = _cacheIndex;
@synthesize inMemoryCache = _inMemoryCache;
@synthesize dataCachePath = _dataCachePath;

#pragma mark - DCCoreDataDiskCache - Public method
DEFINE_SINGLETON_FOR_CLASS(DCCoreDataDiskCache)

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
                NSString *defaultCacheFolderPath = [[cacheList objectAtIndex:0] stringByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier]];
                self.dataCachePath = [defaultCacheFolderPath stringByAppendingPathComponent:kCDDiskCachePath];
            }
            
            [[NSFileManager defaultManager] createDirectoryAtPath:_dataCachePath withIntermediateDirectories:YES attributes:nil error:nil];
            
            dispatch_queue_t bgPriQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
            self.fileQueue = dispatch_queue_create("DCCoreDataDiskCacheFileQueue", DISPATCH_QUEUE_SERIAL);
            dispatch_set_target_queue(_fileQueue, bgPriQueue);
            
            NSString *cacheIndexPath = [self.dataCachePath stringByAppendingPathComponent:kDCCoreDataDiskCache_DefaultDataStoreUUID];
            self.cacheIndex = [[DCCoreDataDiskCacheIndex alloc] initWithDataStoreUUID:cacheIndexPath andFileDelegate:self];
            _cacheIndex.diskCapacity = kDCCoreDataDiskCache_MaxCDDiskCacheSize;
            _cacheIndex.trimLevel = DCCoreDataDiskCacheIndexTrimLevel_Middle;
            
            self.inMemoryCache = [[NSCache alloc] init];
            _inMemoryCache.totalCostLimit = kDCCoreDataDiskCache_MaxCDDataInMemorySize;
            
            self.ready = YES;
        }
    } while (NO);
}

- (NSUInteger)memoryCacheSize {
    NSUInteger result = 0;
    do {
        @synchronized(_inMemoryCache) {
            if (_inMemoryCache) {
                result = _inMemoryCache.totalCostLimit;
            }
        }
    } while (NO);
    return result;
}

- (void)setMemoryCacheSize:(NSUInteger)memoryCacheSize {
    do {
        @synchronized(_inMemoryCache) {
            if (_inMemoryCache) {
                NSUInteger maxAllowSize = [self diskCacheSize] / kDCCoreDataDiskCache_InMemorySizeToDoskSizeFactor;
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
        @synchronized(_cacheIndex) {
            if (_cacheIndex) {
                result = _cacheIndex.diskCapacity;
            }
        }
    } while (NO);
    return result;
}

- (void)setDiskCacheSize:(NSUInteger)diskCacheSize {
    do {
        @synchronized(_cacheIndex) {
            if (_cacheIndex) {
                _cacheIndex.diskCapacity = diskCacheSize;
            }
        }
    } while (NO);
}

- (float)trimDiskCacheLevel {
    float result = 0;
    do {
        @synchronized(_cacheIndex) {
            if (_cacheIndex) {
                result = _cacheIndex.trimLevel;
            }
        }
    } while (NO);
    return result;
}

- (void)setTrimDiskCacheLevel:(float)trimDiskCacheLevel {
    do {
        @synchronized(_cacheIndex) {
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
        if (!_inMemoryCache || !_cacheIndex || !_dataCachePath) {
            break;
        }
        // TODO: Synchronize this across threads
        @try {
            @synchronized(_inMemoryCache) {
                result = (NSData *)[_inMemoryCache objectForKey:dataURL];
            }
            
            
            if (result == nil) {
                DCCoreDataDiskCacheIndexInfo *indexInfo = [_cacheIndex dataIndexInfoForKey:dataURL.absoluteString];
                if (!indexInfo || indexInfo.uuid == nil) {
                    break;
                }
                // Not in-memory, on-disk only, read in
                if ([self _doesFileExist:indexInfo.uuid]) {
                    NSString *cachePath = [_dataCachePath stringByAppendingPathComponent:indexInfo.uuid];
                    
                    NSData *tmpData = [NSData dataWithContentsOfFile:cachePath options:(NSDataReadingMappedAlways | NSDataReadingUncached) error:nil];
                    
                    if (indexInfo.isCompressed) {
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
                        @synchronized(_inMemoryCache) {
                            [_inMemoryCache setObject:result forKey:dataURL cost:result.length];
                        }
                    }
                }
            }
        } @catch (NSException *exception) {
            result = nil;
            DCLog_Error(@"DCCoreDataDiskCache error: %@", exception.reason);
        } @finally {
            ;
        }
    } while (NO);
    return result;
}

- (void)setData:(NSData *)data forURL:(NSURL *)url {
    do {
        if (!data || !url) {
            break;
        }
        if (!_inMemoryCache || !_cacheIndex) {
            break;
        }
        // TODO: Synchronize this across threads
        @try {
            NSString *uuid = [_cacheIndex storeData:data forKey:url.absoluteString];
            DCLog_Debug(@"DCCoreDataDiskCache setData:forURL: uuid:%@", uuid);
            @synchronized(_inMemoryCache) {
                [_inMemoryCache setObject:data forKey:url cost:data.length];
            }
        } @catch (NSException *exception) {
            DCLog_Error(@"DCCoreDataDiskCache error: %@", exception.reason);
        }
    } while (NO);
}

- (void)setDataArray:(NSArray *)dataArray forURLArray:(NSArray *)urlArray {
    do {
        if (!dataArray || !urlArray || [dataArray count] != [urlArray count] || [urlArray count] == 0) {
            break;
        }
        if (!_inMemoryCache || !_cacheIndex) {
            break;
        }
        // TODO: Synchronize this across threads
        @try {
            NSMutableArray *urlStrAry = [NSMutableArray array];
            for (NSURL *url in urlArray) {
                [urlStrAry addObject:url.absoluteString];
            }
            NSArray *uuidAry = [_cacheIndex storeDataArray:dataArray forKeyArray:urlStrAry];
            DCLog_Debug(@"DCCoreDataDiskCache storeDataArray:forKeyArray: uuidAry:%@", uuidAry);
            
            NSUInteger count = [urlArray count];
            for (NSUInteger idx = 0; idx < count; ++idx) {
                NSData *data = [dataArray objectAtIndex:idx];
                NSURL *url = [urlArray objectAtIndex:idx];
                @synchronized(_inMemoryCache) {
                    [_inMemoryCache setObject:data forKey:url cost:data.length];
                }
            }
        } @catch (NSException *exception) {
            DCLog_Error(@"DCCoreDataDiskCache error: %@", exception.reason);
        }
    } while (NO);
}

- (void)removeDataForUrl:(NSURL *)url {
    do {
        if (!url) {
            break;
        }
        if (!_inMemoryCache || !_cacheIndex) {
            break;
        }
        // TODO: Synchronize this across threads
        @try {
            @synchronized(_inMemoryCache) {
                [_inMemoryCache removeObjectForKey:url];
            }
            [_cacheIndex removeEntryForKey:url.absoluteString];
        } @catch (NSException *exception) {
            DCLog_Error(@"DCCoreDataDiskCache error: %@", exception.reason);
        }
    } while (NO);
}

- (void)removeDataForURLArray:(NSArray *)urlArray {
    do {
        if (!urlArray || [urlArray count] == 0) {
            break;
        }
        if (!_inMemoryCache || !_cacheIndex) {
            break;
        }
        // TODO: Synchronize this across threads
        @try {
            NSMutableArray *urlStrAry = [NSMutableArray array];
            for (NSURL *url in urlArray) {
                @synchronized(_inMemoryCache) {
                    [_inMemoryCache removeObjectForKey:url];
                }
                [urlStrAry addObject:url.absoluteString];
            }
            
            [_cacheIndex removeEntryForKeyArray:urlStrAry];
        } @catch (NSException *exception) {
            DCLog_Error(@"DCCoreDataDiskCache error: %@", exception.reason);
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
        if (!_dataCachePath) {
            break;
        }
        NSString *filePath = [_dataCachePath stringByAppendingPathComponent:uuid];
        result = [[NSFileManager defaultManager] fileExistsAtPath:filePath];
    } while (NO);
    return result;
}

#pragma mark - DCCoreDataDiskCache - DCCoreDataDiskCacheIndexFileDelegate
- (void)cacheIndex:(DCCoreDataDiskCacheIndex *)cacheIndex writeFileWithUUID:(NSString *)uuid data:(NSData *)data compress:(BOOL)shouldCompress {
    do {
        if (!cacheIndex || !uuid || uuid.length == 0 || !data) {
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
        if (!_fileQueue || !_dataCachePath) {
            break;
        }
        NSString *filePath = [_dataCachePath stringByAppendingPathComponent:uuid];
        dispatch_async(_fileQueue, ^{
            [tmpData writeToFile:filePath atomically:YES];
        });
    } while (NO);
}

- (void)cacheIndex:(DCCoreDataDiskCacheIndex *)cacheIndex deleteFileWithUUID:(NSString *)uuid {
    do {
        if (!cacheIndex || !uuid || uuid.length == 0) {
            break;
        }
        if (!_fileQueue || !_dataCachePath) {
            break;
        }
        NSString *filePath = [_dataCachePath stringByAppendingPathComponent:uuid];
        dispatch_async(_fileQueue, ^{
            NSError *err = nil;
            if (![[NSFileManager defaultManager] removeItemAtPath:filePath error:&err]) {
                DCLog_Error(@"Remove file error. FilePath:%@ Errpr:%@", filePath, [err localizedDescription]);
            }
        });
    } while (NO);
}

- (BOOL)cacheIndexShouldCompressData:(DCCoreDataDiskCacheIndex *)cacheIndex {
    BOOL result = NO;
    do {
        if (!cacheIndex) {
            break;
        }
        result = _compressed;
    } while (NO);
    return result;
}
@end
