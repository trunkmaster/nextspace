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

#import <SystemKit/OSEMediaManager.h>

#ifdef WITH_HAL
#import <SystemKit/NXHALAdaptor.h>
#else
#import "OSEUDisksAdaptor.h"
#endif

// Volume events
NSString *OSEMediaDriveDidAddNotification = @"OSEMediaDriveDidAddNotification";
NSString *OSEMediaDriveDidRemoveNotification = @"OSEMediaDriveDidRemoveNotification";
NSString *OSEMediaVolumeDidAddNotification = @"OSEMediaVolumeDidAddNotification";
NSString *OSEMediaVolumeDidRemoveNotification = @"OSEMediaVolumeDidRemoveNotification";
NSString *OSEMediaVolumeDidMountNotification = @"OSEMediaVolumeDidMountNotification";
NSString *OSEMediaVolumeDidUnmountNotification = @"OSEMediaVolumeDidUnmountNotification";
// Operations
NSString *OSEMediaOperationDidStartNotification = @"OSEMediaOperationDidStartNotification";
NSString *OSEMediaOperationDidUpdateNotification = @"OSEMediaOperationDidUpdateNotification";
NSString *OSEMediaOperationDidEndNotification = @"OSEMediaOperationDidEndNotification";

//-----------------------------------------------------------------------
static id<MediaManager> adaptor;

@implementation OSEMediaManager

+ (id<MediaManager>)defaultManager
{
  if (!adaptor)
    {
      [[OSEMediaManager alloc] init];
    }
  return adaptor;
}

- (void)dealloc
{
  NSDebugLLog(@"dealloc", @"OSEMediaManager: -dealloc (retain count: %lu)", [self retainCount]);

  [adaptor release];
  
  [super dealloc];
}

- (id)init
{
  if (!(self = [super init])) {
    return nil;
  }

#ifdef WITH_HAL
  adaptor = [[NXHALAdaptor alloc] init];
#else
  adaptor = [[OSEUDisksAdaptor alloc] init];
#endif

  return self;
}

- (id<MediaManager>)adaptor
{
  return adaptor;
}

@end
