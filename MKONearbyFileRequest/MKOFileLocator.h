//
//  MKOFileLocator.h
//  MKOMultipeerFileRequest
//
//  Created by Mathias Köhnke on 16/03/15.
//  Copyright (c) 2015 Mathias Koehnke. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol MKOFileLocator <NSObject>
- (BOOL)fileExists:(NSString *)uuid;
- (NSURL *)fileWithUUID:(NSString *)uuid;
@end
