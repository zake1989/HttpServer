//
//  MTLivePhotoGenerator.m
//  LivePhoto
//
//  Created by zeng on 06/04/2017.
//  Copyright © 2017 zengyukai. All rights reserved.
//

#import "MTLivePhotoGenerator.h"
#import "MTLivePhotoGenerator+Image.h"
#import "MTLivePhotoGenerator+Video.h"

@interface MTLivePhotoGenerator()

/**
 用于匹配图片 视频的唯一标示 必须一致
 */
@property (strong, nonatomic) NSString *contentIdentifier;

/**
 图片原数据是否修改完成
 */
@property (assign, nonatomic) BOOL imageReady;

/**
 视频原数据是否修改完成
 */
@property (assign, nonatomic) BOOL videoReady;

/**
 结束回调
 */
@property (copy, nonatomic) void(^saveLivePhotoCompletionBlock)(BOOL success, NSError *error);

@property (nonatomic, copy) void(^generateLivePhotoCompletionBlock)(PHLivePhoto *livePhoto, NSDictionary *info);

@end

@implementation MTLivePhotoGenerator


/**
 释放临时文件
 */
- (void)dealloc {
    [self deleteTempFiles];
}

- (instancetype)initWithVideoPath:(NSString *)videoPath imagePath:(NSString *)imagePath {
    self = [super init];
    if (self) {
        
        self.contentIdentifier = [NSUUID UUID].UUIDString;
        // 将给过来的视频 图片复制到临时文件中 以便于操作
        [[NSFileManager defaultManager] removeItemAtPath:[self getVideoTempPath] error:nil];
        [[NSFileManager defaultManager] copyItemAtPath:videoPath
                                                toPath:[self getVideoTempPath]
                                                 error:nil];
        
        [[NSFileManager defaultManager] removeItemAtPath:[self getImageTempPath] error:nil];
        [[NSFileManager defaultManager] copyItemAtPath:imagePath
                                                toPath:[self getImageTempPath]
                                                 error:nil];
    }
    return self;
}

- (NSString *)getImageTempPath {
    return [NSTemporaryDirectory() stringByAppendingPathComponent:@"LPTempImage.jpg"];
}

- (NSString *)getVideoTempPath {
    return [NSTemporaryDirectory() stringByAppendingPathComponent:@"LPTempVideo.mov"];
}

- (void)deleteTempFiles {
    [[NSFileManager defaultManager] removeItemAtPath:[self getVideoTempPath] error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:[self getImageTempPath] error:nil];
}

- (void)requestLivePhotoWithPlaceholderImage:(UIImage*)image
                                  targetSize:(CGSize)targetSize
                                  contenMode:(PHImageContentMode)contentMode
                               resultHandler:(void(^)(PHLivePhoto *livePhoto, NSDictionary *info))resultHandler {
    self.generateLivePhotoCompletionBlock = resultHandler;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:[self getImageTempPath]] == NO) {
        if (self.generateLivePhotoCompletionBlock) {
            self.generateLivePhotoCompletionBlock(nil, @{@"error": [self errorWithMessage:@"Live Photo: Image not exist!"]});
        }
        return;
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:[self getVideoTempPath]] == NO) {
        if (self.generateLivePhotoCompletionBlock) {
            self.generateLivePhotoCompletionBlock(nil, @{@"error": [self errorWithMessage:@"Live Photo: Video not exist!"]});
        }
        return;
    }
    // 异步添加原数据
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        __weak MTLivePhotoGenerator *weakSelf = self;
        [self addMetaDataToImageAtPath:[self getImageTempPath] withID:self.contentIdentifier completionHandler:^(BOOL success) {
            weakSelf.imageReady = success;
            if (success) {
                [weakSelf generateLivePhotoPlaceholderImage:image targetSize:targetSize contenMode:contentMode];
            } else {
                if (weakSelf.generateLivePhotoCompletionBlock) {
                    weakSelf.generateLivePhotoCompletionBlock(nil, @{@"error": [weakSelf errorWithMessage:@"Live Photo: Metadata writing to image fail!"]});
                    weakSelf.generateLivePhotoCompletionBlock = nil;
                }
            }
        }];
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        __weak MTLivePhotoGenerator *weakSelf = self;
        [self addMetaDataToVideoAtPath:[self getVideoTempPath] withID:self.contentIdentifier completionHandler:^(BOOL success) {
            weakSelf.videoReady = success;
            if (success) {
                AVURLAsset *asset = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:[weakSelf getVideoTempPath]]];
                NSLog(@"%@",asset.metadata);
                [weakSelf generateLivePhotoPlaceholderImage:image targetSize:targetSize contenMode:contentMode];
            } else {
                if (weakSelf.generateLivePhotoCompletionBlock) {
                    weakSelf.generateLivePhotoCompletionBlock(nil, @{@"error": [weakSelf errorWithMessage:@"Live Photo: Metadata writing to video fail!"]});
                    weakSelf.generateLivePhotoCompletionBlock = nil;
                }
            }
        }];
    });
}

- (void)saveLivePhotoToAppAlbum:(NSString *)albumName
              completionHandler:(void(^)(BOOL success, NSError *error))completionHandler {
    self.saveLivePhotoCompletionBlock = completionHandler;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:[self getImageTempPath]] == NO) {
        self.saveLivePhotoCompletionBlock(NO, [self errorWithMessage:@"Live Photo: Image not exist!"]);
        self.saveLivePhotoCompletionBlock = nil;
        return;
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:[self getVideoTempPath]] == NO) {
        self.saveLivePhotoCompletionBlock(NO, [self errorWithMessage:@"Live Photo: Video not exist!"]);
        self.saveLivePhotoCompletionBlock = nil;
        return;
    }
    
    NSString *album = albumName == nil ? @"" : albumName;
    // 异步添加原数据
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        __weak MTLivePhotoGenerator *weakSelf = self;
        [self addMetaDataToImageAtPath:[self getImageTempPath] withID:self.contentIdentifier completionHandler:^(BOOL success) {
            weakSelf.imageReady = success;
            [weakSelf handleImageAndeVideoProcessResult:@{@"success": @(success), @"writing": @"image", @"albumName": album}];
        }];
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        __weak MTLivePhotoGenerator *weakSelf = self;
        [self addMetaDataToVideoAtPath:[self getVideoTempPath] withID:self.contentIdentifier completionHandler:^(BOOL success) {
            weakSelf.videoReady = success;
            [weakSelf handleImageAndeVideoProcessResult:@{@"success": @(success), @"writing": @"video", @"albumName": album}];
        }];
    });
}

- (void)handleImageAndeVideoProcessResult:(NSDictionary *)resultInfo {
    BOOL success = [resultInfo[@"success"] boolValue];
    if (!success) {
        NSString *errorMessage = [NSString stringWithFormat:@"Live Photo: Metadata writing to %@ fail!",
                                  resultInfo[@"writing"]];
        if (self.saveLivePhotoCompletionBlock) {
            self.saveLivePhotoCompletionBlock(NO, [self errorWithMessage:errorMessage]);
            self.saveLivePhotoCompletionBlock = nil;
        }
    } else if (self.imageReady && self.videoReady) {
        self.imageReady = NO;
        self.videoReady = NO;
        NSString *albumName = resultInfo[@"albumName"];
        [self saveLivePhotoInnerToAppAlbum:albumName];
    }
}

- (void)generateLivePhotoPlaceholderImage:(UIImage*)image
                               targetSize:(CGSize)targetSize
                               contenMode:(PHImageContentMode)contentMode {
    if (self.imageReady && self.videoReady) {
        self.imageReady = NO;
        self.videoReady = NO;
        [PHLivePhoto requestLivePhotoWithResourceFileURLs:@[[NSURL fileURLWithPath:[self getImageTempPath]],
                                                            [NSURL fileURLWithPath:[self getVideoTempPath]]]
                                         placeholderImage:image
                                               targetSize:targetSize
                                              contentMode:contentMode
                                            resultHandler:self.generateLivePhotoCompletionBlock];
    }
}

- (void)saveLivePhotoInnerToAppAlbum:(NSString *)albumName {
    __block PHFetchResult *photosAsset;
    __block PHAssetCollection *collection;
    __block PHObjectPlaceholder *placeholder;
    
    // Find the album
    PHFetchOptions *fetchOptions = [[PHFetchOptions alloc] init];
    if (albumName && ![albumName  isEqual: @""]) {
        fetchOptions.predicate = [NSPredicate predicateWithFormat:@"title = %@", albumName];
    }
    collection = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum
                                                          subtype:PHAssetCollectionSubtypeAny
                                                          options:fetchOptions].firstObject;
    
    // Save to the album
    void(^saveBlock)() = ^{
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
            // https://github.com/genadyo/LivePhotoDemo/issues/3
            // https://realm.io/news/hacking-live-photos-iphone-6s/
            // https://github.com/axiomatic-systems/Bento4
            // http://stackoverflow.com/questions/32959973/extract-video-portion-from-live-photo
            // 用URL保存到相册 ⚠️ 图片 视频metadata必须一致
            PHAssetResourceCreationOptions *options = [[PHAssetResourceCreationOptions alloc] init];
            
            NSURL *imgURL = [NSURL fileURLWithPath:[self getImageTempPath]];
            [request addResourceWithType:PHAssetResourceTypePhoto fileURL:imgURL options:options];
            
            NSURL *videoURL = [NSURL fileURLWithPath:[self getVideoTempPath]];
            [request addResourceWithType:PHAssetResourceTypePairedVideo fileURL:videoURL options:options];
            
            placeholder = [request placeholderForCreatedAsset];
            photosAsset = [PHAsset fetchAssetsInAssetCollection:collection options:nil];
            PHAssetCollectionChangeRequest *albumChangeRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:collection
                                                                                                                          assets:photosAsset];
            [albumChangeRequest addAssets:@[placeholder]];
        } completionHandler:^(BOOL success, NSError *error) {
            if (self.saveLivePhotoCompletionBlock) {
                self.saveLivePhotoCompletionBlock(success, error);
                self.saveLivePhotoCompletionBlock = nil;
            }
        }];
    };
    
    // 制定相册不存在 创建相册后 添加live photo
    if (!collection) {
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            PHAssetCollectionChangeRequest *createAlbum = [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle:albumName];
            placeholder = [createAlbum placeholderForCreatedAssetCollection];
        } completionHandler:^(BOOL success, NSError *error) {
            if (success) {
                PHFetchResult *collectionFetchResult = [PHAssetCollection fetchAssetCollectionsWithLocalIdentifiers:@[placeholder.localIdentifier]
                                                                                                            options:nil];
                collection = collectionFetchResult.firstObject;
                saveBlock();
            } else {
                if (self.saveLivePhotoCompletionBlock) {
                    self.saveLivePhotoCompletionBlock(success, error);
                    self.saveLivePhotoCompletionBlock = nil;
                }
            }
        }];
    } else {
        saveBlock();
    }
}

- (NSError *)errorWithMessage:(NSString *)message {
    NSMutableDictionary* details = [NSMutableDictionary dictionary];
    [details setValue:message forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:@"LivePhoto" code:-1 userInfo:details];
}

@end
