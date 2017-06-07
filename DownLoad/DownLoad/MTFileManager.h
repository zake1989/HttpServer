//
//  MTFileManager.h
//  MTFileManager
//
//  Created by zeng on 20/04/2017.
//  Copyright © 2017 zengyukai. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef void (^completion) (BOOL success, NSError * _Nullable error);

@interface MTFileManager : NSObject

/**
 以下接口为目录基础接口 提供了系统给app访问权限的所有目录地址
 以下为系统提供的结构
 APPSandBox----|
               |----Documents
               |
               |----Library----|
               |               |----Application Support
               |               |
               |               |----Caches
               |               |
               |               |----Preferences
               |
               |----tmp

 APPBundle----|
              |--custom File/Directory
 
 一般情况下 app在运行状态创建的 临时／永久文件 建议放置在沙盒中
 每个对应的目录都输出了两个接口
    第一个输出了文件夹的目录地址
    第二个在目录地址的基础上拼接了提供的用户名
 Documents           对应的是第一组接口 用于存放自定义文件
 Library             对应的是第二组接口 不建议直接使用该目录存放
 Application Support 对应的是第三组接口 应用支持文件可以存放我们下载的素材之类的文件
 Caches              对应的是第四组接口 用于存放缓存文件
 tmp                 对应的是第五组接口 用于存放临时文件
 mainbundle          对应的是第六组接口 应用所在位置
 ⚠️：在使用拼接文件目录时输出参数 filePath 最开始的/可带可不带
     如果要放在子目录中在文件名之前添加子目录即可 如 ／filePath／FileName
 
 */
+ (nullable NSString *)documentDirectoryPath;
+ (nullable NSString *)documentFilePathWithAppendPath:(nonnull NSString *)filePath;

+ (nullable NSString *)libraryDirectoryPath;
+ (nullable NSString *)libraryFilePathWithAppendPath:(nonnull NSString *)filePath;

+ (nullable NSString *)applicationSupportDirectoryPath;
+ (nullable NSString *)applicationSupportFilePathWithAppendPath:(nonnull NSString *)filePath;

+ (nullable NSString *)cachesDirectoryPath;
+ (nullable NSString *)cachesFilePathWithAppendPath:(nonnull NSString *)filePath;

+ (nullable NSString *)temporaryDirectoryPath;
+ (nullable NSString *)temporaryFilePathWithAppendPath:(nonnull NSString *)filePath;

+ (nullable NSString *)mainBundleDirectoryPath;
+ (nullable NSString *)mainBundleFilePathWithAppendPath:(nonnull NSString *)filePath;

/**
 用于判断制定的地址是否存在 不区分文件／文件夹

 @param path 文件／文件夹 地址
 @return 是否存在
 */
+ (BOOL)existsItemAtPath:(nonnull NSString *)path;

/**
 📃 只判断文件是否存在

 @param path 文件／文件夹 地址
 @return 是否存在
 */
+ (BOOL)existsFileAtPath:(nonnull NSString *)path;

/**
 📁 只判断文件夹是否存在
 
 @param path 文件／文件夹 地址
 @return 是否存在
 */
+ (BOOL)existsDirectoryAtPath:(nonnull NSString *)path;

/**
 移除制定的文件／文件夹 📃 📁

 @param path 文件／文件夹 地址
 @param error 操作输出的错误
 @return 是否成功
 */
+ (BOOL)removeItemAtPath:(nonnull NSString *)path
                  error:(NSError *_Nullable __autoreleasing *_Nullable)error;

+ (void)removeItemInBackgroundAtPath:(nonnull NSString *)path
                          completion:(completion _Nullable )complete;

/**
 移除文件夹内部的所有文件

 @param path 文件夹地址
 @param error 操作输出的错误
 @return 是否成功
 */
+ (BOOL)removeItemsInDirectory:(nonnull NSString *)path
                         error:(NSError *_Nullable __autoreleasing *_Nullable)error;

+ (void)removeItemsInBackgroundInDirectory:(nonnull NSString *)path
                                completion:(completion _Nullable )complete;

/**
 创建文件 并写入指定内容

 @param path 文件路径
 @param content 文件内容
 @param overwrite 是否覆盖原来的文件
 @param error 操作输出的错误
 @return 是否成功
 */
+ (BOOL)createFileAtPath:(nonnull NSString *)path
             withContent:(nullable NSObject *)content
               overwrite:(BOOL)overwrite
                   error:(NSError *_Nullable __autoreleasing *_Nullable)error;

+ (void)createFileInBackgroundAtPath:(nonnull NSString *)path
                         withContent:(nullable NSObject *)content
                           overwrite:(BOOL)overwrite
                          completion:(completion _Nullable )complete;

/**
 在指定目录中搜索文件

 @param path 制定的文件夹地址
 @param itemName 搜索目标名称
 @return 输出文件夹列表
 */
+ (nullable NSArray *)searchInDirectory:(nonnull NSString *)path
                           withItemName:(nonnull NSString *)itemName;

/**
 在整个沙盒目录中搜索指定的文件夹

 @param directoryName 文件夹名称
 @return 输出的文件夹列表
 */
+ (nullable NSArray *)searchDirectoriesInSandBoxWith:(nonnull NSString *)directoryName;

/**
 在整个沙盒目录中搜索指定的文件

 @param fileName 文件名称 带后缀
 @return 输出的文件列表
 */
+ (nullable NSArray *)searchFilesInSandBoxWith:(nonnull NSString *)fileName;


/**
 以下read开头的十一个接口为读取接口 只用来读取文件内容并输出为指定的nsobject
 path 为文件地址
 error 为操作的错误
 输出的返回是各种数据类型
 */
+ (nullable NSObject *)readFileAtPathAsCustomModel:(nonnull NSString *)path;
+ (void)readFileInBackgroundAtPathAsCustomModel:(nonnull NSString *)path
                                     completion:(void (^_Nullable)(NSObject * _Nullable value))complete;

+ (nullable NSArray *)readFileAtPathAsArray:(nonnull NSString *)path;
+ (void)readFileInBackgroundAtPathAsArray:(nonnull NSString *)path
                               completion:(void (^_Nullable)(NSArray * _Nullable value))complete;

+ (nullable NSDictionary *)readFileAtPathAsDictionary:(nonnull NSString *)path;
+ (void)readFileInBackgroundAtPathAsDictionary:(nonnull NSString *)path
                                    completion:(void (^_Nullable)(NSDictionary * _Nullable value))complete;

+ (nullable NSData *)readFileAtPathAsData:(nonnull NSString *)path;
+ (nullable NSData *)readFileAtPathAsData:(nonnull NSString *)path
                                    error:(NSError *_Nullable __autoreleasing *_Nullable)error;
+ (void)readFileInBackgroundAtPathAsData:(nonnull NSString *)path
                              completion:(void (^_Nullable)(NSData * _Nullable value, NSError * _Nullable error))complete;

+ (nullable UIImage *)readFileAtPathAsImage:(nonnull NSString *)path;
+ (nullable UIImage *)readFileAtPathDataAsImage:(nonnull NSString *)path
                                          error:(NSError *_Nullable __autoreleasing *_Nullable)error;
+ (void)readFileInBackgroundAtPathAsImage:(nonnull NSString *)path
                               completion:(void (^_Nullable)(UIImage * _Nullable value, NSError * _Nullable error))complete;

+ (nullable NSJSONSerialization *)readFileAtPathAsJSON:(nonnull NSString *)path;
+ (nullable NSJSONSerialization *)readFileAtPathAsJSON:(nonnull NSString *)path
                                                 error:(NSError *_Nullable __autoreleasing *_Nullable)error;
+ (void)readFileInBackgroundAtPathAsJSON:(nonnull NSString *)path
                              completion:(void (^_Nullable)(NSJSONSerialization * _Nullable value, NSError * _Nullable error))complete;

+ (nullable NSString *)readFileAtPathAsString:(nonnull NSString *)path;
+ (nullable NSString *)readFileAtPathAsString:(nonnull NSString *)path
                                        error:(NSError *_Nullable __autoreleasing *_Nullable)error;
+ (void)readFileInBackgroundAtPathAsString:(nonnull NSString *)path
                                completion:(void (^_Nullable)(NSString * _Nullable value, NSError * _Nullable error))complete;

/**
 拷贝文件到另一个地址

 @param path 文件地址
 @param toPath 目标文件地址
 @param overwrite 是否覆盖目标地址
 @param error 操作错误
 @return 是否成功
 */
+ (BOOL)copyItemAtPath:(nonnull NSString *)path
                toPath:(nonnull NSString *)toPath
             overwrite:(BOOL)overwrite
                 error:(NSError *_Nullable __autoreleasing *_Nullable)error;

+ (void)copyItemInBackgroundAtPath:(nonnull NSString *)path
                            toPath:(nonnull NSString *)toPath
                         overwrite:(BOOL)overwrite
                        completion:(completion _Nullable )complete;

/**
 将文件移动到目标地址 
 ⚠️： main bundle中的文件 是不能移动的 只能拷贝

 @param path 文件地址
 @param toPath 目标文件地址
 @param overwrite 是否覆盖目标地址
 @param error 操作错误
 @return 是否成功
 */
+ (BOOL)moveItemAtPath:(nonnull NSString *)path
                toPath:(nonnull NSString *)toPath
             overwrite:(BOOL)overwrite
                 error:(NSError *_Nullable __autoreleasing *_Nullable)error;
+ (void)moveItemInBackgroundAtPath:(nonnull NSString *)path
                            toPath:(nonnull NSString *)toPath
                         overwrite:(BOOL)overwrite
                        completion:(completion _Nullable )complete;

/**
 重命名文件

 @param path 目标文件地址
 @param name 新的文件名称 ⚠️：文件名不能带／
 @return 是否成功
 */
+ (BOOL)renameItemAtPath:(nonnull NSString *)path
                withName:(nonnull NSString *)name;

/**
 重命名文件

 @param path 目标文件地址
 @param name 新的文件名称 ⚠️：文件名不能带／
 @param error 操作错误
 @return 是否成功
 */
+ (BOOL)renameItemAtPath:(nonnull NSString *)path
                withName:(nonnull NSString *)name
                   error:(NSError *_Nullable __autoreleasing *_Nullable)error;
+ (void)renameItemInBackgroundAtPath:(nonnull NSString *)path
                            withName:(nonnull NSString *)name
                          completion:(completion _Nullable )complete;

/**
 输出文件的数据信息 (file, directory, symlink, etc.)

 @param path 文件 文件夹 地址
 @return 参数
 */
+ (nullable NSDictionary *)attributesOfItemAtPath:(nonnull NSString *)path;
+ (nullable NSDictionary *)attributesOfItemAtPath:(nonnull NSString *)path
                                            error:(NSError *_Nullable __autoreleasing *_Nullable)error;


/**
 输出文件或文件夹的大小 ⚠️：该接口只输出文件夹的大小 不包括里面的文件

 @param path 文件 文件夹 地址
 @return 大小 单位：byte
 */
+ (nullable NSNumber *)sizeOfItemAtPath:(nonnull NSString *)path;
+ (nullable NSNumber *)sizeOfItemAtPath:(nonnull NSString *)path
                                  error:(NSError *_Nullable __autoreleasing *_Nullable)error;

/**
 输出文件的大小

 @param path 文件地址
 @return 大小 单位：byte
 */
+ (nullable NSNumber *)sizeOfFileAtPath:(nonnull NSString *)path;
+ (nullable NSNumber *)sizeOfFileAtPath:(nonnull NSString *)path
                                  error:(NSError *_Nullable __autoreleasing *_Nullable)error;

/**
 输出文件夹的大小 包括文件夹内部的所有大小

 @param path 文件地址
 @return 大小 单位：byte
 */
+ (nullable NSNumber *)sizeOfDirectoryAtPath:(nonnull NSString *)path;
+ (nullable NSNumber *)sizeOfDirectoryAtPath:(nonnull NSString *)path
                                       error:(NSError *_Nullable __autoreleasing *_Nullable)error;

/**
 输出图片的meta data

 @param path 图片地址
 @return 图片meta data 信息
 */
+ (nullable NSDictionary *)metadataOfImageAtPath:(nonnull NSString *)path;
+ (nullable NSDictionary *)exifDataOfImageAtPath:(nonnull NSString *)path;
+ (nullable NSDictionary *)tiffDataOfImageAtPath:(nonnull NSString *)path;

@end
