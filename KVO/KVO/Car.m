//
//  Car.m
//  KVO
//
//  Created by Stephen on 25/6/17.
//  Copyright © 2017 zake. All rights reserved.
//

#import "Car.h"
#import <objc/runtime.h>

@interface Car ()

@end

@implementation Car

- (void)printCarDetail {
    NSLog(@"isa:%@,supperclass:%@",NSStringFromClass(object_getClass(self)), class_getSuperclass(object_getClass(self)));
    NSLog(@"self:%@, [self superclass]:%@", self, [self superclass]);
    NSLog(@"brand setter function pointer:%p", class_getMethodImplementation(object_getClass(self), @selector(setBrand:)));
    NSLog(@"printCarDetail function pointer:%p", class_getMethodImplementation(object_getClass(self), @selector(printCarDetail)));
}

//+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)theKey {
//    
//    BOOL automatic = NO;
//    if ([theKey isEqualToString:@"brand"]) {
//        automatic = NO;
//    }
//    else {
//        automatic = [super automaticallyNotifiesObserversForKey:theKey];
//    }
//    return automatic;
//}

@end
