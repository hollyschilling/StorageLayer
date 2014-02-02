//
//  CNPropertyDescription.m
//  CNStorageLayer
//
//  Created by Neal Schilling on 1/25/14.
//  Copyright (c) 2014 CyanideHill. All rights reserved.
//

#import "CNPropertyDescription.h"

@interface CNPropertyDescription ()
@property (nonatomic, strong) NSString *propertyName;
@property (nonatomic, strong) NSString *queryFieldName;
@property (nonatomic, assign) CNPropertyType propertyType;
@end

@interface CNFetchedPropertyDescription ()
@property (nonatomic, strong) NSString *targetClassName;
@property (nonatomic, strong) NSPredicate *fetchPredicate;
@end


CNPropertyDescription *createPropDesc(NSString *pName, NSString *qfName, CNPropertyType pType)
{
    CNPropertyDescription *pd = [[CNPropertyDescription alloc] init];
    pd.propertyName = pName;
    pd.queryFieldName = qfName;
    pd.propertyType = pType;
    return pd;
}

CNFetchedPropertyDescription *createFetchedPropDesc(NSString *pName, BOOL oneToOne, NSString *className, NSString *predicate, ...)
{
    CNFetchedPropertyDescription *fpd = [[CNFetchedPropertyDescription alloc] init];
    fpd.propertyName = pName;
    fpd.queryFieldName = nil;
    fpd.propertyType = (oneToOne ? CNPropertyTypeObject : CNPropertyTypeObjectArray);
    fpd.targetClassName = className;
    va_list vl;
    va_start(vl,predicate);
    fpd.fetchPredicate = [NSPredicate predicateWithFormat:predicate
                                                arguments:vl];
    va_end(vl);
    
    return fpd;
}

@implementation CNPropertyDescription

@end

@implementation CNFetchedPropertyDescription

@end