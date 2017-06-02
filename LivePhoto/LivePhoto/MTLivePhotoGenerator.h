//
//  MTLivePhotoGenerator.h
//  LivePhoto
//
//  Created by zeng on 06/04/2017.
//  Copyright © 2017 zengyukai. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Photos/Photos.h>

@interface MTLivePhotoGenerator : NSObject

/**
 初始化live photo方法

 @param videoPath live photo 需要的视频地址
 @param imagePath live photo 需要的图片地址
 @return 实例
 */
- (instancetype)initWithVideoPath:(NSString *)videoPath
                        imagePath:(NSString *)imagePath;

/**
 获取临时图片地址

 @return 图片地址
 */
- (NSString *)getImageTempPath;

/**
 获取临时视频地址

 @return 视频地址
 */
- (NSString *)getVideoTempPath;

/**
 删除临时文件 默认dealloc会调用
 */
- (void)deleteTempFiles;

/**
 保存live photo到制定相册

 @param albumName 相册名称  nil 或 @"" 为默认相册
 @param completionHandler 完成回调
 */
- (void)saveLivePhotoToAppAlbum:(NSString *)albumName
              completionHandler:(void(^)(BOOL success, NSError *error))completionHandler;

/**
 创建live photo

 @param image 封面图片
 @param targetSize live photo的分辨率 cgrectzero为原始大小
 @param contentMode 填充模式
 @param resultHandler 完成回调
 */
- (void)requestLivePhotoWithPlaceholderImage:(UIImage*)image
                                  targetSize:(CGSize)targetSize
                                  contenMode:(PHImageContentMode)contentMode
                               resultHandler:(void(^)(PHLivePhoto *livePhoto, NSDictionary *info))resultHandler;

@end
