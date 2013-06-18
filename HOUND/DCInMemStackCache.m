//
//  DCInMemStackCache.m
//  HOUND_Mac
//
//  Created by Derek Chen on 13-6-18.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import "DCInMemStackCache.h"

@interface DCInMemStackCache () {
    NSMutableArray *_stack;  // key:(NSString *)
    NSMutableDictionary *_cache;  // key:(NSString *) valve:(id)
    long _countMax;
}

- (void)deallocCache;
- (void)removeLastObject;

@end

@implementation DCInMemStackCache

#pragma mark - DCDataStoreManager - Public method
DEFINE_SINGLETON_FOR_CLASS(DCInMemStackCache);

- (id)init {
    @synchronized(self) {
        self = [super init];
        if (self) {
            [self setMaxCount:INMEMSTACK_DEFAULT_MAXCOUNT];
            [self resetCache];
        }
        return self;
    }
}

- (void)dealloc {
    do {
        [self deallocCache];
        
        SAFE_ARC_SUPER_DEALLOC();
    } while (NO);
}

- (void)setMaxCount:(NSUInteger)newMaxCount {
    do {
        if (newMaxCount <= 0) {
            break;
        }
        
        @synchronized (self) {
            NSInteger diff = _countMax - newMaxCount;
            while (diff > 0) {
                [self removeLastObject];
                --diff;
            }
            
            _countMax = newMaxCount;
        }
    } while (NO);
}

- (void)resetCache {
    do {
        [self deallocCache];
        @synchronized (self) {
            _stack = [[NSMutableArray alloc] initWithCapacity:_countMax];
            
            _cache = [[NSMutableDictionary alloc] initWithCapacity:_countMax];
        }
    } while (NO);
}

- (id)objectForKey:(NSString *)aKey {
    id result = nil;
    do {
        if (!aKey || !_cache || !_stack) {
            break;
        }
        @synchronized (self) {
            result = [_cache objectForKey:aKey];
            
            if (result) {
                [_stack removeObject:aKey];
                [_stack insertObject:aKey atIndex:0];
            }
        }
    } while (NO);
    return result;
}

- (BOOL)cacheObject:(id)anObject forKey:(NSString *)aKey {
    BOOL result = NO;
    do {
        if (!anObject || !aKey || !_cache || !_stack) {
            break;
        }
        @synchronized (self) {
            if ([_stack count] == _countMax) {
                [self removeLastObject];
            }
            
            [_stack insertObject:aKey atIndex:0];
            [_cache setObject:anObject forKey:aKey];
        }
    } while (NO);
    return result;
}

- (void)removeObjectForKey:(NSString *)aKey {
    do {
        if (!aKey || !_cache || !_stack) {
            break;
        }
        @synchronized (self) {
            [_stack removeObject:aKey];
            [_cache removeObjectForKey:aKey];
        }
    } while (NO);
}

#pragma mark - DCDataStoreManager - Private method
- (void)deallocCache {
    do {
        @synchronized (self) {
            if (_stack) {
                [_stack removeAllObjects];
                SAFE_ARC_SAFERELEASE(_stack);
                _stack = nil;
            }
            
            if (_cache) {
                [_cache removeAllObjects];
                SAFE_ARC_SAFERELEASE(_cache);
                _cache = nil;
            }
        }
    } while (NO);
}

- (void)removeLastObject {
    do {
        if (!_cache || !_stack) {
            break;
        }
        @synchronized (self) {
            NSString *keyForRemove = [[_stack lastObject] copy];
            SAFE_ARC_AUTORELEASE(keyForRemove);
            [_stack removeLastObject];
            [_cache removeObjectForKey:keyForRemove];
        }
    } while (NO);
}

@end
