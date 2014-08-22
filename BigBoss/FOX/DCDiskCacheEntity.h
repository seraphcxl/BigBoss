//
//  DCDiskCacheEntity.h
//  HOUND_Mac
//
//  Created by Derek Chen on 13-7-4.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DCSafeARC.h"

@interface DCDiskCacheEntity : NSObject {
}

- (id)initWithKey:(NSString *)key uuid:(NSString *)uuid accessTime:(CFTimeInterval)accessTime fileSize:(NSUInteger)fileSize compressed:(BOOL)compressed;

@property (nonatomic, copy, readonly) NSString *key;
@property (nonatomic, copy, readonly) NSString *uuid;
@property (nonatomic, assign, readonly) CFTimeInterval accessTime;
@property (nonatomic, assign, readonly) NSUInteger fileSize;
@property (nonatomic, assign, readonly, getter = isCompressed) BOOL compressed;
@property (nonatomic, assign, getter = isDirty) BOOL dirty;

- (void)registerAccess;

@end
