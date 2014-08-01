//
//  DCCoreDataDiskCacheEntity.h
//  HOUND_Mac
//
//  Created by Derek Chen on 13-7-4.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface DCCoreDataDiskCacheEntity : NSManagedObject

@property (nonatomic, retain) NSDate * accessTime;
@property (nonatomic, retain) NSNumber * dataSize;
@property (nonatomic, retain) NSString * key;
@property (nonatomic, retain) NSString * uuid;

- (void)registerAccess;

@end
