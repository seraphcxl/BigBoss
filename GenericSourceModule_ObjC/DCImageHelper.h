//
//  DCImageHelper.h
//  AtomicArtist
//
//  Created by Chen XiaoLiang on 12-5-17.
//  Copyright (c) 2012年 seraphCXL. All rights reserved.
//

#import <Foundation/Foundation.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>
#ifdef ALASSETLIB_AVAILABLE
#import <AssetsLibrary/AssetsLibrary.h>
#endif

#else
#import <AppKit/AppKit.h>
#endif

#import <QuartzCore/QuartzCore.h>

#import "DCCommonConstants.h"
#import "SafeARC.h"

#define ALASSETLIB_AVAILABLE 1

@interface DCImageHelper : NSObject

#pragma mark - Fitting
+ (CGSize)fitSize:(CGSize)thisSize inSize:(CGSize)aSize;
+ (CGSize)fitoutSize:(CGSize)thisSize inSize:(CGSize)aSize;
+ (CGRect)frameSize:(CGSize)thisSize inSize:(CGSize)aSize;
#if TARGET_OS_IPHONE
+ (UIImage *)image:(UIImage *)image fitInSize:(CGSize)size;
+ (UIImage *)image:(UIImage *)image fillSize:(CGSize)size;
+ (UIImage *)image:(UIImage *)image centerInSize:(CGSize)size;
#else
#endif
#pragma mark - Rotate
+ (CGFloat)degreesToRadians:(CGFloat)degrees;
#if TARGET_OS_IPHONE
+ (UIImage *)image:(UIImage *)image rotatedByDegrees:(CGFloat)degrees;
+ (UIImage *)imageFromImage:(UIImage *)image inRect:(CGRect)rect;www
+ (UIImage *)doUnrotateImage:(UIImage *)image fromOrientation:(UIImageOrientation)orient;
#else
#endif
#pragma mark - Reflection
#if TARGET_OS_IPHONE
+ (void)addSimpleReflectionToView:(UIView *)view;
+ (void)addReflectionToView:(UIView *)view;
+ (UIImage *)reflectionOfView:(UIView *)view withPercent:(CGFloat)percent;
+ (CGImageRef)createGradientImage:(CGSize)size;
+ (UIImage *)bezierImage:(UIImage *)image withRadius:(CGFloat)radius needCropSquare:(BOOL)needCropSquare;
#else
#endif
#pragma mark - Load image

#if TARGET_OS_IPHONE
#ifdef ALASSETLIB_AVAILABLE
typedef enum {
    DCImageShapeType_Original = 0,
    DCImageShapeType_Square,
} DCImageShapeType;
+ (UIImage *)loadImageFromALAsset:(ALAsset *)asset withShape:(DCImageShapeType)type andMaxPixelSize:(CGFloat)pixelSize;

+ (CGImageRef)loadImageFromALAsset:(ALAsset *)asset withMaxPixelSize:(CGFloat)pixelSize;

+ (CGImageSourceRef)loadImageSourceFromALAsset:(ALAsset *)asset;
#endif

#else
#endif

#if TARGET_OS_IPHONE
+ (NSInteger)UIImageOrientationToCGImagePropertyOrientation:(UIImageOrientation) imageOrientation;
#else
#endif
+ (CGImageRef)loadImageFromContentsOfFile:(NSString *)path withMaxPixelSize:(CGFloat)pixelSize;

+ (CGImageSourceRef)loadImageSourceFromContentsOfFile:(NSString *)path;
@end
