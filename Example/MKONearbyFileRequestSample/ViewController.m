//
//  ViewController.m
//  MKONearbyFileRequestSample
//
//  Created by Mathias Köhnke on 17/03/15.
//  Copyright (c) 2015 Mathias Koehnke. All rights reserved.
//

#import "ViewController.h"
#import "MKONearbyFileRequest.h"
#import "MKOBundleFileLocator.h"

static NSString * const kFileUUID = @"image-123456789.png";

@interface ViewController ()
@property (nonatomic, strong) MKOProgressBlock progressBlock;
@property (nonatomic, strong) MKOCompletionBlock completionBlock;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString *displayName = [NSString stringWithFormat:@"User %d", arc4random() % 1000];
    MKOBundleFileLocator *fileLocator = [MKOBundleFileLocator new];
    [self setFileRequest:[[MKONearbyFileRequest alloc] initWithDisplayName:displayName fileLocator:fileLocator]];
    [self.fileRequest setUploadProgressBlock:[self progressBlock]];
    [self.fileRequest setUploadCompletionBlock:[self completionBlock]];
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
    [self.imageView setImage:nil];
    [self setProgressIndeterminate:YES];
    [self setProgressHidden:NO];
    [self.fileRequest requestNearbyFileWithUUID:kFileUUID progress:[self progressBlock] completion:[self completionBlock]];
    [self setButtonIdle:NO];
}

- (void)didTouchCancelButton
{
    //[self.fileRequest cancelRequest];
    [self setProgressHidden:YES];
    [self setButtonIdle:YES];
    [self.sendButton setEnabled:YES];
}

- (void)setProgressHidden:(BOOL)hidden
{
    [self.progressLabel setHidden:hidden];
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

#pragma mark - MKONearbyFileRequest Callbacks

- (MKOProgressBlock)progressBlock
{
    if (!_progressBlock) {
        ViewController * __weak weakSelf = self;
        _progressBlock = ^void(MKONearbyFileRequestOperation *operation, float progress, BOOL indeterminate) {
            if (progress == 0.0) {
                [weakSelf setProgressHidden:NO];
                [weakSelf setProgressIndeterminate:NO];
                //[weakSelf.sendButton setEnabled:fileRequest.state == MKONearbyFileRequestStateDownloading];
                //[weakSelf.sendButton setBackgroundColor:(fileRequest.state == MKONearbyFileRequestStateDownloading) ? weakSelf.view.tintColor : [UIColor lightGrayColor]];
            } else {
                weakSelf.progressView.progress = progress;
                weakSelf.progressLabel.text = [NSString stringWithFormat:@"%.01f%%", progress * 100];
            }
        };
    }
    return _progressBlock;
}

- (MKOCompletionBlock)completionBlock
{
    if (!_completionBlock) {
        ViewController * __weak weakSelf = self;
        _completionBlock =  ^void(MKONearbyFileRequestOperation *operation, NSURL *url, NSError *error) {
            [weakSelf setProgressHidden:YES];
            [weakSelf setButtonIdle:YES];
            [weakSelf.sendButton setEnabled:YES];
            
            if (error == nil) {
                if (operation.type == MKONearbyFileRequestOperationTypeDownload) {
                    NSData *data = [[NSFileManager defaultManager] contentsAtPath:[url path]];
                    UIImage *image = [UIImage imageWithData:data];
                    [weakSelf.imageView setImage:image];
                    [weakSelf.progressView setProgress:0];
                }
            } else {
                [weakSelf showError:error];
            }
        };
    }
    return _completionBlock;
}

#pragma mark - Helper

- (void)showError:(NSError *)error
{
    NSString *message = [NSString stringWithFormat:@"Could not transmit file: %@", error];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
    [alert show];
}

@end
