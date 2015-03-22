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
#import "MKOFileLocator.h"

@class MKONearbyFileRequest;
@class MKONearbyFileRequestOperation;

///--------------------------------------
/// @name Definitions
///--------------------------------------

typedef NS_ENUM(NSUInteger, MKONearbyFileRequestOperationType){
    MKONearbyFileRequestOperationTypeUpload = 0,
    MKONearbyFileRequestOperationTypeDownload = 1
};

/**
 *  The progress callback that will be called if there's any progress activity during an upload or download.
 *
 *  @param fileRequest   The file request object, that called this block.
 *  @param fileName      The name of the file that is either uploaded or downloaded.
 *  @param progress      The current progress.
 *  @param indeterminate Indicates if the progress is currently indeterminate.
 */
typedef void(^MKOProgressBlock)(MKONearbyFileRequestOperation *operation, float progress);

/**
 *  The completion callback that will be called if the download or upload operation has finished.
 *
 *  @param fileRequest The file request object, that called this block.
 *  @param fileName    The name of the file that is either uploaded or downloaded.
 *  @param url         The url pointing to a file that was uploaded or downloaded.
 *  @param error       Indicates that the operation was not successful.
 */
typedef void(^MKOCompletionBlock)(MKONearbyFileRequestOperation *operation, NSURL *url, NSError *error);

/**
 *  The permission callback that will be called
 *
 *  @param fileRequest <#fileRequest description#>
 *  @param fileName    <#fileName description#>
 *
 *  @return <#return value description#>
 */
typedef BOOL(^MKOPermissionBlock)(MKONearbyFileRequestOperation *operation, NSString *fileUUID);


///--------------------------------------
/// @name MKONearbyFileRequestOperation
///--------------------------------------

@interface MKONearbyFileRequestOperation : NSObject
@property (nonatomic, readonly) MKONearbyFileRequestOperationType type;
@property (nonatomic, strong, readonly) NSString *remotePeer;
@property (nonatomic, strong, readonly) NSString *fileUUID;
@property (nonatomic, strong, readonly) NSError *error;
@property (nonatomic, readonly) float progress;
- (void)cancel;
- (BOOL)isRunning;
@end


///--------------------------------------
/// @name MKONearbyFileRequest
///--------------------------------------

@interface MKONearbyFileRequest : NSObject
@property (nonatomic, strong, readonly) NSString *displayName;
@property (nonatomic, strong, readonly) id<MKOFileLocator> fileLocator;

/**
 *  Designated initializer.
 *
 *  @param displayName <#displayName description#>
 *  @param fileLocator <#fileLocator description#>
 *
 *  @return <#return value description#>
 */
- (id)initWithDisplayName:(NSString *)displayName fileLocator:(id<MKOFileLocator>)fileLocator;

- (void)setUploadProgressBlock:(MKOProgressBlock)block;
- (void)setUploadCompletionBlock:(MKOCompletionBlock)block;
- (void)setUploadPermissionBlock:(MKOPermissionBlock)block;

- (void)startRequestListener;
- (void)stopRequestListener;

- (MKONearbyFileRequestOperation *)requestFile:(NSString *)uuid progress:(MKOProgressBlock)progress completion:(MKOCompletionBlock)completion;
@end
