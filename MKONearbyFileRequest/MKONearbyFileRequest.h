//
//  MKONearbyFileRequest.h
//  MKOMultipeerFileRequest
//
//  Created by Mathias Köhnke on 16/03/15.
//  Copyright (c) 2015 Mathias Koehnke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MKOFileLocator.h"

@class MKONearbyFileRequest;

typedef NS_ENUM(NSUInteger, MKONearbyFileRequestState) {
    MKONearbyFileRequestStateIdle = 0,
    MKONearbyFileRequestStateUploading = 1,
    MKONearbyFileRequestStateDownloading = 2
};

@protocol MKONearbyFileRequestDelegate <NSObject>
@optional
- (void)nearbyFileRequest:(MKONearbyFileRequest *)request didStartTransmissionOfFileWithName:(NSString *)fileName peerDisplayName:(NSString *)peerDisplayName;
- (void)nearbyFileRequest:(MKONearbyFileRequest *)request didUpdateTransmissionProgress:(float)progress forFileWithName:(NSString *)fileName;
- (void)nearbyFileRequest:(MKONearbyFileRequest *)request didFinishTransmissionOfFileWithName:(NSString *)fileName url:(NSURL *)url error:(NSError *)error;
- (void)nearbyFileRequest:(MKONearbyFileRequest *)request wantsAccessToFileWithName:(NSString *)fileName accessHandler:(void (^)(BOOL accept))accessHandler;
@end

@interface MKONearbyFileRequest : NSObject
@property (nonatomic, strong, readonly) NSString *displayName;
@property (nonatomic, strong, readonly) id<MKOFileLocator> fileLocator;
@property (nonatomic, readonly) MKONearbyFileRequestState state;
@property (nonatomic, weak) id<MKONearbyFileRequestDelegate> uploadDelegate;

/** Content Provider **/
- (id)initWithDisplayName:(NSString *)displayName
              fileLocator:(id<MKOFileLocator>)fileLocator
           uploadDelegate:(id<MKONearbyFileRequestDelegate>)uploadDelegate;
- (void)startRequestListener;
- (void)stopRequestListener;

/** Content Requester **/
- (void)requestNearbyFileWithUUID:(NSString *)uuid
                 downloadDelegate:(id<MKONearbyFileRequestDelegate>)downloadDelegate;
- (void)cancelRequest;
- (BOOL)requestInProgress;
@end
