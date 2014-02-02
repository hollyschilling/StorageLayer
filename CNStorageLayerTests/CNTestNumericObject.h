//
//  CNTestNumericObject.h
//  CNStorageLayer
//
//  Created by Neal Schilling on 1/26/14.
//  Copyright (c) 2014 CyanideHill. All rights reserved.
//

#import "CNStorageLayerObject.h"
#import <QuartzCore/QuartzCore.h>

@interface CNTestNumericObject : CNStorageLayerObject <NSCopying>
@property (nonatomic, assign) BOOL isTrue;
@property (nonatomic, assign) NSInteger myInteger;
@property (nonatomic, assign) CGFloat myFloat;
@property (nonatomic, strong) NSNumber *integerObject;

@end
