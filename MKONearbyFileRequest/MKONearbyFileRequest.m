//
//  MKONearbyFileRequest.m
//  MKOMultipeerFileRequest
//
//  Created by Mathias Köhnke on 16/03/15.
//  Copyright (c) 2015 Mathias Koehnke. All rights reserved.
//

#import "MKONearbyFileRequest.h"
#import <MultipeerConnectivity/MultipeerConnectivity.h>

typedef void(^MKOAskPermissionBlock)(BOOL granted);


static NSString *kServiceType = @"mko-filerequest";
static NSString *kDiscoveryMetaKeyType = @"discovery-type";
static NSString *kDiscoveryMetaKeyTypeTransmission = @"discovery-type-transmission";
static NSString *kDiscoveryMetaKeyUUID = @"discovery-uuid";

static NSString *kProgressKeyPath = @"progress.fractionCompleted";

///--------------------------------------------------
/// @name MKONearbyFileRequestOperation
///--------------------------------------------------

@interface MKONearbyFileRequestOperation ()
@property (nonatomic) MKONearbyFileRequestOperationType type;
@property (nonatomic, weak) MCPeerID *localPeerID;
@property (nonatomic, strong) MCPeerID *remotePeerID;
@property (nonatomic, strong) NSString *fileUUID;
@property (nonatomic, strong) NSError *error;
@property (nonatomic) NSProgress *progress;
@property (nonatomic, strong) MKOProgressBlock progressBlock;
@property (nonatomic, strong) MKOCompletionBlock completionBlock;
@property (nonatomic, strong) MCNearbyServiceAdvertiser *advertiser;
@property (nonatomic, weak) id<MCNearbyServiceAdvertiserDelegate> advertiserDelegate;
@property (nonatomic, getter=isRunning) BOOL running;
- (void)start;
- (void)finish;
- (void)cancel;
@end

@implementation MKONearbyFileRequestOperation
- (void)start {
    [self addObserver:self forKeyPath:kProgressKeyPath options:0 context:nil];
    [self setRunning:YES];
    if (self.type == MKONearbyFileRequestOperationTypeDownload) {
        [self startAdvertiser];
    }
}

- (void)finish {
    [self removeObserver:self forKeyPath:kProgressKeyPath];
    [self setRunning:NO];
}

- (void)cancel {
    [self removeObserver:self forKeyPath:kProgressKeyPath];
    [self setRunning:NO];
    if (self.type == MKONearbyFileRequestOperationTypeDownload) {
        [self stopAdvertiser];
    }
}

- (void)cleanup {
    [self removeObserver:self forKeyPath:kProgressKeyPath];
    [self setCompletionBlock:nil];
    [self setProgressBlock:nil];
    [self setProgress:nil];
}

- (NSString *)remotePeer {
    return self.remotePeerID.displayName;
}

- (NSDictionary *)discoveryInfo
{
    return @{kDiscoveryMetaKeyType : kDiscoveryMetaKeyTypeTransmission,
             kDiscoveryMetaKeyUUID : self.fileUUID};
}

#pragma mark - Advertiser

- (void)startAdvertiser {
    [self setAdvertiser:[[MCNearbyServiceAdvertiser alloc] initWithPeer:self.localPeerID discoveryInfo:self.discoveryInfo serviceType:kServiceType]];
    [self.advertiser setDelegate:self.advertiserDelegate];
    [self.advertiser startAdvertisingPeer];
}

- (void)stopAdvertiser {
    [self.advertiser stopAdvertisingPeer];
    [self.advertiser setDelegate:nil];
    [self setAdvertiser:nil];
}

- (BOOL)isAdvertising {
    return self.advertiser != nil;
}

#pragma mark - Progress

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:kProgressKeyPath]) {
        NSLog(@"fractionCompleted: %f", self.progress.fractionCompleted);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.progressBlock) {
                self.progressBlock(self, self.progress.fractionCompleted, self.progress.indeterminate);
            }
        });
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end


///--------------------------------------------------
/// @name MKONearbyFileRequestOperationQueue
///--------------------------------------------------

// Notes
// während ein download in progress ist, kann kein upload durchgeführt werden -> !!Browser ausschalten!!
// wenn kein download in progress ist, können mehrere uploads gleichzeitig durchgeführt werden

@interface MKONearbyFileRequestOperationQueue : NSObject
@property (nonatomic, strong) NSMutableArray *operations;
@property (nonatomic, strong) NSTimer *operationTimer;
- (BOOL)addOperation:(MKONearbyFileRequestOperation *)operation;
- (BOOL)removeOperation:(MKONearbyFileRequestOperation *)operation;
- (NSArray *)operationsInQueue:(MKONearbyFileRequestOperationType)type;
- (NSArray *)operationsNotStarted:(MKONearbyFileRequestOperationType)type;
@end

@implementation MKONearbyFileRequestOperationQueue
- (instancetype)init {
    self = [super init];
    if (self) {
        _operations = [NSMutableArray array];
    }
    return self;
}

- (BOOL)addOperation:(MKONearbyFileRequestOperation *)operation {
    @synchronized (_operations) {
        if ([self canRun:operation]) {
            [_operations addObject:operation];
            return YES;
        }
        return NO;
    }
}

- (BOOL)removeOperation:(MKONearbyFileRequestOperation *)operation {
    @synchronized (_operations) {
        if (operation) {
            [_operations removeObject:operation];
            return YES;
        }
        return NO;
    }
}

- (NSArray *)operationsInQueue:(MKONearbyFileRequestOperationType)type {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"type == %d", type];
    return [self.operations filteredArrayUsingPredicate:predicate];
}

- (NSArray *)operationsInProgress:(MKONearbyFileRequestOperationType)type {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"isRunning == %d AND type == %d", YES, type];
    return [self.operations filteredArrayUsingPredicate:predicate];
}

- (NSArray *)operationsNotStarted:(MKONearbyFileRequestOperationType)type {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"isRunning == %d AND type == %d", NO, type];
    return [self.operations filteredArrayUsingPredicate:predicate];
}

- (MKONearbyFileRequestOperation *)operationWithPeerID:(MCPeerID *)peerID {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"remotePeerID == %@", peerID];
    return [[self.operations filteredArrayUsingPredicate:predicate] firstObject];
}

- (BOOL)canRun:(MKONearbyFileRequestOperation *)operation
{
    if (operation.type == MKONearbyFileRequestOperationTypeDownload) {
        return [self operationsInQueue:MKONearbyFileRequestOperationTypeUpload].count == 0;
    } else if (operation.type == MKONearbyFileRequestOperationTypeUpload) {
        return ([self operationsInQueue:MKONearbyFileRequestOperationTypeDownload].count == 0 &&
                [self operationWithPeerID:operation.remotePeerID] == nil);
    }
    return NO;
}

- (void)downloadOperationTimerFired:(NSTimer *)timer {
    if ([self operationsInProgress:MKONearbyFileRequestOperationTypeDownload].count == 0 &&
        [self operationsInQueue:MKONearbyFileRequestOperationTypeDownload].count > 0) {
        MKONearbyFileRequestOperation *operationToStart = [self operationsNotStarted:MKONearbyFileRequestOperationTypeDownload].firstObject;
        [operationToStart start];
    }
}

- (void)startObserver {
    _operationTimer = [NSTimer scheduledTimerWithTimeInterval:5.
        target:self selector:@selector(downloadOperationTimerFired:) userInfo:nil repeats:YES];
}

- (void)stopObserver {
    [self.operationTimer invalidate];
    [self setOperationTimer:nil];
}

@end


///--------------------------------------------------
/// @name MKONearbyFileRequest
///--------------------------------------------------

@interface MKONearbyFileRequest () <MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate, UIAlertViewDelegate>
@property (nonatomic, strong) MCPeerID *peerID;
@property (nonatomic, strong) MCSession *session;
@property (nonatomic, strong) MCNearbyServiceBrowser *browser;

@property (nonatomic, strong) id<MKOFileLocator> fileLocator;
@property (nonatomic, strong) MKONearbyFileRequestOperationQueue *operationQueue;

@property (nonatomic, strong) MKOProgressBlock uploadProgressBlock;
@property (nonatomic, strong) MKOCompletionBlock uploadCompletionBlock;
@property (nonatomic, strong) MKOPermissionBlock uploadPermissionBlock;

@property (nonatomic, strong) NSMutableArray *askPermissionCompletionBlocks;
@end

@implementation MKONearbyFileRequest

- (id)init {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Must use initWithDisplayName instead." userInfo:nil];
}

- (id)initWithDisplayName:(NSString *)displayName fileLocator:(id<MKOFileLocator>)fileLocator {
    self = [super init];
    if (self) {
        _peerID = [[MCPeerID alloc] initWithDisplayName:displayName];
        _session = [[MCSession alloc] initWithPeer:_peerID];
        _session.delegate = self;
        
        _browser = [[MCNearbyServiceBrowser alloc] initWithPeer:self.peerID serviceType:kServiceType];
        _browser.delegate = self;
        
        _fileLocator = fileLocator;
        _operationQueue = [MKONearbyFileRequestOperationQueue new];
        _askPermissionCompletionBlocks = [NSMutableArray array];
    }
    return self;
}

- (void)startRequestListener {
    [self.operationQueue startObserver];
    [self.browser startBrowsingForPeers];
}

- (void)stopRequestListener {
    [self.operationQueue stopObserver];
    [self.browser stopBrowsingForPeers];
}

- (MKONearbyFileRequestOperation *)requestNearbyFileWithUUID:(NSString *)uuid progress:(MKOProgressBlock)progress completion:(MKOCompletionBlock)completion {
    NSParameterAssert(completion != nil);

    MKONearbyFileRequestOperation *downloadOperation = [MKONearbyFileRequestOperation new];
    downloadOperation.type = MKONearbyFileRequestOperationTypeDownload;
    downloadOperation.fileUUID = uuid;
    downloadOperation.progressBlock = progress;
    downloadOperation.completionBlock = completion;
    downloadOperation.advertiserDelegate = self;
    downloadOperation.localPeerID = self.peerID;
    if ([self.operationQueue addOperation:downloadOperation] == NO) {
        NSError *error = [NSError errorWithDomain:@"de.mathiaskoehnke.filerequest" code:999
                                         userInfo:@{NSLocalizedDescriptionKey : @"Could not start request."}];
        [downloadOperation setError:error];
        dispatch_async(dispatch_get_main_queue(), ^{
            downloadOperation.completionBlock(downloadOperation, nil, downloadOperation.error);
            [downloadOperation cleanup];
        });
    }
    return downloadOperation;
}

- (MKONearbyFileRequestOperation *)currentDownloadOperation {
    return [self.operationQueue operationsInProgress:MKONearbyFileRequestOperationTypeDownload].firstObject;
}

#pragma mark - Advertiser

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didNotStartAdvertisingPeer:(NSError *)error {
    MKONearbyFileRequestOperation *currentDownloadOperation = [self currentDownloadOperation];
    [currentDownloadOperation setError:error];
    [currentDownloadOperation cancel];
    dispatch_async(dispatch_get_main_queue(), ^{
        currentDownloadOperation.completionBlock(currentDownloadOperation, nil, currentDownloadOperation.error);
        [currentDownloadOperation cleanup];
        [self.operationQueue removeOperation:currentDownloadOperation];
    });
}

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID
       withContext:(NSData *)context invitationHandler:(void (^)(BOOL accept, MCSession *session))invitationHandler {
    MKONearbyFileRequestOperation *currentDownloadOperation = [self currentDownloadOperation];
    NSDictionary *discoveryInfo = [NSKeyedUnarchiver unarchiveObjectWithData:context];
    if ([currentDownloadOperation isAdvertising] && [currentDownloadOperation.discoveryInfo isEqualToDictionary:discoveryInfo]) {
        NSLog(@"Found peer %@ for downloading file with UUID: %@", peerID.displayName, discoveryInfo[kDiscoveryMetaKeyUUID]);
        currentDownloadOperation.remotePeerID = peerID;
        [currentDownloadOperation stopAdvertiser];
        invitationHandler(YES, self.session);
    } else {
        invitationHandler(NO, nil);
    }
}

#pragma mark - Browser

- (void)browser:(MCNearbyServiceBrowser *)browser didNotStartBrowsingForPeers:(NSError *)error {
    NSLog(@"Could not start browsing for peers: %@", [error localizedDescription]);
    [self stopRequestListener];
    if (self.uploadCompletionBlock) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.uploadCompletionBlock(nil, nil, error);
        });
    }
}

- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary *)info {
    NSLog(@"Found peer: %@ with info: %@", peerID.displayName, info);
    if ([info[kDiscoveryMetaKeyType] isEqualToString:kDiscoveryMetaKeyTypeTransmission]) {
        NSLog(@"DiscoveryType: Transmission");
        
        NSString *uuid = info[kDiscoveryMetaKeyUUID];
        NSLog(@"Lookup file with uuid: %@", uuid);
        BOOL fileExists = [self.fileLocator fileExists:uuid];
        NSLog(@"File exists: %d", fileExists);
        
        if (fileExists) {
            MKONearbyFileRequestOperation *uploadOperation = [MKONearbyFileRequestOperation new];
            uploadOperation.type = MKONearbyFileRequestOperationTypeUpload;
            uploadOperation.fileUUID = uuid;
            uploadOperation.remotePeerID = peerID;
            uploadOperation.progressBlock = self.uploadProgressBlock;
            uploadOperation.completionBlock = self.uploadCompletionBlock;
            
            void(^accessHandler)(BOOL accept) = ^(BOOL accept) {
                if (accept && [self.operationQueue addOperation:uploadOperation]) {
                    [uploadOperation start];
                    NSData *context = [NSKeyedArchiver archivedDataWithRootObject:uploadOperation.discoveryInfo];
                    [self.browser invitePeer:peerID toSession:self.session withContext:context timeout:30.];
                }
            };
            NSLog(@"Asking User for permission");
            if (self.uploadPermissionBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    BOOL granted = self.uploadPermissionBlock(uploadOperation, uuid);
                    accessHandler(granted);
                });
            } else {
                [self askForPermission:uploadOperation completion:accessHandler];
            }
        }
    }
}

- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID {
    NSLog(@"Peer lost: %@", peerID.displayName);

    //TODO handle browser loses peer -> check if peer was connected
    
    //TODO cancelling state -> multiple peers
}


#pragma mark - Session

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
    if (state == MCSessionStateConnected) {
        NSLog(@"Peer %@ did connect to session.", peerID.displayName);
        MKONearbyFileRequestOperation *uploadOperation = [self.operationQueue operationWithPeerID:peerID];
        if (uploadOperation.type == MKONearbyFileRequestOperationTypeUpload) {
            
            /** Sending file to connected Peer **/
            NSURL *fileToSend = [self.fileLocator fileWithUUID:uploadOperation.fileUUID];
            
            if (self.uploadProgressBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.uploadProgressBlock(uploadOperation, 0., YES);
                });
            }
            uploadOperation.progress = [self.session sendResourceAtURL:fileToSend withName:uploadOperation.fileUUID toPeer:peerID withCompletionHandler:^(NSError *error) {
                NSLog(@"Sending completed: %@", error);
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (self.uploadCompletionBlock) {
                        self.uploadCompletionBlock(uploadOperation, fileToSend, error);
                    }
                    [uploadOperation cleanup];
                });
            }];
        }
    } else if (state == MCSessionStateNotConnected) {
        NSLog(@"Peer %@ did disconnect from session.", peerID.displayName);
        
        // TODO check: only finish upload action if the right peer disconnects
//        if (self.role == MKONearbyFileRequestRoleHost && self.progress.fractionCompleted < 1.) {
//            [self setCancelling:YES];
//            NSLog(@"It seems that peer %@ disconnected before the file was transmitted completely. Aborting ...", peerID.displayName);
//            NSString *uuid = self.discoveryInfos[peerID][kDiscoveryMetaKeyUUID];
//            NSError *error = [NSError errorWithDomain:@"de.mathiaskoehnke.nearbyfilerequest" code:999 userInfo:@{NSLocalizedDescriptionKey : @"Connection to peer lost."}];
//            [self finishUploadWithURL:nil uuid:uuid peerID:peerID error:error];
//        }
    } else if (state == MCSessionStateConnecting) {
        NSLog(@"Peer %@ will connect to session.", peerID.displayName);
    }
}

- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress {
    NSLog(@"didStartReceivingResourceWithName: %@ from peer: %@", resourceName, peerID.displayName);
    MKONearbyFileRequestOperation *currentDownloadOperation = [self currentDownloadOperation];
    currentDownloadOperation.progress = progress;
    if (currentDownloadOperation.progressBlock) {
        dispatch_async(dispatch_get_main_queue(), ^{
            currentDownloadOperation.progressBlock(currentDownloadOperation, 0., YES);
        });
    }
}

- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error {
    NSLog(@"didFinishReceivingResourceWithName: %@ from peer: %@", resourceName, peerID.displayName);
    [self.session disconnect];

    MKONearbyFileRequestOperation *currentDownloadOperation = [self currentDownloadOperation];
    __block MKOCompletionBlock completion = currentDownloadOperation.completionBlock;
    [currentDownloadOperation cleanup];
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(currentDownloadOperation, localURL, error);
        completion = nil;
    });
}

- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID { }
- (void)session:(MCSession *)session didReceiveCertificate:(NSArray *)certificate
       fromPeer:(MCPeerID *)peerID certificateHandler:(void (^)(BOOL))certificateHandler { certificateHandler(YES); }
- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID { }

#pragma mark - Helper Methods

- (void)askForPermission:(MKONearbyFileRequestOperation *)operation completion:(MKOAskPermissionBlock)completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        @synchronized (_askPermissionCompletionBlocks) {
            [_askPermissionCompletionBlocks addObject:completion];
        }
        NSString *message = [NSString stringWithFormat:@"%@ would like to download\n%@\nfrom your device.", operation.remotePeer, operation.fileUUID];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Upload File" message:message delegate:self cancelButtonTitle:@"Don't allow" otherButtonTitles:@"Allow", nil];
        [alert show];
    });
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    @synchronized(_askPermissionCompletionBlocks) {
        MKOAskPermissionBlock completion = [_askPermissionCompletionBlocks firstObject];
        completion(buttonIndex == 1);
        [_askPermissionCompletionBlocks removeObjectAtIndex:0];
        completion = nil;
    }
}

@end





