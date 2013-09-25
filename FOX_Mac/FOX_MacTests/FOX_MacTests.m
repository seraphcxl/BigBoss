//
//  FOX_MacTests.m
//  FOX_MacTests
//
//  Created by Derek Chen on 13-7-8.
//  Copyright (c) 2013年 CaptainSolid Studio. All rights reserved.
//

#import "FOX_MacTests.h"
#import "DCSafeARC.h"
#import "DCCoreDataStore.h"

@implementation FOX_MacTests

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

- (void)testCoreDataStore {
    do {
        DCCoreDataStore *dataStore = [[DCCoreDataStore alloc] initWithQueryPSCURLBlock:^NSURL *{
            NSURL *result = nil;
            do {
                NSArray *documentDirectories = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
                NSString *documentDirectory = [documentDirectories objectAtIndex:0];
                result = [NSURL fileURLWithPath:[documentDirectory stringByAppendingPathComponent:@"DCCDS.data"]];
            } while (NO);
            return result;
        } andConfigureEntityBlock:^(NSManagedObjectModel *aModel) {
            do {
                if (!aModel) {
                    break;
                }
            } while (NO);
        }];
        SAFE_ARC_AUTORELEASE(dataStore);
        NSLog(@"%@", dataStore.mainManagedObjectContext);
    } while (NO);
}

@end
