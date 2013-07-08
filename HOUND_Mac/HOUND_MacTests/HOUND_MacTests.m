//
//  HOUND_MacTests.m
//  HOUND_MacTests
//
//  Created by Chen XiaoLiang on 6/17/13.
//  Copyright (c) 2013 CaptainSolid Studio. All rights reserved.
//

#import "HOUND_MacTests.h"

#import "DCInMemStackCache.h"
#import "DCCoreDataDiskCache.h"
#import "DCDiskCache.h"

@implementation HOUND_MacTests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void)testForCreateInMemStackCreate {
    STAssertNotNil([DCInMemStackCache sharedDCInMemStackCache], @"Error create DCInMemStackCache.");
}

- (void)testForCreateDCCoreDataDiskCache {
    STAssertNotNil([DCCoreDataDiskCache sharedDCCoreDataDiskCache], @"Error create DCCoreDataDiskCache.");
    [[DCCoreDataDiskCache sharedDCCoreDataDiskCache] initWithCachePath:nil];
    STAssertTrue([DCCoreDataDiskCache sharedDCCoreDataDiskCache].isReady, @"Error DCCoreDataDiskCache not ready");
}

- (void)testForCreateDCDiskCache {
    STAssertNotNil([DCDiskCache sharedDCDiskCache], @"Error create DCDiskCache.");
    [[DCDiskCache sharedDCDiskCache] initWithCachePath:nil];
    STAssertTrue([DCDiskCache sharedDCDiskCache].isReady, @"Error DCDiskCache not ready");
}

- (void)testForUseingDCCoreDataDiskCache {
    STAssertNotNil([DCCoreDataDiskCache sharedDCCoreDataDiskCache], @"Error create DCCoreDataDiskCache.");
    [[DCCoreDataDiskCache sharedDCCoreDataDiskCache] initWithCachePath:nil];
}

@end
