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

///-----------------------------------
/// @name Definitions
///-----------------------------------

/**
 *  The state that indicates the current state of the file request.
 */
typedef NS_ENUM(NSUInteger, MKONearbyFileRequestState){
    /**
     *  No Peer is connected and there's no download/upload in progress.
     */
    MKONearbyFileRequestStateIdle = 0,
    /**
     *  There's currently an upload in progress.
     */
    MKONearbyFileRequestStateUploading = 1,
    /**
     *  There's currently an download in progress.
     */
    MKONearbyFileRequestStateDownloading = 2
};

/**
 *  The progress callback that will be called if there's any progress activity during an upload or download.
 *
 *  @param fileRequest   The file request object, that called this block.
 *  @param fileName      The name of the file that is either uploaded or downloaded.
 *  @param progress      The current progress.
 *  @param indeterminate Indicates if the progress is currently indeterminate.
 */
typedef void(^MKOProgressBlock)(MKONearbyFileRequest *fileRequest, NSString *fileName, float progress, BOOL indeterminate);

/**
 *  The completion callback that will be called if the download or upload operation has finished.
 *
 *  @param fileRequest The file request object, that called this block.
 *  @param fileName    The name of the file that is either uploaded or downloaded.
 *  @param url         The url pointing to a file that was uploaded or downloaded.
 *  @param error       Indicates that the operation was not successful.
 */
typedef void(^MKOCompletionBlock)(MKONearbyFileRequest *fileRequest, NSString *fileName, NSURL *url, NSError *error);

/**
 *  The permission callback that will be called
 *
 *  @param fileRequest <#fileRequest description#>
 *  @param fileName    <#fileName description#>
 *
 *  @return <#return value description#>
 */
typedef BOOL(^MKOPermissionBlock)(MKONearbyFileRequest *fileRequest, NSString *fileName);



@interface MKONearbyFileRequest : NSObject

@property (nonatomic, strong, readonly) NSString *displayName;
@property (nonatomic, strong, readonly) id<MKOFileLocator> fileLocator;
@property (nonatomic, readonly) MKONearbyFileRequestState state;


///-----------------------------------
/// @name Hosting methods & callbacks
///-----------------------------------

/**
 *  Designated initializer.
 *
 *  @param displayName <#displayName description#>
 *  @param fileLocator <#fileLocator description#>
 *
 *  @return <#return value description#>
 */
- (id)initWithDisplayName:(NSString *)displayName fileLocator:(id<MKOFileLocator>)fileLocator;

- (void)startRequestListener;
- (void)stopRequestListener;

- (void)setUploadProgressBlock:(MKOProgressBlock)block;
- (void)setUploadCompletionBlock:(MKOCompletionBlock)block;
- (void)setUploadPermissionBlock:(MKOPermissionBlock)block;


///-----------------------------------
/// @name Requesting methods
///-----------------------------------
- (void)requestNearbyFileWithUUID:(NSString *)uuid
                         progress:(MKOProgressBlock)progress
                       completion:(MKOCompletionBlock)completion;
- (void)cancelRequest;
- (BOOL)requestInProgress;

@end
