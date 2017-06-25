//
//  ViewController.m
//  KVO
//
//  Created by Stephen on 25/6/17.
//  Copyright © 2017 zake. All rights reserved.
//

#import "ViewController.h"
#import "Car.h"

@interface ViewController ()

@property (nonatomic, strong) Car *car;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.car = [[Car alloc]init];
//    NSLog(@"Before add observer————————————————————————–");
//    [car printCarDetail];
//    [car addObserver:self forKeyPath:@"brand" options:NSKeyValueObservingOptionNew context:nil];
//    NSLog(@"After add observer————————————————————————–");
//    [car printCarDetail];
//    [car removeObserver:self forKeyPath:@"brand"];
//    NSLog(@"After remove observer————————————————————————–");
//    [car printCarDetail];
    
    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(100, 100, 100, 100)];
    button.backgroundColor = [UIColor redColor];
    [button addTarget:self action:@selector(changeName) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    
    [self.car addObserver:self forKeyPath:@"brand" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];
}

//属性发生改变时
- (void)changeName
{
    // this will allow us as an observer to notified
    /*(see observeValueForKeyPath)*/
    // so we can update our UITableView
    [self.car willChangeValueForKey:@"brand"];
//    self.car.brand = @"Ford";
//    _car.brand = @"hehe";
    [self.car didChangeValueForKey:@"brand"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:@"brand"]) {
        NSLog(@"%@",change);
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
