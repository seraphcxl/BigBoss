//
//  DCCoreDataDiskCacheIndex.h
//  HOUND_Mac
//
//  Created by Derek Chen on 13-7-4.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DCSafeARC.h"
#import "DCLogger.h"

extern const float DCCoreDataDiskCacheIndexTrimLevel_Low;
extern const float DCCoreDataDiskCacheIndexTrimLevel_Middle;
extern const float DCCoreDataDiskCacheIndexTrimLevel_High;

@class DCCoreDataDiskCacheIndex;
@class DCCoreDataDiskCacheIndexInfo;

@protocol DCCoreDataDiskCacheIndexFileDelegate <NSObject>

@required
- (void)cacheIndex:(DCCoreDataDiskCacheIndex *)cacheIndex writeFileWithUUID:(NSString *)uuid data:(NSData *)data compress:(BOOL)shouldCompress;
- (void)cacheIndex:(DCCoreDataDiskCacheIndex *)cacheIndex deleteFileWithUUID:(NSString *)uuid;
- (BOOL)cacheIndexShouldCompressData:(DCCoreDataDiskCacheIndex *)cacheIndex;
@end

@interface DCCoreDataDiskCacheIndex : NSObject {
}

@property (nonatomic, weak) id<DCCoreDataDiskCacheIndexFileDelegate> fileDelegate;
@property (nonatomic, assign, readonly) NSUInteger currentDiskUsage;
@property (nonatomic, assign) NSUInteger diskCapacity;
@property (nonatomic, assign) float trimLevel;
@property (nonatomic, copy, readonly) NSString *dataStoreUUID;

- (id)initWithDataStoreUUID:(NSString *)dataStoreUUID andFileDelegate:(id<DCCoreDataDiskCacheIndexFileDelegate>)fileDelegate;

- (DCCoreDataDiskCacheIndexInfo *)dataIndexInfoForKey:(NSString *)key;

- (NSString *)storeData:(NSData *)data forKey:(NSString *)key;
- (NSArray *)storeDataArray:(NSArray *)dataArray forKeyArray:(NSArray *)keyArray;

- (void)removeEntryForKey:(NSString *)key;
- (void)removeEntryForKeyArray:(NSArray *)keyArray;

@end
