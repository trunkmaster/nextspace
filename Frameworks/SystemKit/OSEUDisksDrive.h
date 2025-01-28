/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - SystemKit framework
//
// Copyright (C) 2014-2019 Sergii Stoian
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free
// Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
//

/*
 * Object which represents physical storage device.
 * UDisks base path is: "/org/freedesktop/UDisks2/drives/<name of drive>".
 */

#import <SystemKit/OSEMediaManager.h>
#import "OSEUDisksAdaptor.h"

@class OSEUDisksVolume;

@interface OSEUDisksDrive : NSObject <UDisksObject>
{
  NSMutableArray *mountedVolumesToDetach;
  BOOL needsDetach;

  NSNotificationCenter *notificationCenter;
}

//--- Protocol
@property (readonly) NSMutableDictionary *properties;
@property (readonly) NSString *objectPath;

//--- Object network
@property (readwrite, assign) OSEUDisksAdaptor *udisksAdaptor;
// @property (readonly) NSMutableDictionary *volumes;

//--- Attributes
@property (readonly) NSString *humanReadableName;  // vendor, model
@property (readonly) BOOL isRemovable;
@property (readonly) BOOL isEjectable;
@property (readonly) BOOL canPowerOff;

// valuable for optical disks
@property (readonly) BOOL isOptical;
@property (readonly) BOOL hasMedia;
@property (readonly) BOOL isMediaRemovable;
@property (readonly) BOOL isOpticalBlank;
@property (readonly) NSNumber *numberOfAudioTracks;
@property (readonly) NSNumber *numberOfDataTracks;

//--- Actions
@property (readonly) NSArray *mountedVolumes;
- (NSArray *)mountVolumes:(BOOL)wait;
- (BOOL)unmountVolumes:(BOOL)wait;
- (void)unmountVolumesAndDetach;
- (BOOL)eject:(BOOL)wait;
- (BOOL)powerOff:(BOOL)wait;

@end
