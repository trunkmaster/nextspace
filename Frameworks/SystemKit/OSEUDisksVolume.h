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
 * OSEOSEOSEUDisksVolume.h
 *
 * Media object which treated by UDisks as 'block_devices' object.
 * Can contain filesystem, swap, extended partition, RAID volume.
 */

#import <SystemKit/OSEMediaManager.h>
#import "OSEUDisksAdaptor.h"

@class OSEUDisksAdaptor;
@class OSEUDisksDrive;

@interface OSEUDisksVolume : NSObject <UDisksObject>
{
}

- (void)_dumpProperties;

//--- Protocol
@property (readonly) NSMutableDictionary *properties;
@property (readonly) NSString *objectPath;

//--- Parent objects
@property (readwrite, assign) OSEUDisksAdaptor *udisksAdaptor;
@property (readwrite, assign) OSEUDisksDrive *drive;
- (OSEUDisksVolume *)masterVolume;
- (NSString *)driveObjectPath;

//--- Accessories
@property (readonly) NSString *UUID;
@property (readonly) NSString *UNIXDevice;
@property (readonly) NSNumber *size;
@property (readonly) BOOL isSystem;

@property (readonly) BOOL hasPartition;
@property (readonly) NSString *partitionType;
@property (readonly) NSNumber *partitionNumber;
@property (readonly) NSNumber *partitionSize;

@property (readonly) BOOL isFilesystem;
@property (readonly) NXTFSType filesystemType;
@property (readonly) NSString *filesystemName;
@property (readonly) NSString *label;
@property (readonly) NSString *mountPoint;
@property (readonly) BOOL isMounted;
@property (readonly) BOOL isWritable;

@property (readonly) BOOL isLoopVolume;

//--- Actions

// Creates Job object. Returns mount point.
- (NSString *)mount:(BOOL)wait;

// Creates Job object. Returns YES on success, NO - otherwise.
- (BOOL)unmount:(BOOL)wait;

@end
