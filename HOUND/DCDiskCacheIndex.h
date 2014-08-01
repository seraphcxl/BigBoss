//
//  DCDiskCacheIndex.h
//  HOUND_Mac
//
//  Created by Derek Chen on 13-7-4.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>

extern const float DCDiskCacheIndexTrimLevel_Low;
extern const float DCDiskCacheIndexTrimLevel_Middle;
extern const float DCDiskCacheIndexTrimLevel_High;

@class DCDiskCacheIndex;

@protocol DCDiskCacheIndexFileDelegate <NSObject>
@required
- (void)cacheIndex:(DCDiskCacheIndex* )cacheIndex writeFileWithName:(NSString *)name data:(NSData *)data;
- (void)cacheIndex:(DCDiskCacheIndex *)cacheIndex deleteFileWithName:(NSString *)name;
@end

@interface DCDiskCacheIndex : NSObject {
@protected
    __unsafe_unretained id<DCDiskCacheIndexFileDelegate> _delegate;
    
    NSCache *_cachedEntries;
    
    NSUInteger _currentDiskUsage;
    NSUInteger _diskCapacity;
    float _trimLevel;
    
    sqlite3 *_database;
    sqlite3_stmt *_insertStatement;
    sqlite3_stmt *_removeByKeyStatement;
    sqlite3_stmt *_selectByKeyStatement;
    sqlite3_stmt *_selectByKeyFragmentStatement;
    sqlite3_stmt *_selectExcludingKeyFragmentStatement;
    sqlite3_stmt *_trimStatement;
    sqlite3_stmt *_updateStatement;
    
    dispatch_queue_t _databaseQueue;
}

- (id)initWithCacheFolder:(NSString* )folderPath;

@property (nonatomic, assign) id<DCDiskCacheIndexFileDelegate> delegate;
@property (nonatomic, assign, readonly) NSUInteger currentDiskUsage;
@property (nonatomic, assign) NSUInteger diskCapacity;
@property (nonatomic, assign) NSUInteger entryCacheCountLimit;
@property (nonatomic, readonly) dispatch_queue_t databaseQueue;
@property (nonatomic, assign) float trimLevel;

- (NSString *)fileNameForKey:(NSString *)key;
- (NSString *)storeFileForKey:(NSString *)key withData:(NSData *)data;
- (void)removeEntryForKey:(NSString *)key;
- (void)removeEntries:(NSString *)keyFragment excludingFragment:(BOOL)exclude;

@end
