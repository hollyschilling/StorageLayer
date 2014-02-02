//
//  NSPredicate+CNStorageLayer.h
//  CNStorageLayer
//
//  Created by Neal Schilling on 1/25/14.
//  Copyright (c) 2014 CyanideHill. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSPredicate (CNStorageLayer)

- (BOOL)convertToClause:(NSString * __autoreleasing *)string
              arguments:(NSArray * __autoreleasing *)args
           usingMapping:(NSDictionary *)mapping;
@end

@interface NSComparisonPredicate (CNStorageLayer)

- (BOOL)convertToClause:(NSString * __autoreleasing *)string
              arguments:(NSArray * __autoreleasing *)args
           usingMapping:(NSDictionary *)mapping;

@end

@interface NSCompoundPredicate (CNStorageLayer)

- (BOOL)convertToClause:(NSString * __autoreleasing *)string
              arguments:(NSArray * __autoreleasing *)args
           usingMapping:(NSDictionary *)mapping;

@end

@interface NSExpression (CNStorageLayer)

- (BOOL)convertToClause:(NSString * __autoreleasing *)string
              arguments:(NSArray * __autoreleasing *)args
           usingMapping:(NSDictionary *)mapping;

@end