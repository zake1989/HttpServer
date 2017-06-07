//
//  MTFileManager.m
//  MTFileManager
//
//  Created by zeng on 20/04/2017.
//  Copyright © 2017 zengyukai. All rights reserved.
//

#import "MTFileManager.h"
#import <ImageIO/ImageIO.h>

@implementation MTFileManager

+ (BOOL)isNotError:(NSError **)error {
    //the first check prevents EXC_BAD_ACCESS error in case methods are called passing nil to error argument
    //the second check prevents that the methods returns always NO just because the error pointer exists (so the first condition returns YES)
    return ((error == nil) || ((*error) == nil));
}

+ (void)defineError:(NSError **)error withErrorMessage:(NSString *)message {
    if (error) {
        *error = [NSError errorWithDomain:@"MTFileManager"
                                     code:-1
                                 userInfo:@{NSLocalizedDescriptionKey: message}];
    }
}

#pragma mark - 基础接口 创建需要的文件夹 文件 路径

+ (NSString *)cachesDirectoryPath {
    static NSString *path = nil;
    static dispatch_once_t token;
    // 只做一次这个路径生成  路径方法都是这套逻辑
    dispatch_once(&token, ^{
        path = [self customeDirectoryPathWithAppendPath:NSCachesDirectory];
    });
    
    return path;
}

+ (NSString *)cachesFilePathWithAppendPath:(NSString *)filePath {
    // 使用path的方式拼接 可以忽略掉 filepath变量是否用／开始
    return [[self cachesDirectoryPath] stringByAppendingPathComponent:filePath];
}

+ (NSString *)documentDirectoryPath {
    static NSString *path = nil;
    static dispatch_once_t token;
    
    dispatch_once(&token, ^{
        path =[self customeDirectoryPathWithAppendPath:NSDocumentDirectory];
    });
    
    return path;
}

+ (NSString *)documentFilePathWithAppendPath:(NSString *)filePath {
    return [[self documentDirectoryPath] stringByAppendingPathComponent:filePath];
}

+ (NSString *)libraryDirectoryPath {
    static NSString *path = nil;
    static dispatch_once_t token;
    
    dispatch_once(&token, ^{
        path = [self customeDirectoryPathWithAppendPath:NSLibraryDirectory];
    });
    
    return path;
}

+ (NSString *)libraryFilePathWithAppendPath:(NSString *)filePath {
    return [[self libraryDirectoryPath] stringByAppendingPathComponent:filePath];
}

+ (NSString *)temporaryDirectoryPath {
    static NSString *path = nil;
    static dispatch_once_t token;
    
    dispatch_once(&token, ^{
        path = NSTemporaryDirectory();
    });
    
    return path;
}

+ (NSString *)temporaryFilePathWithAppendPath:( NSString *)filePath {
    return [[self temporaryDirectoryPath] stringByAppendingPathComponent:filePath];
}

+ (NSString *)customeDirectoryPathWithAppendPath:(NSSearchPathDirectory)directroyType {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(directroyType, NSUserDomainMask, YES);
    return [paths lastObject];
}

+ (NSString *)customeFilePathWithAppendPath:(NSSearchPathDirectory)directoryType filePath:( NSString *)filePath {
    return [[self customeDirectoryPathWithAppendPath:directoryType] stringByAppendingPathComponent:filePath];
}

+ (NSString *)applicationSupportDirectoryPath {
    static NSString *path = nil;
    static dispatch_once_t token;
    
    dispatch_once(&token, ^{
        path = [self customeDirectoryPathWithAppendPath:NSApplicationSupportDirectory];
    });
    
    return path;
}

+ (NSString *)applicationSupportFilePathWithAppendPath:( NSString *)filePath {
    return [[self applicationSupportDirectoryPath] stringByAppendingPathComponent:filePath];
}

+ (NSString *)mainBundleDirectoryPath {
    return [NSBundle mainBundle].resourcePath;
}

+ (NSString *)mainBundleFilePathWithAppendPath:( NSString *)filePath {
    return [[self mainBundleDirectoryPath] stringByAppendingString:filePath];
}

#pragma mark - 基础接口 将文件移除

+ (BOOL)removeItemAtPath:( NSString *)path error:(NSError **)error {
    // 确保移除前 该文件是存在的
    if ([self existsItemAtPath:path]) {
        return [[NSFileManager defaultManager] removeItemAtPath:path error:error];
    }
    [self defineError:error withErrorMessage:@"File not Exist!"];
    return NO;
}

+ (void)removeItemInBackgroundAtPath:(nonnull NSString *)path
                          completion:(completion _Nullable )complete {
    NSOperationQueue *removeQueue = [[NSOperationQueue alloc] init];
    [removeQueue addOperationWithBlock:^{
        // 移除文件
        NSError *error = nil;
        BOOL result = [MTFileManager removeItemAtPath:path error:&error];
        // 回到主线程 回调
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            if (complete) {
                complete(result, error);
            }
        }];
    }];
}

+ (BOOL)removeItemsInDirectory:(NSString *)path error:(NSError **)error {
    // 确保移除前 文件夹存在
    if ([self existsDirectoryAtPath:path]) {
        BOOL success = YES;
        for (NSString *subPath in [self listItemsInDirectoryAtPath:path deep:NO]) {
            success &= [self removeItemAtPath:subPath error:error];
        }
        return success;
    }
    [self defineError:error withErrorMessage:@"Directory not Exist!"];
    return  NO;
}

+ (void)removeItemsInBackgroundInDirectory:(nonnull NSString *)path
                                completion:(completion _Nullable )complete {
    NSOperationQueue *removeQueue = [[NSOperationQueue alloc] init];
    [removeQueue addOperationWithBlock:^{
        // 移除文件
        NSError *error = nil;
        BOOL result = [MTFileManager removeItemsInDirectory:path error:&error];
        // 回到主线程 回调
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            if (complete) {
                complete(result, error);
            }
        }];
    }];
}

#pragma mark - 基础接口 判断 文件 文件夹 是否存在

+ (BOOL)existsItemAtPath:(NSString *)path {
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

+ (BOOL)existsFileAtPath:(NSString *)path {
    BOOL isDir;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
    return exists && !isDir;
}

+ (BOOL)existsDirectoryAtPath:(NSString *)path {
    BOOL isDir;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
    return exists && isDir;
}

#pragma mark - 基础接口 将文件内容写入到制定目录

+ (BOOL)createFileAtPath:(NSString *)path withContent:(NSObject *)content overwrite:(BOOL)overwrite error:(NSError **)error {
    if(![self existsItemAtPath:path] || // 确保文件路径是空的
       (overwrite && [self removeItemAtPath:path error:error] && [self isNotError:error])) { // 或者开启overwrite 移除非空文件来写入 另外还要保证error指针传入的正确性
        // 先创建文件夹
        if([self createDirectoriesForFileAtPath:path error:error]) {
            // 再创建文件
            BOOL created = [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
            // 如果内容不为空 写入内容
            if(content != nil) {
                [self writeFileAtPath:path content:content error:error];
            }
            return (created && [self isNotError:error]);
        } else {
            return NO;
        }
    } else {
        [self defineError:error withErrorMessage:@"File can not created!"];
        return NO;
    }
}

+ (void)createFileInBackgroundAtPath:(nonnull NSString *)path
                         withContent:(nullable NSObject *)content
                           overwrite:(BOOL)overwrite
                          completion:(completion _Nullable )complete {
    NSOperationQueue *createQueue = [[NSOperationQueue alloc] init];
    [createQueue addOperationWithBlock:^{
        // 创建文件
        NSError *error = nil;
        BOOL result = [MTFileManager createFileAtPath:path
                                          withContent:content
                                            overwrite:overwrite
                                                error:&error];
        // 回到主线程 回调
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            if (complete) {
                complete(result, error);
            }
        }];
    }];
}

+ (BOOL)createDirectoriesForPath:( NSString *)path error:(NSError **)error {
    return [[NSFileManager defaultManager] createDirectoryAtPath:path
                                     withIntermediateDirectories:YES
                                                      attributes:nil
                                                           error:error];
}

+ (BOOL)createDirectoriesForFileAtPath:( NSString *)path error:(NSError **)error {
    // 确保文件路径最后不带／
    NSString *pathLastChar = [path substringFromIndex:(path.length - 1)];
    if([pathLastChar isEqualToString:@"/"]) {
        [self defineError:error withErrorMessage:@"Directory Path cannot end with /!"];
        return NO;
    }
    // 如果文件路径已经存在直接返回
    if ([self existsDirectoryAtPath:[path stringByDeletingLastPathComponent]]) {
        return YES;
    }
    return [self createDirectoriesForPath:[path stringByDeletingLastPathComponent] error:error];
}

+ (BOOL)writeFileAtPath:(NSString *)path content:(NSObject *)content error:(NSError **)error {
    // 为了保证写入 写入前 创建文件
    [self createFileAtPath:path withContent:nil overwrite:YES error:error];
    NSString *absolutePath = path;
    // 更具不同类型 处理保存逻辑
    if([content isKindOfClass:[NSMutableArray class]]) {
        [((NSMutableArray *)content) writeToFile:absolutePath atomically:YES];
    } else if([content isKindOfClass:[NSArray class]]) {
        [((NSArray *)content) writeToFile:absolutePath atomically:YES];
    } else if([content isKindOfClass:[NSMutableData class]]) {
        [((NSMutableData *)content) writeToFile:absolutePath atomically:YES];
    } else if([content isKindOfClass:[NSData class]]) {
        [((NSData *)content) writeToFile:absolutePath atomically:YES];
    } else if([content isKindOfClass:[NSMutableDictionary class]]) {
        [((NSMutableDictionary *)content) writeToFile:absolutePath atomically:YES];
    } else if([content isKindOfClass:[NSDictionary class]]) {
        [((NSDictionary *)content) writeToFile:absolutePath atomically:YES];
    } else if([content isKindOfClass:[NSJSONSerialization class]]) {
        [((NSDictionary *)content) writeToFile:absolutePath atomically:YES];
    } else if([content isKindOfClass:[NSMutableString class]]) {
        [[((NSString *)content) dataUsingEncoding:NSUTF8StringEncoding] writeToFile:absolutePath atomically:YES];
    } else if([content isKindOfClass:[NSString class]]) {
        [[((NSString *)content) dataUsingEncoding:NSUTF8StringEncoding] writeToFile:absolutePath atomically:YES];
    } else if([content isKindOfClass:[UIImage class]]) {
        [UIImagePNGRepresentation((UIImage *)content) writeToFile:absolutePath atomically:YES];
    } else if([content conformsToProtocol:@protocol(NSCoding)]) {
        [NSKeyedArchiver archiveRootObject:content toFile:absolutePath];
    } else {
        [self defineError:error
         withErrorMessage:[NSString stringWithFormat:@"content of type %@ is not handled.", NSStringFromClass([content class])]];
        return NO;
    }
    return YES;
}

#pragma mark - 基础接口 寻找已有的文件夹 文件 路径

+ (NSArray *)searchInDirectory:(NSString *)path withItemName:(NSString *)itemName {
    // 创建目录枚举 会包含目录内的所有内容
    NSMutableArray *items = [NSMutableArray new];
    NSDirectoryEnumerator *direnum = [[NSFileManager defaultManager] enumeratorAtPath:path];
    NSString *documentsSubpath;
    // 遍历文件夹下 所有文件
    while (documentsSubpath = [direnum nextObject]) {
        if ([documentsSubpath.lastPathComponent isEqual:itemName]){
            [items addObject:[path stringByAppendingPathComponent:documentsSubpath]];
        }
    }
    return items;
}

+ (NSArray *)searchDirectoriesInSandBoxWith:( NSString *)directoryName {
    NSMutableArray *directories = [NSMutableArray new];
    NSString *mainPath = [[MTFileManager documentDirectoryPath] stringByDeletingLastPathComponent];
    NSDirectoryEnumerator *direnum = [[NSFileManager defaultManager] enumeratorAtPath:mainPath];
    NSString *documentsSubpath;
    
    while (documentsSubpath = [direnum nextObject]) {
        if ([documentsSubpath.lastPathComponent isEqual:directoryName] &&
            [self existsDirectoryAtPath:[mainPath stringByAppendingPathComponent:documentsSubpath]]) {
            [directories addObject:[mainPath stringByAppendingPathComponent:documentsSubpath]];
        }
    }
    return directories;
}

+ (NSArray *)searchFilesInSandBoxWith:( NSString *)fileName {
    NSMutableArray *directories = [NSMutableArray new];
    NSString *mainPath = [[MTFileManager documentDirectoryPath] stringByDeletingLastPathComponent];
    NSDirectoryEnumerator *direnum = [[NSFileManager defaultManager] enumeratorAtPath:mainPath];
    NSString *documentsSubpath;

    while (documentsSubpath = [direnum nextObject]) {
        if ([documentsSubpath.lastPathComponent isEqual:fileName] &&
            [self existsFileAtPath:[mainPath stringByAppendingPathComponent:documentsSubpath]]) {
            [directories addObject:[mainPath stringByAppendingPathComponent:documentsSubpath]];
        }
    }
    
    return directories;
}

#pragma mark - 基础接口 读取文件地址内容
// 读取文件接口 均会判断输入路径是否合法 如果不合法 输出nil
+ (NSObject *)readFileAtPathAsCustomModel:(NSString *)path {
    if (![self existsFileAtPath:path]) {
        return nil;
    }
    return [NSKeyedUnarchiver unarchiveObjectWithFile:path];
}

+ (void)readFileInBackgroundAtPathAsCustomModel:(nonnull NSString *)path
                                     completion:(void (^_Nullable)(NSObject * _Nullable value))complete {
    NSOperationQueue *createQueue = [[NSOperationQueue alloc] init];
    [createQueue addOperationWithBlock:^{
        // 创建文件
        NSObject *result = [MTFileManager readFileAtPathAsCustomModel:path];
        // 回到主线程 回调
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            if (complete) {
                complete(result);
            }
        }];
    }];
}

+ (NSArray *)readFileAtPathAsArray:(NSString *)path {
    if (![self existsFileAtPath:path]) {
        return nil;
    }
    return [NSArray arrayWithContentsOfFile:path];
}

+ (void)readFileInBackgroundAtPathAsArray:(nonnull NSString *)path
                               completion:(void (^_Nullable)(NSArray * _Nullable value))complete {
    NSOperationQueue *createQueue = [[NSOperationQueue alloc] init];
    [createQueue addOperationWithBlock:^{
        // 创建文件
        NSArray *result = [MTFileManager readFileAtPathAsArray:path];
        // 回到主线程 回调
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            if (complete) {
                complete(result);
            }
        }];
    }];
}

+ (NSData *)readFileAtPathAsData:(NSString *)path {
    if (![self existsFileAtPath:path]) {
        return nil;
    }
    return [self readFileAtPathAsData:path error:nil];
}

+ (NSData *)readFileAtPathAsData:(NSString *)path error:(NSError **)error {
    if (![self existsFileAtPath:path]) {
        [self defineError:error withErrorMessage:@"File Path not exist!"];
        return nil;
    }
    return [NSData dataWithContentsOfFile:path options:NSDataReadingMapped error:error];
}

+ (void)readFileInBackgroundAtPathAsData:(nonnull NSString *)path
                              completion:(void (^_Nullable)(NSData * _Nullable value, NSError * _Nullable error))complete {
    NSOperationQueue *createQueue = [[NSOperationQueue alloc] init];
    [createQueue addOperationWithBlock:^{
        // 创建文件
        NSError *error = nil;
        NSData *result = [MTFileManager readFileAtPathAsData:path error:&error];
        // 回到主线程 回调
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            if (complete) {
                complete(result, error);
            }
        }];
    }];
}

+ (NSDictionary *)readFileAtPathAsDictionary:(NSString *)path {
    if (![self existsFileAtPath:path]) {
        return nil;
    }
    return [NSDictionary dictionaryWithContentsOfFile:path];
}

+ (void)readFileInBackgroundAtPathAsDictionary:(nonnull NSString *)path
                                    completion:(void (^_Nullable)(NSDictionary * _Nullable value))complete {
    NSOperationQueue *createQueue = [[NSOperationQueue alloc] init];
    [createQueue addOperationWithBlock:^{
        // 创建文件
        NSDictionary *result = [MTFileManager readFileAtPathAsDictionary:path];
        // 回到主线程 回调
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            if (complete) {
                complete(result);
            }
        }];
    }];
}

+ (UIImage *)readFileAtPathAsImage:(NSString *)path {
    if (![self existsFileAtPath:path]) {
        return nil;
    }
    return [UIImage imageWithContentsOfFile:path];
}

+ (UIImage *)readFileAtPathDataAsImage:(NSString *)path error:(NSError **)error {
    if (![self existsFileAtPath:path]) {
        [self defineError:error withErrorMessage:@"File Path not exist!"];
        return nil;
    }
    NSData *data = [self readFileAtPathAsData:path error:error];
    
    if([self isNotError:error]) {
        return [UIImage imageWithData:data];
    }
    
    return nil;
}

+ (void)readFileInBackgroundAtPathAsImage:(nonnull NSString *)path
                               completion:(void (^_Nullable)(UIImage * _Nullable value, NSError * _Nullable error))complete {
    NSOperationQueue *createQueue = [[NSOperationQueue alloc] init];
    [createQueue addOperationWithBlock:^{
        // 创建文件
        NSError *error = nil;
        UIImage *result = [MTFileManager readFileAtPathDataAsImage:path error:&error];
        // 回到主线程 回调
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            if (complete) {
                complete(result, error);
            }
        }];
    }];
}

+ (NSJSONSerialization *)readFileAtPathAsJSON:(NSString *)path {
    if (![self existsFileAtPath:path]) {
        return nil;
    }
    return [self readFileAtPathAsJSON:path error:nil];
}

+ (NSJSONSerialization *)readFileAtPathAsJSON:(NSString *)path error:(NSError **)error {
    if (![self existsFileAtPath:path]) {
        [self defineError:error withErrorMessage:@"File Path not exist!"];
        return nil;
    }
    NSData *data = [self readFileAtPathAsData:path error:error];
    
    if([self isNotError:error])  {
        NSJSONSerialization *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
        
        if([NSJSONSerialization isValidJSONObject:json]) {
            return json;
        }
    }
    
    return nil;
}

+ (void)readFileInBackgroundAtPathAsJSON:(nonnull NSString *)path
                              completion:(void (^_Nullable)(NSJSONSerialization * _Nullable value, NSError * _Nullable error))complete {
    NSOperationQueue *createQueue = [[NSOperationQueue alloc] init];
    [createQueue addOperationWithBlock:^{
        // 创建文件
        NSError *error = nil;
        NSJSONSerialization *result = [MTFileManager readFileAtPathAsJSON:path error:&error];
        // 回到主线程 回调
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            if (complete) {
                complete(result, error);
            }
        }];
    }];
}

+ (NSString *)readFileAtPathAsString:(NSString *)path {
    if (![self existsFileAtPath:path]) {
        return nil;
    }
    return [self readFileAtPathAsString:path error:nil];
}

+ (NSString *)readFileAtPathAsString:(NSString *)path error:(NSError **)error {
    if (![self existsFileAtPath:path]) {
        [self defineError:error withErrorMessage:@"File Path not exist!"];
        return nil;
    }
    return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:error];
}

+ (void)readFileInBackgroundAtPathAsString:(nonnull NSString *)path
                                completion:(void (^_Nullable)(NSString * _Nullable value, NSError * _Nullable error))complete {
    NSOperationQueue *createQueue = [[NSOperationQueue alloc] init];
    [createQueue addOperationWithBlock:^{
        // 创建文件
        NSError *error = nil;
        NSString *result = [MTFileManager readFileAtPathAsString:path error:&error];
        // 回到主线程 回调
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            if (complete) {
                complete(result, error);
            }
        }];
    }];
}

#pragma mark - 基础接口 文件移动方法

+ (BOOL)copyItemAtPath:(NSString *)path
                toPath:(NSString *)toPath
             overwrite:(BOOL)overwrite
                 error:(NSError **)error {
    if (![self existsFileAtPath:path]) {
        [self defineError:error withErrorMessage:@"File Path not exist!"];
        return NO;
    }
    if (![self existsItemAtPath:toPath] ||
        (overwrite && [self removeItemAtPath:toPath error:error] && [self isNotError:error])) {
        if([self createDirectoriesForFileAtPath:toPath error:error]) {
            BOOL copied = [[NSFileManager defaultManager] copyItemAtPath:path toPath:toPath error:error];
            return (copied && [self isNotError:error]);
        } else {
            return NO;
        }
    } else {
        return NO;
    }
}

+ (void)copyItemInBackgroundAtPath:(nonnull NSString *)path
                            toPath:(nonnull NSString *)toPath
                         overwrite:(BOOL)overwrite
                        completion:(completion _Nullable )complete {
    NSOperationQueue *copyQueue = [[NSOperationQueue alloc] init];
    [copyQueue addOperationWithBlock:^{
        // 创建文件
        NSError *error = nil;
        BOOL result = [MTFileManager copyItemAtPath:path
                                             toPath:toPath
                                          overwrite:overwrite
                                              error:&error];
        // 回到主线程 回调
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            if (complete) {
                complete(result, error);
            }
        }];
    }];
}

+ (BOOL)moveItemAtPath:(NSString *)path
                toPath:(NSString *)toPath
             overwrite:(BOOL)overwrite
                 error:(NSError **)error {
    if (![self existsFileAtPath:path]) {
        [self defineError:error withErrorMessage:@"File Path not exist!"];
        return NO;
    }
    if (![self existsItemAtPath:toPath] ||
        (overwrite && [self removeItemAtPath:toPath error:error] && [self isNotError:error])) {
        return ([self createDirectoriesForFileAtPath:toPath error:error] && [[NSFileManager defaultManager] moveItemAtPath:path toPath:toPath error:error]);
    } else {
        return NO;
    }
}

+ (void)moveItemInBackgroundAtPath:(nonnull NSString *)path
                            toPath:(nonnull NSString *)toPath
                         overwrite:(BOOL)overwrite
                        completion:(completion _Nullable )complete {
    NSOperationQueue *moveQueue = [[NSOperationQueue alloc] init];
    [moveQueue addOperationWithBlock:^{
        // 创建文件
        NSError *error = nil;
        BOOL result = [MTFileManager moveItemAtPath:path
                                             toPath:toPath
                                          overwrite:overwrite
                                              error:&error];
        // 回到主线程 回调
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            if (complete) {
                complete(result, error);
            }
        }];
    }];
}

#pragma mark - 基础接口 文件 文件夹 属性

+ (NSDictionary *)attributesOfItemAtPath:(NSString *)path {
    return [self attributesOfItemAtPath:path error:nil];
}

+ (NSDictionary *)attributesOfItemAtPath:(NSString *)path error:(NSError **)error {
    if (![self existsItemAtPath:path]) {
        [self defineError:error withErrorMessage:@"File not exist!"];
        return nil;
    }
    return [[NSFileManager defaultManager] attributesOfItemAtPath:path error:error];
}

#pragma mark - 基础接口 重命名文件

+ (BOOL)renameItemAtPath:(NSString *)path withName:(NSString *)name {
    return [self renameItemAtPath:path withName:name error:nil];
}


+ (BOOL)renameItemAtPath:(NSString *)path withName:(NSString *)name error:(NSError **)error {
    if (![self existsItemAtPath:path]) {
        [self defineError:error withErrorMessage:@"Item not exist!"];
        return NO;
    }
    
    NSRange indexOfSlash = [name rangeOfString:@"/"];
    
    if(indexOfSlash.location < name.length) {
        [self defineError:error withErrorMessage:@"File name can't contain a '/'."];
        return NO;
    }
    
    return [self moveItemAtPath:path
                         toPath:[[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:name]
                      overwrite:false error:error];
}

+ (void)renameItemInBackgroundAtPath:(nonnull NSString *)path
                            withName:(nonnull NSString *)name
                          completion:(completion _Nullable )complete {
    NSOperationQueue *renameQueue = [[NSOperationQueue alloc] init];
    [renameQueue addOperationWithBlock:^{
        // 创建文件
        NSError *error = nil;
        BOOL result = [MTFileManager renameItemAtPath:path
                                             withName:name
                                                error:&error];
        // 回到主线程 回调
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            if (complete) {
                complete(result, error);
            }
        }];
    }];
}

#pragma mark - 基础接口 文件 文件夹 大小输出

+ (NSNumber *)sizeOfItemAtPath:(NSString *)path {
    return [self sizeOfItemAtPath:path error:nil];
}

+ (NSNumber *)sizeOfItemAtPath:(NSString *)path error:(NSError **)error {
    if (![self existsItemAtPath:path]) {
        [self defineError:error withErrorMessage:@"File name can't contain a '/'."];
        return nil;
    }
    return (NSNumber *)[[self attributesOfItemAtPath:path error:error] objectForKey:NSFileSize];
}

+ (NSNumber *)sizeOfFileAtPath:(NSString *)path {
    return [self sizeOfFileAtPath:path error:nil];
}

+ (NSNumber *)sizeOfFileAtPath:(NSString *)path error:(NSError **)error {
    if ([self existsFileAtPath:path]) {
        if ([self isNotError:error]) {
            return [self sizeOfItemAtPath:path error:error];
        }
    }
    [self defineError:error withErrorMessage:@"File not exist!"];
    return nil;
}

+ (NSNumber *)sizeOfDirectoryAtPath:(NSString *)path {
    return [self sizeOfDirectoryAtPath:path error:nil];
}

+ (NSNumber *)sizeOfDirectoryAtPath:(NSString *)path error:(NSError **)error {
    if ([self existsDirectoryAtPath:path]) {
        if([self isNotError:error]) {
            NSNumber *size = [self sizeOfItemAtPath:path error:error];
            double sizeValue = [size doubleValue];
            
            if ([self isNotError:error]) {
                NSArray *subpaths = [self listItemsInDirectoryAtPath:path deep:YES];
                NSUInteger subpathsCount = [subpaths count];
                
                for (NSUInteger i = 0; i < subpathsCount; i++) {
                    NSString *subpath = [subpaths objectAtIndex:i];
                    NSNumber *subpathSize = [self sizeOfItemAtPath:subpath error:error];
                    
                    if([self isNotError:error]) {
                        sizeValue += [subpathSize doubleValue];
                    } else {
                        return nil;
                    }
                }
                
                return [NSNumber numberWithDouble:sizeValue];
            }
        }
    }
    [self defineError:error withErrorMessage:@"Directory not exist!"];
    return nil;
}

+ (NSArray *)listItemsInDirectoryAtPath:(NSString *)path deep:(BOOL)deep {
    NSArray *relativeSubpaths = (deep ? [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:path error:nil] :
                                        [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil]);
    
    NSMutableArray *absoluteSubpaths = [[NSMutableArray alloc] init];
    
    for(NSString *relativeSubpath in relativeSubpaths) {
        NSString *absoluteSubpath = [path stringByAppendingPathComponent:relativeSubpath];
        [absoluteSubpaths addObject:absoluteSubpath];
    }
    
    return [NSArray arrayWithArray:absoluteSubpaths];
}

#pragma mark - 扩展接口 图片信息

+ (NSDictionary *)metadataOfImageAtPath:(NSString *)path {
    if ([self existsFileAtPath:path]) {
        NSURL *url = [NSURL fileURLWithPath:path];
        CGImageSourceRef sourceRef = CGImageSourceCreateWithURL((CFURLRef)url, NULL);
        NSDictionary *metadata = (NSDictionary *)CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(sourceRef, 0, NULL));
        return metadata;
    }
    return nil;
}

+ (NSDictionary *)exifDataOfImageAtPath:(NSString *)path {
    NSDictionary *metadata = [self metadataOfImageAtPath:path];
    if(metadata) {
        return [metadata objectForKey:(NSString *)kCGImagePropertyExifDictionary];
    }
    return nil;
}

+ (NSDictionary *)tiffDataOfImageAtPath:(NSString *)path {
    NSDictionary *metadata = [self metadataOfImageAtPath:path];
    if(metadata) {
        return [metadata objectForKey:(NSString *)kCGImagePropertyTIFFDictionary];
    }
    return nil;
}

@end
