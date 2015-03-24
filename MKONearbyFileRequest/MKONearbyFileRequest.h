//
// MKONearbyFileRequest.h
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

#import <Foundation/Foundation.h>
#import "MKOBundleFileLocator.h"

@class MKONearbyFileRequest;
@class MKONearbyFileRequestOperation;

///--------------------------------------
/// @name Definitions
///--------------------------------------

/**
 *  The file request operation type.
 */
typedef NS_ENUM(NSUInteger, MKONearbyFileRequestOperationType){
    /**
     *  File upload operation
     */
    MKONearbyFileRequestOperationTypeUpload = 0,
    /**
     *  File download operation
     */
    MKONearbyFileRequestOperationTypeDownload = 1
};

/**
 *  The progress callback that will be called if there's any progress activity during an upload or download.
 *
 *  @param operation The file request operation instance.
 *  @param progress  The current progress.
 */
typedef void(^MKOProgressBlock)(MKONearbyFileRequestOperation *operation, float progress);

/**
 *  The completion callback that will be called if the download or upload operation has finished.
 *
 *  @param operation The file request operation instance.
 *  @param url       The url that points to the downloaded/uploaded file.
 *  @param error     The object that will be passed if an error occurred.
 */
typedef void(^MKOCompletionBlock)(MKONearbyFileRequestOperation *operation, NSURL *url, NSError *error);

/**
 *  The permission callback that will be called before upload operations in order to determine
 *  if a user is allowed to download a file from the local device.
 *
 *  @param operation The file request operation instance.
 *  @param fileUUID  The unique identifier of the file, that is requested by a remote peer.
 *
 *  @return 'YES' if permission is granted to download the file
 */
typedef BOOL(^MKOPermissionBlock)(MKONearbyFileRequestOperation *operation, NSString *fileUUID);


///--------------------------------------
/// @name MKONearbyFileRequestOperation
///--------------------------------------

/**
 *  This is a base class for all upload and download operations.
 */
@interface MKONearbyFileRequestOperation : NSObject
/**
 *  The operation type.
 */
@property (nonatomic, readonly) MKONearbyFileRequestOperationType type;
/**
 *  The name of the remote peer that is either uploading or downloading a file.
 */
@property (nonatomic, strong, readonly) NSString *remotePeer;
/**
 *  The unique identifier of the file that is supposed to be uploaded or downloaded.
 */
@property (nonatomic, strong, readonly) NSString *fileUUID;
/**
 *  The current upload or download progress of this operation. 
 *  A progress of 0.0 means the upload/download itself has not started yet.
 */
@property (nonatomic, readonly) float progress;
/**
 *  Determines if the operation has been started or not (still in the queue).
 */
@property (nonatomic, readonly) BOOL isRunning;
/**
 *  Cancels this operation and aborts the file upload/download.
 */
- (void)cancel;
@end


///--------------------------------------
/// @name MKONearbyFileRequest
///--------------------------------------

/**
 *  Using this class one is able to simply download a specific file
 *  from a random nearby peer.
 */
@interface MKONearbyFileRequest : NSObject
/**
 *  The display name that identifies the local device to other peers.
 */
@property (nonatomic, strong, readonly) NSString *displayName;
/**
 *  Responsible for finding a specific file by it's unique identifier
 *  on this device.
 */
@property (nonatomic, strong, readonly) id<MKOFileLocator> fileLocator;

/**
 *  Designated initializer.
 *
 *  @param displayName The display name.
 *  @param fileLocator The file descriptor.
 *
 *  @return An instance of the MKONearbyFileRequest class.
 */
- (id)initWithDisplayName:(NSString *)displayName fileLocator:(id<MKOFileLocator>)fileLocator;

/**
 *  If set, this block is called during an upload of a file and informs about it's progress.
 *  If multiple uploads take place at the same time, the progress information will be summarized.
 *
 *  @param block The progress block.
 */
- (void)setUploadProgressBlock:(MKOProgressBlock)block;

/**
 *  If set, this block is called if an upload of a file is completed.
 *  If multiple uploads take place at the same time, the completion block will only called once.
 *
 *  @param block The completion block.
 */
- (void)setUploadCompletionBlock:(MKOCompletionBlock)block;

/**
 *  If set, this block is called when a remote peer wants to download a file that
 *  that is stored on your device. 
 *  It must return 'YES' for access granted, or 'NO' for access denied.
 *
 *  @param block The permission block.
 */
- (void)setUploadPermissionBlock:(MKOPermissionBlock)block;

/**
 *  Starts listening for nearby file requests.
 */
- (void)startRequestListener;

/**
 *  Stops listening for nearby file requests.
 */
- (void)stopRequestListener;

/**
 *  Starts a request to download a file from a nearby peer.
 *
 *  @param uuid       The file unique identifier.
 *  @param progress   The progress block.
 *  @param completion The completion block.
 *
 *  @return The operation that can be used for cancelling or to
 *          query for detailed information.
 */
- (MKONearbyFileRequestOperation *)requestFile:(NSString *)uuid progress:(MKOProgressBlock)progress completion:(MKOCompletionBlock)completion;
@end
