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
 * Provides integration with OSEUDisksAdaptor subsystem.
 * Construct network of objects: OSEOSEUDisksDrive, OSEOSEUDisksVolume.
 */

#import <Foundation/Foundation.h>

#import <SystemKit/OSEMediaManager.h>
#import <SystemKit/OSEBusConnection.h>
#import <SystemKit/OSEBusService.h>

@class OSEUDisksDrive;
@class OSEUDisksVolume;

typedef enum {
  OSEUDisksUnknownObject = 0,
  OSEOSEUDisksDriveObject,
  OSEUDisksBlockObject,
  OSEUDisksJobObject
} OSEUDisksObject;

// /org/freedesktop/UDisks2/drives/
#define DRIVE_INTERFACE     @"org.freedesktop.UDisks2.Drive"
#define DRIVE_ATA_INTERFACE @"org.freedesktop.UDisks2.Drive.Ata"
// /org/freedesktop/UDisks2/block_devices/
#define BLOCK_INTERFACE     @"org.freedesktop.UDisks2.Block"
#define PARTITION_INTERFACE @"org.freedesktop.UDisks2.Partition"
#define PTABLE_INTERFACE    @"org.freedesktop.UDisks2.PartitionTable"
#define FS_INTERFACE @"org.freedesktop.UDisks2.Filesystem"
// TODO
#define LOOP_INTERFACE      @"org.freedesktop.UDisks2.Loop"
// /org/freedesktop/UDisks2/jobs
#define JOB_INTERFACE       @"org.freedesktop.UDisks2.Job"

extern NSString *OSEUDisksPropertiesDidChangeNotification;
extern NSString *OSEUDisksInterfacesDidAddNotification;
extern NSString *OSEUDisksInterfacesDidRemoveNotification;

@interface OSEUDisksAdaptor : OSEBusService <DBus_ObjectManager, MediaManager>
{
  // /org/freedesktop/UDisks2/block_devices/
  NSMutableDictionary *udisksBlockDevicesCache;
  // /org/freedesktop/UDisks2/drives/
  NSMutableDictionary *OSEUDisksDrivesCache;
  // List of /org/freedesktop/UDisks2/jobs objects
  NSMutableDictionary *jobsCache;
  
  // List of OSEOSEUDisksVolume objects with D-Bus object path as key
  NSMutableDictionary *volumes;
  // List of OSEOSEUDisksDrive objects with D-Bus object path as key
  NSMutableDictionary *drives;
  
  NSMutableArray *drivesToCleanup;  // unsafely detached drives

  NSNotificationCenter *notificationCenter;
}

- (NSDictionary *)availableDrives;
- (NSDictionary *)availableVolumesForDrive:(NSString *)driveObjectPath;
- (id)objectWithUDisksPath:(NSString *)objectPath;

- (OSEUDisksVolume *)mountedVolumeForPath:(NSString *)filesystemPath;

- (void)operationWithName:(NSString *)name
                   object:(id)object
                   failed:(BOOL)failed
                   status:(NSString *)status
                    title:(NSString *)title
                  message:(NSString *)message;

// TODO
// - (BOOL)setLoopToFileAtPath:(NSString *)imageFile;
// - (BOOL)unsetLoop:(NSString *)objectPath;

@end

@protocol UDisksObject <NSObject>

- (NSString *)objectPath;
- (NSMutableDictionary *)properties;

- (id)initWithProperties:(NSDictionary *)properties
              objectPath:(NSString *)path
                 adaptor:(OSEUDisksAdaptor *)adaptor;
- (void)setProperty:(NSString *)property
              value:(NSString *)value
      interfaceName:(NSString *)interface;
- (void)removeProperties:(NSArray *)properties
           interfaceName:(NSString *)interface;
- (id)propertyForKey:(NSString *)key interface:(NSString *)interface;
- (BOOL)boolPropertyForKey:(NSString *)key interface:(NSString *)interface;

// This is for debug
- (void)_dumpProperties;

@end
