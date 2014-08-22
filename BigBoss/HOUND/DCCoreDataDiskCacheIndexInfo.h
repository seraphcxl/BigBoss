//
//  DCCoreDataDiskCacheIndexInfo.h
//  BigBoss
//
//  Created by Derek Chen on 8/22/14.
//  Copyright (c) 2014 Derek Chen. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DCCoreDataDiskCacheIndexInfo : NSObject

@property (nonatomic, copy) NSString *uuid;
@property (nonatomic, assign, getter = isCompressed) BOOL compressed;

@end
