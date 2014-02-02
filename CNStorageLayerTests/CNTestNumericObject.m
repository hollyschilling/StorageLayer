//
//  CNTestNumericObject.m
//  CNStorageLayer
//
//  Created by Neal Schilling on 1/26/14.
//  Copyright (c) 2014 CyanideHill. All rights reserved.
//

#import "CNTestNumericObject.h"

#import "CNStorageLayer.h"

@implementation CNTestNumericObject

+ (NSString *)tableName
{
    static NSString *tableName = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        tableName = @"TestNumericObjects";
    });
    return tableName;
}

+ (NSArray *)propertyDescriptions
{
    static NSArray *properties = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        properties = @[
                       createPropDesc(CNProperty(isTrue), CNProperty(isTrue), CNPropertyTypeBoolean),
                       createPropDesc(CNProperty(myInteger), CNProperty(myInteger), CNPropertyTypeInteger),
                       createPropDesc(CNProperty(myFloat), CNProperty(myFloat), CNPropertyTypeFloat),
                       createPropDesc(CNProperty(integerObject), CNProperty(integerObject), CNPropertyTypeInteger)
                       ];
    });
    return properties;
}

- (id)copyWithZone:(NSZone *)zone
{
    CNTestNumericObject *copiedObj = [[CNTestNumericObject alloc] init];
    copiedObj.isTrue = self.isTrue;
    copiedObj.myInteger = self.myInteger;
    copiedObj.myFloat = self.myFloat;
    copiedObj.integerObject = [self.integerObject copy];
    return  copiedObj;
}

@end
