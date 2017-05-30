//
//  ViewController.m
//  HttpServer
//
//  Created by Stephen on 30/5/17.
//  Copyright © 2017 zake. All rights reserved.
//

#import "ViewController.h"
#import "HttpServer.h"
#import "ServerRequest.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [[HttpServer sharedInstance] start];
    
    UIButton *button = [[UIButton alloc]initWithFrame:CGRectMake(100, 100, 100, 100)];
    button.backgroundColor = [UIColor yellowColor];
    [button addTarget:self action:@selector(hit) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
}

- (void)hit {
    NSOperationQueue *requsetQueue = [[NSOperationQueue alloc] init];
    ServerRequest *request = [ServerRequest new];
    [requsetQueue addOperation:request];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
