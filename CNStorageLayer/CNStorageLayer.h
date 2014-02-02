//
//  CNStorageLayer.h
//  CNStorageLayer
//
//  Created by Neal Schilling on 1/25/14.
//  Copyright (c) 2014 CyanideHill. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "FMDatabaseQueue.h"
#import "CNStorageLayerObject.h"

#define CNClass(CLASS) NSStringFromClass([CLASS class])
#define CNProperty(PROPERTY) NSStringFromSelector(@selector(PROPERTY))
#define CNTableName(CLASS) [CLASS tableName]
#define CNQueryFieldName(CLASS, PROPERTY) [[CLASS propertyDescriptionForProperty:CNProperty(PROPERTY)] queryFieldName];

extern NSString * const CNStorageLayerSaveNotification;
extern NSString * const CNStorageLayerSavedClassesKey;
extern NSString * const CNStorageLayerSavedObjectsKey;

@interface CNStorageLayer : NSObject
@property (nonatomic, strong, readonly) FMDatabaseQueue *dbQueue;

- (instancetype)initWithDatabaseQueue:(FMDatabaseQueue *)dbQueue;

// Table Functions
- (BOOL)createTableForClass:(NSString *)className;

// Save
- (void)saveObjects:(NSArray *)objects;


// Simplified Fetching methods
- (NSArray *)fetchObjectsOfClass:(NSString *)className
                  matchingValues:(NSDictionary *)params;
- (NSArray *)fetchObjectsOfClass:(NSString *)className
                  matchingValues:(NSDictionary *)params
                 sortDescriptors:(NSArray *)sortDescriptors;
- (NSArray *)fetchObjectsOfClass:(NSString *)className
               matchingPredicate:(NSPredicate *)predicate;
- (NSArray *)fetchObjectsOfClass:(NSString *)className
               matchingPredicate:(NSPredicate *)predicate
                 sortDescriptors:(NSArray *)sortDescriptors;



// Base Fetching Method
- (id)objectOfClass:(NSString *)className
     withPrimaryKey:(NSNumber *)primaryKey;
- (NSArray *)fetchObjectsOfClass:(NSString *)className
                       fromQuery:(NSString *)query
                            args:(NSArray *)args;

@end
