//
// MKOFileLocator.h
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

/**
 *  MKOFileLocator
 */
@protocol MKOFileLocator <NSObject>

/**
 *  The implementation of this method determines if a file with a given uuid
 *  exists on the local device.
 *
 *  @param uuid a file uuid
 *
 *  @return returns 'YES' if the file exists on the local machine
 */
- (BOOL)fileExists:(NSString *)uuid;

/**
 *  The implementation of this method returns a path to a file with a given uuid.
 *
 *  @param uuid a file uuid
 *
 *  @return returns a NSURL if the file exists, otherwise 'nil'.
 */
- (NSURL *)fileWithUUID:(NSString *)uuid;
@end
