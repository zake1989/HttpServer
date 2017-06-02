//
//  ViewController.m
//  AssetReaderPlayer
//
//  Created by zeng on 02/06/2017.
//  Copyright © 2017 zengyukai. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface ViewController ()

@property (nonatomic, strong) AVAssetReader *reader;
@property (nonatomic, strong) NSMutableArray *images;
@property (nonatomic, strong) AVURLAsset *asset;

@property (nonatomic, strong) UIView *playerView;

@property (nonatomic, strong) NSMutableData *audioData;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.images = [[NSMutableArray alloc] init];
    
    // Do any additional setup after loading the view, typically from a nib.
    
    NSURL *fileUrl = [[NSBundle mainBundle] URLForResource:@"ww" withExtension:@"mp4"];
    self.asset = [[AVURLAsset alloc] initWithURL:fileUrl options:nil];
    
    NSError *error = nil;
    self.reader = [[AVAssetReader alloc] initWithAsset:self.asset error:&error];
    
    self.audioData = [NSMutableData data];
    
    NSArray *videoTracks = [self.asset tracksWithMediaType:AVMediaTypeVideo];
    AVAssetTrack *videoTrack =[videoTracks objectAtIndex:0];
    
    int m_pixelFormatType;
    //     视频播放时，
    m_pixelFormatType = kCVPixelFormatType_32BGRA;
    // 其他用途，如视频压缩
    // m_pixelFormatType = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
    
    NSMutableDictionary *options = [NSMutableDictionary dictionary];
    [options setObject:@(m_pixelFormatType) forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    AVAssetReaderTrackOutput *videoReaderOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:videoTrack
                                                                                   outputSettings:options];
    
    [self.reader addOutput:videoReaderOutput];
    
    [self.reader startReading];
    
    NSLog(@"%ld",(long)[self.reader status]);
    NSOperationQueue *operationQueue = [[NSOperationQueue alloc] init];
    
    __weak AVAssetReader *weakReader = self.reader;
    __weak ViewController *weakSelf = self;
    [operationQueue addOperationWithBlock:^{
        
        AudioBufferList audioBufferList;
        CMBlockBufferRef blockBuffer;
        
        while ([weakReader status] == AVAssetReaderStatusReading && videoTrack.nominalFrameRate > 0) {
            
            CMSampleBufferRef videoBuffer = [videoReaderOutput copyNextSampleBuffer];
            if (videoBuffer) {
//                [weakSelf readVideoBuffer:videoBuffer];
                CGImageRef cgimage = [self imageFromSampleBufferRef:videoBuffer];
                CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(videoBuffer,
                                                                        NULL,
                                                                        &audioBufferList,
                                                                        sizeof(audioBufferList),
                                                                        NULL,
                                                                        NULL,
                                                                        0,
                                                                        &blockBuffer);
                for( int y=0; y< audioBufferList.mNumberBuffers; y++ ){
                    
                    AudioBuffer audioBuffer = audioBufferList.mBuffers[y];
                    Float32 *frame = (Float32*)audioBuffer.mData;
                    
                    [weakSelf.audioData appendBytes:frame length:audioBuffer.mDataByteSize];
                    
                }
                
//                if (!(__bridge id)(cgimage)) {
//                    NSLog(@"audio");
//                } else {
//                    NSLog(@"image");
//                }
            }
//            [NSThread sleepForTimeInterval:CMTimeGetSeconds(videoTrack.minFrameDuration)];
        }
        

    }];
    
    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(100, 100, 100, 100)];
    button.backgroundColor = [UIColor yellowColor];
    [button addTarget:self action:@selector(hit) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    
    UIButton *button2 = [[UIButton alloc] initWithFrame:CGRectMake(200, 100, 100, 100)];
    button2.backgroundColor = [UIColor redColor];
    [button2 addTarget:self action:@selector(stop) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button2];
    
    
    self.playerView = [[UIView alloc] init];
    self.playerView.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.width*videoTrack.naturalSize.height/videoTrack.naturalSize.width);
    
    [self.view addSubview:self.playerView];
    
}

- (void)hit {
    if ([self.reader status] == AVAssetReaderStatusCompleted) {
//        [self mMoveDecoderOnDecoderFinished];
        [self.reader cancelReading];
        self.reader = nil;
    }
}

- (void)stop {
    NSLog(@"%@",self.images);
    self.images = nil;
//    for (int i; i < self.images.count; i++) {
//        CGImageRef image = (__bridge CGImageRef)(self.images[i]);
//        CGImageRelease(image);
//    }
}

- (void)readVideoBuffer:(CMSampleBufferRef)videoBuffer  {
    CGImageRef cgimage = [self imageFromSampleBufferRef:videoBuffer];
    if (!(__bridge id)(cgimage)) {
        return;
    }
//    [self.images addObject:((__bridge id)(cgimage))];
//    dispatch_async(dispatch_get_main_queue(), ^{
//        self.playerView.layer.contents = (__bridge id)cgimage;
//        CGImageRelease(cgimage);
//        CFRelease(videoBuffer);
//    });

}

- (void)mMoveDecoderOnDecoderFinished {
    NSLog(@"视频解档完成");
    // 通过动画来播放我们的图片
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"contents"];
    // asset.duration.value/asset.duration.timescale 得到视频的真实时间
    animation.duration = self.asset.duration.value/self.asset.duration.timescale;
    animation.values = self.images;
    animation.repeatCount = MAXFLOAT;
    [self.playerView.layer addAnimation:animation forKey:nil];
    // 确保内存能及时释放掉
    [self.images enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj) {
            obj = nil;
        }
    }];
}

// AVFoundation 捕捉视频帧，很多时候都需要把某一帧转换成 image
- (CGImageRef)imageFromSampleBufferRef:(CMSampleBufferRef)sampleBufferRef
{
    // 为媒体数据设置一个CMSampleBufferRef
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBufferRef);
    // 锁定 pixel buffer 的基地址
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    // 得到 pixel buffer 的基地址
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    // 得到 pixel buffer 的行字节数
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // 得到 pixel buffer 的宽和高
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // 创建一个依赖于设备的 RGB 颜色空间
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // 用抽样缓存的数据创建一个位图格式的图形上下文（graphic context）对象
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    //根据这个位图 context 中的像素创建一个 Quartz image 对象
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // 解锁 pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    // 释放 context 和颜色空间
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    // 用 Quzetz image 创建一个 UIImage 对象
    // UIImage *image = [UIImage imageWithCGImage:quartzImage];
    
    // 释放 Quartz image 对象
    //    CGImageRelease(quartzImage);
    
    return quartzImage;
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
