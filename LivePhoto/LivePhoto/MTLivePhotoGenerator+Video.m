//
//  MTLivePhotoGenerator+Video.m
//  LivePhoto
//
//  Created by zeng on 06/04/2017.
//  Copyright © 2017 zengyukai. All rights reserved.
//

#import "MTLivePhotoGenerator+Video.h"

#define kKeyAppleMov_AssetIdentifier (@"mdta/com.apple.quicktime.content.identifier")
#define kKeyMetadataKeySpace @"mdta"
#define kKeyMetadataContentIdentifier @"com.apple.quicktime.content.identifier"
#define kKeyMetadataStillImageTime @"com.apple.quicktime.still-image-time"
#define kKeyMetadataDataType @"com.apple.metadata.datatype.UTF-8"
#define kKeyDataTypeInt8 @"com.apple.metadata.datatype.int8"

@implementation MTLivePhotoGenerator (Video)

- (void)addMetaDataToVideoAtPath:(NSString *)videoPath withID:(NSString *)ID completionHandler:(void(^)(BOOL success))completionHandler {
    // https://github.com/genadyo/LivePhotoDemo
    
    AVURLAsset *asset = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:videoPath]];
    NSArray *videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    AVAssetTrack *track = nil;
    if (videoTracks.count > 0) {
        track = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    }
    if (!track || track == ((void*)0)) {
        NSLog(@"Invalid video");
        completionHandler(NO);
        return;
    }
    
    // --------------------------------------------------
    // reader for source video
    // --------------------------------------------------
    AVAssetReaderTrackOutput *output = [[AVAssetReaderTrackOutput alloc] initWithTrack:track outputSettings:@{(NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)}];
    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:asset error:nil];
    [reader addOutput:output];
    
    // add audio track if any
    NSArray *audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
    AVAssetTrack *audioTrack = nil;
    if (audioTracks.count > 0) {
        audioTrack = [audioTracks firstObject];;
    }
    AVAssetReaderTrackOutput *audioOutput = nil;
    if (audioTrack && audioTrack != ((void*)0)) {
        audioOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:audioTrack outputSettings:@{AVFormatIDKey: @(kAudioFormatLinearPCM)}];
        [reader addOutput:audioOutput];
    }
    
    // --------------------------------------------------
    // writer for mov
    // --------------------------------------------------
    [[NSFileManager defaultManager] removeItemAtPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"LPTempVideoMeta.mov"] error:nil];
    AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"LPTempVideoMeta.mov"]] fileType:AVFileTypeQuickTimeMovie error:nil];
    NSMutableArray *newMetadata = [[NSMutableArray alloc] initWithCapacity:1];
    AVMutableMetadataItem *itemID = [[AVMutableMetadataItem alloc] init];
    itemID.keySpace = kKeyMetadataKeySpace;
    itemID.key = kKeyMetadataContentIdentifier;
    itemID.value = ID;
    itemID.dataType = kKeyMetadataDataType;
    [newMetadata addObject:itemID];
    writer.metadata = newMetadata;
    
    // video track
    AVAssetWriterInput *input = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo
                                                               outputSettings:@{AVVideoCodecKey: AVVideoCodecH264,
                                                                                AVVideoWidthKey: @(track.naturalSize.width),
                                                                                AVVideoHeightKey: @(track.naturalSize.height)}];
    input.expectsMediaDataInRealTime = YES;
    input.transform = track.preferredTransform;
    [writer addInput:input];
    
    // audio track
    AVAssetWriterInput *audioInput = nil;
    if (audioTrack) {
        AudioChannelLayout acl;
        bzero( &acl, sizeof(acl));
        acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;
        
        AVAudioSession *sharedAudioSession = [AVAudioSession sharedInstance];
        double preferredHardwareSampleRate = [sharedAudioSession sampleRate];
        NSDictionary *audioSettings =   [NSDictionary dictionaryWithObjectsAndKeys:
                                         [ NSNumber numberWithInt: kAudioFormatMPEG4AAC], AVFormatIDKey,
                                         [ NSNumber numberWithInt: 1 ], AVNumberOfChannelsKey,
                                         [ NSNumber numberWithFloat: preferredHardwareSampleRate ], AVSampleRateKey,
                                         [ NSData dataWithBytes: &acl length: sizeof( acl ) ], AVChannelLayoutKey,
                                         [ NSNumber numberWithInt: 64000 ], AVEncoderBitRateKey,
                                         nil];
        audioInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio
                                                    outputSettings:audioSettings];
        audioInput.expectsMediaDataInRealTime = YES;
        [writer addInput:audioInput];
    }
    
    // metadata track
    NSDictionary *spec = @{(__bridge NSString *)kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier: [NSString stringWithFormat:@"%@/%@", kKeyMetadataKeySpace, kKeyMetadataStillImageTime],
                           (__bridge NSString *)kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType: kKeyDataTypeInt8};
    CMFormatDescriptionRef desc = NULL;
    AVAssetWriterInputMetadataAdaptor *adaptor = nil;
    OSStatus error = CMMetadataFormatDescriptionCreateWithMetadataSpecifications(kCFAllocatorDefault, kCMMetadataFormatType_Boxed, (__bridge CFArrayRef)(@[spec]), &desc);
    if (!error) {
        AVAssetWriterInput *metadataInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeMetadata outputSettings:nil sourceFormatHint:desc];
        adaptor = [[AVAssetWriterInputMetadataAdaptor alloc] initWithAssetWriterInput:metadataInput];
        [writer addInput:adaptor.assetWriterInput];
    } else {
        NSLog(@"Invalid metadata: %d", error);
        completionHandler(NO);
        return;
    }
    CFRelease(desc);
    
    // --------------------------------------------------
    // creating video
    // --------------------------------------------------
    [writer startWriting];
    [reader startReading];
    [writer startSessionAtSourceTime:kCMTimeZero];
    
    // write metadata track
    AVMutableMetadataItem *item = [[AVMutableMetadataItem alloc] init];
    item.key = kKeyMetadataStillImageTime;
    item.keySpace = kKeyMetadataKeySpace;
    item.value = @(-1);
    item.dataType = kKeyDataTypeInt8;
    [adaptor appendTimedMetadataGroup:[[AVTimedMetadataGroup alloc] initWithItems:@[item] timeRange:CMTimeRangeMake(CMTimeMake(6, 12), CMTimeMake(1, 12))]];
    
    // write video track
    [input requestMediaDataWhenReadyOnQueue:dispatch_queue_create("assetAudioWriterQueue", nil) usingBlock:^{
        while (input.readyForMoreMediaData) {
            if (reader.status == AVAssetReaderStatusReading) {
                CMSampleBufferRef buffer = [output copyNextSampleBuffer];
                if (buffer) {
                    if (![input appendSampleBuffer:buffer]) {
                        NSLog(@"cannot write: %@", writer.error);
                        [reader cancelReading];
                        completionHandler(NO);
                        return;
                    }
                    CFRelease(buffer);
                } else {
                    [input markAsFinished];
                    [writer finishWritingWithCompletionHandler:^{
                        if (writer.error) {
                            NSLog(@"cannot write: %@", writer.error);
                            completionHandler(NO);
                            return;
                        } else {
                            // finish writing
                            [[NSFileManager defaultManager] removeItemAtPath:videoPath error:nil];
                            [[NSFileManager defaultManager] moveItemAtPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"LPTempVideoMeta.mov"]
                                                                    toPath:videoPath
                                                                     error:nil];
                            completionHandler(YES);
                            return;
                        }
                    }];
                }
            }
        }
    }];
    // write audio track
    if (audioTrack) {
        [audioInput requestMediaDataWhenReadyOnQueue:dispatch_queue_create("assetAudioWriterQueue", nil) usingBlock:^{
            while (audioInput.readyForMoreMediaData) {
                if (reader.status == AVAssetReaderStatusReading) {
                    CMSampleBufferRef buffer = [audioOutput copyNextSampleBuffer];
                    if (buffer) {
                        if (![audioInput appendSampleBuffer:buffer]) {
                            NSLog(@"cannot write: %@", writer.error);
                            [reader cancelReading];
                            completionHandler(NO);
                            return;
                        }
                        CFRelease(buffer);
                    } else {
                        [audioInput markAsFinished];
                    }
                }
            }
        }];
    }
    while (writer.status == AVAssetWriterStatusWriting) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    }
    if (writer.error) {
        NSLog(@"cannot write: %@", writer.error);
        completionHandler(NO);
        return;
    }
}

@end
