//
//  CNComplexTests.m
//  CNStorageLayer
//
//  Created by Neal Schilling on 2/1/14.
//  Copyright (c) 2014 CyanideHill. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "CNStorageLayer.h"
#import "CNTestComplexObject.h"

@interface CNComplexTests : XCTestCase
@property (nonatomic, strong) CNStorageLayer *storageLayer;
@end

@implementation CNComplexTests

- (void)setUp
{
    [super setUp];

    FMDatabaseQueue *dbq = [[FMDatabaseQueue alloc] initWithPath:@""];
    self.storageLayer = [[CNStorageLayer alloc] initWithDatabaseQueue:dbq];
    
    NSString *className = CNClass(CNTestComplexObject);
    BOOL success = [self.storageLayer createTableForClass:className];
    XCTAssert(success, @"Failed to create table for class %@.", className);
}

- (void)tearDown
{
    self.storageLayer = nil;

    [super tearDown];
}

#pragma mark - Helper Methods

- (void)assertObjectValuesMatch:(CNTestComplexObject *)original fetchedObject:(CNTestComplexObject *)fetchedObject
{
    XCTAssert(original.title==fetchedObject.title || [original.title isEqualToString:fetchedObject.title], @"NSString property mangled between save and fetch. Expected: %@; Actual: %@", original.title, fetchedObject.title);
    XCTAssert(original.someDate==fetchedObject.someDate || [original.someDate isEqualToDate:fetchedObject.someDate], @"NSDate property mangled between save and fetch. Expected: %@; Actual: %@", original.someDate, fetchedObject.someDate);
    XCTAssert(original.dataBlob==fetchedObject.dataBlob || [original.dataBlob isEqualToData:fetchedObject.dataBlob], @"NSString property mangled between save and fetch. Expected: %@; Actual: %@", original.dataBlob, fetchedObject.dataBlob);
    XCTAssert(original.foreignKey==fetchedObject.foreignKey, @"NSInteger property mangled between save and fetch. Expected: %d; Actual: %d", original.foreignKey, fetchedObject.foreignKey);
}

#pragma mark - Tests


- (void)testString
{
    NSNumber *pk = nil;
    CNTestComplexObject *orig = nil;
    
    @autoreleasepool {
        CNTestComplexObject *createdObject = [[CNTestComplexObject alloc] init];
        createdObject.title = @"Simple String Test";
        
        [self.storageLayer saveObjects:@[createdObject]];
        XCTAssert([createdObject isInStorageLayer], @"Object not in storage layer after save.");
        pk = createdObject.primaryKey;
        orig = [createdObject copy];
    }
    
    CNTestComplexObject *fetchedObj = [self.storageLayer objectOfClass:CNClass(CNTestComplexObject)
                                                        withPrimaryKey:pk];
    [self assertObjectValuesMatch:orig fetchedObject:fetchedObj];
}

- (void)testDate
{
    NSNumber *pk = nil;
    CNTestComplexObject *orig = nil;
    
    @autoreleasepool {
        CNTestComplexObject *createdObject = [[CNTestComplexObject alloc] init];
        createdObject.someDate = [NSDate dateWithTimeIntervalSinceNow:-10000];
        
        [self.storageLayer saveObjects:@[createdObject]];
        XCTAssert([createdObject isInStorageLayer], @"Object not in storage layer after save.");
        pk = createdObject.primaryKey;
        orig = [createdObject copy];
    }
    
    CNTestComplexObject *fetchedObj = [self.storageLayer objectOfClass:CNClass(CNTestComplexObject)
                                                        withPrimaryKey:pk];
    [self assertObjectValuesMatch:orig fetchedObject:fetchedObj];
}

- (void)testData
{
    NSNumber *pk = nil;
    CNTestComplexObject *orig = nil;
    
    @autoreleasepool {
        CNTestComplexObject *createdObject = [[CNTestComplexObject alloc] init];
        createdObject.dataBlob = [@"Here's a string" dataUsingEncoding:NSUTF8StringEncoding];
        
        [self.storageLayer saveObjects:@[createdObject]];
        XCTAssert([createdObject isInStorageLayer], @"Object not in storage layer after save.");
        pk = createdObject.primaryKey;
        orig = [createdObject copy];
    }
    
    CNTestComplexObject *fetchedObj = [self.storageLayer objectOfClass:CNClass(CNTestComplexObject)
                                                        withPrimaryKey:pk];
    [self assertObjectValuesMatch:orig fetchedObject:fetchedObj];
}

- (void)testCompound
{
    NSNumber *pk = nil;
    CNTestComplexObject *orig = nil;
    
    @autoreleasepool {
        CNTestComplexObject *createdObject = [[CNTestComplexObject alloc] init];
        createdObject.someDate = [NSDate dateWithTimeIntervalSinceNow:-10000];
        createdObject.dataBlob = [@"Here's a string" dataUsingEncoding:NSUTF8StringEncoding];
        createdObject.title = @"Simple String Test";

        [self.storageLayer saveObjects:@[createdObject]];
        XCTAssert([createdObject isInStorageLayer], @"Object not in storage layer after save.");
        pk = createdObject.primaryKey;
        orig = [createdObject copy];
    }
    
    CNTestComplexObject *fetchedObj = [self.storageLayer objectOfClass:CNClass(CNTestComplexObject)
                                                        withPrimaryKey:pk];
    [self assertObjectValuesMatch:orig fetchedObject:fetchedObj];
}


- (void)testPropertyFetching
{
    NSNumber *pk = nil;
    CNTestComplexObject *orig = nil;
    
    @autoreleasepool {
        CNTestComplexObject *createdObject = [[CNTestComplexObject alloc] init];
        createdObject.someDate = [NSDate dateWithTimeIntervalSinceNow:-10000];
        createdObject.dataBlob = [@"Here's a string" dataUsingEncoding:NSUTF8StringEncoding];
        createdObject.title = @"Simple String Test";
        
        [self.storageLayer saveObjects:@[createdObject]];
        XCTAssert([createdObject isInStorageLayer], @"Object not in storage layer after save.");
        orig = [createdObject copy];
        
        CNTestComplexObject *rootObject = [[CNTestComplexObject alloc] init];
        rootObject.foreignKey = [createdObject.primaryKey integerValue];
        rootObject.title = @"Root object.";
        
        [self.storageLayer saveObjects:@[rootObject]];
        XCTAssert([rootObject isInStorageLayer], @"Object not in storage layer after save.");
        pk = rootObject.primaryKey;
    }
    
    CNTestComplexObject *rootFetchedObj = [self.storageLayer objectOfClass:CNClass(CNTestComplexObject)
                                                            withPrimaryKey:pk];
    CNTestComplexObject *fetchedObj = rootFetchedObj.fetchedObject;
    [self assertObjectValuesMatch:orig fetchedObject:fetchedObj];
}

- (void)testListPropertyFetching
{
    @autoreleasepool {
        
        NSMutableArray *createdObjects = [NSMutableArray array];
        for (int i=0; i<20; i++) {
            CNTestComplexObject *obj = [[CNTestComplexObject alloc] init];
            obj.someDate = [NSDate dateWithTimeIntervalSinceNow:i - 9.5];
            obj.title = [NSString stringWithFormat:@"Object %d", i];
            [createdObjects addObject:obj];
        }
        [self.storageLayer saveObjects:createdObjects];
        for (CNTestComplexObject *anObj in createdObjects) {
            XCTAssert([anObj isInStorageLayer], @"Object not in storage layer after save.");
        }
    }
    
    CNTestComplexObject *rootFetchedObj = [[CNTestComplexObject alloc] init];
    rootFetchedObj.title = @"Root Obj";
    rootFetchedObj.someDate = [NSDate date];
    [self.storageLayer saveObjects:@[rootFetchedObj]];
    
    NSArray *fetchedList = rootFetchedObj.fetchedList;
    XCTAssert([fetchedList count]==10, @"Wrong number of fetched objects in list. Expected %d; Actual: %d", 10, [fetchedList count]);
}



@end
