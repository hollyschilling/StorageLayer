//
//  CNStorageLayerObject.h
//  CNStorageLayer
//
//  Created by Neal Schilling on 1/25/14.
//  Copyright (c) 2014 CyanideHill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CNPropertyDescription.h"

@class  CNStorageLayer;

@interface CNStorageLayerObject : NSObject
@property (nonatomic, weak, readonly) CNStorageLayer *storageLayer;
@property (nonatomic, strong, readonly) NSNumber *primaryKey;

// Abstract Method with a Default implementaion
+ (CNPropertyDescription *)primaryKeyDescription;

// Abstract Method
+ (NSString *)tableName;
+ (NSArray *)propertyDescriptions;

// Class Helper Methods
+ (NSArray *)fetchedPropertyNames;
+ (NSArray *)orderedPropertyNames; // Only native properties
+ (NSArray *)orderedPropertyNamesWithPrimaryKey;
+ (NSArray *)orderedQueryFields;
+ (NSString *)serializedOrderedQueryFields;
+ (NSString *)serializedOrderedQueryFieldsWithPrimaryKey;

+ (NSDictionary *)propertyDescriptionMapByPropertyName;
+ (NSDictionary *)propertyDescriptionMapByQueryFieldName;
+ (CNPropertyDescription *)propertyDescriptionForProperty:(NSString *)propertyName;
+ (CNPropertyDescription *)propertyDescriptionForQueryField:(NSString *)queryField;


// Instance Helper Methods
- (BOOL)isInStorageLayer;
- (NSArray *)orderedValues;
- (NSArray *)orderedValuesWithPrimaryKey;

- (void)willLoadValues NS_REQUIRES_SUPER;
- (void)didLoadValues NS_REQUIRES_SUPER;


@end
