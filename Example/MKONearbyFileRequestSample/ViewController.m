//
// ViewController.m
//
// Copyright (c) 2015 Mathias Koehnke (http://www.mathiaskoehnke.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "ViewController.h"
#import "MKONearbyFileRequest.h"

static NSString * const kFileUUID           = @"image-123456789.png";

@interface ViewController ()
@property (nonatomic, strong) MKOProgressBlock progressBlock;
@property (nonatomic, strong) MKOCompletionBlock completionBlock;
@property (nonatomic, strong) MKONearbyFileRequestOperation *operation;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString *displayName = [NSString stringWithFormat:@"User %d", arc4random() % 1000];
    MKOBundleFileLocator *fileLocator = [MKOBundleFileLocator new];
    [self setFileRequest:[[MKONearbyFileRequest alloc] initWithDisplayName:displayName fileLocator:fileLocator]];
    [self.fileRequest setUploadProgressBlock:[self progressBlock]];
    [self.fileRequest setUploadCompletionBlock:[self completionBlock]];
    [self setButtonIdle:YES];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.fileRequest startRequestListener];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.fileRequest stopRequestListener];
}

- (void)setButtonIdle:(BOOL)idle {
    NSString *title = (idle) ? @"Download Nearby File" : @"Cancel Download";
    UIColor *backgroundColor = (idle) ? self.view.tintColor : [UIColor redColor];
    SEL action = (idle) ? @selector(didTouchSendButton) : @selector(didTouchCancelButton);
    
    [self.sendButton removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
    [self.sendButton setTitle:title forState:UIControlStateNormal];
    [self.sendButton setBackgroundColor:backgroundColor];
    [self.sendButton addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
}

- (void)didTouchSendButton {
    self.operation = [self.fileRequest requestFile:kFileUUID progress:[self progressBlock] completion:[self completionBlock]];
    if (self.operation) {
        [self addRemotePeerObserverToOperation:self.operation];
        [self.imageView setImage:nil];
        [self setProgressIndeterminate:YES];
        [self setProgressHidden:NO];
        [self setButtonIdle:NO];
    }
}

- (void)didTouchCancelButton {
    [self removeRemotePeerObserverFromOperation:self.operation];
    [self.operation cancel];
    [self setProgressHidden:YES];
    [self setButtonIdle:YES];
    [self.sendButton setEnabled:YES];
}

- (void)setProgressHidden:(BOOL)hidden {
    [self.progressLabel setHidden:hidden];
    self.progressView.hidden = (hidden) ? YES : self.progressView.hidden;
    self.activityIndicator.hidden = (hidden) ? YES : self.activityIndicator.hidden;
    self.imageView.alpha = (hidden) ? (CGFloat)1.0 : (CGFloat)0.3;
}

- (void)setProgressIndeterminate:(BOOL)indeterminate {
    self.progressView.hidden = indeterminate;
    self.activityIndicator.hidden = !indeterminate;
    self.progressLabel.text = (indeterminate) ? @"Browsing for Nearby File" : @"0%";
}

#pragma mark - MKONearbyFileRequest Callbacks

- (MKOProgressBlock)progressBlock {
    if (!_progressBlock) {
        __weak __typeof__(self) weakSelf = self;
        _progressBlock = ^void(MKONearbyFileRequestOperation *operation, float progress) {
            #pragma unused(operation)
            __typeof__(self) strongSelf = weakSelf;
            if (progress > 0. && progress <= 0.1) {
                [strongSelf setProgressHidden:NO];
                [strongSelf setProgressIndeterminate:NO];
            } else {
                strongSelf.progressView.progress = progress;
                strongSelf.progressLabel.text = [NSString stringWithFormat:@"%.01f%%", progress * 100];
            }
        };
    }
    return _progressBlock;
}

- (MKOCompletionBlock)completionBlock {
    if (!_completionBlock) {
        __weak __typeof__(self) weakSelf = self;
        _completionBlock =  ^void(MKONearbyFileRequestOperation *operation, NSURL *url, NSError *error) {
            __typeof__(self) strongSelf = weakSelf;
            [strongSelf setProgressHidden:YES];
            [strongSelf setButtonIdle:YES];
            [strongSelf.sendButton setEnabled:YES];
            [strongSelf removeRemotePeerObserverFromOperation:weakSelf.operation];
            
            if (error == nil) {
                if (operation.type == MKONearbyFileRequestOperationTypeDownload) {
                    NSData *data = [[NSFileManager defaultManager] contentsAtPath:[url path]];
                    UIImage *image = [UIImage imageWithData:data];
                    [strongSelf.imageView setImage:image];
                    [strongSelf.progressView setProgress:0];
                }
            } else {
                [strongSelf showError:error];
            }
        };
    }
    return _completionBlock;
}

#pragma mark - Helper

- (void)showError:(NSError *)error {
    NSString *message = [NSString stringWithFormat:@"Could not transmit file.\n%@", [error localizedDescription]];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Sorry" message:message delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
    [alert show];
}

- (void)addRemotePeerObserverToOperation:(MKONearbyFileRequestOperation *)operation {
    [operation addObserver:self forKeyPath:NSStringFromSelector(@selector(remotePeer)) options:0 context:nil];
}

- (void)removeRemotePeerObserverFromOperation:(MKONearbyFileRequestOperation *)operation {
    @try {
        [operation removeObserver:self forKeyPath:NSStringFromSelector(@selector(remotePeer))];
    }
    @catch (NSException * __unused exception) {}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:NSStringFromSelector(@selector(remotePeer))]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.progressLabel.text = [NSString stringWithFormat:@"Found %@ for downloading file.", self.operation.remotePeer];
        });
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}


@end
