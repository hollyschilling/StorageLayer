//
//  CNStorageLayerObject.m
//  CNStorageLayer
//
//  Created by Neal Schilling on 1/25/14.
//  Copyright (c) 2014 CyanideHill. All rights reserved.
//

#import "CNStorageLayerObject.h"

#import "CNStorageLayer.h"
#import <objc/runtime.h>

@interface CNStorageLayerObject ()
@property (nonatomic, strong) NSNumber *primaryKey;
@property (nonatomic, weak) CNStorageLayer *storageLayer;
@property (nonatomic, strong) NSMapTable *fetchedObjectStorage;
- (BOOL)isFetchedObjectStorageLoaded;
- (NSDictionary *)substitutionVariables;
@end

id fetchedPropertyAutoloader(CNStorageLayerObject *self, SEL _cmd)
{
    NSAssert(self.storageLayer!=nil, @"Can't fetch from objects that aren't saved.");
    NSString *propertyName = NSStringFromSelector(_cmd);
    id result = [self.fetchedObjectStorage objectForKey:propertyName];
    if (!result) {
        CNFetchedPropertyDescription *desc = (CNFetchedPropertyDescription *)[[self class] propertyDescriptionForProperty:propertyName];
        NSAssert([desc isKindOfClass:[CNFetchedPropertyDescription class]], @"Property Description for property %@ is not a fetched property.", propertyName);
        NSPredicate *origPred = desc.fetchPredicate;
        NSPredicate *subPred = [origPred predicateWithSubstitutionVariables:[self substitutionVariables]];
        NSArray *matches = [self.storageLayer fetchObjectsOfClass:desc.targetClassName
                                                matchingPredicate:subPred];
        if (desc.propertyType==CNPropertyTypeObject) {
            result = [matches firstObject];
        } else {
            result = matches;
        }
        
        if (result) {
            [self.fetchedObjectStorage setObject:result forKey:propertyName];
        }
    }
    return result;
}


@implementation CNStorageLayerObject

#pragma mark - Runtime Definitions

+ (BOOL)resolveInstanceMethod:(SEL)aSEL
{
    NSString *propertyName = NSStringFromSelector(aSEL);
    CNPropertyDescription *pd = [[self class] propertyDescriptionForProperty:propertyName];
    if (pd && (pd.propertyType==CNPropertyTypeObject || pd.propertyType==CNPropertyTypeObjectArray)) {
        class_addMethod([self class], aSEL, (IMP) fetchedPropertyAutoloader, "@");
        return YES;
    }
    return [super resolveInstanceMethod:aSEL];
}

//- (IMP)methodForSelector:(SEL)aSelector
//{
//    NSString *propertyName = NSStringFromSelector(aSelector);
//    CNPropertyDescription *pd = [[self class] propertyDescriptionForProperty:propertyName];
//    if (pd && (pd.propertyType==CNPropertyTypeObject || pd.propertyType==CNPropertyTypeObjectArray)) {
//        return (IMP)fetchedPropertyAutoloader;
//    }
//    return [super methodForSelector:aSelector];
//}

#pragma mark - Abstract Methods

+ (NSString *)tableName
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

+ (NSArray *)propertyDescriptions
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

+ (CNPropertyDescription *)primaryKeyDescription
{
    static CNPropertyDescription *desc = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        desc = createPropDesc(CNProperty(primaryKey), @"id", CNPropertyTypeInteger);
    });
    return desc;
}

#pragma mark - Helper methods

+ (NSArray *)fetchedPropertyNames
{
    static NSMapTable *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [NSMapTable strongToStrongObjectsMapTable];
    });
    NSMutableArray *result = [cache objectForKey:NSStringFromClass(self)];
    if (!result) {
        NSArray *pds = [self propertyDescriptions];
        result = [NSMutableArray arrayWithCapacity:[pds count]];
        for (CNPropertyDescription *pd in pds) {
            if (pd.propertyType==CNPropertyTypeObject || pd.propertyType==CNPropertyTypeObjectArray) {
                [result addObject:pd.propertyName];
            }
        }
        [cache setObject:result forKey:NSStringFromClass(self)];
    }
    return result;
}


+ (NSArray *)orderedPropertyNames
{
    static NSMapTable *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [NSMapTable strongToStrongObjectsMapTable];
    });
    NSMutableArray *result = [cache objectForKey:NSStringFromClass(self)];
    if (!result) {
        NSArray *pds = [self propertyDescriptions];
        result = [NSMutableArray arrayWithCapacity:[pds count]];
        for (CNPropertyDescription *pd in pds) {
            if (pd.propertyType!=CNPropertyTypeObject && pd.propertyType!=CNPropertyTypeObjectArray) {
                [result addObject:pd.propertyName];
            }
        }
        [cache setObject:[NSArray arrayWithArray:result]
                  forKey:NSStringFromClass(self)];
    }
    return result;
}

+ (NSArray *)orderedPropertyNamesWithPrimaryKey
{
    NSMutableArray *result = [NSMutableArray arrayWithArray:[self orderedPropertyNames]];
    [result addObject:CNProperty(primaryKey)];
    return result;
}

+ (NSArray *)orderedQueryFields
{
    static NSMapTable *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [NSMapTable strongToStrongObjectsMapTable];
    });
    NSMutableArray *result = [cache objectForKey:NSStringFromClass(self)];
    if (!result) {
        NSArray *pds = [self propertyDescriptions];
        result = [NSMutableArray arrayWithCapacity:[pds count]];
        for (CNPropertyDescription *pd in pds) {
            if (pd.propertyType!=CNPropertyTypeObject && pd.propertyType!=CNPropertyTypeObjectArray) {
                [result addObject:pd.queryFieldName];
            }
        }
        [cache setObject:[NSArray arrayWithArray:result]
                  forKey:NSStringFromClass(self)];
    }
    return result;
}

+ (NSString *)serializedOrderedQueryFields
{
    return [[self orderedQueryFields] componentsJoinedByString:@", "];
}

+ (NSArray *)orderedQueryFieldsWithPrimaryKey
{
    NSMutableArray *result = [NSMutableArray arrayWithArray:[self orderedQueryFields]];
    CNPropertyDescription *pd = [self primaryKeyDescription];
    [result addObject:pd.queryFieldName];
    return result;
}

+ (NSString *)serializedOrderedQueryFieldsWithPrimaryKey
{
    return [[self orderedQueryFieldsWithPrimaryKey] componentsJoinedByString:@", "];
}

+ (NSDictionary *)propertyDescriptionMapByPropertyName
{
    static NSMapTable *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [NSMapTable strongToStrongObjectsMapTable];
    });
    NSMutableDictionary *result = [cache objectForKey:NSStringFromClass(self)];
    if (!result) {
        NSArray *pds = [self propertyDescriptions];
        result = [NSMutableDictionary dictionaryWithCapacity:[pds count]];
        
        for (CNPropertyDescription *pd in pds) {
            [result setObject:pd forKey:pd.propertyName];
        }
        // Add the Primary Key
        [result setObject:[self primaryKeyDescription] forKey:CNProperty(primaryKey)];
        
        [cache setObject:result forKey:NSStringFromClass(self)];
    }
    return result;
}

+ (NSDictionary *)propertyDescriptionMapByQueryFieldName
{
    static NSMapTable *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [NSMapTable strongToStrongObjectsMapTable];
    });
    NSMutableDictionary *result = [cache objectForKey:NSStringFromClass(self)];
    if (!result) {
        NSArray *pds = [self propertyDescriptions];
        result = [NSMutableDictionary dictionaryWithCapacity:[pds count]];
        
        for (CNPropertyDescription *pd in pds) {
            // Fetched Properties do not have queryFieldNames
            if ([pd.queryFieldName length] > 0) {
                [result setObject:pd forKey:pd.queryFieldName];
            }
        }
        // Add the Primary Key
        CNPropertyDescription *pd = [self primaryKeyDescription];
        [result setObject:pd forKey:pd.queryFieldName];

        [cache setObject:result forKey:NSStringFromClass(self)];
    }
    return result;
}

+ (CNPropertyDescription *)propertyDescriptionForProperty:(NSString *)propertyName
{
    NSDictionary *map = [self propertyDescriptionMapByPropertyName];
    CNPropertyDescription *result = [map objectForKey:propertyName];
    return result;
}

+ (CNPropertyDescription *)propertyDescriptionForQueryField:(NSString *)queryField
{
    NSDictionary *map = [self propertyDescriptionMapByQueryFieldName];
    CNPropertyDescription *result = [map objectForKey:queryField];
    return result;
}


#pragma mark - Instance methods

- (BOOL)isInStorageLayer
{
    return self.storageLayer!=nil && self.primaryKey!=nil;
}

- (NSArray *)orderedValues
{
    NSArray *propertyNames = [[self class] orderedPropertyNames];
    NSMutableArray *values = [NSMutableArray arrayWithCapacity:[propertyNames count]];
    for (NSString *aPropName in propertyNames) {
        id value = [self valueForKey:aPropName];
        if (!value) {
            value = [NSNull null];
        }
        [values addObject:value];
    }
    return values;
}

- (NSArray *)orderedValuesWithPrimaryKey
{
    NSMutableArray *result = (NSMutableArray *)[self orderedValues];
    NSAssert([result isKindOfClass:[NSMutableArray class]], @"Array is not mutable.");
    [result addObject:self.primaryKey];
    return result;
}

- (void)willLoadValues
{
    
}

- (void)didLoadValues
{
    if ([self isFetchedObjectStorageLoaded]) {
        [self.fetchedObjectStorage removeAllObjects];
    }
}

- (BOOL)isFetchedObjectStorageLoaded
{
    return (_fetchedObjectStorage!=nil);
}

- (NSDictionary *)substitutionVariables
{
    NSArray *properties = [[self class] orderedPropertyNamesWithPrimaryKey];
    NSArray *values = [self orderedValuesWithPrimaryKey];
    NSDictionary *result = [[NSDictionary alloc] initWithObjects:values
                                                         forKeys:properties];
    return  result;
}


#pragma mark - Autoloader

- (NSMapTable *)fetchedObjectStorage
{
    if (!_fetchedObjectStorage) {
        _fetchedObjectStorage = [NSMapTable strongToStrongObjectsMapTable];
    }
    return  _fetchedObjectStorage;
}



@end
