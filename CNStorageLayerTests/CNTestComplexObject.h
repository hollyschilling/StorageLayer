//
//  CNTestComplexObject.h
//  CNStorageLayer
//
//  Created by Neal Schilling on 2/1/14.
//  Copyright (c) 2014 CyanideHill. All rights reserved.
//

#import "CNStorageLayerObject.h"

@interface CNTestComplexObject : CNStorageLayerObject <NSCopying>
@property (nonatomic, strong) NSString *title;
@property (nonatomic, assign) NSInteger foreignKey;
@property (nonatomic, strong) NSDate *someDate;
@property (nonatomic, strong) NSData *dataBlob;

@property (nonatomic, strong, readonly) CNTestComplexObject *fetchedObject;
@property (nonatomic, strong, readonly) NSArray *fetchedList;
@end
