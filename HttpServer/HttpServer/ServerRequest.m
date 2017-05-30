//
//  ServerRequest.m
//  HttpServer
//
//  Created by Stephen on 30/5/17.
//  Copyright © 2017 zake. All rights reserved.
//

#import "ServerRequest.h"
#import <UIKit/UIKit.h>

@interface ServerRequest()
@property (nonatomic, strong) NSMutableData *responseData;
@property (nonatomic, strong) NSURLConnection* operationConnection;
@end


@implementation ServerRequest

- (void)main {
    
    if ([self isCancelled])
        return;
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    
    NSLog(@"NSOperation Calling...");
    
    NSURL *url = [NSURL URLWithString:@"http://127.0.0.1:8080/"];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url] ;
    [request setHTTPBody:[@"Request Body Data" dataUsingEncoding:NSUTF8StringEncoding]];
    [request setHTTPMethod:@"POST"];
    
    NSURLConnection *con = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    [con setDelegateQueue:[NSOperationQueue currentQueue]];
    [con start];
}

#pragma mark - Connection Delegate

- (void) connection:(NSURLConnection *) connection didReceiveResponse:(NSURLResponse *) response {
    
    // This method is called when the server has determined that it has enough information to create the NSURLResponse.
    
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    NSInteger responseStatusCode = httpResponse.statusCode;
    NSLog(@"Response Status Code: %ld", (long)responseStatusCode);
    
    // It can be called multiple times, for example in the case of a
    // redirect, so each time we reset the data.
    // responseData is an instance variable declared elsewhere.
    self.responseData = [NSMutableData new];
    
}

- (void) connection:(NSURLConnection *) connection didReceiveData:(NSData *) data {
    [self.responseData appendData:data];
}

- (void) connection:(NSURLConnection *) connection didFailWithError:(NSError *) error {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    NSLog(@"Error Code: %@",error);
    self.responseData = nil;
}

- (void) connectionDidFinishLoading:(NSURLConnection *) connection  {
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    NSLog(@"ConnectionDidFinish");
    
    // String Test
    //    NSString *strIncomingData = [[[NSString alloc] initWithData:self.responseData encoding:NSUTF8StringEncoding] autorelease];
    //    NSLog(@"Response String: %@", strIncomingData);
    //    return;
    
    // Image Test
    NSString *imagePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"/myImage1.jpg"];
    
    UIImage *img = [UIImage imageWithData:self.responseData];
    NSLog(@"Image is %@, DataLen: %lu, Path: %@", (img == nil)?@"nil":@"valid", (unsigned long)self.responseData.length, imagePath);
    [self.responseData writeToFile:imagePath atomically:YES];
    
    
    self.responseData = nil;
    [connection cancel];
    connection = nil;
}

- (void)dealloc {
    self.responseData = nil;
    NSLog(@"request finsih");
}

@end
