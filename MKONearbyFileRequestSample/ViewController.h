//
//  ViewController.h
//  MKONearbyFileRequestSample
//
//  Created by Mathias Köhnke on 17/03/15.
//  Copyright (c) 2015 Mathias Koehnke. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MKONearbyFileRequest;

@interface ViewController : UIViewController
@property (nonatomic, strong) MKONearbyFileRequest *fileRequest;

@property (nonatomic, weak) IBOutlet UIImageView *imageView;
@property (nonatomic, weak) IBOutlet UIProgressView *progressView;
@property (nonatomic, weak) IBOutlet UILabel *progressLabel;
@property (nonatomic, weak) IBOutlet UIButton *sendButton;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *activityIndicator;
@end

