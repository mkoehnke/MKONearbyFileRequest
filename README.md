# MKONearbyFileRequest
The usual workflow for a user to receive a file from a nearby peer is to ask her to send it to a specific device. MKONearbyFileRequest, however, enables you to request a file and download it from every nearby peer that is ready to share it with you.

# Requirements
MKONearbyFileRequest requires the MultipeerConnectivity Framework, hence iOS 7.0 and higher versions are supported.

# Installation
Add the **MultipeerConnectivity.framework** to your target's *Linked Frameworks and Libraries* section. Drag the **MKONearbyFileRequest** folder to your project and make sure the following checkboxes are selected:

* Copy items if needed
* Add to targets

### Objective-C
Import the following header file to the class where you like to use it: 

```objective-c
#import "MKONearbyFileRequest.h"
```
### Swift
1. To import Objective-C files to your Swift project, you rely on an *Objective-C bridging header* to expose those files to Swift. Xcode offers to create this header file when you add the *MKONearbyFileRequest* files to your existing Swift app.<br />Alternatively, you can create a bridging header yourself by choosing File > New > File > iOS > Source > Header File and name it *projectname-bridging-header.h*.
2. In your Objective-C bridging header file, import the following header file:

	```objective-c
	#import "MKONearbyFileRequest.h"
	```
3. Under Build Settings, make sure the Objective-C Bridging Header build setting under Swift Compiler - Code Generation has a path to the header.
The path should be relative to your project, similar to the way your Info.plist path is specified in Build Settings. In most cases, you should not need to modify this setting.

# Usage

## Setup
```objective-c
MKOBundleFileLocator *fileLocator = [MKOBundleFileLocator new];
MKONearbyFileRequest *fileRequest = [[MKONearbyFileRequest alloc] initWithDisplayName:displayName fileLocator:fileLocator];
[fileRequest startRequestListener];
```
There's currently one implementation of the MKOFilelocator protocol available, which can locate a file in the local bundle. You can simply create your own file locator (e.g. looking up files in your database or file system) by implementing the following methods:

```objective-c
- (BOOL)fileExists:(NSString *)uuid;
- (NSURL *)fileWithUUID:(NSString *)uuid;
```

## Start Request
```objective-c
MKONearbyFileRequestOperation *operation = [fileRequest requestFile:@"image-123456789.jpg" 
  progress:^(MKONearbyFileRequestOperation *operation, float progress) {
    // show progress in UI
  } 
  completion:^(MKONearbyFileRequestOperation *operation, NSURL *url, NSError *error) {
	NSData *data = [[NSFileManager defaultManager] contentsAtPath:[url path]];
    UIImage *image = [UIImage imageWithData:data];
  }
];

```

## Cancel Request
```objective-c
[operation cancel];
```

# License
MKNearbyFileRequest is available under the MIT license. See the LICENSE file for more info.

# Recent Changes
The release notes can be found [here](https://github.com/mkoehnke/MKONearbyFileRequest/releases).
