//
//  MKONearbyFileRequest.m
//  MKOMultipeerFileRequest
//
//  Created by Mathias Köhnke on 16/03/15.
//  Copyright (c) 2015 Mathias Koehnke. All rights reserved.
//

#import "MKONearbyFileRequest.h"
#import <MultipeerConnectivity/MultipeerConnectivity.h>

static NSString *kServiceType = @"fileRequest";
static NSString *kDiscoveryMetaKeyType = @"discoveryType";
static NSString *kDiscoveryMetaKeyTypeTransmission = @"transmission";
static NSString *kDiscoveryMetaKeyUUID = @"discoveryUUID";

typedef void(^MKOPermissionCompletionBlock)(BOOL granted);

@interface MKONearbyFileRequest () <MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate, UIAlertViewDelegate>
@property (nonatomic, strong) MCPeerID *peerID;
@property (nonatomic, strong) MCSession *session;
@property (nonatomic, strong) MCNearbyServiceAdvertiser *advertiser;
@property (nonatomic, strong) MCNearbyServiceBrowser *browser;

@property (nonatomic, strong) id<MKOFileLocator> fileLocator;
@property (nonatomic) MKONearbyFileRequestState state;

@property (nonatomic, strong) NSDictionary *currentDiscoveryInfo;
@property (nonatomic, strong) NSProgress *progress;

@property (nonatomic, strong) MKOPermissionCompletionBlock permissionCompletionBlock;

@property (nonatomic, weak) id<MKONearbyFileRequestDelegate> downloadDelegate;
@end

@implementation MKONearbyFileRequest

- (id)init
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"Must use initWithDisplayName instead."
                                 userInfo:nil];
}

- (id)initWithDisplayName:(NSString *)displayName fileLocator:(id<MKOFileLocator>)fileLocator uploadDelegate:(id<MKONearbyFileRequestDelegate>)uploadDelegate
{
    self = [super init];
    if (self) {
        _peerID = [[MCPeerID alloc] initWithDisplayName:displayName];
        _session = [[MCSession alloc] initWithPeer:_peerID];
        _session.delegate = self;
        
        _browser = [[MCNearbyServiceBrowser alloc] initWithPeer:self.peerID serviceType:kServiceType];
        _browser.delegate = self;
        
        _fileLocator = fileLocator;
        _uploadDelegate = uploadDelegate;
    }
    return self;
}

- (void)startRequestListener
{
    [self addObserver:self forKeyPath:@"progress.fractionCompleted" options:0 context:nil];
    [self addObserver:self forKeyPath:@"progress.indeterminate" options:0 context:nil];
    [self.browser startBrowsingForPeers];
}

- (void)stopRequestListener
{
    [self.browser stopBrowsingForPeers];
    [self removeObserver:self forKeyPath:@"progress.fractionCompleted"];
    [self removeObserver:self forKeyPath:@"progress.indeterminate"];
}

- (void)requestNearbyFileWithUUID:(NSString *)uuid downloadDelegate:(id<MKONearbyFileRequestDelegate>)downloadDelegate
{
    self.downloadDelegate = downloadDelegate;
    self.currentDiscoveryInfo = @{kDiscoveryMetaKeyType : kDiscoveryMetaKeyTypeTransmission, kDiscoveryMetaKeyUUID : uuid};
    [self setAdvertiser:[[MCNearbyServiceAdvertiser alloc] initWithPeer:self.peerID discoveryInfo:self.currentDiscoveryInfo serviceType:kServiceType]];
    [self.advertiser setDelegate:self];
    [self.advertiser startAdvertisingPeer];
}

- (void)cancelRequest
{
    [self.advertiser stopAdvertisingPeer];
}

- (BOOL)requestInProgress
{
    return self.currentDiscoveryInfo != nil;
}

#pragma mark - Advertiser

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didNotStartAdvertisingPeer:(NSError *)error {
    if ([self.downloadDelegate respondsToSelector:@selector(nearbyFileRequest:didFinishTransmissionOfFileWithName:url:error:)]) {
        NSString *uuid = self.currentDiscoveryInfo[kDiscoveryMetaKeyUUID];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.downloadDelegate nearbyFileRequest:self didFinishTransmissionOfFileWithName:uuid url:nil error:error];
        });
    }
}

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID
       withContext:(NSData *)context invitationHandler:(void (^)(BOOL accept, MCSession *session))invitationHandler {
    NSDictionary *discoveryInfo = [NSKeyedUnarchiver unarchiveObjectWithData:context];
    if ([discoveryInfo isEqualToDictionary:self.currentDiscoveryInfo]) {
        NSLog(@"Found peer %@ for downloading file with UUID: %@", peerID.displayName, discoveryInfo[kDiscoveryMetaKeyUUID]);
        invitationHandler(YES, self.session);
    } else {
        invitationHandler(NO, nil);
    }
}

#pragma mark - Browser

- (void)browser:(MCNearbyServiceBrowser *)browser didNotStartBrowsingForPeers:(NSError *)error {
    NSLog(@"Could not start browsing for peers: %@", [error localizedDescription]);
    if ([self.uploadDelegate respondsToSelector:@selector(nearbyFileRequest:didFinishTransmissionOfFileWithName:url:error:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.uploadDelegate nearbyFileRequest:self didFinishTransmissionOfFileWithName:nil url:nil error:error];
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
            void(^accessHandler)(BOOL accept) = ^(BOOL accept) {
                if (accept) {
                    self.currentDiscoveryInfo = info;
                    NSData *context = [NSKeyedArchiver archivedDataWithRootObject:info];
                    [self.browser invitePeer:peerID toSession:self.session withContext:context timeout:30.];
                }
            };
            NSLog(@"Asking User for permission");
            if ([self.uploadDelegate respondsToSelector:@selector(nearbyFileRequest:wantsAccessToFileWithName:accessHandler:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.uploadDelegate nearbyFileRequest:self wantsAccessToFileWithName:uuid accessHandler:accessHandler];
                });
            } else {
                [self askPermissionForPeer:peerID info:info completion:accessHandler];
            }
        }
    }
}

- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID {
    NSLog(@"Peer lost: %@", peerID.displayName);
}


#pragma mark - Session

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
    if (state == MCSessionStateConnected) {
        NSLog(@"Peer %@ did connect to session.", peerID.displayName);
        if (self.downloadDelegate == nil) {
            // Sending file to connected Peer
            NSString *uuid = self.currentDiscoveryInfo[kDiscoveryMetaKeyUUID];
            NSURL *fileToSend = [self.fileLocator fileWithUUID:uuid];
            self.state = MKONearbyFileRequestStateUploading;
            if ([self.uploadDelegate respondsToSelector:@selector(nearbyFileRequest:didStartTransmissionOfFileWithName:peer:)]) {
                [self.uploadDelegate nearbyFileRequest:self didStartTransmissionOfFileWithName:uuid peer:peerID];
            }
            self.progress = [self.session sendResourceAtURL:fileToSend withName:uuid toPeer:peerID withCompletionHandler:^(NSError *error) {
                NSLog(@"Sending completed: %@", error);
                if ([self.uploadDelegate respondsToSelector:@selector(nearbyFileRequest:didFinishTransmissionOfFileWithName:url:error:)]) {
                    [self.uploadDelegate nearbyFileRequest:self didFinishTransmissionOfFileWithName:uuid url:fileToSend error:error];
                }
                self.state = MKONearbyFileRequestStateIdle;
            }];
        }
    } else if (state == MCSessionStateNotConnected) {
        NSLog(@"Peer %@ did disconnect from session.", peerID.displayName);
    } else if (state == MCSessionStateConnecting) {
        NSLog(@"Peer %@ will connect to session.", peerID.displayName);
    }
}

- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress {
    NSLog(@"didStartReceivingResourceWithName: %@ from peer: %@", resourceName, peerID.displayName);
    self.progress = progress;
    self.state = MKONearbyFileRequestStateDownloading;
    if ([self.downloadDelegate respondsToSelector:@selector(nearbyFileRequest:didStartTransmissionOfFileWithName:peer:)]) {
        [self.downloadDelegate nearbyFileRequest:self didStartTransmissionOfFileWithName:resourceName peer:peerID];
    }
}

- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error {
    NSLog(@"didFinishReceivingResourceWithName: %@ from peer: %@", resourceName, peerID.displayName);
    if ([self.downloadDelegate respondsToSelector:@selector(nearbyFileRequest:didFinishTransmissionOfFileWithName:url:error:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.downloadDelegate nearbyFileRequest:self didFinishTransmissionOfFileWithName:resourceName url:localURL error:error];
        });
    }
    self.state = MKONearbyFileRequestStateIdle;
}

- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID { }
- (void)session:(MCSession *)session didReceiveCertificate:(NSArray *)certificate
       fromPeer:(MCPeerID *)peerID certificateHandler:(void (^)(BOOL))certificateHandler { certificateHandler(YES); }
- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID { }

#pragma mark - Helper Methods

- (void)askPermissionForPeer:(MCPeerID *)peerID info:(NSDictionary *)info completion:(MKOPermissionCompletionBlock)completion
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.permissionCompletionBlock = completion;
        NSString *message = [NSString stringWithFormat:@"%@ would like to download\n%@\nfrom your device.", peerID.displayName, info[kDiscoveryMetaKeyUUID]];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Upload File" message:message delegate:self cancelButtonTitle:@"Don't allow" otherButtonTitles:@"Allow", nil];
        [alert show];
    });
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    self.permissionCompletionBlock(buttonIndex == 1);
    self.permissionCompletionBlock = nil;
}

#pragma mark - Progress

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"progress.fractionCompleted"]) {
        NSLog(@"fractionCompleted: %f", self.progress.fractionCompleted);
        dispatch_async(dispatch_get_main_queue(), ^{
            //TODO pass filename
            if (self.downloadDelegate && [self.downloadDelegate respondsToSelector:@selector(nearbyFileRequest:didUpdateTransmissionProgress:forFileWithName:)]) {
                [self.downloadDelegate nearbyFileRequest:self didUpdateTransmissionProgress:self.progress.fractionCompleted forFileWithName:nil];
            } else if (self.uploadDelegate && [self.uploadDelegate respondsToSelector:@selector(nearbyFileRequest:didUpdateTransmissionProgress:forFileWithName:)]) {
                [self.uploadDelegate nearbyFileRequest:self didUpdateTransmissionProgress:self.progress.fractionCompleted forFileWithName:nil];
            }
        });
    } else if ([keyPath isEqualToString:@"progress.indeterminate"]) {
        NSLog(@"indeterminate: %d", self.progress.indeterminate);
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
