//
//  DCInMemStackCache.h
//  HOUND_Mac
//
//  Created by Derek Chen on 13-6-18.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DCSafeARC.h"
#import "DCSingletonTemplate.h"

#define INMEMSTACK_DEFAULT_MAXCOUNT 256

@interface DCInMemStackCache : NSObject {
}

DEFINE_SINGLETON_FOR_HEADER(DCInMemStackCache);

- (void)setMaxCount:(NSUInteger)newMaxCount;
- (void)resetCache;

- (id)objectForKey:(NSString *)aKey;
- (BOOL)cacheObject:(id)anObject forKey:(NSString *)aKey;
- (void)removeObjectForKey:(NSString *)aKey;

@end
