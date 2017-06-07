//
//  ViewController.m
//  DownLoad
//
//  Created by zeng on 17/05/2017.
//  Copyright © 2017 zengyukai. All rights reserved.
//

#import "ViewController.h"
#import "MTFileManager.h"
#import "NSString+Hash.h"

#define urlString @"http://fujifilm-indonesia.co.id/Products/digital_cameras/x/fujifilm_x_m1/sample_images/img/index/ff_x_m1_020.JPG"
#define TotalLengthFile [MTFileManager documentFilePathWithAppendPath:@"totalLength"]

@interface ViewController () <NSURLSessionDataDelegate>

@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, strong) NSString *filePath;
@property (nonatomic, strong) NSURL *fileURL;
@property (nonatomic, assign) NSInteger DownloadLength;
@property (nonatomic, assign) NSInteger TotalLength;
@property (nonatomic, strong) NSOutputStream *stream;
@property (nonatomic, strong) NSURLSessionDataTask *download;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.fileName = urlString.md5String;
    self.filePath = [MTFileManager documentFilePathWithAppendPath:self.fileName];
    self.fileURL = [NSURL URLWithString:urlString];
    self.stream = [NSOutputStream outputStreamToFileAtPath:self.filePath append:YES];
    
    NSLog(@"%ld",(long)self.DownloadLength);
    NSLog(@"%@",self.fileName);
    
    UIButton *button = [[UIButton alloc]initWithFrame:CGRectMake(100, 100, 100, 100)];
    button.backgroundColor = [UIColor yellowColor];
    [button addTarget:self action:@selector(hit:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    
    UIButton *button2 = [[UIButton alloc]initWithFrame:CGRectMake(210, 100, 100, 100)];
    button2.backgroundColor = [UIColor redColor];
    [button2 addTarget:self action:@selector(stop:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button2];
    
}

- (NSInteger)DownloadLength {
    NSNumber *size = [MTFileManager sizeOfFileAtPath:self.filePath];
    if (size) {
        return [size integerValue];
    } else {
        return 0;
    }
}

- (void)hit:(UIButton *)button {
    //1.是否已经下载完成
    NSInteger total = [[MTFileManager readFileAtPathAsDictionary:TotalLengthFile][self.fileName] integerValue];
    if (total && total == self.DownloadLength) {
        NSLog(@"下载完成");
        return;
    }

    if (!self.download) {
        //2.请求
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.fileURL];
        //设置请求头
        NSString *range = [NSString stringWithFormat:@"bytes=%zd-",self.DownloadLength];
        [request setValue:range forHTTPHeaderField:@"Range"];
        
        //3.下载
        NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                                              delegate:self
                                                         delegateQueue:[NSOperationQueue new]];
        
        self.download = [session dataTaskWithRequest:request];
    }

    [self.download resume];
}

- (void)stop:(UIButton *)button {
    [self.download suspend];
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    //
    [self.stream open];
    //
//    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
//    NSLog(@"%@",httpResponse);
    self.TotalLength = response.expectedContentLength;
    NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithDictionary:[MTFileManager readFileAtPathAsDictionary:TotalLengthFile]];
    if (!dic) {
        dic = [NSMutableDictionary new];
    }
    NSLog(@"%ld",(long)self.TotalLength);
    dic[self.fileName] = @(self.TotalLength);
    [MTFileManager createFileAtPath:TotalLengthFile withContent:dic overwrite:true error:nil];
    
    // 接收这个请求，允许接收服务器的数据
    completionHandler(NSURLSessionResponseAllow);
}

-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    [self.stream write:data.bytes maxLength:data.length];
    
    float progress = 1.0 * self.DownloadLength / self.TotalLength;
    
    NSLog(@"%f",progress);
}

-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    [self.stream close];
    if (error) {
        NSLog(@"error:%@",error);
    } else {
        NSLog(@"%@",self.filePath);
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
