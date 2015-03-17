//
//  ViewController.m
//  MKONearbyFileRequestSample
//
//  Created by Mathias Köhnke on 17/03/15.
//  Copyright (c) 2015 Mathias Koehnke. All rights reserved.
//

#import "ViewController.h"
#import "MKONearbyFileRequest.h"
#import "MKOStandardFileLocator.h"

@interface ViewController () <MKONearbyFileRequestDelegate>

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString *displayName = [NSString stringWithFormat:@"User %d", arc4random() % 1000];
    MKOStandardFileLocator *fileLocator = [MKOStandardFileLocator new];
    self.fileRequest = [[MKONearbyFileRequest alloc] initWithDisplayName:displayName fileLocator:fileLocator uploadDelegate:self];
    [self.fileRequest startRequestListener];
    
    [self setButtonIdle:YES];
}

- (void)setButtonIdle:(BOOL)idle
{
    NSString *title = (idle) ? @"Download Nearby File" : @"Cancel Download";
    UIColor *backgroundColor = (idle) ? self.view.tintColor : [UIColor redColor];
    SEL action = (idle) ? @selector(didTouchSendButton) : @selector(didTouchCancelButton);
    
    [self.sendButton removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
    [self.sendButton setTitle:title forState:UIControlStateNormal];
    [self.sendButton setBackgroundColor:backgroundColor];
    [self.sendButton addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
}

- (void)didTouchSendButton
{
    NSString *uuid = @"image-123456789.jpeg";
    [self.imageView setImage:nil];
    [self setProgressIndeterminate:YES];
    [self setProgressHidden:NO];
    [self.fileRequest requestNearbyFileWithUUID:uuid downloadDelegate:self];
    [self setButtonIdle:NO];
}

- (void)didTouchCancelButton
{
    NSLog(@"Cancel");
}

- (void)setProgressHidden:(BOOL)hidden
{
    self.progressLabel.hidden = hidden;
    self.progressView.hidden = (hidden) ? YES : self.progressView.hidden;
    self.activityIndicator.hidden = (hidden) ? YES : self.activityIndicator.hidden;
    self.imageView.alpha = hidden ? 1. : .3;
}

- (void)setProgressIndeterminate:(BOOL)indeterminate
{
    self.progressView.hidden = indeterminate;
    self.activityIndicator.hidden = !indeterminate;
    self.progressLabel.text = (indeterminate) ? @"Browsing for Nearby File" : @"0%";
}

#pragma mark - MKONearbyFileRequest Delegate

- (void)nearbyFileRequest:(MKONearbyFileRequest *)request didStartTransmissionOfFileWithName:(NSString *)fileName peerDisplayName:(NSString *)peerDisplayName
{
    [self setProgressHidden:NO];
    [self setProgressIndeterminate:NO];
    [self.sendButton setEnabled:request.state == MKONearbyFileRequestStateDownloading];
    [self.sendButton setBackgroundColor:(request.state == MKONearbyFileRequestStateDownloading) ? self.view.tintColor : [UIColor lightGrayColor]];
}

- (void)nearbyFileRequest:(MKONearbyFileRequest *)request didUpdateTransmissionProgress:(float)progress forFileWithName:(NSString *)fileName
{
    self.progressView.progress = progress;
    self.progressLabel.text = [NSString stringWithFormat:@"%.01f%%", progress * 100];
}

- (void)nearbyFileRequest:(MKONearbyFileRequest *)request didFinishTransmissionOfFileWithName:(NSString *)fileName url:(NSURL *)url error:(NSError *)error
{
    [self setProgressHidden:YES];
    [self setButtonIdle:YES];
    [self.sendButton setEnabled:YES];
    if (request.state == MKONearbyFileRequestStateDownloading && error == nil) {
        NSData *data = [[NSFileManager defaultManager] contentsAtPath:[url path]];
        UIImage *image = [UIImage imageWithData:data];
        [self.imageView setImage:image];
        [self.progressView setProgress:0];
    }
}

@end
