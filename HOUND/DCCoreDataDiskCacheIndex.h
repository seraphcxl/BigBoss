//
//  DCCoreDataDiskCacheIndex.h
//  HOUND_Mac
//
//  Created by Derek Chen on 13-7-4.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import <Foundation/Foundation.h>

extern const float DCCoreDataDiskCacheIndexTrimLevel_Low;
extern const float DCCoreDataDiskCacheIndexTrimLevel_Middle;
extern const float DCCoreDataDiskCacheIndexTrimLevel_High;

@class DCCoreDataDiskCacheIndex;

@protocol DCCoreDataDiskCacheIndexFileDelegate <NSObject>

@required
- (void)cacheIndex:(DCCoreDataDiskCacheIndex *)cacheIndex writeFileWithUUID:(NSString *)uuid data:(NSData *)data;
- (void)cacheIndex:(DCCoreDataDiskCacheIndex *)cacheIndex deleteFileWithUUID:(NSString *)uuid;

@end

@interface DCCoreDataDiskCacheIndex : NSObject {
}

@property (unsafe_unretained, readonly) id<DCCoreDataDiskCacheIndexFileDelegate> fileDelegate;
@property (atomic, assign, readonly) NSUInteger currentDiskUsage;
@property (atomic, assign) NSUInteger diskCapacity;
@property (nonatomic, assign) float trimLevel;
@property (nonatomic, copy, readonly) NSString *dataStoreUUID;

- (id)initWithDataStoreUUID:(NSString *)dataStoreUUID andFileDelegate:(id<DCCoreDataDiskCacheIndexFileDelegate>)fileDelegate;

- (NSString *)dataUUIDForKey:(NSString *)key;

- (NSString *)storeData:(NSData *)data forKey:(NSString *)key;
- (NSArray *)storeDataArray:(NSArray *)dataArray forKeyArray:(NSArray *)keyArray;

- (void)removeEntryForKey:(NSString *)key;
- (void)removeEntryForKeyArray:(NSArray *)keyArray;

@end
