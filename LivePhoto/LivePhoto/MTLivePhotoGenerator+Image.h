//
//  MTLivePhotoGenerator+Image.h
//  LivePhoto
//
//  Created by zeng on 06/04/2017.
//  Copyright © 2017 zengyukai. All rights reserved.
//

#import "MTLivePhotoGenerator.h"

@interface MTLivePhotoGenerator (Image)

- (void)addMetaDataToImageAtPath:(NSString *)imagePath withID:(NSString *)ID completionHandler:(void(^)(BOOL success))completionHandler;

@end
