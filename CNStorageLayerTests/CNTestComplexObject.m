//
//  CNTestComplexObject.m
//  CNStorageLayer
//
//  Created by Neal Schilling on 2/1/14.
//  Copyright (c) 2014 CyanideHill. All rights reserved.
//

#import "CNTestComplexObject.h"

#import "CNStorageLayer.h"

@implementation CNTestComplexObject

@dynamic fetchedObject;
@dynamic fetchedList;

+ (NSString *)tableName
{
    static NSString *tableName = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        tableName = @"TestComplexObject";
    });
    return tableName;
}

+ (NSArray *)propertyDescriptions
{
    static NSArray *properties = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        properties = @[
                       createPropDesc(CNProperty(title), CNProperty(title), CNPropertyTypeString),
                       createPropDesc(CNProperty(foreignKey), CNProperty(foreignKey), CNPropertyTypeInteger),
                       createPropDesc(CNProperty(someDate), CNProperty(someDate), CNPropertyTypeDate),
                       createPropDesc(CNProperty(dataBlob), CNProperty(dataBlob), CNPropertyTypeData),
                       createFetchedPropDesc(CNProperty(fetchedObject), YES, CNClass(CNTestComplexObject), @"%K = $foreignKey", CNProperty(primaryKey)),
                       createFetchedPropDesc(CNProperty(fetchedList), NO, CNClass(CNTestComplexObject), @"%K < $someDate", CNProperty(someDate))
                       ];
    });
    return properties;
}

- (id)copyWithZone:(NSZone *)zone
{
    CNTestComplexObject *copied = [[CNTestComplexObject alloc] init];
    copied.title = [self.title copy];
    copied.foreignKey = self.foreignKey;
    copied.someDate = [self.someDate copy];
    copied.dataBlob = [self.dataBlob copy];
    
    return copied;
}

@end
