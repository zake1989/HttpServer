//
//  MTPlayerAudioQueue.m
//  MTPlayerIOS
//
//  Created by meitu on 16/5/30.
//  Copyright © 2016年 meitu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MTPlayerAudioQueue.h"
//#import "MTPlayerAudioCommon.h"

#define SDL_AUDIO_MASK_BITSIZE       (0xFF)
#define SDL_AUDIO_BITSIZE(x)         (x & SDL_AUDIO_MASK_BITSIZE)


static void AudioQueueRenderCallback(void * __nullable       inUserData,
                              AudioQueueRef           inAQ,
                              AudioQueueBufferRef     inBuffer);


@interface MTPlayerAudioQueue ()
{
    AudioQueueRef _audioQueueRef;
    AudioQueueBufferRef _audioQueueBufferRefArray[3];
    
    NSLock *_lock;
}

@property (nonatomic, readonly) BOOL paused;  //playing;
@property (nonatomic, readonly) BOOL stopped;

@end

@implementation MTPlayerAudioQueue

- (id)initWithAudioSpec: (const SDL_AudioSpec *)spec
{
    self = [super init];
    if (self)
    {
        if (spec == NULL)
        {
            NSLog(@"MTPlayerAudioQueue initWithAudioSpec, audio spec is NULL, failed");
            self = nil;
            return nil;
        }
        
        _audioSpec = *spec;
        
        // Describe the output unit.
        AudioComponentDescription description;
        GetAudioStreamBasicDescriptionFromSpec(&_audioSpec, &description);
        
        AudioQueueRef audioQueueRef;
        OSStatus status = AudioQueueNewOutput(&description,
                                             AudioQueueRenderCallback,
                                             (__bridge void *)(self),
                                             NULL,
                                             kCFRunLoopCommonModes,
                                             0,
                                             &audioQueueRef);
        if (status != noErr)
        {
            NSLog(@"MTPlayerAudioQueue initWithAudioSpec, audioQueue new output failed");
            self = nil;
            return nil;
        }
        
        UInt32 propValue = 1;
        AudioQueueSetProperty(audioQueueRef, kAudioQueueProperty_EnableTimePitch, &propValue, sizeof(propValue));
        propValue = 1;
        AudioQueueSetProperty(audioQueueRef, kAudioQueueProperty_TimePitchBypass, &propValue, sizeof(propValue));
        propValue = kAudioQueueTimePitchAlgorithm_Spectral;
        AudioQueueSetProperty(audioQueueRef, kAudioQueueProperty_TimePitchAlgorithm, &propValue, sizeof(propValue));
        
        status= AudioQueueStart(audioQueueRef, NULL);
        if (status != noErr)
        {
            NSLog(@"MTPlayerAudioQueue initWithAudioSpec, audioQueue start failed");
            self = nil;
            return nil;
        }
        
        SDL_Calc_AudioSpec(&_audioSpec);
        
        _audioQueueRef = audioQueueRef;
        
        for (int i = 0; i < 3; i++)
        {
            AudioQueueAllocateBuffer(audioQueueRef, _audioSpec.size, &_audioQueueBufferRefArray[i]);
            _audioQueueBufferRefArray[i]->mAudioDataByteSize = _audioSpec.size;
            memset(_audioQueueBufferRefArray[i]->mAudioData, 0, _audioSpec.size);  //
            AudioQueueEnqueueBuffer(audioQueueRef, _audioQueueBufferRefArray[i], 0, NULL);
        }
        
        _lock = [[NSLock alloc] init];
        
        _stopped = NO;
    }
    
    return self;
}

void GetAudioStreamBasicDescriptionFromSpec(const SDL_AudioSpec *spec, AudioStreamBasicDescription *desc)
{
    if (!spec || !desc)
    {
        return;
    }
    
    desc->mSampleRate = spec->freq;
    desc->mFormatID = kAudioFormatLinearPCM;
    desc->mFormatFlags = kLinearPCMFormatFlagIsPacked;
    desc->mChannelsPerFrame = spec->channels;
    desc->mFramesPerPacket = 1;
    
    desc->mBitsPerChannel = SDL_AUDIO_BITSIZE(spec->format);
    
//    if (SDL_AUDIO_ISBIGENDIAN(spec->format))
//        desc->mFormatFlags |= kLinearPCMFormatFlagIsBigEndian;
//    if (SDL_AUDIO_ISFLOAT(spec->format))
//        desc->mFormatFlags |= kLinearPCMFormatFlagIsFloat;
//    if (SDL_AUDIO_ISSIGNED(spec->format))
    desc->mFormatFlags |= kLinearPCMFormatFlagIsSignedInteger;
    
    desc->mBytesPerFrame = desc->mBitsPerChannel * desc->mChannelsPerFrame / 8;
    desc->mBytesPerPacket = desc->mBytesPerFrame * desc->mFramesPerPacket;
}

void SDL_Calc_AudioSpec(SDL_AudioSpec *spec)
{
    if (!spec)
    {
        return;
    }
    

    spec->silence = 0x0;
    
    
    spec->size = SDL_AUDIO_BITSIZE(spec->format) / 8;
    spec->size *= spec->channels;
    spec->size *= spec->samples;
}

- (void)dealloc
{
    NSLog(@"MTPlayerAudioQueue dealloc");
    
    [self close];
}

- (int)play
{
    NSLog(@"MTPlayerAudioQueue play");
    
    if (!_audioQueueRef)
    {
        NSLog(@"MTPlayerAudioQueue play, audioQueue ref is nil, failed");
        return -1;
    }
    
    @synchronized (_lock)
    {
        _paused = NO;  //_playing = YES;
        
        NSError *error = nil;
        if ([[AVAudioSession sharedInstance] setActive:YES error:&error] == NO)
        {
            NSLog(@"MTPlayerAudioQueue play, AVAudioSession set active failed, %@", error ? [error localizedDescription] : @"nil");
        }
        
        OSStatus status = AudioQueueStart(_audioQueueRef, NULL);
        if (status != noErr)
        {
            NSLog(@"MTPlayerAudioQueue play, audio queue start failed, %d", status);
            return -1;
        }
        
        return 0;
    }
}

- (int)pause
{
    NSLog(@"MTPlayerAudioQueue pause");
    
    if (!_audioQueueRef)
    {
        NSLog(@"MTPlayerAudioQueue pause, audioQueue ref is nil, failed");
        return -1;
    }
    
    @synchronized (_lock)
    {
        if (_stopped)
        {
            return -1;
        }
        
        _paused = YES;  //_playing = NO;
        
        OSStatus status = AudioQueuePause(_audioQueueRef);
        if (status != noErr)
        {
            NSLog(@"MTPlayerAudioQueue play, audio queue pause failed");
            return -1;
        }
        
        return 0;
    }
}

- (int)flush
{
    NSLog(@"MTPlayerAudioQueue flush");
    
    if (!_audioQueueRef)
    {
        NSLog(@"MTPlayerAudioQueue flush, audioQueue ref is nil, failed");
        return -1;
    }
    
    @synchronized (_lock)
    {
        if (_stopped)
        {
            return -1;
        }
        
        OSStatus status = AudioQueueFlush(_audioQueueRef);
        if (status != noErr)
        {
            NSLog(@"MTPlayerAudioQueue play, audio queue flush failed");
            return -1;
        }
        
        return 0;
    }
}

- (int)stop
{
    NSLog(@"MTPlayerAudioQueue stop");
    
    if (!_audioQueueRef)
    {
        NSLog(@"MTPlayerAudioQueue stop, audioQueue ref is nil, failed");
        return -1;
    }
    
    @synchronized (_lock)
    {
        if (_stopped)
        {
            return -1;
        }
        
        _stopped = YES;  //_playing = NO;
    }
    
    OSStatus status = AudioQueueStop(_audioQueueRef, true);
    if (status != noErr)
    {
        NSLog(@"MTPlayerAudioQueue stop, audio queue stop failed");
    }
    
    status = AudioQueueDispose(_audioQueueRef, true);
    if (status != noErr)
    {
        NSLog(@"MTPlayerAudioQueue stop, audio queue dispose failed");
    }
    
    return 0;
}

- (int)close
{
    NSLog(@"MTPlayerAudioQueue close");
    
    if (!_audioQueueRef)
    {
        NSLog(@"MTPlayerAudioQueue close, audioQueue ref is nil, failed");
        return -1;
    }
    
    [self stop];
    
    _audioQueueRef = nil;
    
    return 0;
}

- (int)setPlaybackRate: (float)playbackRate
{
    //NSLog(@"MTPlayerAudioQueue setPlaybackRate");
    
    if (!_audioQueueRef)
    {
        return -1;
    }
    
    if (fabsf(playbackRate - 1.0f) <= 0.000001)
    {
        UInt32 propValue = 1;
        
        AudioQueueSetProperty(_audioQueueRef, kAudioQueueProperty_TimePitchBypass, &propValue, sizeof(propValue));
        AudioQueueSetParameter(_audioQueueRef, kAudioQueueParam_PlayRate, 1.0f);
    }
    else
    {
        UInt32 propValue = 0;
        
        AudioQueueSetProperty(_audioQueueRef, kAudioQueueProperty_TimePitchBypass, &propValue, sizeof(propValue));
        AudioQueueSetParameter(_audioQueueRef, kAudioQueueParam_PlayRate, playbackRate);
    }
    
    return 0;
}

- (int)setAudioVolume: (float)audioVolume
{
    if (!_audioQueueRef)
    {
        return -1;
    }
    
    AudioQueueSetParameter(_audioQueueRef, kAudioQueueParam_Volume, audioVolume);
    
    return 0;
}

- (float)getAudioVolume
{
    if (!_audioQueueRef)
    {
        return 1.0;
    }
    
    float audioVolume = 1.0;
    AudioQueueGetParameter(_audioQueueRef, kAudioQueueParam_Volume, &audioVolume);
    
    return audioVolume;
}

//AudioQueueReset

//- (void)setupAVAudioSession
//- (BOOL)setActive: (BOOL)active
//- (void)SessionInterruptionListener: (NSNotification *)notification

@end

static void AudioQueueRenderCallback(void * __nullable       inUserData,
                              AudioQueueRef           inAQ,
                              AudioQueueBufferRef     inBuffer)
{
    @autoreleasepool
    {
        MTPlayerAudioQueue *aq = (__bridge MTPlayerAudioQueue *)inUserData;
        
        if (!aq)
        {
            //
        }
        else if (aq.paused || aq.stopped)
        {
            memset(inBuffer->mAudioData, aq.audioSpec.silence, inBuffer->mAudioDataByteSize);
        }
        else
        {
            //(*aq.audioSpec.callback)(aq.audioSpec.userdata, inBuffer->mAudioData, inBuffer->mAudioDataByteSize);
            aq.audioSpec.callback(aq.audioSpec.userdata, inBuffer->mAudioData, inBuffer->mAudioDataByteSize);
        }
        
        AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
    }
}







