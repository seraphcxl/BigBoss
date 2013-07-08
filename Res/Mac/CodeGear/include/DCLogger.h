//
//  DCLogger.h
//  CodeGear_ObjC_Mac
//
//  Created by Derek Chen on 13-7-1.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "DCCommonConstants.h"
#import "DCSafeARC.h"
#import "DCSingletonTemplate.h"

typedef enum {
    DCLL_DEBUG = 0,
    DCLL_INFO,
    DCLL_WARN,
    DCLL_ERROR,
    DCLL_FATAL,
} DCLogLevel;

@interface DCLogger : NSObject {
}

@property (atomic, assign) DCLogLevel logLevel;
@property (atomic, assign) BOOL enableLogToFile;
@property (atomic, assign) BOOL enableTimestamp;
@property (atomic, assign) BOOL enableSourceCodeInfo;
@property (atomic, assign) BOOL enableThreadInfo;
@property (atomic, SAFE_ARC_PROP_STRONG, readonly) NSFileHandle *fileHandle;
@property (atomic, SAFE_ARC_PROP_STRONG, readonly) NSDateFormatter *dateFormatter;

DEFINE_SINGLETON_FOR_HEADER(DCLogger)

+ (void)logWithLevel:(DCLogLevel)level andFormat:(NSString *)format, ...;

#define DCLog_Debug(format, ...) [DCLogger logWithLevel:DCLL_DEBUG andFormat:format, ## __VA_ARGS__]
#define DCLog_Info(format, ...) [DCLogger logWithLevel:DCLL_INFO andFormat:format, ## __VA_ARGS__]
#define DCLog_Warn(format, ...) [DCLogger logWithLevel:DCLL_WARN andFormat:format, ## __VA_ARGS__]
#define DCLog_Error(format, ...) [DCLogger logWithLevel:DCLL_ERROR andFormat:format, ## __VA_ARGS__]
#define DCLog_Fatal(format, ...) [DCLogger logWithLevel:DCLL_FATAL andFormat:format, ## __VA_ARGS__]

@end
