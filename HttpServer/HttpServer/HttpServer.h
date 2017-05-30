//
//  HttpServer.h
//  HttpServer
//
//  Created by Stephen on 30/5/17.
//  Copyright © 2017 zake. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HttpServer : NSObject

+ (instancetype)sharedInstance;

- (void)start;
- (void)stop;


@end
