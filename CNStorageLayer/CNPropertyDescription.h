//
//  CNPropertyDescription.h
//  CNStorageLayer
//
//  Created by Neal Schilling on 1/25/14.
//  Copyright (c) 2014 CyanideHill. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    CNPropertyTypeString,
    CNPropertyTypeDate,
    CNPropertyTypeData,
    CNPropertyTypeBoolean,
    CNPropertyTypeInteger,
    CNPropertyTypeFloat,
    CNPropertyTypeObject,
    CNPropertyTypeObjectArray
} CNPropertyType;

@class CNPropertyDescription;
@class CNFetchedPropertyDescription;

CNPropertyDescription *createPropDesc(NSString *pName, NSString *qfName, CNPropertyType pType);
CNFetchedPropertyDescription *createFetchedPropDesc(NSString *pName, BOOL oneToOne, NSString *className, NSString *predicate, ...);

@interface CNPropertyDescription : NSObject
@property (nonatomic, strong, readonly) NSString *propertyName;
@property (nonatomic, strong, readonly) NSString *queryFieldName;
@property (nonatomic, assign, readonly) CNPropertyType propertyType;
@end

@interface CNFetchedPropertyDescription : CNPropertyDescription
@property (nonatomic, strong, readonly) NSString *targetClassName;
@property (nonatomic, strong, readonly) NSPredicate *fetchPredicate;
@end
