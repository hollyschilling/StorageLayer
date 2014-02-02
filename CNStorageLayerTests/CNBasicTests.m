//
//  CNBasicTests.m
//  CNBasicTests
//
//  Created by Neal Schilling on 1/25/14.
//  Copyright (c) 2014 CyanideHill. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "CNStorageLayer.h"
#import "CNTestNumericObject.h"

@interface CNBasicTests: XCTestCase
@property (nonatomic, strong) CNStorageLayer *storageLayer;
@end

@implementation CNBasicTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    FMDatabaseQueue *dbq = [[FMDatabaseQueue alloc] initWithPath:@""];
    self.storageLayer = [[CNStorageLayer alloc] initWithDatabaseQueue:dbq];
    
    NSString *className = CNClass(CNTestNumericObject);
    BOOL success = [self.storageLayer createTableForClass:className];
    XCTAssert(success, @"Failed to create table for class %@.", className);
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    self.storageLayer = nil;
    
    [super tearDown];
}

#pragma mark - Helper methods

- (CNTestNumericObject *)createTestObject
{
    CNTestNumericObject *createdObject = [[CNTestNumericObject alloc] init];
    createdObject.isTrue = YES;
    createdObject.myInteger = 37;
    createdObject.myFloat = 1.2345;
    createdObject.integerObject = @(42);
    
    return createdObject;
}

- (void)assertObjectValuesMatch:(CNTestNumericObject *)original fetchedObject:(CNTestNumericObject *)fetchedObject
{
    XCTAssert(original.isTrue==fetchedObject.isTrue, @"BOOL property mangled between save and fetch. Expected: %d; Actual: %d", original.isTrue, fetchedObject.isTrue);
    XCTAssert(original.myInteger==fetchedObject.myInteger, @"NSInteger property mangled between save and fetch. Expected: %d; Actual: %d", original.myInteger, fetchedObject.myInteger);
    XCTAssert([original.integerObject isEqual:fetchedObject.integerObject], @"NSNumber property mangled between save and fetch. Expected: %@; Actual: %@", original.integerObject, fetchedObject.integerObject);
    XCTAssert(original.myFloat==fetchedObject.myFloat, @"CGFloat property mangled between save and fetch. Expected: %f; Actual: %f", original.myFloat, fetchedObject.myFloat);
    
}

#pragma mark - Tests

- (void)testStoreObject
{
    CNTestNumericObject *createdObject = [self createTestObject];
    [self.storageLayer saveObjects:@[createdObject]];
    XCTAssert([createdObject isInStorageLayer], @"Object not in storage layer after save.");
}

- (void)testFetchByPrimaryKey
{
    NSNumber *pk = nil;
    CNTestNumericObject *originalValues = nil;
    
    @autoreleasepool {
        CNTestNumericObject *createdObject = [self createTestObject];
        [self.storageLayer saveObjects:@[createdObject]];
        pk = createdObject.primaryKey;
        XCTAssert(pk!=nil, @"Primary Key should not be nil after save.");
        
        originalValues = [createdObject copy];
    }
    
    CNTestNumericObject *fetchedObject = [self.storageLayer objectOfClass:CNClass(CNTestNumericObject)
                                                           withPrimaryKey:pk];
    XCTAssert(fetchedObject!=nil, @"Fetched object should not be nil.");
    [self assertObjectValuesMatch:originalValues
                    fetchedObject:fetchedObject];
}

- (void)testFetchByPrimaryKeyFromCache
{
    NSNumber *pk = nil;
    
    CNTestNumericObject *createdObject = [self createTestObject];
    [self.storageLayer saveObjects:@[createdObject]];
    pk = createdObject.primaryKey;
    XCTAssert(pk!=nil, @"Primary Key should not be nil after save.");
    
    CNTestNumericObject *fetchedObject = [self.storageLayer objectOfClass:CNClass(CNTestNumericObject)
                                                           withPrimaryKey:pk];
    XCTAssert(fetchedObject!=nil, @"Fetched object should not be nil.");
    XCTAssert(fetchedObject==createdObject, @"Fetched object should be the same object as created object.");
}

- (void)testFetchBySingleEquality
{
    CNTestNumericObject *originalValues = nil;
    
    @autoreleasepool {
        CNTestNumericObject *createdObject = [self createTestObject];
        [self.storageLayer saveObjects:@[createdObject]];
        originalValues = [createdObject copy];
    }
    
    NSArray *matchedObjects = [self.storageLayer fetchObjectsOfClass:CNClass(CNTestNumericObject)
                                                           matchingValues:@{CNProperty(myInteger) : @(originalValues.myInteger)}];
    XCTAssert([matchedObjects count]==1, @"Wrong number of objects fetched with values. Expected: %d; Actual: %d", 1, [matchedObjects count]);
    CNTestNumericObject *fetchedObject = [matchedObjects firstObject];
    [self assertObjectValuesMatch:originalValues
                    fetchedObject:fetchedObject];
}

- (void)testFetchBySingleEqualityFromCache
{
    CNTestNumericObject *createdObject = [self createTestObject];
    [self.storageLayer saveObjects:@[createdObject]];

    NSArray *valueMatchedObjects = [self.storageLayer fetchObjectsOfClass:CNClass(CNTestNumericObject)
                                                           matchingValues:@{CNProperty(myInteger) : @(createdObject.myInteger)}];
    XCTAssert([valueMatchedObjects count]==1, @"Wrong number of objects fetched with values. Expected: %d; Actual: %d", 1, [valueMatchedObjects count]);
    CNTestNumericObject *fetchedObject = [valueMatchedObjects firstObject];
    XCTAssert(fetchedObject==createdObject, @"Fetched object should be the same object as created object.");
}

- (void)testFetchByPredicate
{
    CNTestNumericObject *originalValues = nil;
    
    @autoreleasepool {
        CNTestNumericObject *createdObject = [self createTestObject];
        [self.storageLayer saveObjects:@[createdObject]];
        originalValues = [createdObject copy];
    }
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K = %d", CNProperty(myInteger), originalValues.myInteger];

    NSArray *matchedObjects = [self.storageLayer fetchObjectsOfClass:CNClass(CNTestNumericObject)
                                                   matchingPredicate:predicate];
    XCTAssert([matchedObjects count]==1, @"Wrong number of objects fetched with values. Expected: %d; Actual: %d", 1, [matchedObjects count]);
    CNTestNumericObject *fetchedObject = [matchedObjects firstObject];
    [self assertObjectValuesMatch:originalValues
                    fetchedObject:fetchedObject];
    
}

- (void)testFetchByPredicateFromCache
{
    CNTestNumericObject *createdObject = [self createTestObject];
    [self.storageLayer saveObjects:@[createdObject]];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K = %d", CNProperty(myInteger), createdObject.myInteger];
    NSArray *matchedObjects = [self.storageLayer fetchObjectsOfClass:CNClass(CNTestNumericObject)
                                                   matchingPredicate:predicate];
    XCTAssert([matchedObjects count]==1, @"Wrong number of objects fetched with values. Expected: %d; Actual: %d", 1, [matchedObjects count]);
    CNTestNumericObject *fetchedObject = [matchedObjects firstObject];
    XCTAssert(fetchedObject==createdObject, @"Fetched object should be the same object as created object.");
    
}


@end
