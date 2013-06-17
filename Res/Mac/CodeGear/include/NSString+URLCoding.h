//
//  NSString+URLCoding.h
//  CodeGear_ObjC
//
//  Created by Derek Chen on 13-6-7.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DCSafeARC.h"

@interface NSString (URLCoding)

+ (NSString *)stringByURLDecodingString:(NSString *)escapedString;
+ (NSString *)stringByURLEncodingString:(NSString *)unescapedString;

@end
