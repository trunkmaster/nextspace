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
 * OSEUDisksVolume.h
 * 
 * Media object which treated by UDisks as 'block_devices' object.
 * Can contain filesystem, swap, extended partition, RAID volume.
 */

#ifdef WITH_UDISKS

#import <SystemKit/OSEMediaManager.h>
#import <SystemKit/OSEUDisksAdaptor.h>
#import <SystemKit/OSEUDisksDrive.h>

@class OSEUDisksDrive;

@interface OSEUDisksVolume : NSObject <UDisksMedia>
{
  OSEUDisksAdaptor     *adaptor;
  NSMutableDictionary *properties;
  NSString            *objectPath;
  OSEUDisksDrive       *drive;

  NSNotificationCenter *notificationCenter;
}

//--- Parent object
- (OSEUDisksAdaptor *)adaptor;
- (OSEUDisksDrive *)drive;
- (void)setDrive:(OSEUDisksDrive *)driveObject;
- (OSEUDisksVolume *)masterVolume;
- (NSString *)driveObjectPath;

//--- Accessories
- (NXTFSType)type;
- (NSString *)UUID;
- (NSString *)label;
- (NSString *)size;
- (NSString *)UNIXDevice;
- (NSString *)mountPoints;

- (NSString *)partitionType;
- (NSString *)partitionNumber;
- (NSString *)partitionSize;

- (BOOL)isFilesystem;
- (BOOL)isMounted;
- (BOOL)isWritable;

- (BOOL)isLoopVolume;
- (BOOL)isSystem;

//--- Actions

// Creates Job object. Returns mount point.
- (NSString *)mount:(BOOL)wait;

// Creates Job object. Returns YES on success, NO - otherwise.
- (BOOL)unmount:(BOOL)wait;

@end

#endif // WITH_UDISKS
