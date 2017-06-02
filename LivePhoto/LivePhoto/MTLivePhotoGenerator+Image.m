
//
//  MTLivePhotoGenerator+Image.m
//  LivePhoto
//
//  Created by zeng on 06/04/2017.
//  Copyright © 2017 zengyukai. All rights reserved.
//

#import "MTLivePhotoGenerator+Image.h"

#define kKeyAppleMakerNote_AssetIdentifier (@"17")

@implementation MTLivePhotoGenerator (Image)

- (void)addMetaDataToImageAtPath:(NSString *)imagePath withID:(NSString *)ID completionHandler:(void(^)(BOOL success))completionHandler {
    NSData *demoImageData = [NSData dataWithContentsOfFile:imagePath];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath])
    {
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtPath:imagePath error:&error];
        if (error)
        {
            NSLog(@"remove old image file error: %@", error.localizedDescription);
        }
    }
    
    CGImageSourceRef imageSourceRef = CGImageSourceCreateWithData((__bridge CFDataRef)demoImageData, NULL);
    CFDictionaryRef metadataRef = CGImageSourceCopyPropertiesAtIndex(imageSourceRef, 0,NULL);
    NSMutableDictionary *metadata = [(__bridge NSDictionary *)metadataRef mutableCopy];
    CFRelease(metadataRef);
    NSDictionary *makerApple = @{ kKeyAppleMakerNote_AssetIdentifier: ID };
    CFDictionarySetValue((__bridge CFMutableDictionaryRef) metadata, kCGImagePropertyMakerAppleDictionary, (__bridge void *) makerApple);
    
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef) demoImageData, NULL);
    
    CFStringRef UTI = CGImageSourceGetType(source); // this is the type of image (e.g., public.jpeg)
    
    NSMutableData *dest_data = [NSMutableData data];
    
    CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef) dest_data, UTI, 1, NULL);
    
    if (!destination)
    {
        NSLog(@"***Could not create image destination ***");
    }
    
    // add the image contained in the image source to the destination, overidding the old metadata with our modified metadata
    CGImageDestinationAddImageFromSource(destination, source, 0, (__bridge CFDictionaryRef) metadata);
    
    // tell the destination to write the image data and metadata into our data object.
    // It will return false if something goes wrong
    BOOL success = CGImageDestinationFinalize(destination);
    
    if (!success)
    {
        NSLog(@"***Could not create data from image destination ***");
    }
    
    success = [dest_data writeToFile:imagePath atomically:YES];
    
    CFRelease(destination);
    CFRelease(source);
    CFRelease(imageSourceRef);
    if (completionHandler) {
        completionHandler(success);
    }
}

@end
