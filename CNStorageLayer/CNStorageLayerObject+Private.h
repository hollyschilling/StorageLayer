//
//  CNStorageLayerObject+Private.h
//  CNStorageLayer
//
//  Created by Neal Schilling on 1/25/14.
//  Copyright (c) 2014 CyanideHill. All rights reserved.
//

#import "CNStorageLayerObject.h"

@interface CNStorageLayerObject (Private)
@property (nonatomic, weak) CNStorageLayer *storageLayer;
@property (nonatomic, strong) NSNumber *primaryKey;

@end
