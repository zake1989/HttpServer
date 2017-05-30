//
//  HttpServer.m
//  HttpServer
//
//  Created by Stephen on 30/5/17.
//  Copyright © 2017 zake. All rights reserved.
//

#import "HttpServer.h"
#import <UIKit/UIKit.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <CFNetwork/CFNetwork.h>

@interface HttpServer () {
    NSFileHandle *listeningHandle;
    CFSocketRef socket;
    CFMutableDictionaryRef incomingRequests;
}
@end

@implementation HttpServer

+ (instancetype)sharedInstance {
    static HttpServer *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[HttpServer alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        incomingRequests = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                                     0,
                                                     &kCFTypeDictionaryKeyCallBacks,
                                                     &kCFTypeDictionaryValueCallBacks);
    }
    return self;
}

- (void)start {
    // 创建socket
    socket = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_TCP, 0, NULL, NULL);
    if (!socket) {
        NSLog(@"[Proxy Server] Unable to create socket.");
        return;
    }
    
    int reuse = true;
    int fileDescriptor = CFSocketGetNative(socket);
    if (setsockopt(fileDescriptor, SOL_SOCKET, SO_REUSEADDR, (void *)&reuse, sizeof(int)) != 0) {
        NSLog(@"[Proxy Server] Unable to set socket options.");
        return;
    }
    
    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_len = sizeof(address);
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_ANY);
    address.sin_port = htons(8080);
    CFDataRef addressData = CFDataCreate(NULL, (const UInt8 *)&address, sizeof(address));
    
    if (CFSocketSetAddress(socket, addressData) != kCFSocketSuccess) {
        NSLog(@"[Proxy Server] Unable to bind socket to address.");
        return;
    }
    
    CFRelease(addressData);
    
    // 将socket地址转换成可用的类型
    CFDataRef actualAddress = CFSocketCopyAddress(socket);
    struct sockaddr_in socketAddressActual;
    memcpy(&socketAddressActual, CFDataGetBytePtr(actualAddress) , CFDataGetLength(actualAddress));
    CFRelease(actualAddress);
    
//    // 与当前线程runloop链接
//    CFRunLoopRef cfRunLoop = CFRunLoopGetCurrent();
//    CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(kCFAllocatorDefault, socket, 0);
//    CFRunLoopAddSource(cfRunLoop, source, kCFRunLoopCommonModes);
//    CFRelease(source);

    listeningHandle = [[NSFileHandle alloc] initWithFileDescriptor:fileDescriptor closeOnDealloc:YES];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveIncomingConnectionNotification:)
                                                 name:NSFileHandleConnectionAcceptedNotification object:nil];
    [listeningHandle acceptConnectionInBackgroundAndNotify];
    
    NSLog(@"[Proxy Server] Started");
}

- (void)receiveIncomingConnectionNotification:(NSNotification *)notification {
    
    NSDictionary *userInfo = [notification userInfo];
    NSFileHandle *incomingFileHandle = [userInfo objectForKey:NSFileHandleNotificationFileHandleItem];
    if (incomingFileHandle) {
        
        CFDictionaryAddValue( incomingRequests,
                             (__bridge const void *)(incomingFileHandle),
                             (__bridge const void *)((__bridge id)CFHTTPMessageCreateEmpty(kCFAllocatorDefault, TRUE)));
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveIncomingDataNotification:)
                                                     name:NSFileHandleDataAvailableNotification object:incomingFileHandle];
        
        [incomingFileHandle waitForDataInBackgroundAndNotify];
    }
    
    // Need to call this func again for other requests
    [listeningHandle acceptConnectionInBackgroundAndNotify];
}

- (void)receiveIncomingDataNotification:(NSNotification *)notification {
    
    NSFileHandle *incomingFileHandle = [notification object];
    NSData *data = [incomingFileHandle availableData];
    
    //    NSString *strIncomingData = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    //    NSLog(@"[Proxy Server] receiveIncomingDataNotification: %@", strIncomingData);
    
    if ([data length] == 0) {
        NSLog(@"Stop Receiving ForFileHandle - Data len 0 - %@", [self requestTypeForFileHandler:incomingFileHandle]);
        [self stopReceivingForFileHandle:incomingFileHandle close:NO];
        return;
    }
    
    CFHTTPMessageRef incomingRequest = (CFHTTPMessageRef)CFDictionaryGetValue(incomingRequests,
                                                                              (__bridge const void *)(incomingFileHandle));
    if (!incomingRequest) {
        NSLog(@"Stop Receiving ForFileHandle - incoming req nil - %@", [self requestTypeForFileHandler:incomingFileHandle]);
        [self stopReceivingForFileHandle:incomingFileHandle close:YES];
        return;
    }
    
    if (CFHTTPMessageAppendBytes(incomingRequest, [data bytes], [data length]) == false) {
        NSLog(@"Stop Receiving ForFileHandle - append byte failed - %@", [self requestTypeForFileHandler:incomingFileHandle]);
        [self stopReceivingForFileHandle:incomingFileHandle close:YES];
        return;
    }
    
    if (CFHTTPMessageIsHeaderComplete(incomingRequest) == true) {
        
        //            NSURL *messageURL = [NSMakeCollectable(CFHTTPMessageCopyRequestURL(incomingRequest)) autorelease];
        //            NSLog(@"URL: %@", messageURL.absoluteString);
        //
        //            NSString *httpMethod = [NSMakeCollectable(CFHTTPMessageCopyRequestMethod(incomingRequest)) autorelease];
        //            NSLog(@"HTTP method: %@", httpMethod);
        //
        //            NSDictionary *httpHeaderFields = [NSMakeCollectable(CFHTTPMessageCopyAllHeaderFields(incomingRequest)) autorelease];
        //            NSLog(@"HTTP Header Fields: %@", httpHeaderFields);
        //
        //            NSData *httpBodyData = [NSMakeCollectable(CFHTTPMessageCopyBody(incomingRequest)) autorelease];
        //            NSString *httpBody = [[[NSString alloc] initWithData:httpBodyData encoding:NSUTF8StringEncoding] autorelease];
        //            NSLog(@"HTTP Body: %@", httpBody);
        
        [self startResponse:incomingFileHandle];
        
        NSLog(@"Stop Receiving ForFileHandle - header finished - %@", [self requestTypeForFileHandler:incomingFileHandle]);
        [self stopReceivingForFileHandle:incomingFileHandle close:NO];
        
        return;
    }
    
    // Need to call this func again for remaining data.
    [incomingFileHandle waitForDataInBackgroundAndNotify];
}

- (void)startResponse:(NSFileHandle*)fileHandle {
    
    NSInteger responseCode = 200;
    CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, responseCode, NULL, kCFHTTPVersion1_1);
    
    CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)@"Content-Type", (CFStringRef)@"text/plain");
    CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)@"Connection", (CFStringRef)@"close");
    
    NSData *fileData = [self responseDataForFilaHandler:fileHandle];
    NSString *dataLength = [NSString stringWithFormat:@"%ld", (unsigned long)[fileData length]];
    CFHTTPMessageSetHeaderFieldValue(response,
                                     (CFStringRef)@"Content-Length",
                                     (__bridge CFStringRef)dataLength);
    
    CFDataRef headerData = CFHTTPMessageCopySerializedMessage(response);
    
    //    NSString *strHeaderData = [[[NSString alloc] initWithData:(NSData*)headerData encoding:NSUTF8StringEncoding] autorelease];
    //    NSString *strFileData = [[[NSString alloc] initWithData:(NSData*)fileData encoding:NSUTF8StringEncoding] autorelease];
    //    NSLog(@"[Proxy Server] Response: %@ %@", strHeaderData, strFileData);
    
    @try {
        [fileHandle writeData:(__bridge NSData *)headerData];
        if (fileData) {
            NSLog(@"[Proxy Server] Writing Data: %lu", (unsigned long)fileData.length);
            [fileHandle writeData:fileData];
        }
    }
    @catch (NSException *exception) {
        // Ignore the exception, it normally just means the client
        // closed the connection from the other end.
    }
    @finally {
        
        NSLog(@"[Proxy Server] Connection Stopped %@", [self requestTypeForFileHandler:fileHandle]);
        
        CFRelease(headerData);
        CFRelease(response);
        NSLog(@"[Proxy Server] Stop Receiving ForFileHandle - start res finally called - %@", [self requestTypeForFileHandler:fileHandle]);
        [self stopReceivingForFileHandle:fileHandle close:YES];
    }
    
}


- (NSData*)responseDataForFilaHandler:(NSFileHandle*)incomingFileHandle {
    
    // TEXT
    //    NSString *response = [NSString stringWithFormat:@"This is my sample response from Proxy Server for debugging."];
    //    return [response dataUsingEncoding:NSUTF8StringEncoding];
    
    // SMALL IMAGE
    NSData *fileData = UIImageJPEGRepresentation([UIImage imageNamed:@"1.jpg"], 1.0);
    
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"1" ofType:@"jpg"];
    NSLog(@"SMALL File Size : %@ - %lu - %@", [self fileSizeFromPath:path],  (unsigned long)fileData.length , path);
    return fileData;
    
    // LARGE FILE
    //    NSData *fileData = UIImageJPEGRepresentation([UIImage imageNamed:@"4.jpg"], 1.0f);
    //    NSString *path = [[NSBundle mainBundle] pathForResource:@"4" ofType:@"jpg"];
    //    NSLog(@"LARGE File Size : %@ - %lu - %@", [self fileSizeFromPath:path],  (unsigned long)fileData.length , path);
    //    return fileData;
}


- (void)stopReceivingForFileHandle:(NSFileHandle *)incomingFileHandle close:(BOOL)closeFileHandle {
    
    if (closeFileHandle == YES) {
        if (incomingFileHandle) {
            NSLog(@"[Proxy Server] File Closed and Incoming Request Removed from dic. - %@", [self requestTypeForFileHandler:incomingFileHandle]);
            [incomingFileHandle closeFile];
        }
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSFileHandleDataAvailableNotification object:incomingFileHandle];
    CFDictionaryRemoveValue(incomingRequests, (__bridge const void *)(incomingFileHandle));
}

- (void)stop {

}

- (NSString*)requestTypeForFileHandler:(NSFileHandle*)fileHandle {
    
    NSString *requestType = nil;
    CFHTTPMessageRef incomingRequest = (CFHTTPMessageRef)CFDictionaryGetValue(incomingRequests,
                                                                              (__bridge const void *)(fileHandle));
    if (incomingRequest) {
        NSDictionary *httpHeaderFields = (__bridge NSDictionary *)(CFHTTPMessageCopyAllHeaderFields(incomingRequest));
        if (httpHeaderFields) {
            requestType = [httpHeaderFields objectForKey:@"RequestType"];
        }
    }
    return requestType;
}

- (NSString *)fileSizeFromPath:(NSString*)filePath {
    
    NSError *error = nil;
    NSUInteger theSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:&error] fileSize];
    
    if (theSize == 0) {
        NSLog(@"[Size error]: %@", error);
    }
    
    float floatSize = theSize;
    
    // bytes
    if (theSize<1023)
        return ([NSString stringWithFormat:@"%lu bytes",(unsigned long)theSize]);
    
    // KB
    floatSize = floatSize / 1024;
    if (floatSize<1023)
        return([NSString stringWithFormat:@"%1.1f KB",floatSize]);
    
    // MB
    floatSize = floatSize / 1024;
    if (floatSize<1023)
        return([NSString stringWithFormat:@"%1.1f MB",floatSize]);
    
    // GB
    floatSize = floatSize / 1024;
    return ([NSString stringWithFormat:@"%1.1f GB",floatSize]);
}

@end
