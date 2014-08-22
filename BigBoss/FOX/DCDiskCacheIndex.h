//
//  DCDiskCacheIndex.h
//  HOUND_Mac
//
//  Created by Derek Chen on 13-7-4.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>
#import "DCSafeARC.h"

extern const float DCDiskCacheIndexTrimLevel_Low;
extern const float DCDiskCacheIndexTrimLevel_Middle;
extern const float DCDiskCacheIndexTrimLevel_High;

@class DCDiskCacheIndex;
@class DCDiskCacheEntity;

@protocol DCDiskCacheIndexFileDelegate <NSObject>
@required
- (void)cacheIndex:(DCDiskCacheIndex* )cacheIndex writeFileWithName:(NSString *)name data:(NSData *)data compress:(BOOL)shouldCompress;
- (void)cacheIndex:(DCDiskCacheIndex *)cacheIndex deleteFileWithName:(NSString *)name;
- (BOOL)cacheIndex:(DCDiskCacheIndex *)cacheIndex shouldCompressFileWithName:(NSString *)name;
@end

@interface DCDiskCacheIndex : NSObject {
@protected    
    sqlite3 *_database;
    sqlite3_stmt *_insertStatement;
    sqlite3_stmt *_removeByKeyStatement;
    sqlite3_stmt *_selectByKeyStatement;
    sqlite3_stmt *_selectByKeyFragmentStatement;
    sqlite3_stmt *_selectExcludingKeyFragmentStatement;
    sqlite3_stmt *_trimStatement;
    sqlite3_stmt *_updateStatement;
}

- (id)initWithCacheFolder:(NSString* )folderPath;

@property (nonatomic, weak) id<DCDiskCacheIndexFileDelegate> delegate;
@property (nonatomic, assign, readonly) NSUInteger currentDiskUsage;
@property (nonatomic, assign) NSUInteger diskCapacity;
@property (nonatomic, readonly) dispatch_queue_t databaseQueue;
@property (nonatomic, assign) float trimLevel;
@property (nonatomic, strong, readonly) NSCache *cachedEntries;

- (DCDiskCacheEntity *)entryForKey:(NSString *)key;
- (NSString *)fileNameForKey:(NSString *)key;
- (NSString *)storeFileForKey:(NSString *)key withData:(NSData *)data;
- (void)removeEntryForKey:(NSString *)key;
- (void)removeEntries:(NSString *)keyFragment excludingFragment:(BOOL)exclude;

- (NSUInteger)entryCacheCountLimit;
- (void)setEntryCacheCountLimit:(NSUInteger)entryCacheCountLimit;

@end
