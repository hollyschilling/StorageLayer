//
//  CNStorageLayer.m
//  CNStorageLayer
//
//  Created by Neal Schilling on 1/25/14.
//  Copyright (c) 2014 CyanideHill. All rights reserved.
//

#import "CNStorageLayer.h"

#import "CNStorageLayer.h"
#import "CNStorageLayerObject+Private.h"
#import "NSPredicate+CNStorageLayer.h"

#import "FMDatabase.h"

NSString * const CNStorageLayerSaveNotification = @"CNStorageLayerSaveNotification";
NSString * const CNStorageLayerSavedClassesKey = @"SavedClasses";
NSString * const CNStorageLayerSavedObjectsKey = @"SavedObjects";

@interface CNStorageLayer ()
@property (nonatomic, strong) NSMapTable *objectCache;

@property (nonatomic, strong) NSMapTable *selectCache;
@property (nonatomic, strong) NSMapTable *keyedSelectCache;
@property (nonatomic, strong) NSMapTable *insertCache;
@property (nonatomic, strong) NSMapTable *updateCache;
@property (nonatomic, strong) NSMapTable *deleteCache;
@property (nonatomic, strong )NSMapTable *keyedDeleteCache;

@property (nonatomic, strong) NSObject *lockObject;
@end

@implementation CNStorageLayer

#pragma mark - Lifecycle

+ (void)initialize
{
    if (![NSPredicate instancesRespondToSelector:@selector(convertToClause:arguments:usingMapping:)]) {
        [NSException raise:@"Missing Linker Flag"
                    format:@"The project must be compiled with the -ObjC flag set."];
    }
}

- (instancetype)initWithDatabaseQueue:(FMDatabaseQueue *)dbQueue
{
    self = [super init];
    if (self) {
        _dbQueue = dbQueue;
        // NSDateFormatter is not thread safe, so we don't keep a reference to it
        [_dbQueue inDatabase:^(FMDatabase *db) {
            if (![db hasDateFormatter]) {
                NSDateFormatter *df = [FMDatabase storeableDateFormat:@"yyyy-MM-dd hh:mm:ss.SSS"];
                df.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
                [db setDateFormat:df];
            }
        }];
    }
    return self;
}

#pragma mark - Table Functions

- (BOOL)createTableForClass:(NSString *)className
{
    Class targetClass = NSClassFromString(className);
    NSAssert([targetClass isSubclassOfClass:[CNStorageLayerObject class]], @"Can't create tables for classes that don't decent from CNStorageLayerObject.");
    CNPropertyDescription *primaryKey = [targetClass primaryKeyDescription];
    NSArray *propDescs = [targetClass propertyDescriptions];
    
    NSMutableArray *cols = [NSMutableArray arrayWithCapacity:[propDescs count] + 1];
    
    [cols addObject:[NSString stringWithFormat:@"%@ INTEGER PRIMARY KEY AUTOINCREMENT", primaryKey.queryFieldName]];
    
    for (CNPropertyDescription *pd in propDescs) {
        switch (pd.propertyType) {
            case CNPropertyTypeBoolean:
                [cols addObject:[NSString stringWithFormat:@"%@ INT(1)", pd.queryFieldName]];
                break;
            case CNPropertyTypeInteger:
                [cols addObject:[NSString stringWithFormat:@"%@ INTEGER", pd.queryFieldName]];
                break;
            case CNPropertyTypeFloat:
                [cols addObject:[NSString stringWithFormat:@"%@ REAL", pd.queryFieldName]];
                break;
            case CNPropertyTypeDate:
                [cols addObject:[NSString stringWithFormat:@"%@ VARCHAR(32)", pd.queryFieldName]];
                break;
            case CNPropertyTypeString:
                [cols addObject:[NSString stringWithFormat:@"%@ TEXT", pd.queryFieldName]];
                break;
            case CNPropertyTypeData:
                [cols addObject:[NSString stringWithFormat:@"%@ BLOB", pd.queryFieldName]];
                break;
            case CNPropertyTypeObject:
            case CNPropertyTypeObjectArray:
                //Do nothing for both fetched types.
                break;
        }
    }
    NSString *tableName = [targetClass tableName];
    NSString *colDesc = [cols componentsJoinedByString:@", "];
    NSString *query = [NSString stringWithFormat:@"CREATE TABLE %@ (%@)", tableName, colDesc];
    __block BOOL success = NO;
    
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        success = [db executeUpdate:query];
        if (!success) {
            NSString *errMsg = [db lastErrorMessage];
            NSLog(@"Error creating table for class %@. Error: %@", className, errMsg);
        }
    }];

    return success;
}

#pragma mark - Saving

- (void)saveObjects:(NSArray *)objects
{
    NSMutableSet *savedClassNames = [NSMutableSet setWithCapacity:[objects count]];
    
    [self.dbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        for (CNStorageLayerObject *anObject in objects) {
            NSAssert([anObject isKindOfClass:[CNStorageLayerObject class]], @"Can't save objects that don't decend from CNStorageLayerObject.");
            NSString *query = nil;
            NSArray *args = nil;
            if ([anObject isInStorageLayer]) {
                args = [anObject orderedValuesWithPrimaryKey];
                query = [self updateStatementForClass:CNClass(anObject)];
            } else {
                // Don't need primary key for insert because there isn't one yet
                args = [anObject orderedValues];
                query = [self insertStatementForClass:CNClass(anObject)];
            }
            BOOL success = [db executeUpdate:query withArgumentsInArray:args];
            if (success) {
                [savedClassNames addObject:CNClass(anObject)];
                
                if (![anObject isInStorageLayer]) {
                    sqlite_int64 rowid = [db lastInsertRowId];
                    anObject.primaryKey = @(rowid);
                    [self addObjectToCache:anObject];
                    
                }
            } else {
                NSString *errMsg = [db lastErrorMessage];
                NSLog(@"Error saving object to database. Error: %@", errMsg);
                *rollback = YES;
                return;
            }
        }
    }];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *userInfo = @{
                                   CNStorageLayerSavedClassesKey : [savedClassNames allObjects],
                                   CNStorageLayerSavedObjectsKey : objects
                                   };
        [[NSNotificationCenter defaultCenter] postNotificationName:CNStorageLayerSaveNotification
                                                            object:self
                                                          userInfo:userInfo];
    });
}

#pragma mark - Match-based Fetching

- (NSArray *)fetchObjectsOfClass:(NSString *)className
                  matchingValues:(NSDictionary *)params
{
    return [self fetchObjectsOfClass:className
                      matchingValues:params
                     sortDescriptors:@[]];
}

- (NSArray *)fetchObjectsOfClass:(NSString *)className
                  matchingValues:(NSDictionary *)params
                 sortDescriptors:(NSArray *)sortDescriptors
{
    __block NSString *query = nil;
    __block NSMutableArray *args = nil;
    Class targetClass = NSClassFromString(className);
    NSDictionary *map = [targetClass propertyDescriptionMapByPropertyName];
    
    // Cached Query functions are not thread safe, so we only access them
    // from the DB queue.
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        NSMutableArray *nonNullKeys = [NSMutableArray arrayWithCapacity:[params count]];
        NSMutableArray *nullKeys = [NSMutableArray arrayWithCapacity:[params count]];
        args = [NSMutableArray arrayWithCapacity:[params count]];
        
        [params enumerateKeysAndObjectsUsingBlock:^(NSString *aKey, id aValue, BOOL *stop) {
            if (aValue==[NSNull null]) {
                [nullKeys addObject:aKey];
            } else {
                [nonNullKeys addObject:aKey];
                [args addObject:aValue];
            }
        }];
    
        query = [self keyedSelectForClass:className withKeys:nonNullKeys];
        if ([nullKeys count] > 0) {
            NSString *nullClauses = [nullKeys componentsJoinedByString:@" IS NULL AND "];
            query = [NSString stringWithFormat:@"%@ AND %@ IS NULL", query, nullClauses];
        }
        
        NSString *orderBy = [self orderByClauseFromSortDescriptors:sortDescriptors
                                                  usingPropertyMap:map];
        if ([orderBy length] > 0) {
            query = [NSString stringWithFormat:@"%@ ORDER BY %@", query, orderBy];
        }
    }];
    
    return [self fetchObjectsOfClass:className
                           fromQuery:query
                                args:args];
    
}

#pragma mark - Predicate-based Fetching

- (NSArray *)fetchObjectsOfClass:(NSString *)className
               matchingPredicate:(NSPredicate *)predicate
{
    return [self fetchObjectsOfClass:className
                   matchingPredicate:predicate
                     sortDescriptors:@[]];
}

- (NSArray *)fetchObjectsOfClass:(NSString *)className
               matchingPredicate:(NSPredicate *)predicate
                 sortDescriptors:(NSArray *)sortDescriptors
{
    __block NSString *query = nil;
    Class targetClass = NSClassFromString(className);
    NSString *tableName = [targetClass tableName];
    NSDictionary *map = [targetClass propertyDescriptionMapByPropertyName];
    NSString *serializedFields = [targetClass serializedOrderedQueryFieldsWithPrimaryKey];

    NSString *whereClause = nil;
    NSArray *args = nil;
    BOOL success = [predicate convertToClause:&whereClause
                                    arguments:&args
                                 usingMapping:map];
    NSAssert(success, @"Failed to convert predicate to SQL clause.");

    // We always need at least one clause
    whereClause = ([whereClause length] > 0 ? whereClause : @"1 = 1");
    query = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@", serializedFields, tableName, whereClause];

    // Add Order By clause if there is one
    NSString *orderBy = [self orderByClauseFromSortDescriptors:sortDescriptors
                                              usingPropertyMap:map];
    if ([orderBy length] > 0) {
        query = [NSString stringWithFormat:@"%@ ORDER BY %@", query, orderBy];
    }
   
    return [self fetchObjectsOfClass:className
                           fromQuery:query
                                args:args];
}

#pragma mark - Identifier-based Fetching Method

- (id)objectOfClass:(NSString *)className
     withPrimaryKey:(NSNumber *)primaryKey
{
    NSAssert(primaryKey!=nil, @"PrimaryKey cannot be nil.");
    __block CNStorageLayerObject *result = nil;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        result = [self objectFromCacheOfClass:className
                               withPrimaryKey:primaryKey];
        if (!result) {
            NSString *query = [self selectStatementForClass:className];
            FMResultSet *rs = [db executeQuery:query withArgumentsInArray:@[primaryKey]];
            if (!rs) {
                NSString *errMsg = [db lastErrorMessage];
                NSLog(@"Error executing Query (%@). Error: %@", query, errMsg);
                return;
            }
            if ([rs next]) {
                Class objectClass = NSClassFromString(className);
                NSAssert([objectClass isSubclassOfClass:[CNStorageLayerObject class]], @"Object class must be a subclass of CNStorageLayerObject.");
                NSDictionary *map = [objectClass propertyDescriptionMapByQueryFieldName];
                result = [[objectClass alloc] init];
                [self populateObject:result
                            database:db
                           resultSet:rs
                             mapping:map];
                [self addObjectToCache:result];
            }
        }
    }];
    
    return result;
}

#pragma mark - Query-based Fetching Method

- (NSArray *)fetchObjectsOfClass:(NSString *)className
                       fromQuery:(NSString *)query
                            args:(NSArray *)args
{
    __block NSMutableArray *results = nil;
    
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        
        FMResultSet *rs = [db executeQuery:query
                      withArgumentsInArray:args];
        if (!rs) {
            NSString *errMsg = [db lastErrorMessage];
            NSLog(@"Error executing Query (%@). Error: %@", query, errMsg);
            return;
        }
        Class objectClass = NSClassFromString(className);
        NSAssert([objectClass isSubclassOfClass:[CNStorageLayerObject class]], @"Object class must be a subclass of CNStorageLayerObject.");
        NSDictionary *map = [objectClass propertyDescriptionMapByQueryFieldName];
        CNPropertyDescription *primaryKeyDescription = [objectClass primaryKeyDescription];
        results = [[NSMutableArray alloc] initWithCapacity:100];
        while ([rs next]) {
            NSNumber *pk = [rs objectForColumnName:primaryKeyDescription.queryFieldName];
            NSAssert(pk!=nil && ![pk isKindOfClass:[NSNull class]], @"Primary Key in result set cannot be nil.");
            CNStorageLayerObject *obj = nil;
            obj = [self objectFromCacheOfClass:className withPrimaryKey:pk];
            if (!obj) {
                obj = [[objectClass alloc] init];
                [self populateObject:obj
                            database:db
                           resultSet:rs
                             mapping:map];
                [self addObjectToCache:obj];
            }
            [results addObject:obj];
        }
    }];
    
    return results;
}

#pragma mark - Internal Methods

- (NSString *)orderByClauseFromSortDescriptors:(NSArray *)sortDescriptors
                              usingPropertyMap:(NSDictionary *)mapping
{
    NSMutableArray *clauses = [NSMutableArray arrayWithCapacity:[sortDescriptors count]];
    for (NSSortDescriptor *sd in sortDescriptors) {
        CNPropertyDescription *pd = [mapping objectForKey:sd.key];
        NSAssert(pd!=nil, @"Can't find Property Descriptor for key %@", sd.key);
        [clauses addObject:[NSString stringWithFormat:@"%@ %@", pd.queryFieldName, (sd.ascending ? @"ASC" : @"DESC")]];
    }
    return [clauses componentsJoinedByString:@", "];
}

- (void)populateObject:(CNStorageLayerObject *)object
              database:(FMDatabase *)database
             resultSet:(FMResultSet *)resultSet
               mapping:(NSDictionary *)mapping
{
    NSArray *queryFields = mapping.allKeys;
    for (NSString *aQueryField in queryFields) {
        CNPropertyDescription *pd = mapping[aQueryField];
        id value = nil;
        switch (pd.propertyType) {
            case CNPropertyTypeDate:
                value = [resultSet dateForColumn:aQueryField];
                break;
            case CNPropertyTypeString:
                value = [resultSet objectForColumnName:aQueryField];

                if ([value isKindOfClass:[NSNumber class]]) {
                    value = [value stringValue];
                }
                break;
            case CNPropertyTypeInteger:
                value = [resultSet objectForColumnName:aQueryField];
                if ([value isKindOfClass:[NSString class]]) {
                    value = @([value integerValue]);
                }
                break;
            case CNPropertyTypeFloat:
                value = [resultSet objectForColumnName:aQueryField];
                if ([value isKindOfClass:[NSString class]]) {
                    value = @([value floatValue]);
                }
                break;
            case CNPropertyTypeBoolean:
                value = [resultSet objectForColumnName:aQueryField];
                if ([value isKindOfClass:[NSString class]]) {
                    value = @([value boolValue]);
                }
                break;
            case CNPropertyTypeData:
                value = [resultSet objectForColumnName:aQueryField];
                NSAssert(![value isKindOfClass:[NSNumber class]], @"Can't convert a number to data.");
                if ([value isKindOfClass:[NSString class]]) {
                    value = [value dataUsingEncoding:NSUTF8StringEncoding];
                }
                break;
            default:
                NSLog(@"Property Type %u should not be received here.", pd.propertyType);
                break;
        }
        if (value==[NSNull null]) {
            value = nil;
        }
        
        [object setValue:value forKey:pd.propertyName];
    }
}

- (NSString *)placeHoldersOfLength:(NSInteger)length
{
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:length];
    for (int i=0; i<length; i++) {
        [array addObject:@"?"];
    }
    return [array componentsJoinedByString:@", "];
}

#pragma mark - Object Cache Management

- (void)addObjectToCache:(CNStorageLayerObject *)object
{
    NSAssert(object!=nil, @"Object cannot be nil.");
    NSAssert(object.storageLayer==nil, @"Object is already in the Storage Layer.");
    
    NSMapTable *cache = [self objectCacheForClassName:CNClass(object)];
    
    [cache setObject:object forKey:object.primaryKey];
    object.storageLayer = self;
}

- (CNStorageLayerObject *)objectFromCacheOfClass:(NSString *)className
                                  withPrimaryKey:(NSNumber *)primaryKey
{
    NSMapTable *cache = [self objectCacheForClassName:className];
    CNStorageLayerObject *result = [cache objectForKey:primaryKey];
    return result;
}

- (void)removeFromCacheObjectOfClass:(NSString *)className
                      withPrimaryKey:(NSNumber *)primaryKey
{
    NSMapTable *cache = [self objectCacheForClassName:className];
    
    // If the object is in the cache, we need to remove the link to the
    // storage layer.
    CNStorageLayerObject *obj = [cache objectForKey:primaryKey];
    if (obj) {
        obj.primaryKey = nil;
        obj.storageLayer = nil;
        [cache removeObjectForKey:primaryKey];
    }
}

#pragma mark - Statement Generation

- (NSString *)selectStatementForClass:(NSString *)className
{
    NSString *query = [self.selectCache objectForKey:className];
    if (!query) {
        Class objClass = NSClassFromString(className);
        NSString *tableName = [objClass tableName];
        NSString *serializedFields = [objClass serializedOrderedQueryFields];
        CNPropertyDescription *pd = [objClass primaryKeyDescription];
        query = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@ = ?", serializedFields, tableName, pd.queryFieldName];
        [self.selectCache setObject:query forKey:className];
    }
    return query;
}

- (NSString *)keyedSelectForClass:(NSString *)className
                         withKeys:(NSArray *)paramKeys
{
    NSString *key = [NSString stringWithFormat:@"%@^^%@", className, [paramKeys componentsJoinedByString:@"^^"]];
    
    NSString *query = [self.keyedSelectCache objectForKey:key];
    if (!query) {
        Class objClass = NSClassFromString(className);
        NSString *tableName = [objClass tableName];
        NSDictionary *map = [objClass propertyDescriptionMapByQueryFieldName];
        NSString *serializedFields = [objClass serializedOrderedQueryFieldsWithPrimaryKey];
        NSString *whereClause = [self whereClauseForProperties:paramKeys
                                                  usingMapping:map];
        // We always need at least one clause
        whereClause = ([whereClause length] > 0 ? whereClause : @"1 = 1");
        query = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@", serializedFields, tableName, whereClause];
        [self.keyedSelectCache setObject:key forKey:className];
    }
    return query;
}

- (NSString *)deleteStatementForClass:(NSString *)className
{
    NSString *query = [self.deleteCache objectForKey:className];
    if (!query) {
        Class objClass = NSClassFromString(className);
        NSString *tableName = [objClass tableName];
        CNPropertyDescription *pd = [objClass primaryKeyDescription];
        query = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ = ?", tableName, pd.queryFieldName];
        [self.deleteCache setObject:query forKey:className];
    }
    return query;
}

- (NSString *)keyedDeleteStatementForClass:(NSString *)className
                                  withKeys:(NSArray *)paramKeys
{
    NSString *key = [NSString stringWithFormat:@"%@^^%@", className, [paramKeys componentsJoinedByString:@"^^"]];
    
    NSString *query = [self.keyedDeleteCache objectForKey:key];
    if (!query) {
        Class objClass = NSClassFromString(className);
        NSString *tableName = [objClass tableName];
        NSDictionary *map = [objClass propertyDescriptionMapByQueryFieldName];
        NSString *whereClause = [self whereClauseForProperties:paramKeys
                                                  usingMapping:map];
        // We always need at least one clause
        whereClause = ([whereClause length] > 0 ? whereClause : @"1 = 1");
        query = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@", tableName, whereClause];
        [self.keyedDeleteCache setObject:key forKey:className];
    }
    return query;
}

- (NSString *)insertStatementForClass:(NSString *)className
{
    NSString *query = [self.insertCache objectForKey:className];
    if (!query) {
        Class objClass = NSClassFromString(className);
        NSString *tableName = [objClass tableName];
        NSArray *queryFields = [objClass orderedQueryFields];
        NSString *serializedFields = [queryFields componentsJoinedByString:@", "];
        NSString *placeHolders = [self placeHoldersOfLength:[queryFields count]];
        query = [NSString stringWithFormat:@"INSERT INTO %@ (%@) VALUES (%@)", tableName, serializedFields, placeHolders];
        [self.insertCache setObject:query forKey:className];
    }
    return query;
}

- (NSString *)updateStatementForClass:(NSString *)className
{
    NSString *query = [self.updateCache objectForKey:className];
    if (!query) {
        Class objClass = NSClassFromString(className);
        NSString *tableName = [objClass tableName];
        NSArray *queryFields = [objClass orderedQueryFields];
        NSString *serializedFields = [queryFields componentsJoinedByString:@" = ?, "];
        CNPropertyDescription *pd = [objClass primaryKeyDescription];
        query = [NSString stringWithFormat:@"UPDATE %@ SET %@ = ? WHERE %@ = ?", tableName, serializedFields, pd.queryFieldName];
        [self.updateCache setObject:query forKey:className];
    }
    return query;
}

- (NSString *)whereClauseForProperties:(NSArray *)properties
                          usingMapping:(NSDictionary *)map
{
    NSMutableArray *fields = [NSMutableArray arrayWithCapacity:[properties count]];
    
    for (NSString *aKey in properties) {
        CNPropertyDescription *pd = map[aKey];
        [fields addObject:pd.queryFieldName];
    }
    NSString *whereParams = [fields componentsJoinedByString:@" = ? AND "];
    if ([whereParams length] > 0) {
        whereParams = [whereParams stringByAppendingString:@" = ?"];
    }
    return whereParams;
}

- (NSString *)whereClauseForNullProperties:(NSArray *)properties
                                  usingMap:(NSDictionary *)map
{
    NSMutableArray *fields = [NSMutableArray arrayWithCapacity:[properties count]];
    
    for (NSString *aKey in properties) {
        CNPropertyDescription *pd = map[aKey];
        [fields addObject:pd.queryFieldName];
    }
    NSString *clause = [fields componentsJoinedByString:@" IS NULL AND "];
    if ([clause length] > 0) {
        clause = [clause stringByAppendingString:@" IS NULL"];
    }
    return clause;
}

#pragma mark - Autoloaders

- (NSMapTable *)objectCacheForClassName:(NSString *)className
{
    NSMapTable *cache = [self.objectCache objectForKey:className];
    if (!cache) {
        cache = [[NSMapTable alloc] initWithKeyOptions:NSMapTableCopyIn
                                          valueOptions:NSMapTableWeakMemory
                                              capacity:10];
        [self.objectCache setObject:cache forKey:className];
    }
    return  cache;
}

- (NSMapTable *)objectCache
{
    if (!_objectCache) {
        _objectCache = [[NSMapTable alloc] initWithKeyOptions:NSMapTableCopyIn
                                                 valueOptions:NSMapTableStrongMemory capacity:10];
    }
    return _objectCache;
}

- (NSMapTable *)selectCache
{
    if (!_selectCache) {
        _selectCache = [[NSMapTable alloc] initWithKeyOptions:NSMapTableCopyIn
                                                 valueOptions:NSMapTableStrongMemory capacity:10];
    }
    return _selectCache;
}

- (NSMapTable *)keyedSelectCache
{
    if (!_keyedSelectCache) {
        _keyedSelectCache = [[NSMapTable alloc] initWithKeyOptions:NSMapTableCopyIn
                                                      valueOptions:NSMapTableStrongMemory   capacity:10];
    }
    return _keyedSelectCache;
}

- (NSMapTable *)insertCache
{
    if (!_insertCache) {
        _insertCache = [[NSMapTable alloc] initWithKeyOptions:NSMapTableCopyIn
                                                 valueOptions:NSMapTableStrongMemory capacity:10];
    }
    return _insertCache;
}

- (NSMapTable *)updateCache
{
    if (!_updateCache) {
        _updateCache = [[NSMapTable alloc] initWithKeyOptions:NSMapTableCopyIn
                                                 valueOptions:NSMapTableStrongMemory capacity:10];
    }
    return _updateCache;
}

- (NSMapTable *)deleteCache
{
    if (!_deleteCache) {
        _deleteCache = [[NSMapTable alloc] initWithKeyOptions:NSMapTableCopyIn
                                                 valueOptions:NSMapTableStrongMemory capacity:10];
    }
    return _deleteCache;
}

- (NSMapTable *)keyedDeleteCache
{
    if (!_keyedDeleteCache) {
        _keyedDeleteCache = [[NSMapTable alloc] initWithKeyOptions:NSMapTableCopyIn
                                                      valueOptions:NSMapTableStrongMemory capacity:10];
    }
    return _keyedDeleteCache;
}


@end
