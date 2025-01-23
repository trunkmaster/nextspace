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

#import <SystemKit/OSEFileManager.h>
#import <SystemKit/OSEBusMessage.h>

#import "OSEUDisksDrive.h"
#import "OSEUDisksVolume.h"

#import "OSEUDisksAdaptor.h"

// Signals
NSString *OSEUDisksInterfacesDidAddNotification = @"OSEUDisksInterfacesDidAddNotification";
NSString *OSEUDisksInterfacesDidRemoveNotification = @"OSEUDisksInterfacesDidRemoveNotification";
NSString *OSEUDisksPropertiesDidChangeNotification = @"OSEUDisksPropertiesDidChangeNotification";

@interface OSEUDisksAdaptor (Private)
- (OSEUDisksObject)_objectTypeForPath:(NSString *)objectPath;

- (void)_parseDrive:(NSString *)objectPath withProperties:(NSArray *)objectProperties;
- (void)_parseBlockDevice:(NSString *)objectPath withProperties:(NSArray *)objectProperties;
- (void)_parseObject:(NSString *)objectPath withProperties:(NSArray *)objectProperties;

- (void)_removeObject:(NSString *)objectPath andNotify:(BOOL)notify;

- (void)_registerDrive:(NSString *)objectPath andNotify:(BOOL)notify;
- (void)_registerBlockDevice:(NSString *)objectPath andNotify:(BOOL)notify;
- (void)_registerObjects;
@end

@implementation OSEUDisksAdaptor (Private)

- (OSEUDisksObject)_objectTypeForPath:(NSString *)objectPath
{
  NSArray *pathComponents = [objectPath pathComponents];
  NSString *objectType = nil;
  int type = OSEUDisksUnknownObject;

  if (pathComponents.count > 2) {
    objectType = [pathComponents objectAtIndex:[pathComponents count] - 2];
    if ([objectType isEqualToString:@"drives"]) {
      type = OSEOSEUDisksDriveObject;
    } else if ([objectType isEqualToString:@"block_devices"]) {
      type = OSEUDisksBlockObject;
    } else if ([objectType isEqualToString:@"jobs"]) {
      type = OSEUDisksJobObject;
    }
  }

  return type;
}

#pragma mark - D-Bus objects cache

- (NSMutableDictionary *)_parsePropertiesSection:(NSArray *)sectionProperties
{
  NSMutableDictionary *normalizedProperties = [NSMutableDictionary new];
  for (NSDictionary *prop in sectionProperties) {
    [normalizedProperties addEntriesFromDictionary:prop];
  }
  return normalizedProperties;
}

- (NSMutableDictionary *)_parseDriveProperties:(NSArray *)objectProperties
{
  NSMutableDictionary *driveProperties = [NSMutableDictionary new];
  NSMutableDictionary *driveSection;
  NSMutableDictionary *driveAtaSection;

  for (NSDictionary *property in objectProperties) {
    // .Drive
    driveSection = [self _parsePropertiesSection:property[DRIVE_INTERFACE]];
    if (driveSection.allKeys.count > 0) {
      driveProperties[DRIVE_INTERFACE] = driveSection;
    }
    [driveSection release];
    // .Drive.Ata
    driveAtaSection = [self _parsePropertiesSection:property[DRIVE_ATA_INTERFACE]];
    if (driveAtaSection.allKeys.count > 0) {
      driveProperties[DRIVE_ATA_INTERFACE] = driveAtaSection;
    }
    [driveAtaSection release];
  }
  return driveProperties;
}
// `drive` is an array of dictionaries:
//   org.freedesktop.UDisks2.Drive ({})
//   org.freedesktop.UDisks2.Drive.Ata ({})
- (void)_parseDrive:(NSString *)objectPath withProperties:(NSArray *)objectProperties
{
  NSMutableDictionary *driveProperties = [self _parseDriveProperties:objectProperties];
  [OSEUDisksDrivesCache setObject:driveProperties forKey:objectPath];
  [driveProperties release];
}

- (NSMutableDictionary *)_parseBlockDeviceProperties:(NSArray *)objectProperties
{
  NSMutableDictionary *blockDeviceProperties = [NSMutableDictionary new];
  NSMutableDictionary *blockSection;
  NSMutableDictionary *fileSystemSection;
  NSMutableDictionary *partitionSection;

  for (NSDictionary *property in objectProperties) {
    // .Block section
    blockSection = [self _parsePropertiesSection:property[BLOCK_INTERFACE]];
    if (blockSection.allKeys.count > 0) {
      blockDeviceProperties[BLOCK_INTERFACE] = blockSection;
    }
    [blockSection release];
    // .Filesystem section
    fileSystemSection = [self _parsePropertiesSection:property[FS_INTERFACE]];
    if (fileSystemSection.allKeys.count > 0) {
      blockDeviceProperties[FS_INTERFACE] = fileSystemSection;
    }
    [fileSystemSection release];
    // .Partition section
    partitionSection = [self _parsePropertiesSection:property[PARTITION_INTERFACE]];
    if (partitionSection.allKeys.count > 0) {
      blockDeviceProperties[PARTITION_INTERFACE] = partitionSection;
    }
    [partitionSection release];
  }
  return blockDeviceProperties;
}
- (void)_parseBlockDevice:(NSString *)objectPath withProperties:(NSArray *)objectProperties
{
  NSMutableDictionary *blockDeviceProperties = [self _parseBlockDeviceProperties:objectProperties];
  udisksBlockDevicesCache[objectPath] = blockDeviceProperties;
  [blockDeviceProperties release];
}

- (void)_parseObject:(NSString *)objectPath withProperties:(NSArray *)objectProperties
{
  NSDebugLLog(@"UDisks", @"Parsing '%@'", objectPath);
  switch ([self _objectTypeForPath:objectPath]) {
    case OSEOSEUDisksDriveObject:
      [self _parseDrive:objectPath withProperties:objectProperties];
      break;
    case OSEUDisksBlockObject:
      [self _parseBlockDevice:objectPath withProperties:objectProperties];
      break;
    case OSEUDisksJobObject:
      break;
    default:
      NSDebugLLog(@"UDisks",
                 @"OSEUDisksAdaptor Warning: trying to append unknown object type with path '%@'",
                 objectPath);
  }
}

#pragma mark - OSEUDisksDrive, OSEUDisksVolume objects

- (void)_removeObject:(NSString *)objectPath andNotify:(BOOL)notify
{
  NSDebugLLog(@"UDisks", @"Removing and unregistering '%@'", objectPath);
  switch ([self _objectTypeForPath:objectPath]) {
    case OSEOSEUDisksDriveObject:
      // [OSEUDisksDrivesCache removeObjectForKey:objectPath];
      [drives removeObjectForKey:objectPath];
      if (notify != NO) {
        [notificationCenter postNotificationName:OSEMediaDriveDidRemoveNotification
                                          object:self
                                        userInfo:@{@"ObjectPath" : objectPath}];
      }
      break;
    case OSEUDisksBlockObject:
      // [udisksBlockDevicesCache removeObjectForKey:objectPath];
      [volumes removeObjectForKey:objectPath];
      if (notify != NO) {
        [notificationCenter postNotificationName:OSEMediaVolumeDidRemoveNotification
                                          object:self
                                        userInfo:@{@"ObjectPath" : objectPath}];
      }
      break;
    case OSEUDisksJobObject:
      // TODO
      [jobsCache removeObjectForKey:objectPath];
      break;
    default:
      NSDebugLLog(@"UDisks",
                 @"OSEUDisksAdaptor Warning: trying to remove unknown object type with path %@",
                 objectPath);
  }
}

- (void)_registerDrive:(NSString *)objectPath andNotify:(BOOL)notify
{
  OSEUDisksDrive *driveInstance;
  NSDictionary *drive = OSEUDisksDrivesCache[objectPath];

  driveInstance = [[OSEUDisksDrive alloc] initWithProperties:drive
                                                  objectPath:objectPath
                                                     adaptor:self];
  driveInstance.udisksAdaptor = self;
  [OSEUDisksDrivesCache removeObjectForKey:objectPath];

  [drives setObject:driveInstance forKey:objectPath];
  [driveInstance release];
  if (notify != NO) {
    [notificationCenter postNotificationName:OSEMediaDriveDidAddNotification
                                      object:self
                                    userInfo:driveInstance.properties];
  }
}

- (void)_registerBlockDevice:(NSString *)objectPath andNotify:(BOOL)notify
{
  NSDictionary *blockDevice = udisksBlockDevicesCache[objectPath];
  NSString *drivePath;
  OSEUDisksDrive *drive;
  OSEUDisksVolume *volumeInstance;

  if ([blockDevice[BLOCK_INTERFACE][@"HintIgnore"] boolValue] != NO) {
    // Ignored devices leaves in the cache
    return;
  }
  volumeInstance = [[OSEUDisksVolume alloc] initWithProperties:blockDevice
                                                    objectPath:objectPath
                                                       adaptor:self];
  volumeInstance.udisksAdaptor = self;
  [volumes setObject:volumeInstance forKey:objectPath];
  [udisksBlockDevicesCache removeObjectForKey:objectPath];

  drivePath = blockDevice[BLOCK_INTERFACE][@"Drive"];
  // NSDebugLLog(@"UDisks", @"_registerBlockDevice: %@", blockDevice);
  drive = [drives objectForKey:drivePath];
  if (drive == nil) {
    NSDebugLLog(@"UDisks",
               @"OSEUDisksAdaptor Warning: no drive with path '%@' found for block device '%@'",
               drivePath, objectPath);
    return;
  }
  [drive addVolume:volumeInstance withPath:objectPath];
  volumeInstance.drive = drive;
  [volumeInstance release];

  if (notify != NO) {
    [notificationCenter postNotificationName:OSEMediaVolumeDidAddNotification
                                      object:self
                                    userInfo:volumeInstance.properties];
  }
}

- (void)_registerObjects
{
  [volumes removeAllObjects];
  [drives removeAllObjects];

  // Create OSEUDisksDrive instances
  for (NSString *drivePath in OSEUDisksDrivesCache.allKeys) {
    [self _registerDrive:drivePath andNotify:NO];
  }

  // Create OSEUDisksVolume instances and set to appropriate drive
  for (NSString *blockDevicePath in udisksBlockDevicesCache.allKeys) {
    [self _registerBlockDevice:blockDevicePath andNotify:NO];
  }
}

// a{ oa{ sa{ sv } } }
- (BOOL)_updateObjectsList
{
  NSArray *managedObjects = [self GetManagedObjects];
  NSString *objectPath;

  [managedObjects writeToFile:@"_ManagedObjects.result" atomically:NO];

  [udisksBlockDevicesCache removeAllObjects];
  [OSEUDisksDrivesCache removeAllObjects];

  for (NSDictionary *object in managedObjects) {
    objectPath = [object allKeys][0];  // ao{}
    [self _parseObject:objectPath withProperties:object[objectPath]];
  }

  [self _registerObjects];

  return YES;
}

// Returns volume dictionary which mounted at 'path'
// 'path' is not necessary a mount point, it can be some path inside
// mounted filesystem
- (OSEUDisksVolume *)_mountedVolumeForPath:(NSString *)filesystemPath
{
  OSEUDisksVolume *volume = nil;
  NSString *mp, *mp1;
  NSString *mountPoint = nil;

  // Find longest mount point for path
  mp = @"";
  for (OSEUDisksVolume *volume1 in [self mountedVolumes]) {
    mountPoint = [volume1 mountPoints][0];
    // NSDebugLLog(@"UDisks", @"LongestMP(%@): process MP: %@", filesystemPath, mountPoint);
    mp1 = NXTIntersectionPath(filesystemPath, mountPoint);
    if ([mp1 isEqualToString:mountPoint] && ([mp1 length] >= [mp length])) {
      ASSIGN(mp, mp1);
      ASSIGN(volume, volume1);
    }
  }

  NSDebugLLog(@"udisks", @"Longest MP: %@ for path %@", [volume mountPoints], filesystemPath);

  // if ([[volume mountPoints] isEqualToString:@"/"])
  //   return nil;
  // else
  return [volume autorelease];
}

// Returns list of OSEOSEUDisksVolume objects.
// Each object represents mounted volume (fixed and removable).
// If path == nil, returns list of all mounted diskVolumes in system.
- (NSArray *)_mountedVolumesForDrive:(NSString *)driveObjectPath
{
  NSMutableArray *mountedVolumes;
  OSEUDisksDrive *drive;
  NSArray *driveVolumes;

  if (driveObjectPath) {
    drive = [drives objectForKey:driveObjectPath];
    return [drive mountedVolumes];
  }

  mountedVolumes = [NSMutableArray new];
  // e = [[drives allValues] objectEnumerator];
  // while ((drive = [e nextObject]) != nil) {
  for (OSEUDisksDrive *drive in [drives allValues]) {
    driveVolumes = [drive mountedVolumes];
    if (driveVolumes && [driveVolumes count] > 0) {
      [mountedVolumes addObjectsFromArray:driveVolumes];
    }
  }

  return mountedVolumes;
}

@end

@implementation OSEUDisksAdaptor (Signals)

- (void)setSignalsMonitoring
{
  // [self.connection addSignalObserver:self
  //                           selector:@selector(handlePropertiesChangedSignal:)
  //                             signal:@"PropertiesChanged"
  //                             object:self.objectPath
  //                          interface:@"org.freedesktop.DBus.Properties"
  //                       notification:OSEUDisksPropertiesDidChangeNotification];
  
  [self.connection addSignalObserver:self
                            selector:@selector(handleInterfacesAdeddSignal:)
                              signal:@"InterfacesAdded"
                              object:self.objectPath
                           interface:@"org.freedesktop.DBus.ObjectManager"
                        notification:OSEUDisksInterfacesDidAddNotification];
  
  [self.connection addSignalObserver:self
                            selector:@selector(handleInterfacesRemovedSignal:)
                              signal:@"InterfacesRemoved"
                              object:self.objectPath
                           interface:@"org.freedesktop.DBus.ObjectManager"
                        notification:OSEUDisksInterfacesDidRemoveNotification];
}

- (void)handlePropertiesChangedSignal:(NSDictionary *)info
{
  NSDebugLLog(@"UDisks", @"OSEUDisksAdaptor \e[1mPropertiesChanged\e[0m: %@", info[@"Message"]);
}

- (void)handleInterfacesAdeddSignal:(NSDictionary *)info
{
  NSDebugLLog(@"UDisks", @"OSEUDisksAdaptor \e[1mInterfacesAdded\e[0m: %@", info[@"Message"]);

  NSArray *message = info[@"Message"];
  NSString *objectPath = nil;
  NSArray *objectProperties = nil;

  if (message && message.count > 1) {
    objectPath = message[0];
    objectProperties = message[1];
  } else {
    NSDebugLLog(@"UDisks",
               @"OSEUDisksAdaptor error: message in InterfaceAdded notification is broken.");
    return;
  }

  [self _parseObject:objectPath withProperties:objectProperties];
  
  switch ([self _objectTypeForPath:objectPath]) {
    case OSEOSEUDisksDriveObject:
      [self _registerDrive:objectPath andNotify:YES];
      [drives[objectPath] _dumpProperties];
      break;
    case OSEUDisksBlockObject: {
      OSEUDisksVolume *volume = [volumes objectForKey:objectPath];
      if (volume == nil) {
        [self _registerBlockDevice:objectPath andNotify:YES];
        [volumes[objectPath] _dumpProperties];
      } else {
        // OSEUDisksAdaptor InterfacesAdded: (
        // "/org/freedesktop/UDisks2/block_devices/sr0", <--- message[0]
        //   ({                                          <--- message[1]
        //     "org.freedesktop.UDisks2.Filesystem" = (
        //       { MountPoints = (); },
        //       { Size = 0; }
        //     );
        //   })
        // )
        // 1. Normalize 'objectProperties'
        // 2. [volume setProperty:@"MountPoints" value:(NSString *)
        // interfaceName:@"org.fredesktop.UDisks2.Filesystem"]
        NSMutableDictionary *properties = [self _parseBlockDeviceProperties:message[1]];
        [[volume properties] addEntriesFromDictionary:properties];
        [volume _dumpProperties];
        [properties release];
      }
      [[volumes objectForKey:objectPath] mount:YES];
    } break;
    case OSEUDisksJobObject: {
      // TODO
      // OSEUDisksAdaptor InterfacesAdded: (
      // "/org/freedesktop/UDisks2/jobs/1",    <--- message[0]
      // ({                                    <--- message[1]
      //    "org.freedesktop.UDisks2.Job" = (
      //      {Operation = "filesystem-unmount"; },
      //      {Progress = 0; },
      //      {ProgressValid = 0; },
      //      {Bytes = 0; },
      //      {Rate = 0; },
      //      {StartTime = 1736953604254703; },
      //      {ExpectedEndTime = 0; },
      //      {Objects = ("/org/freedesktop/UDisks2/block_devices/sr0"); },
      //      {StartedByUID = 0; },
      //      {Cancelable = 1; }
      //   );
      // })
      // )
      NSString *objectPath = message[0];
      NSArray *jobProperties = message[1];
      NSMutableDictionary *properties =
          [self _parsePropertiesSection:jobProperties.firstObject[JOB_INTERFACE]];
      [jobsCache setObject:properties forKey:objectPath];
    } break;
    default:
      NSDebugLLog(@"UDisks",
                 @"OSEUDisksAdaptor Warning: trying to remove unknown object type with path %@",
                 objectPath);
  }
}

- (void)handleInterfacesRemovedSignal:(NSDictionary *)info
{
  NSDebugLLog(@"UDisks", @"OSEUDisksAdaptor \e[1mInterfacesRemoved\e[0m: %@", info[@"Message"]);
  NSArray *message = info[@"Message"];
  NSString *objectPath;

  if (message.count == 0) {
    NSDebugLLog(@"UDisks",
               @"OSEUDisksAdaptor InterfacesRemoved warning: no object path specified in message.");
    return;
  } else {
    objectPath = message.firstObject;
  }

  if (message.count == 1) {
    [self _removeObject:objectPath andNotify:YES];
  } else if (message.count > 1) {
    id<UDisksObject> object = nil;
    // TODO: OSEUDisksAdaptor InterfacesRemoved:
    // ("/org/freedesktop/UDisks2/block_devices/sr0", ("org.freedesktop.UDisks2.Filesystem"))
    switch ([self _objectTypeForPath:objectPath]) {
      case OSEUDisksBlockObject: {
        object = [volumes objectForKey:objectPath];
      } break;
      case OSEOSEUDisksDriveObject: {
        object = [drives objectForKey:objectPath];
      } break;
      case OSEUDisksJobObject: {
        [jobsCache removeObjectForKey:objectPath];
      } break;
      default:
        NSDebugLLog(@"UDisks", @"OSEUDisksAdaptor InterfacesRemoved warning: unknown object type "
                              @"was removed, skipping.");
        break;
    }
    if (object != nil) {
      for (NSString *interface in message[1]) {
        [[object properties] removeObjectForKey:interface];
      }
      if (object.properties.allKeys.count == 0) {
        [self _removeObject:objectPath andNotify:YES];
      }
      // [object _dumpProperties];
    }
  }
}

@end

@implementation OSEUDisksAdaptor

//-------------------------------------------------------------------------------
#pragma mark - Init
//-------------------------------------------------------------------------------
- (void)dealloc
{
  NSDebugLLog(@"dealloc", @"OSEUDisksAdaptor: dealloc (retain count: %lu)", [self retainCount]);

  [udisksBlockDevicesCache release];
  [OSEUDisksDrivesCache release];

  [volumes release];
  [drives release];
  [jobsCache release];

  // OSEUDisksAdaptor is the main owner of connection to UDisks2 D-Bus service (OSEBusConnection) - release it.
  [self.connection release];

  [super dealloc];
}

- (id)init
{
  [super init];

  self.objectPath = @"/org/freedesktop/UDisks2";
  self.serviceName = @"org.freedesktop.UDisks2";

  OSEUDisksDrivesCache = [NSMutableDictionary new];
  udisksBlockDevicesCache = [NSMutableDictionary new];

  drives = [NSMutableDictionary new];
  volumes = [NSMutableDictionary new];
  jobsCache = [NSMutableDictionary new];

  if ([self _updateObjectsList] != NO) {
    [OSEUDisksDrivesCache writeToFile:@"_UDisks.drives.result" atomically:YES];
    [udisksBlockDevicesCache writeToFile:@"_UDisks.block_devices.result" atomically:YES];
  }

  notificationCenter = [NSNotificationCenter defaultCenter];
  [self setSignalsMonitoring];
#ifdef CF_BUS_CONNECTION
  dispatch_queue_t media_q = dispatch_queue_create("ns.workspace.media", DISPATCH_QUEUE_CONCURRENT);
  dispatch_async(media_q, ^{
    [self.connection run];
  });
#endif

  return self;
}

//-------------------------------------------------------------------------------
#pragma mark - Main implementation
//-------------------------------------------------------------------------------

// It's for 'disktool'
// TODO: remove by fixing 'disktool'
- (NSDictionary *)availableDrives
{
  return drives;
}

// Used by OSEOSEUDisksDrive to collect it's diskVolumes.
// That's why we iterate registered diskVolumes.
- (NSDictionary *)availableVolumesForDrive:(NSString *)driveObjectPath
{
  NSArray *volumePaths = [volumes allKeys];
  OSEUDisksVolume *volume;
  NSMutableDictionary *driveVolumes = [NSMutableDictionary new];

  for (NSString *path in volumePaths) {
    volume = [volumes objectForKey:path];
    if ([[volume driveObjectPath] isEqualToString:driveObjectPath]) {
      [driveVolumes setObject:volume forKey:path];
    }
  }

  return driveVolumes;
}

- (id)objectWithUDisksPath:(NSString *)objectPath
{
  id object = nil;

  switch ([self _objectTypeForPath:objectPath]) {
    case OSEOSEUDisksDriveObject:
      object = [drives objectForKey:objectPath];
      break;
    case OSEUDisksBlockObject: 
      object = [volumes objectForKey:objectPath];
      break;
    case OSEUDisksJobObject:
      object = [jobsCache objectForKey:objectPath];
      break;
    default:
      NSDebugLLog(@"UDisks",
                 @"OSEUDisksAdaptor objectWithUDisksPath: unknow object for object path %@",
                 objectPath);
  }
  
  return object;
}

- (OSEUDisksVolume *)mountedVolumeForPath:(NSString *)filesystemPath
{
  OSEUDisksVolume *volume = nil;
  NSString *commonPath = nil;

  // Find longest mount point for path
  for (OSEUDisksVolume *vol in [self mountedVolumes]) {
    for (NSString *mp in [vol mountPoints]) {
      commonPath = NXTIntersectionPath(filesystemPath, mp);
      if ([commonPath isEqualToString:mp] && ([commonPath length] >= [mp length])) {
        volume = vol;
      }
    }
  }

  NSDebugLLog(@"udisks", @"Longest MP: %@ for path %@", [volume mountPoints], filesystemPath);

  return volume;
}

- (void)postVolumeDidMountNotification:(NSDictionary *)info
{
  [notificationCenter postNotificationName:OSEMediaVolumeDidMountNotification object:self userInfo:info];
}

- (void)operationWithName:(NSString *)name
                   object:(id)object
                   failed:(BOOL)failed
                   status:(NSString *)status
                    title:(NSString *)title
                  message:(NSString *)message
{
  NSMutableDictionary *info = [NSMutableDictionary new];

  [info setObject:object forKey:@"ID"];
  [info setObject:name forKey:@"Operation"];
  [info setObject:title forKey:@"Title"];
  [info setObject:message forKey:@"Message"];
  if ([name isEqualToString:@"Mount"] || [name isEqualToString:@"Unmount"]) {
    [info setObject:[object UNIXDevice] forKey:@"UNIXDevice"];
  } else if ([name isEqualToString:@"Eject"]) {
    [info setObject:[object humanReadableName] forKey:@"UNIXDevice"];
  }

  if (failed) {
    [info setObject:@"false" forKey:@"Success"];
  } else {
    [info setObject:@"true" forKey:@"Success"];
  }

  if ([status isEqualToString:@"Started"]) {
    [notificationCenter postNotificationName:OSEMediaOperationDidStartNotification
                                      object:self
                                    userInfo:info];
  } else {
    // "Completed" - operation was started by framework methods.
    // OSEMediaVolume* and OSEMediaOperation* notifications will be sent.
    // "Occured" - operation was performed without framework methods (outside)
    // of application. Only OSEMediaVolume* notification will be sent.
    if ([name isEqualToString:@"Mount"] || [name isEqualToString:@"Unmount"]) {
      [info setObject:[object UNIXDevice] forKey:@"UNIXDevice"];

      if ([name isEqualToString:@"Mount"] && !failed) {
        if ([object mountPoints].count > 0) {
          [info setObject:[object mountPoints] forKey:@"MountPoint"];
        }
        [notificationCenter postNotificationName:OSEMediaVolumeDidMountNotification
                                          object:self
                                        userInfo:info];
      } else if ([name isEqualToString:@"Unmount"] && !failed) {
        NSString *mp = [object mountPoints][0];

        // If "MountPoint" property of NX*Volume already updated
        // get value saved into "OldMountPoint" property
        if (!mp || [mp isEqualToString:@""]) {
          mp = [object propertyForKey:@"OldMountPoint" interface:FS_INTERFACE];
        }
        [info setObject:mp forKey:@"MountPoint"];
        [notificationCenter postNotificationName:OSEMediaVolumeDidUnmountNotification
                                          object:self
                                        userInfo:info];
      }
    }

    if ([status isEqualToString:@"Completed"]) {
      [notificationCenter postNotificationName:OSEMediaOperationDidEndNotification
                                        object:self
                                      userInfo:info];
    }
  }
}

//-------------------------------------------------------------------------------
#pragma mark - MediaManager protocol
//-------------------------------------------------------------------------------
// Returns list of all mounted diskVolumes.
// Scan through local diskVolumes cache to get loop diskVolumes (diskVolumes without drive)
- (NSArray *)mountedVolumes
{
  NSMutableArray *mountedVolumes = [NSMutableArray new];

  for (OSEUDisksVolume *volume in [volumes allValues]) {
    if ([volume isMounted]) {
      [mountedVolumes addObject:volume];
    }
  }

  return mountedVolumes;
}

// 'path' is not necessary a mount point, it can be some path inside
// mounted filesystem
- (NXTFSType)filesystemTypeAtPath:(NSString *)filesystemPath
{
  OSEUDisksVolume *volume = [self _mountedVolumeForPath:filesystemPath];

  if (volume == nil) {
    return -1;
  }

  return [volume filesystemType];
}

// 'path' is not necessary a mount point, it can be some path inside
// mounted filesystem
- (NSString *)mountPointForPath:(NSString *)filesystemPath
{
  return [[self _mountedVolumeForPath:filesystemPath] mountPoints][0];
}

// Unmount filesystem mounted at subpath of 'path'.
// Unmount only if FS resides on removable drive.
// Async - OK.
- (void)unmountRemovableVolumeAtPath:(NSString *)path
{
  OSEUDisksVolume *volume = [self _mountedVolumeForPath:path];

  if (volume == nil) {
    return;
  }

  [volume unmount:NO];
}

- (NSArray *)_mountNewRemovableVolumesAndWait:(BOOL)wait
{
  NSMutableArray *mountPoints = [[NSMutableArray alloc] init];

  for (OSEUDisksDrive *drive in [drives allValues]) {
    if ([drive isRemovable]) {
      [mountPoints addObjectsFromArray:[drive mountVolumes:wait]];
    }
  }

  // Loop devices is always removable and have no drives
  for (OSEUDisksVolume *volume in [volumes allValues]) {
    if ([volume isLoopVolume] && [volume isFilesystem]) {
      [volume mount:wait];
    }
  }

  return [mountPoints autorelease];
}
// ...mounts the disk asynchronously and returns immediately
// Async - OK.
// NSWorkspace
- (void)checkForRemovableMedia
{
  [self _mountNewRemovableVolumesAndWait:NO];
}

// Check for unmounted removables and mount them.
// Returns list of pathnames to newly mounted diskVolumes (operation is synchronous).
// Sync - OK.
// NSWorkspace
- (NSArray *)mountNewRemovableMedia
{
  return [self _mountNewRemovableVolumesAndWait:YES];
}

// Returns list of pathnames to mount points of already mounted diskVolumes.
// NSWorkspace
- (NSArray *)mountedRemovableMedia
{
  NSArray *mountedVolumes = [self mountedVolumes];
  NSMutableArray *mountPaths = [NSMutableArray new];

  for (OSEUDisksVolume *volume in mountedVolumes) {
    NSDebugLLog(@"udisks", @"OSEUDisksAdaptor: mountedRemovableMedia check: %@ (%@)", [volume mountPoints],
                [[[[volume drive] properties] objectForKey:@"org.freedesktop.UDisks2.Drive"]
                    objectForKey:@"Id"]);

    if ([volume isFilesystem] &&
        ([[volume drive] isRemovable] || [[volume drive] isMediaRemovable])) {
      [mountPaths addObject:[volume mountPoints]];
    }
  }

  NSDebugLLog(@"udisks", @"Adaptor: mountedRemovableMedia: %@", mountPaths);

  return mountPaths;
}

// Unmounts and ejects device mounted at 'path'.
// Async - OK.
// NSWorkspace
- (void)unmountAndEjectDeviceAtPath:(NSString *)path
{
  OSEUDisksVolume *volume, *loopMaster;
  OSEUDisksDrive *drive;

  // 1. Found volume mounted at subpath of 'path'
  volume = [self _mountedVolumeForPath:path];

  // 2. Found drive which contains volume
  if (![volume isLoopVolume]) {
    drive = [drives objectForKey:[volume driveObjectPath]];
    // 3. Unmount all diskVolumes mounted from that drive.
    [drive unmountVolumesAndDetach];
  } else {
    // 3. Get loop master volume
    loopMaster = [volume masterVolume];
    NSDebugLLog(@"UDisks", @"Eject loop volume: %@ (%@)", loopMaster, volume);
    // 4. Unmount all loop diskVolumes for that master
    if (loopMaster != volume) {
      for (OSEUDisksVolume *vol in [volumes allValues]) {
        NSDebugLLog(@"UDisks", @">>%@", [vol UNIXDevice]);
        if ([vol masterVolume] == loopMaster) {
          NSDebugLLog(@"UDisks", @"Unmount volume %@", [vol UNIXDevice]);
          [vol unmount:NO];
        }
      }
    }
    // 5. Delete loop master volume
    // NSString *objectPath;
    // if ([volume isLoopVolume] && !loopMaster)
    //   objectPath = [volume objectPath];
    // else
    //   objectPath = [loopMaster objectPath];

    // NSLog(@"Now delete loop device: %@", objectPath);
    // [self unsetLoop:objectPath];
  }
}

// Operation is synchronous.
// Async - OK.
- (void)ejectAllRemovables
{
  // Loops first...
  for (OSEUDisksVolume *volume in [volumes allValues]) {
    if ([volume isLoopVolume]) {
      [volume unmount:YES];
    }
  }

  //...drives then
  for (OSEUDisksDrive *drive in [drives allValues]) {
    if ([drive isRemovable]) {
      [drive unmountVolumesAndDetach];
    }
  }
}

- (BOOL)mountImageMediaFileAtPath:(NSString *)imageFile
{
  // return [self setLoopToFileAtPath:imageFile];
  return NO;
}

#if 0
//-- Loops

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <gio/gunixfdlist.h>
- (BOOL)setLoopToFileAtPath:(NSString *)imageFile
{
  GVariant *options;
  GVariantBuilder builder;
  GError *error;
  
  // Map image file in read only mode
  g_variant_builder_init (&builder, G_VARIANT_TYPE_VARDICT);
  g_variant_builder_add(&builder, "{sv}",
                        "read-only", g_variant_new_boolean(TRUE));
  options = g_variant_builder_end(&builder);
  g_variant_ref_sink(options);

  gchar *resulting_object_path;
  UDisksObject *resulting_object;
  GUnixFDList *fd_list;
  gint fd;
  gboolean rc;
  
  fd = open ([imageFile cString], O_RDONLY);
  fd_list = g_unix_fd_list_new_from_array(&fd, 1); /* adopts the fd */
  
  rc = udisks_manager_call_loop_setup_sync(udisks_client_get_manager(udisks_client),
                                           g_variant_new_handle(0),
                                           options,
                                           fd_list,
                                           &resulting_object_path,
                                           NULL,                       /* out_fd_list */
                                           NULL,                       /* GCancellable */
                                           &error);
  g_object_unref(fd_list);
  udisks_client_settle(udisks_client);

  resulting_object = UDISKS_OBJECT(g_dbus_object_manager_get_object(udisks_client_get_object_manager (udisks_client), (resulting_object_path)));
  // g_print ("Mapped file %s as %s.\n",
  //          [imageFile cString],
  //          udisks_block_get_device(udisks_object_get_block(resulting_object)));
  g_object_unref(resulting_object);
  
  g_free(resulting_object_path);

  return rc;
}

- (BOOL)unsetLoop:(NSString *)objectPath
{
  UDisksObject *object;
  GError       *error = NULL;
  gboolean     rc;

  object = udisks_client_get_object(udisks_client, [objectPath cString]);

  rc = udisks_loop_call_delete_sync(udisks_object_peek_loop(object),
                                    g_variant_new("a{sv}", NULL), /* GVariant */
                                    NULL,                         /* GCancellable */
                                    &error);
  g_object_unref(object);

  return rc;
}
#endif

//-------------------------------------------------------------------------------
#pragma mark - DBus_ObjectManager protocol
//-------------------------------------------------------------------------------

- (NSArray *)GetManagedObjects
{
  OSEBusMessage *message;
  id result;

  message = [[OSEBusMessage alloc] initWithService:self
                                         interface:@"org.freedesktop.DBus.ObjectManager"
                                            method:@"GetManagedObjects"];
  result = [message send];

  [message release];

  return result;
}

@end

