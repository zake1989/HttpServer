//
//  MTPlayerAudioQueue.h
//  MTPlayerIOS
//
//  Created by meitu on 16/5/30.
//  Copyright © 2016年 meitu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#include <pthread.h>

typedef void (*SDL_AudioCallback)(void *userdata, UInt8 *stream, int len);
typedef struct SDL_AudioSpec
{
    int freq;		    /**< DSP frequency -- samples per second */
    UInt16 format;		/**< Audio data format */
    UInt8  channels;	/**< Number of channels: 1 mono, 2 stereo */
    UInt8  silence;		/**< Audio buffer silence value (calculated) */
    UInt16 samples;		/**< Audio buffer size in samples (power of 2) */
    UInt16 padding;		/**< Necessary for some compile environments */
    UInt32 size;		/**< Audio buffer size in bytes (calculated) */
    /**
     *  This function is called when the audio device needs more data.
     *
     *  @param[out] stream	A pointer to the audio data buffer
     *  @param[in]  len	The length of the audio buffer in bytes.
     *
     *  Once the callback returns, the buffer will no longer be valid.
     *  Stereo samples are stored in a LRLRLR ordering.
     */
    SDL_AudioCallback callback;  //void (*callback)(void *userdata, Uint8 *stream, int len);
    void  *userdata;
} SDL_AudioSpec;


@interface MTPlayerAudioQueue : NSObject

@property (nonatomic, readonly) SDL_AudioSpec audioSpec;

- (id)initWithAudioSpec: (SDL_AudioSpec *)spec;

- (int)play;
- (int)pause;
- (int)flush;
- (int)stop;
- (int)close;

- (int)setPlaybackRate: (float)playbackRate;

- (int)setAudioVolume: (float)audioVolume;
- (float)getAudioVolume;

@end
