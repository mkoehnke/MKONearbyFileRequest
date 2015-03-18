//
//  MKONearbyFileRequest.m
//  MKOMultipeerFileRequest
//
//  Created by Mathias Köhnke on 16/03/15.
//  Copyright (c) 2015 Mathias Koehnke. All rights reserved.
//

#import "MKONearbyFileRequest.h"
#import <MultipeerConnectivity/MultipeerConnectivity.h>

static NSString *kServiceType = @"mko-filerequest";
static NSString *kDiscoveryMetaKeyType = @"discovery-type";
static NSString *kDiscoveryMetaKeyTypeTransmission = @"discovery-type-transmission";
static NSString *kDiscoveryMetaKeyUUID = @"discovery-uuid";

static NSString *kProgressKeyPath = @"progress.fractionCompleted";

typedef void(^MKOAskPermissionBlock)(BOOL granted);

typedef NS_ENUM(NSUInteger, MKONearbyFileRequestRole){
    MKONearbyFileRequestRoleHost = 0,
    MKONearbyFileRequestRoleRequester = 1
};

@interface MKONearbyFileRequest () <MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate, UIAlertViewDelegate>
@property (nonatomic, strong) MCPeerID *peerID;
@property (nonatomic, strong) MCSession *session;
@property (nonatomic, strong) MCNearbyServiceAdvertiser *advertiser;
@property (nonatomic, strong) MCNearbyServiceBrowser *browser;

@property (nonatomic, strong) id<MKOFileLocator> fileLocator;
@property (nonatomic) MKONearbyFileRequestState state;
@property (nonatomic) MKONearbyFileRequestRole role;

@property (nonatomic, strong) NSMutableDictionary *discoveryInfos;
@property (nonatomic, strong) NSProgress *progress;

@property (nonatomic, strong) NSMutableArray *permissionCompletionBlocks;

@property (nonatomic, strong) MKOProgressBlock downloadProgressBlock;
@property (nonatomic, strong) MKOCompletionBlock downloadCompletionBlock;

@property (nonatomic, strong) MKOProgressBlock uploadProgressBlock;
@property (nonatomic, strong) MKOCompletionBlock uploadCompletionBlock;
@property (nonatomic, strong) MKOPermissionBlock uploadPermissionBlock;

@property (nonatomic, getter=isCancelling) BOOL cancelling;
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
        
        _discoveryInfos = [NSMutableDictionary dictionary];
        _permissionCompletionBlocks = [NSMutableArray array];
        
        _role = MKONearbyFileRequestRoleHost;
    }
    return self;
}

- (void)startRequestListener {
    
    //TODO move observer methods
    
    [self addObserver:self forKeyPath:kProgressKeyPath options:0 context:nil];
    [self.browser startBrowsingForPeers];
}

- (void)stopRequestListener {
    [self.browser stopBrowsingForPeers];
    [self removeObserver:self forKeyPath:kProgressKeyPath];
}

- (void)startAdvertiser {
    [self setAdvertiser:[[MCNearbyServiceAdvertiser alloc] initWithPeer:self.peerID discoveryInfo:self.discoveryInfos[self.peerID] serviceType:kServiceType]];
    [self.advertiser setDelegate:self];
    [self.advertiser startAdvertisingPeer];
}

- (void)stopAdvertiser {
    [self.advertiser stopAdvertisingPeer];
    [self.advertiser setDelegate:nil];
    [self setAdvertiser:nil];
}

- (void)requestNearbyFileWithUUID:(NSString *)uuid progress:(MKOProgressBlock)progress completion:(MKOCompletionBlock)completion {
    NSParameterAssert(completion != nil);
    if (self.downloadCompletionBlock || [self.session.connectedPeers count] != 0) {
        NSLog(@"Cannot start request for nearby file. There are peers connected or already a request in progress.");
        return;
    }
    [self setCancelling:NO];
    [self setRole:MKONearbyFileRequestRoleRequester];
    [self setDownloadProgressBlock:progress];
    [self setDownloadCompletionBlock:completion];
    [self.discoveryInfos setObject:@{kDiscoveryMetaKeyType : kDiscoveryMetaKeyTypeTransmission, kDiscoveryMetaKeyUUID : uuid} forKey:self.peerID];
    [self startAdvertiser];
}

- (void)cancelRequest {
    [self setCancelling:YES];
    [self stopAdvertiser];
    NSString *uuid = self.discoveryInfos[self.peerID][kDiscoveryMetaKeyUUID];
    [self finishDownloadWithURL:nil uuid:uuid peerID:[self.session.connectedPeers firstObject] error:nil];
    [self.session disconnect];
}

- (BOOL)requestInProgress {
    return self.discoveryInfos != nil;
}

#pragma mark - Advertiser

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didNotStartAdvertisingPeer:(NSError *)error {
    [self cancelRequest];
    NSString *uuid = self.discoveryInfos[self.peerID][kDiscoveryMetaKeyUUID];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.downloadCompletionBlock(self, uuid, nil, error);
    });
}

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID
       withContext:(NSData *)context invitationHandler:(void (^)(BOOL accept, MCSession *session))invitationHandler {
    NSDictionary *discoveryInfo = [NSKeyedUnarchiver unarchiveObjectWithData:context];
    if (self.advertiser && [discoveryInfo isEqualToDictionary:self.discoveryInfos[self.peerID]]) {
        NSLog(@"Found peer %@ for downloading file with UUID: %@", peerID.displayName, discoveryInfo[kDiscoveryMetaKeyUUID]);
        invitationHandler(YES, self.session);
        [self stopAdvertiser];
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
            self.uploadCompletionBlock(self, nil, nil, error);
        });
    }
}

- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary *)info {
    NSLog(@"Found peer: %@ with info: %@", peerID.displayName, info);
    if (self.role == MKONearbyFileRequestRoleHost && [info[kDiscoveryMetaKeyType] isEqualToString:kDiscoveryMetaKeyTypeTransmission]) {
        NSLog(@"DiscoveryType: Transmission");
        
        NSString *uuid = info[kDiscoveryMetaKeyUUID];
        NSLog(@"Lookup file with uuid: %@", uuid);
        BOOL fileExists = [self.fileLocator fileExists:uuid];
        NSLog(@"File exists: %d", fileExists);
        
        if (fileExists) {
            void(^accessHandler)(BOOL accept) = ^(BOOL accept) {
                if (accept) {
                    self.discoveryInfos[peerID] = info;
                    NSData *context = [NSKeyedArchiver archivedDataWithRootObject:info];
                    [self.browser invitePeer:peerID toSession:self.session withContext:context timeout:30.];
                }
            };
            NSLog(@"Asking User for permission");
            if (self.uploadPermissionBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    BOOL granted = self.uploadPermissionBlock(self, uuid);
                    accessHandler(granted);
                });
            } else {
                [self askPermissionForPeer:peerID info:info completion:accessHandler];
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
        if (self.role == MKONearbyFileRequestRoleHost) {
            /** Sending file to connected Peer **/
            NSString *uuid = self.discoveryInfos[peerID][kDiscoveryMetaKeyUUID];
            NSURL *fileToSend = [self.fileLocator fileWithUUID:uuid];
            [self setState:MKONearbyFileRequestStateUploading];
            
            if (self.uploadProgressBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.uploadProgressBlock(self, uuid, 0., YES);
                });
            }
            self.progress = [self.session sendResourceAtURL:fileToSend withName:uuid toPeer:peerID withCompletionHandler:^(NSError *error) {
                [self finishUploadWithURL:fileToSend uuid:uuid peerID:peerID error:error];
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

- (void)finishUploadWithURL:(NSURL *)url uuid:(NSString *)uuid peerID:(MCPeerID *)peerID error:(NSError *)error {
    /** Prevent this to be double-called in case of a race condition **/
    if (self.progress) { // -> TODO multiple progress instances necessary
        [self setProgress:nil];
        NSLog(@"Sending completed: %@", error);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.uploadCompletionBlock) {
                self.uploadCompletionBlock(self, uuid, url, error);
            }
            [self setState:MKONearbyFileRequestStateIdle];
            [self.discoveryInfos removeObjectForKey:peerID];
            [self setCancelling:NO];
        });
    }
}

- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress {
    NSLog(@"didStartReceivingResourceWithName: %@ from peer: %@", resourceName, peerID.displayName);
    [self setProgress:progress];
    [self setState:MKONearbyFileRequestStateDownloading];
    if (self.downloadProgressBlock) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.downloadProgressBlock(self, resourceName, 0., YES);
        });
    }
}

- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error {
    NSLog(@"didFinishReceivingResourceWithName: %@ from peer: %@", resourceName, peerID.displayName);
    [self.session disconnect];
    [self finishDownloadWithURL:localURL uuid:resourceName peerID:peerID error:error];
}

- (void)finishDownloadWithURL:(NSURL *)url uuid:(NSString *)uuid peerID:(MCPeerID *)peerID error:(NSError *)error {
    if (self.progress) {
        [self setProgress:nil];
        __block MKOCompletionBlock completion = self.downloadCompletionBlock;
        [self setDownloadCompletionBlock:nil];
        [self setDownloadProgressBlock:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(self, uuid, url, (self.isCancelling) ? nil : error);
            completion = nil;
            [self setState:MKONearbyFileRequestStateIdle];
        });
        [self.discoveryInfos removeAllObjects];
        [self setRole:MKONearbyFileRequestRoleHost];
        [self setCancelling:NO];
    }
}

- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID { }
- (void)session:(MCSession *)session didReceiveCertificate:(NSArray *)certificate
       fromPeer:(MCPeerID *)peerID certificateHandler:(void (^)(BOOL))certificateHandler { certificateHandler(YES); }
- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID { }

#pragma mark - Helper Methods

- (void)askPermissionForPeer:(MCPeerID *)peerID info:(NSDictionary *)info completion:(MKOAskPermissionBlock)completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        @synchronized (_permissionCompletionBlocks) {
            [_permissionCompletionBlocks addObject:completion];
        }
        NSString *message = [NSString stringWithFormat:@"%@ would like to download\n%@\nfrom your device.", peerID.displayName, info[kDiscoveryMetaKeyUUID]];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Upload File" message:message delegate:self cancelButtonTitle:@"Don't allow" otherButtonTitles:@"Allow", nil];
        [alert show];
    });
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    @synchronized(_permissionCompletionBlocks) {
        MKOAskPermissionBlock completion = [self.permissionCompletionBlocks firstObject];
        completion(buttonIndex == 1);
        [self.permissionCompletionBlocks removeObjectAtIndex:0];
        completion = nil;
    }
}

#pragma mark - Progress

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:kProgressKeyPath]) {
        if (self.isCancelling == NO) {
            NSLog(@"fractionCompleted: %f", self.progress.fractionCompleted);
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *uuid = self.discoveryInfos[self.peerID][kDiscoveryMetaKeyUUID];
                if (self.downloadProgressBlock) {
                    self.downloadProgressBlock(self, uuid, self.progress.fractionCompleted, self.progress.indeterminate);
                } else if (self.uploadProgressBlock) {
                    self.uploadProgressBlock(self, uuid, self.progress.fractionCompleted, self.progress.indeterminate);
                }
            });
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
