//
//  NSPredicate+CNStorageLayer.m
//  CNStorageLayer
//
//  Created by Neal Schilling on 1/25/14.
//  Copyright (c) 2014 CyanideHill. All rights reserved.
//

#import "NSPredicate+CNStorageLayer.h"
#import "CNPropertyDescription.h"

@implementation NSPredicate (CNStorageLayer)

- (BOOL)convertToClause:(NSString * __autoreleasing *)string
              arguments:(NSArray * __autoreleasing *)args
           usingMapping:(NSDictionary *)mapping
{
    return NO;
}

@end

@implementation NSComparisonPredicate (CNStorageLayer)

- (BOOL)convertToClause:(NSString * __autoreleasing *)string
              arguments:(NSArray * __autoreleasing *)args
           usingMapping:(NSDictionary *)mapping
{
    static NSDictionary *binaryOps = nil;
    static NSDictionary *suffixs = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        binaryOps = @{
                      @(NSLessThanPredicateOperatorType) : @"<",
                      @(NSLessThanOrEqualToPredicateOperatorType) : @"<=",
                      @(NSGreaterThanPredicateOperatorType) : @">",
                      @(NSGreaterThanOrEqualToPredicateOperatorType) : @">=",
                      @(NSEqualToPredicateOperatorType) : @"=",
                      @(NSNotEqualToPredicateOperatorType) : @"<>",
                      @(NSBeginsWithPredicateOperatorType) : @"LIKE '%' ||",
                      @(NSEndsWithPredicateOperatorType) : @"LIKE",
                      @(NSContainsPredicateOperatorType) : @"LIKE '%' ||"
                      };
        suffixs = @{
                    @(NSLessThanPredicateOperatorType) : @"",
                    @(NSLessThanOrEqualToPredicateOperatorType) : @"",
                    @(NSGreaterThanPredicateOperatorType) : @"",
                    @(NSGreaterThanOrEqualToPredicateOperatorType) : @"",
                    @(NSEqualToPredicateOperatorType) : @"",
                    @(NSNotEqualToPredicateOperatorType) : @"",
                    @(NSBeginsWithPredicateOperatorType) : @"",
                    @(NSEndsWithPredicateOperatorType) : @" || '%'",
                    @(NSContainsPredicateOperatorType) : @" || '%'"
                    };
        
    });
  
  
    
    NSString *binaryOperator = binaryOps[@(self.predicateOperatorType)];
    NSString *suffix = suffixs[@(self.predicateOperatorType)];
    
    if (binaryOperator==nil || suffix==nil) {
        // Currently not implementing:
        // NSMatchesPredicateOperatorType
        // NSLikePredicateOperatorType
        // NSInPredicateOperatorType
        // NSCustomSelectorPredicateOperatorType
        // NSBetweenPredicateOperatorType
        NSLog(@"Unsupported predicateOperatorType: %u", (unsigned)self.predicateOperatorType);
        return NO;
    }
    
    NSMutableArray *resultArgs = [NSMutableArray arrayWithCapacity:4];
    
    NSArray *lhsArgs = nil;
    NSString *lhsClause = nil;
    BOOL lhsSuccess = [self.leftExpression convertToClause:&lhsClause
                                                 arguments:&lhsArgs
                                              usingMapping:mapping];
    if (!lhsSuccess) {
        NSLog(@"LHS Conversion failed.");
        return NO;
    }
    
    
    NSArray *rhsArgs = nil;
    NSString *rhsClause = nil;
    BOOL rhsSuccess = [self.rightExpression convertToClause:&rhsClause
                                                  arguments:&rhsArgs
                                               usingMapping:mapping];
    if (!rhsSuccess) {
        NSLog(@"RHS Conversion failed.");
        return NO;
    }
    
    // The special case to handle IS NULL and IS NOT NULL
    if ([rhsArgs count]==1 && [rhsArgs firstObject]==[NSNull null]) {
        if (self.predicateOperatorType==NSEqualToPredicateOperatorType) {
            *args = lhsArgs;
            *string = [NSString stringWithFormat:@"%@ IS NULL", lhsClause];
            return YES;
        } else if (self.predicateOperatorType==NSNotEqualToPredicateOperatorType) {
            *args = lhsArgs;
            *string = [NSString stringWithFormat:@"%@ IS NOT NULL", lhsClause];
            return YES;
        }
        NSLog(@"RHS cannot be nil for inequalities.");
        return NO;
    }
    
    [resultArgs addObjectsFromArray:lhsArgs];
    [resultArgs addObjectsFromArray:rhsArgs];
    *args = resultArgs;
    *string = [NSString stringWithFormat:@"%@ %@ %@%@", lhsClause, binaryOperator, rhsClause, suffix];
    return YES;
}

@end

@implementation NSCompoundPredicate (CNStorageLayer)

- (BOOL)convertToClause:(NSString * __autoreleasing *)string
              arguments:(NSArray * __autoreleasing *)args
           usingMapping:(NSDictionary *)mapping
{
    if (self.compoundPredicateType==NSNotPredicateType) {
        NSPredicate *first = [self.subpredicates firstObject];
        NSString *subclause = nil;
        BOOL success = [first convertToClause:&subclause
                                    arguments:args
                                 usingMapping:mapping];
        if (success) {
            *string = [NSString stringWithFormat:@"NOT (%@)", subclause];
        }
        return success;
    } else {
        NSString *joinString = (self.compoundPredicateType==NSAndPredicateType) ? @") AND (" : @") OR (";

        NSMutableArray *subClauses = [NSMutableArray arrayWithCapacity:[self.subpredicates count]];
        NSMutableArray *cumulativeArgs = [NSMutableArray arrayWithCapacity:[self.subpredicates count]];
        for (NSPredicate *aPredicate in self.subpredicates) {
            NSString *singleClause = nil;
            NSArray *singleArgs = nil;
            BOOL success = [aPredicate convertToClause:&singleClause
                                             arguments:&singleArgs
                                          usingMapping:mapping];
            if (!success) {
                return NO;
            }
            [subClauses addObject:singleClause];
            [cumulativeArgs addObjectsFromArray:singleArgs];
        }
        NSString *joined = [subClauses componentsJoinedByString:joinString];
        *string = [NSString stringWithFormat:@"(%@)", joined];
        *args = cumulativeArgs;
        return YES;
    }
}

@end

@implementation NSExpression (CNStorageLayer)

- (BOOL)convertToClause:(NSString * __autoreleasing *)string
              arguments:(NSArray * __autoreleasing *)args
           usingMapping:(NSDictionary *)mapping
{
    switch (self.expressionType) {
        case NSConstantValueExpressionType:
        {
            *args = @[self.constantValue ?: [NSNull null]];
            *string = @"?";
            return YES;
        }
        case NSKeyPathExpressionType:
        {
            CNPropertyDescription *property = [mapping objectForKey:self.keyPath];
            if (!property) {
                return NO;
            }
            if (property.propertyType==CNPropertyTypeObject || property.propertyType==CNPropertyTypeObjectArray) {
                NSLog(@"Lookup by join not yet implemented.");
                return  NO;
            }
            *args = @[];
            *string = property.queryFieldName;
            return YES;
        }
        default:
            NSLog(@"Cannot convert NSExpression of type %u.", (unsigned)self.expressionType);
            return NO;
            break;
    }
}

@end

