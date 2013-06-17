//
//  DCImageHelper.h
//  CodeGear_ObjC
//
//  Created by Derek Chen on 13-6-7.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>

#import "DCSafeARC.h"
#import "DCCommonConstants.h"

/**** **** **** **** **** **** **** ****/
#ifndef DC_RGB_DEFINE
#define DC_RGB_DEFINE
#define DC_RGB(x) (x / 255.0f)
#endif

/**** **** **** **** **** **** **** ****/
@interface DCImageHelper : NSObject

+ (CGSize)fitSize:(CGSize)thisSize inSize:(CGSize)aSize;
+ (CGSize)fitoutSize:(CGSize)thisSize inSize:(CGSize)aSize;
+ (CGRect)frameSize:(CGSize)thisSize inSize:(CGSize)aSize;

+ (CGFloat)degreesToRadians:(CGFloat)degrees;

+ (CGImageRef)loadImageFromContentsOfFile:(NSString *)path withMaxPixelSize:(CGFloat)pixelSize;
+ (CGImageSourceRef)loadImageSourceFromContentsOfFile:(NSString *)path;

@end
