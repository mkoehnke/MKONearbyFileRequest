//
//  UIAlertController+MKO.m
//  MKONearbyFileRequestSample
//
//  Created by Mathias Köhnke on 24/10/15.
//  Copyright © 2015 Mathias Koehnke. All rights reserved.
//

#import "UIAlertController+MKO.h"
#import <objc/runtime.h>

@interface UIAlertController (Private)
@property (nonatomic, strong) UIWindow *alertWindow;
@end

@implementation UIAlertController (Private)
@dynamic alertWindow;
- (void)setAlertWindow:(UIWindow *)alertWindow {
    objc_setAssociatedObject(self, @selector(alertWindow), alertWindow, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIWindow *)alertWindow {
    return objc_getAssociatedObject(self, @selector(alertWindow));
}
@end


@implementation UIAlertController (MKO)

- (void)show {
    [self show:YES];
}

- (void)show:(BOOL)animated {
    self.alertWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.alertWindow.rootViewController = [[UIViewController alloc] init];
    self.alertWindow.windowLevel = UIWindowLevelAlert + 1;
    [self.alertWindow makeKeyAndVisible];
    [self.alertWindow.rootViewController presentViewController:self animated:animated completion:nil];
}

@end
