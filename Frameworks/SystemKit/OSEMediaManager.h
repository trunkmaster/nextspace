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
 * This class is aimed to provide:
 * - access to OS-dependent adaptor via MediaManager protocol;
 * - definition of notifications sent by adaptor;
 * - definition of base types inside MediaManager network of classes.
 */

#import <Foundation/Foundation.h>

// Events
extern NSString *OSEDiskAppeared;
extern NSString *OSEDiskDisappeared;
extern NSString *NXVolumeAppeared;
extern NSString *NXVolumeDisappeared;
extern NSString *NXVolumeMounted;
extern NSString *NXVolumeUnmounted;

extern NSString *OSEMediaOperationDidStart;
extern NSString *OSEMediaOperationDidUpdate;
extern NSString *OSEMediaOperationDidEnd;

// Filesystem types
typedef enum
{
  NXTFSTypeNTFS = 0,
  NXTFSTypeFAT  = 1,
  NXTFSTypeUDF  = 2,
  NXTFSTypeUFS  = 3,
  NXTFSTypeISO  = 4,
  NXTFSTypeSwap = 5
} NXTFSType;

// Class which adopts <MediaManager> protocol aimed to implement
// interaction with OS's method of getting information about disks, volumes,
// partitions and its events (add, remove, mount, unmount, eject).
@protocol MediaManager <NSObject>

/** Returns a list of the pathnames of currently mounted removable and fixed 
    disks.*/
- (NSArray *)mountedVolumes;

/** Returns name of filesystem type mounted at subpath of 'path'.*/
- (NXTFSType)filesystemTypeAtPath:(NSString *)path;
- (NSString *)mountPointForPath:(NSString *)path;

// Disks -> Unmount.
// Async - OK.
- (void)unmountRemovableVolumeAtPath:(NSString *)path;

//--- NSWorkspace methods
  
/** Causes the Workspace Manager to poll the system's drives for any disks
    that have been inserted but not yet mounted. Asks the Workspace Manager to
    mount the disk asynchronously and returns immediately.
    'Workspace -> Disk -> Check For Disks'*/
- (void)checkForRemovableMedia;

/** Causes the Workspace Manager to poll the system's drives for any disks
    that have been inserted but not yet mounted, waits until the new disks
    have been mounted, and returns a list of full pathnames to all newly
    mounted disks.*/
// Sync - OK.
- (NSArray *)mountNewRemovableMedia;

/** Returns a list of the pathnames of all currently mounted removable disks.*/
- (NSArray *)mountedRemovableMedia;

/** Unmounts and ejects the device at path and returns YES if unmount 
    succeeded and NO otherwise.
    'Disk -> Eject' */
// Async - OK.
- (void)unmountAndEjectDeviceAtPath:(NSString *)path;

// Async - OK.
- (void)ejectAllRemovables;

- (BOOL)mountImageMediaFileAtPath:(NSString *)imageFile;

@end

// Initiates and hold 'adaptor' object instance.
@interface OSEMediaManager : NSObject
{
}

+ (id<MediaManager>)defaultManager;
  
// Returned object must not be released directrly.
// It will be released by releasing OSEMediaManager object.
- (id<MediaManager>)adaptor;

@end
