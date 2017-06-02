//
//  ViewController.m
//  LivePhoto
//
//  Created by zeng on 06/04/2017.
//  Copyright © 2017 zengyukai. All rights reserved.
//

#import "ViewController.h"
#import "MTLivePhotoGenerator.h"
#import <PhotosUI/PhotosUI.h>

@interface ViewController ()

@property (nonatomic, strong) MTLivePhotoGenerator *livePhotoUtil;

@end

@implementation ViewController



- (void)viewDidLoad {
    [super viewDidLoad];
    
    PHLivePhotoView *livePhotoView = [[PHLivePhotoView alloc] initWithFrame:self.view.frame];
    [self.view addSubview:livePhotoView];
    
    
    self.livePhotoUtil = [[MTLivePhotoGenerator alloc] initWithVideoPath:[[NSBundle mainBundle] pathForResource:@"IMG_6040" ofType:@"MOV"]
                                                               imagePath:[[NSBundle mainBundle] pathForResource:@"image" ofType:@"jpg"]];
    
    
//    [self.livePhotoUtil saveLivePhotoToAppAlbum:nil completionHandler:^(BOOL success, NSError *error) {
//        dispatch_async(dispatch_get_main_queue(), ^{
//            if (success) {
//                NSLog(@"好了");
//            } else {
//                NSLog(@"失败: %@", error);
//            }
//        });
//    }];
    
    [self.livePhotoUtil requestLivePhotoWithPlaceholderImage:[UIImage imageNamed:@"image.jpg"] targetSize:CGSizeZero contenMode:PHImageContentModeAspectFit resultHandler:^(PHLivePhoto *livePhoto, NSDictionary *info) {
        if (livePhoto) {
            livePhotoView.livePhoto = livePhoto;
        } else {
            NSLog(@"失败: %@", info);
        }
    }];
    
    
//    AVURLAsset *videoAsset = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:[self.livePhotoUtil getVideoTempPath]]];
//    AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:videoAsset];
//    generator.appliesPreferredTrackTransform = YES;
//    CMTime generateTime = CMTimeMakeWithSeconds(0.2, videoAsset.duration.timescale);
//    [generator generateCGImagesAsynchronouslyForTimes:@[[NSValue valueWithCMTime:generateTime]] completionHandler:^(CMTime requestedTime, CGImageRef  _Nullable image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError * _Nullable error) {
//        if (image) {
//            UIImage *uiImage = [UIImage imageWithCGImage:image];
//            NSData *imageData = UIImageJPEGRepresentation(uiImage, 1.0);
//            [imageData writeToFile:[self.livePhotoUtil getImageTempPath] atomically:YES];
//
//
//            
//        } else {
//
//        }
//    }];

}


@end
