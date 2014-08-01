//
//  DCDiskCacheEntity.h
//  HOUND_Mac
//
//  Created by Derek Chen on 13-7-4.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DCDiskCacheEntity : NSObject {
@private
    NSString *_uuid;
    NSString *_key;
    CFTimeInterval _accessTime;
    NSUInteger _fileSize;
    BOOL _dirty;
}

- (id)initWithKey:(NSString *)key uuid:(NSString *)uuid accessTime:(CFTimeInterval)accessTime fileSize:(NSUInteger)fileSize;

@property (copy, readonly) NSString *key;
@property (copy, readonly) NSString *uuid;
@property (assign, readonly) CFTimeInterval accessTime;
@property (assign, readonly) NSUInteger fileSize;
@property (assign, getter = isDirty) BOOL dirty;

- (void)registerAccess;

@end
