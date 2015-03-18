//
//  MKOBundleFileLocator.m
//  MKOMultipeerFileRequest
//
//  Created by Mathias Köhnke on 16/03/15.
//  Copyright (c) 2015 Mathias Koehnke. All rights reserved.
//

#import "MKOBundleFileLocator.h"

@implementation MKOBundleFileLocator

- (BOOL)fileExists:(NSString *)uuid
{
    return ([self pathForUUID:uuid] != nil);
}

- (NSURL *)fileWithUUID:(NSString *)uuid
{
    return [NSURL fileURLWithPath:[self pathForUUID:uuid]];
}

- (NSString *)pathForUUID:(NSString *)uuid
{
    return [[NSBundle mainBundle] pathForResource:[uuid stringByDeletingPathExtension] ofType:[uuid pathExtension]];
}

@end
