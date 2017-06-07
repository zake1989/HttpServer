//
//  ViewController.m
//  AssetReaderPlayer
//
//  Created by zeng on 02/06/2017.
//  Copyright © 2017 zengyukai. All rights reserved.
//

#import "ViewController.h"

#define kNumberPlaybackBuffers	16
#define kAQMaxPacketDescs 6


typedef enum
{
    AS_INITIALIZED = 0,
    AS_STARTING_FILE_THREAD,
    AS_BUFFERING,
    AS_PLAYING,
    AS_STOPPED
} AudioStreamerState;

@interface ViewController (){
    UInt32 bufferByteSize;
    UInt32 numPacketsToRead;
    AudioStreamPacketDescription *packetDescs;
    size_t bytesFilled;
    size_t packetsFilled;
    unsigned int fillBufferIndex;
    
    AudioFileID playbackFile;
    Boolean	isDone;
    SInt64 packetPosition;
    
    pthread_mutex_t queueBuffersMutex;
    pthread_cond_t queueBufferReadyCondition;
    bool inuse[kNumberPlaybackBuffers];
    NSInteger buffersUsed;

    OSStatus err;
    
    AudioQueueBufferRef	audioQueueBuffers[kNumberPlaybackBuffers];
    
   	AudioQueueRef queue;
    AudioStreamBasicDescription nativeTrackASBD;
    
    AudioStreamerState state;
}

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
    AVAssetTrack *videoTrack = nil;
    
    int m_pixelFormatType;
    //     视频播放时，
    m_pixelFormatType = kCVPixelFormatType_32BGRA;
    // 其他用途，如视频压缩
    // m_pixelFormatType = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
    
    if (videoTracks.count > 0) {
        videoTrack = [[self.asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    }
    if (!videoTrack || videoTrack == ((void*)0)) {
        NSLog(@"Invalid video");
        return;
    }
    
    // --------------------------------------------------
    // reader for source video
    // --------------------------------------------------
    AVAssetReaderTrackOutput *videoReaderOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:videoTrack
                                                                                   outputSettings:@{(NSString *)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_32BGRA)}];
    [self.reader addOutput:videoReaderOutput];
    
    // --------------------------------------------------
    // add audio track if any
    // --------------------------------------------------
    NSArray *audioTracks = [self.asset tracksWithMediaType:AVMediaTypeAudio];
    AVAssetTrack *audioTrack = nil;
    if (audioTracks.count > 0) {
        audioTrack = [audioTracks firstObject];;
    }
    
    AVAssetReaderTrackOutput *audioOutput = nil;
    if (audioTrack && audioTrack != ((void*)0)) {
        audioOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:audioTrack
                                                       outputSettings:@{AVFormatIDKey: @(kAudioFormatLinearPCM)}];
        [self.reader addOutput:audioOutput];
    }
    
    [self.reader startReading];
    [self setupQueue];
    CheckError(AudioQueueStart(queue, NULL), "AudioQueueStart failed");
    
    NSLog(@"%ld",(long)[self.reader status]);
    NSOperationQueue *operationQueue = [[NSOperationQueue alloc] init];
    
    __weak AVAssetReader *weakReader = self.reader;
    __weak ViewController *weakSelf = self;
    [operationQueue addOperationWithBlock:^{
        
        while ([weakReader status] == AVAssetReaderStatusReading && videoTrack.nominalFrameRate > 0) {
            
//            CMSampleBufferRef videoBuffer = [videoReaderOutput copyNextSampleBuffer];
//            if (videoBuffer) {
//                [weakSelf readVideoBuffer:videoBuffer];
//                CGImageRef cgimage = [self imageFromSampleBufferRef:videoBuffer];
//            } else {
//                
//            }
            
            CMSampleBufferRef audioBuffer = [audioOutput copyNextSampleBuffer];
            if (audioBuffer) {
                CMBlockBufferRef CMBuffer = CMSampleBufferGetDataBuffer( audioBuffer );
                AudioBufferList audioBufferList;
                
                CheckError(CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
                                                                                   audioBuffer,
                                                                                   NULL,
                                                                                   &audioBufferList,
                                                                                   sizeof(audioBufferList),
                                                                                   NULL,
                                                                                   NULL,
                                                                                   kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
                                                                                   &CMBuffer
                                                                                   ),
                           "could not read sample data");
                
                const AudioStreamPacketDescription   * inPacketDescriptions;
                size_t packetDescriptionsSizeOut;
                size_t inNumberPackets;
                
                CheckError(CMSampleBufferGetAudioStreamPacketDescriptionsPtr(audioBuffer,
                                                                             &inPacketDescriptions,
                                                                             &packetDescriptionsSizeOut),
                           "could not read sample packet descriptions");

                inNumberPackets = packetDescriptionsSizeOut/sizeof(AudioStreamPacketDescription);
                
                AudioBuffer audioBuffer = audioBufferList.mBuffers[0];
                
                for (int i = 0; i < inNumberPackets; ++i)
                {
                    
                    SInt64 dataOffset = inPacketDescriptions[i].mStartOffset;
                    UInt32 packetSize   = inPacketDescriptions[i].mDataByteSize;
                    
                    size_t packetSpaceRemaining;
                    packetSpaceRemaining = bufferByteSize - bytesFilled;
                    
                    // if the space remaining in the buffer is not enough for the data contained in this packet
                    // then just write it
                    if (packetSpaceRemaining < packetSize)
                    {
                        // NSLog(@"oops! packetSpaceRemaining (%zu) is smaller than datasize (%lu) SO WE WILL SHIP PACKET [%d]: (abs number %lu)",
                        //     packetSpaceRemaining, dataSize, i, packetNumber);
                        
                        [self enqueueBuffer];
                        
                        
                        //                [self encapsulateAndShipPacket:packet packetDescriptions:packetDescriptions packetID:assetID];
                    }
                    
                    
                    // copy data to the audio queue buffer
                    AudioQueueBufferRef fillBuf = audioQueueBuffers[fillBufferIndex];
                    memcpy((char*)fillBuf->mAudioData + bytesFilled,
                           (const char*)(audioBuffer.mData + dataOffset), packetSize);
                    
                    
                    
                    // fill out packet description
                    packetDescs[packetsFilled] = inPacketDescriptions[i];
                    packetDescs[packetsFilled].mStartOffset = bytesFilled;
                    
                    
                    bytesFilled += packetSize;
                    packetsFilled += 1;
                    
                    
                    // if this is the last packet, then ship it
                    size_t packetsDescsRemaining = kAQMaxPacketDescs - packetsFilled;
                    if (packetsDescsRemaining == 0) {
                        //NSLog(@"woooah! this is the last packet (%d).. so we will ship it!", i);
                        [self enqueueBuffer];
                        //  [self encapsulateAndShipPacket:packet packetDescriptions:packetDescriptions packetID:assetID];                 
                    }                  
                }
                
                
            } else {
            
            }
            
//            [NSThread sleepForTimeInterval:CMTimeGetSeconds(videoTrack.minFrameDuration)];
        }

    }];
    
    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(100, 300, 100, 100)];
    button.backgroundColor = [UIColor yellowColor];
    [button addTarget:self action:@selector(hit) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    
    UIButton *button2 = [[UIButton alloc] initWithFrame:CGRectMake(200, 300, 100, 100)];
    button2.backgroundColor = [UIColor redColor];
    [button2 addTarget:self action:@selector(stop) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button2];
    
    
    self.playerView = [[UIView alloc] init];
    self.playerView.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.width*videoTrack.naturalSize.height/videoTrack.naturalSize.width);
    
    [self.view addSubview:self.playerView];
    
}

-(void)enqueueBuffer
{
    @synchronized(self)
    {
        
        inuse[fillBufferIndex] = true;		// set in use flag
        buffersUsed++;
        
        // enqueue buffer
        AudioQueueBufferRef fillBuf = audioQueueBuffers[fillBufferIndex];
        fillBuf->mAudioDataByteSize = (UInt32)bytesFilled;
        
        
        /*NSData *bufContent = [NSData dataWithBytes:fillBuf->mAudioData length:fillBuf->mAudioDataByteSize];
         NSLog(@"we are enquing the queue with buffer (length: %lu) %@",fillBuf->mAudioDataByteSize,bufContent);
         NSLog(@"\n\n\n");
         NSLog(@":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::");*/
        
        if (packetsFilled)
        {
            /*        NSLog(@"\n\n\n\n\n\n");
             NSLog(@":::::: we are enqueuing buffer with %zu packtes!",packetsFilled);
             NSLog(@"buffer data is %@",[NSData dataWithBytes:fillBuf->mAudioData length:fillBuf->mAudioDataByteSize]);
             
             for (int i = 0; i < packetsFilled; i++)
             {
             NSLog(@"\THIS IS THE PACKET WE ARE COPYING TO AUDIO BUFFER----------------\n");
             NSLog(@"this is packetDescriptionArray.mStartOffset: %lld", packetDescs[i].mStartOffset);
             NSLog(@"this is packetDescriptionArray.mVariableFramesInPacket: %lu", packetDescs[i].mVariableFramesInPacket);
             NSLog(@"this is packetDescriptionArray[.mDataByteSize: %lu", packetDescs[i].mDataByteSize);
             NSLog(@"\n----------------\n");
             }
             */
            
            
            err = AudioQueueEnqueueBuffer(queue, fillBuf, (UInt32)packetsFilled, packetDescs);
        }
        else
        {
            NSLog(@":::::: we are enqueuing buffer with fillBufIndex %d, and bytes %zu", fillBufferIndex, bytesFilled);
            
            //NSLog(@"enqueue buffer thread name %@", [NSThread currentThread].name);
            err = AudioQueueEnqueueBuffer(queue, fillBuf, 0, NULL);
        }
        
        if (err)
        {
            NSLog(@"could not enqueue queue with buffer");
            return;
        }
        
        
        if (state == AS_BUFFERING)
        {
            //
            // Fill all the buffers before starting. This ensures that the
            // AudioFileStream stays a small amount ahead of the AudioQueue to
            // avoid an audio glitch playing streaming files on iPhone SDKs < 3.0
            //
            if (buffersUsed == kNumberPlaybackBuffers - 1)
            {
                NSLog(@"STARTING THE QUEUE");
                err = AudioQueueStart(queue, NULL);
                if (err)
                {
                    NSLog(@"couldn't start queue");
                    return;
                }
                state = AS_PLAYING;
            }
        }
        
        // go to next buffer
        if (++fillBufferIndex >= kNumberPlaybackBuffers) fillBufferIndex = 0;
        bytesFilled = 0;		// reset bytes filled
        packetsFilled = 0;		// reset packets filled
        
    }
    
    // wait until next buffer is not in use
    pthread_mutex_lock(&queueBuffersMutex);
    while (inuse[fillBufferIndex])
    {
        pthread_cond_wait(&queueBufferReadyCondition, &queueBuffersMutex);
    }
    pthread_mutex_unlock(&queueBuffersMutex);
    
}

- (void)hit {
    if ([self.reader status] == AVAssetReaderStatusCompleted) {
//        [self mMoveDecoderOnDecoderFinished];
//        [self.reader cancelReading];
//        self.reader = nil;

    }
}


- (void) setupQueue
{
    
    AudioStreamBasicDescription asbd = nativeTrackASBD;
    
    // create a output (playback) queue
    CheckError(AudioQueueNewOutput(&asbd, // ASBD
                                   MyAQOutputCallback, // Callback
                                   (__bridge void *)self, // user data
                                   NULL, // run loop
                                   NULL, // run loop mode
                                   0, // flags (always 0)
                                   &queue), // output: reference to AudioQueue object
               "AudioQueueNewOutput failed");
    
    
    // adjust buffer size to represent about a half second (0.5) of audio based on this format
    CalculateBytesForTime(asbd,  0.5, &bufferByteSize, &numPacketsToRead);
    bufferByteSize = 2048;
    NSLog(@"this is buffer byte size %u", (unsigned int)bufferByteSize);
    //   bufferByteSize = 800;
    
    // check if we are dealing with a VBR file. ASBDs for VBR files always have
    // mBytesPerPacket and mFramesPerPacket as 0 since they can fluctuate at any time.
    // If we are dealing with a VBR file, we allocate memory to hold the packet descriptions
    bool isFormatVBR = (asbd.mBytesPerPacket == 0 || asbd.mFramesPerPacket == 0);
    if (isFormatVBR)
        packetDescs = (AudioStreamPacketDescription*)malloc(sizeof(AudioStreamPacketDescription) * numPacketsToRead);
    else
        packetDescs = NULL; // we don't provide packet descriptions for constant bit rate formats (like linear PCM)
    
    // get magic cookie from file and set on queue
    MyCopyEncoderCookieToQueue(playbackFile, queue);
    
    // allocate the buffers and prime the queue with some data before starting
    isDone = false;
    packetPosition = 0;
    int i;
    for (i = 0; i < kNumberPlaybackBuffers; ++i)
    {
        CheckError(AudioQueueAllocateBuffer(queue, bufferByteSize, &audioQueueBuffers[i]), "AudioQueueAllocateBuffer failed");
        
        // EOF (the entire file's contents fit in the buffers)
        if (isDone)
            break;
    }
    
    AudioSessionInitialize (
                            NULL,                          // 'NULL' to use the default (main) run loop
                            NULL,                          // 'NULL' to use the default run loop mode
                            NULL,  //ASAudioSessionInterruptionListenera reference to your interruption callback
                            NULL                       // data to pass to your interruption listener callback
                            );
    UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
    AudioSessionSetProperty (
                             kAudioSessionProperty_AudioCategory,
                             sizeof (sessionCategory),
                             &sessionCategory
                             );
    AudioSessionSetActive(true);
    
    
    
//    [[AVAudioSession sharedInstance]
//     setCategory:AVAudioSessionCategoryPlayback error:nil];
//    
//    [[AVAudioSession sharedInstance] setActive:YES error:nil];
//    
//    [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:0.1 error:nil];
    
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
    dispatch_async(dispatch_get_main_queue(), ^{
        self.playerView.layer.contents = (__bridge id)cgimage;
        CGImageRelease(cgimage);
        CFRelease(videoBuffer);
    });

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

#pragma mark - utility functions -

// generic error handler - if err is nonzero, prints error message and exits program.
static void CheckError(OSStatus error, const char *operation)
{
    if (error == noErr) return;
    
    char str[20];
    // see if it appears to be a 4-char-code
    *(UInt32 *)(str + 1) = CFSwapInt32HostToBig(error);
    if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) {
        str[0] = str[5] = '\'';
        str[6] = '\0';
    } else
        // no, format it as an integer
        sprintf(str, "%d", (int)error);
    
    fprintf(stderr, "Error: %s (%s)\n", operation, str);
    
    exit(1);
}

static void MyAQOutputCallback(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inCompleteAQBuffer)
{
//    AppDelegate *appDelegate = (__bridge AppDelegate *) inUserData;
//    [appDelegate myCallback:inUserData
//               inAudioQueue:inAQ
//        audioQueueBufferRef:inCompleteAQBuffer];
    
    ViewController *controller = (__bridge ViewController *) inUserData;
    [controller myCallback:inUserData inAudioQueue:inAQ audioQueueBufferRef:inCompleteAQBuffer];
}

- (void)myCallback:(void *)userData
      inAudioQueue:(AudioQueueRef)inAQ
audioQueueBufferRef:(AudioQueueBufferRef)inCompleteAQBuffer
{
    
    unsigned int bufIndex = -1;
    for (unsigned int i = 0; i < kNumberPlaybackBuffers; ++i)
    {
        if (inCompleteAQBuffer == audioQueueBuffers[i])
        {
            bufIndex = i;
            break;
        }
    }
    
    if (bufIndex == -1)
    {
        NSLog(@"something went wrong at queue callback");
        return;
    }
    
    // signal waiting thread that the buffer is free.
    pthread_mutex_lock(&queueBuffersMutex);
    
    NSLog(@"in call back and we are freeing buf index %d", bufIndex);
    inuse[bufIndex] = false;
    buffersUsed--;
    
    pthread_cond_signal(&queueBufferReadyCondition);
    pthread_mutex_unlock(&queueBuffersMutex);
}

// we only use time here as a guideline
// we're really trying to get somewhere between 16K and 64K buffers, but not allocate too much if we don't need it/*
void CalculateBytesForTime(AudioStreamBasicDescription inDesc, Float64 inSeconds, UInt32 *outBufferSize, UInt32 *outNumPackets)
{
    
    // we need to calculate how many packets we read at a time, and how big a buffer we need.
    // we base this on the size of the packets in the file and an approximate duration for each buffer.
    //
    // first check to see what the max size of a packet is, if it is bigger than our default
    // allocation size, that needs to become larger
    
    // we don't have access to file packet size, so we just default it to maxBufferSize
    UInt32 maxPacketSize = 0x10000;
    
    static const int maxBufferSize = 0x10000; // limit size to 64K
    static const int minBufferSize = 0x4000; // limit size to 16K
    
    if (inDesc.mFramesPerPacket) {
        Float64 numPacketsForTime = inDesc.mSampleRate / inDesc.mFramesPerPacket * inSeconds;
        *outBufferSize = numPacketsForTime * maxPacketSize;
    } else {
        // if frames per packet is zero, then the codec has no predictable packet == time
        // so we can't tailor this (we don't know how many Packets represent a time period
        // we'll just return a default buffer size
        *outBufferSize = maxBufferSize > maxPacketSize ? maxBufferSize : maxPacketSize;
    }
    
    // we're going to limit our size to our default
    if (*outBufferSize > maxBufferSize && *outBufferSize > maxPacketSize)
        *outBufferSize = maxBufferSize;
    else {
        // also make sure we're not too small - we don't want to go the disk for too small chunks
        if (*outBufferSize < minBufferSize)
            *outBufferSize = minBufferSize;
    }
    *outNumPackets = *outBufferSize / maxPacketSize;
}

// many encoded formats require a 'magic cookie'. if the file has a cookie we get it
// and configure the queue with it
static void MyCopyEncoderCookieToQueue(AudioFileID theFile, AudioQueueRef queue ) {
    UInt32 propertySize;
    OSStatus result = AudioFileGetPropertyInfo (theFile, kAudioFilePropertyMagicCookieData, &propertySize, NULL);
    if (result == noErr && propertySize > 0)
    {
        Byte* magicCookie = (UInt8*)malloc(sizeof(UInt8) * propertySize);
        CheckError(AudioFileGetProperty (theFile, kAudioFilePropertyMagicCookieData, &propertySize, magicCookie), "get cookie from file failed");
        CheckError(AudioQueueSetProperty(queue, kAudioQueueProperty_MagicCookie, magicCookie, propertySize), "set cookie on queue failed");
        free(magicCookie);
    }
}

@end
