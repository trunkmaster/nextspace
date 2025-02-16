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

#import <SystemKit/OSEBusMessage.h>
#include "Foundation/NSArray.h"

#import "OSEUDisksDrive.h"
#import "OSEUDisksVolume.h"

@implementation OSEUDisksVolume

- (void)_dumpProperties
{
  NSString *fileName;
  NSMutableDictionary *props = [_properties mutableCopy];

  fileName = [NSString stringWithFormat:@"_Volume_%@", [_objectPath lastPathComponent]];
  [props writeToFile:fileName atomically:YES];
  [props release];
}


- (id)_propertyValueWithName:(NSString *)propertyName section:(NSString *)sectionName
{
  OSEBusMessage *message;
  id result = nil;

  message = [[OSEBusMessage alloc] initWithServiceName:_udisksAdaptor.serviceName
                                                object:_objectPath
                                             interface:@"org.freedesktop.DBus.Properties"
                                                method:@"Get"
                                             arguments:@[ sectionName, propertyName ]
                                             signature:@"ss"];
  result = [message sendWithConnection:_udisksAdaptor.connection];
  [message release];

  if ([result isKindOfClass:[NSError class]]) {
    return nil;
  }

  return result;
}

- (void)handlePropertiesChangedSignal:(NSDictionary *)info
{
  id objectPath;
  // sa{sv}as
  NSArray *message;
  NSString *interface;  // s
  NSArray *properties;  // a{sv}
  NSArray *change;      // as
  NSMutableDictionary *parsedProperties;

  // Sanity checks
  objectPath = info[@"ObjectPath"];
  if ([objectPath isKindOfClass:[NSString class]] &&
      [objectPath isEqualToString:_objectPath] == NO) {
    NSDebugLLog(@"UDisks", @"OSEUDisksVolume (%@) PropertiesChanged: is not mine, skipping...",
                _objectPath);
    return;
  }
  message = info[@"Message"];
  if (message == nil || message.count < 3) {
    NSDebugLLog(@"UDisks",
                @"OSEUDisksVolume (%@) PropertiesChanged: wrong number of elements inside "
                @"`Message`. It's %lu must be 3.",
                _objectPath, message.count);
    return;
  }

  NSDebugLLog(@"UDisks", @"OSEUDisksVolume (%@) \e[1mPropertiesChanged\e[0m: %@", _objectPath,
              info);
  // sa{sv}as
  interface = message[0];   // s
  properties = message[1];  // a{sv}
  change = message[2];      // as

  if (properties.count > 0) {
    // Update/add properties
    NSMutableDictionary *currInterfaceProperties = _properties[interface];
    parsedProperties = [_udisksAdaptor _parsePropertiesSection:properties];
    if (currInterfaceProperties != nil) {
      // update properties
      NSDebugLLog(@"UDisks", @"OSEUDisksVolume (%@) updating properties for %@: %@", _objectPath,
                  interface, parsedProperties);
      for (NSString *propName in parsedProperties.allKeys) {
        currInterfaceProperties[propName] = parsedProperties[propName];
      }
    } else {
      // add interface with properties
      NSDebugLLog(@"UDisks", @"OSEUDisksVolume (%@) adding interface %@", _objectPath, interface);
      _properties[interface] = parsedProperties;
    }

    // Send notification first if needed
    for (NSDictionary *prop in properties) {
      for (NSString *key in prop.allKeys) {
        if ([key isEqualToString:@"MountPoints"]) {
          NSArray *mps = prop[key];
          if (mps && [mps isKindOfClass:[NSArray class]] && mps.count > 0) {
            [[NSNotificationCenter defaultCenter]
                postNotificationName:OSEMediaVolumeDidMountNotification
                              object:_udisksAdaptor
                            userInfo:@{@"MountPoint" : mps.firstObject}];
          } else {
            [[NSNotificationCenter defaultCenter]
                postNotificationName:OSEMediaVolumeDidUnmountNotification
                              object:_udisksAdaptor
                            userInfo:@{}];
          }
        }
      }
    }
  }

  // proceed with existing properties change
  for (NSString *propName in change) {
    id propValue = [self _propertyValueWithName:propName section:interface];
    if (propValue != nil) {
      _properties[interface][propName] = propValue;
    }
  }

  [self _dumpProperties];
  NSDebugLLog(@"UDisks", @"OSEUDisksVolume - handlePropertiesChanged - END");
}

//-------------------------------------------------------------------------------
#pragma mark - UDisksObject protocol
//-------------------------------------------------------------------------------
- (void)dealloc
{
  NSDebugLLog(@"dealloc", @"OSEUDisksVolume -dealloc %@", self.objectPath);

  [self removeSignalsObserving];
  [_properties release];
  [_objectPath release];

  [super dealloc];
}

- (id)initWithProperties:(NSDictionary *)properties
              objectPath:(NSString *)path
                 adaptor:(OSEUDisksAdaptor *)adaptor
{
  self = [super init];

  _properties = [properties mutableCopy];
  _objectPath = [path copy];

  self.udisksAdaptor = adaptor;
  [self setSignalsObserving];
  
  // [self _dumpProperties];

  return self;
}

- (void)setSignalsObserving
{
  [_udisksAdaptor.connection addSignalObserver:self
                                      selector:@selector(handlePropertiesChangedSignal:)
                                        signal:@"PropertiesChanged"
                                        object:self.objectPath
                                     interface:@"org.freedesktop.DBus.Properties"];
}

- (void)removeSignalsObserving
{
  // UDisksAdaptor could be deallocated first
  if (_udisksAdaptor) {
    [_udisksAdaptor.connection removeSignalObserver:self
                                             signal:@"PropertiesChanged"
                                             object:self.objectPath
                                          interface:@"org.freedesktop.DBus.Properties"];
  }
}

// Change _properties
- (void)setProperty:(NSString *)property value:(NSString *)value interfaceName:(NSString *)interface
{
  NSMutableDictionary *interfaceDict;

  // Get dictionary which contains changed property
  if (!(interfaceDict = [[_properties objectForKey:interface] mutableCopy])) {
    interfaceDict = [NSMutableDictionary new];
  } else if ([[interfaceDict objectForKey:property] isEqualToString:value]) {
    // Protect from generating actions on double-setting _properties
    return;
  }

  if ([property isEqualToString:@"MountPoints"] && [interfaceDict objectForKey:@"MountPoints"]) {
    [interfaceDict setObject:[interfaceDict objectForKey:@"MountPoints"] forKey:@"OldMountPoint"];
  }

  // Update property
  if (value) {
    [interfaceDict setObject:value forKey:property];
  }
  [_properties setObject:interfaceDict forKey:interface];
  [interfaceDict release];

  // Mounted state of volume changed
  if ([property isEqualToString:@"MountPoints"]) {
    if ([value isEqualToString:@""]) {
      [_udisksAdaptor operationWithName:@"Unmount"
                                 object:self
                                 failed:NO
                                 status:@"Occured"
                                  title:@"Unmount"
                                message:@"Volume unmounted at system level."];
    } else {
      [_udisksAdaptor operationWithName:@"Mount"
                                 object:self
                                 failed:NO
                                 status:@"Occured"
                                  title:@"Mount"
                                message:@"Volume mounted at system level."];
    }
  }

  // Optical _drive gets media or block device was formatted.
  if ([property isEqualToString:@"IdUsage"] && [value isEqualToString:@"filesystem"]) {
    [self mount:NO];
  }

  // [self _dumpProperties];
}

- (void)removeProperties:(NSArray *)props interfaceName:(NSString *)interface
{
  NSDebugLLog(@"UDisks", @"Volume: remove _properties: %@ for interface: %@", props, interface);
}

- (NSString *)propertyForKey:(NSString *)key interface:(NSString *)interface
{
  NSDictionary *interfaceDict;
  NSString *value;

  if (interface) {
    interfaceDict = [_properties objectForKey:interface];
    value = [interfaceDict objectForKey:key];
  } else {
    value = [_properties objectForKey:key];
  }

  return value;
}

- (BOOL)boolPropertyForKey:(NSString *)key interface:(NSString *)interface
{
  id propertyValue = [self propertyForKey:key interface:interface];
  BOOL boolValue = NO;

  if ([propertyValue isKindOfClass:[NSNumber class]]) {
    boolValue = [propertyValue boolValue];
  }
  return boolValue;
}

//-------------------------------------------------------------------------------
#pragma mark - Parent objects
//-------------------------------------------------------------------------------
// Master volume represents _drive partition table e.g. '/dev/sda'.
- (OSEUDisksVolume *)masterVolume
{
  NSString *masterPath;

  masterPath = [self propertyForKey:@"Table" interface:PARTITION_INTERFACE];

  if (!masterPath)
    return nil;

  return [_udisksAdaptor objectWithUDisksPath:masterPath];
}

- (NSString *)driveObjectPath
{
  return [self propertyForKey:@"Drive" interface:BLOCK_INTERFACE];
}

//-------------------------------------------------------------------------------
#pragma mark - General properties
//-------------------------------------------------------------------------------
- (NSString *)UUID
{
  return [self propertyForKey:@"IdUUID" interface:BLOCK_INTERFACE];
}

- (NSString *)UNIXDevice
{
  return [self propertyForKey:@"Device" interface:BLOCK_INTERFACE];
}

- (NSNumber *)size
{
  return [self propertyForKey:@"Size" interface:BLOCK_INTERFACE];
}

- (BOOL)isSystem
{
  if ([self boolPropertyForKey:@"HintSystem" interface:BLOCK_INTERFACE] && ![self isLoopVolume] &&
      [self masterVolume] != self &&
      ![self boolPropertyForKey:@"HintAuto" interface:BLOCK_INTERFACE]) {
    return YES;
  }

  return NO;
}

// Partition
- (BOOL)hasPartition
{
  NSDictionary *interfaceDict = [_properties objectForKey:PARTITION_INTERFACE];
  if (interfaceDict != nil && interfaceDict.allKeys.count > 0) {
    return YES;
  }
  return NO;
}
- (NSString *)partitionType
{
  return [self propertyForKey:@"Type" interface:PARTITION_INTERFACE];
}

- (NSNumber *)partitionNumber
{
  return [self propertyForKey:@"Number" interface:PARTITION_INTERFACE];
}

- (NSNumber *)partitionSize
{
  return [self propertyForKey:@"Size" interface:PARTITION_INTERFACE];
}

// Filesystem
- (BOOL)isFilesystem
{
  NSString *usage = [self propertyForKey:@"IdUsage" interface:BLOCK_INTERFACE];
  // BOOL isFilesystem = [usage isEqualToString:@"filesystem"];
  BOOL isFilesystem = NO;

  // NSDebugLLog(@"UDisks", @"isFilesystem: %@ = %@", _objectPath, [_properties objectForKey:FS_INTERFACE]);

  if (([_properties objectForKey:FS_INTERFACE] != nil) || ([usage isEqualToString:@"filesystem"] != NO)) {
    isFilesystem = YES;
  }

  return isFilesystem;
}

- (NXTFSType)filesystemType
{
  NSString *fsType = [self propertyForKey:@"IdType" interface:BLOCK_INTERFACE];

  // Return NXTFSType filesystem name
  if ([fsType isEqualToString:@"ext2"] || [fsType isEqualToString:@"ext3"] ||
      [fsType isEqualToString:@"ext4"]) {
    return NXTFSTypeEXT;
  } else if ([fsType isEqualToString:@"xfs"]) {
    return NXTFSTypeXFS;
  } else if ([fsType isEqualToString:@"msdosfs"] || [fsType isEqualToString:@"vfat"] ||
             [fsType isEqualToString:@"fat"]) {
    return NXTFSTypeFAT;
  } else if ([fsType isEqualToString:@"ntfs"]) {
    return NXTFSTypeNTFS;
  } else if ([fsType isEqualToString:@"iso9660"]) {
    return NXTFSTypeISO;
  } else if ([fsType isEqualToString:@"ufs"]) {
    return NXTFSTypeUFS;
  } else if ([fsType isEqualToString:@"udf"]) {
    return NXTFSTypeUDF;
  } else if ([fsType isEqualToString:@"swap"]) {
    return NXTFSTypeSwap;
  }

  return -1;
}

- (NSString *)filesystemName
{
  NSString *name = [self propertyForKey:@"IdType" interface:BLOCK_INTERFACE];

  if (name == nil || [name isEqualToString:@""]) {
    return @"Unknown";
  }
  return name;
}

- (NSString *)label
{
  return [self propertyForKey:@"IdLabel" interface:BLOCK_INTERFACE];
}

- (NSString *)mountPoint
{
  NSArray *points = [self propertyForKey:@"MountPoints" interface:FS_INTERFACE];

  if (points && points.count > 0) {
    return points.firstObject;
  }

  return nil;
}

- (BOOL)isMounted
{
  NSString *mountPoint = [self mountPoint];

  // Don't call [self isFilesystem] because CD has IdUsage=""
  if (mountPoint == nil || [mountPoint isEqualToString:@""]) {
    return NO;
  }

  return YES;
}

- (BOOL)isWritable
{
  return ![self boolPropertyForKey:@"ReadOnly" interface:BLOCK_INTERFACE];
}

// OSEOSEUDisksVolume which represents mapped image file
- (BOOL)isLoopVolume
{
  NSArray *loopProperties = [_properties objectForKey:LOOP_INTERFACE];

  return (loopProperties != nil || loopProperties.count > 0);
}

//-------------------------------------------------------------------------------
#pragma mark - Actions
//-------------------------------------------------------------------------------

- (NSString *)mount:(BOOL)wait
{
  NSString *message;
  OSEBusMessage *busMessage;
  id result = nil;

  if (!self.isFilesystem || self.isMounted || self.isSystem) {
    return nil;
  }

  NSDebugLLog(@"UDisks", @"OSEOSEUDisksVolume: mount: %@", _objectPath);

  message = [NSString stringWithFormat:@"Mounting volume %@", [self UNIXDevice]];
  [_udisksAdaptor operationWithName:@"Mount"
                             object:self
                             failed:NO
                             status:@"Started"
                              title:@"Mount"
                            message:message];

  busMessage = [[OSEBusMessage alloc]
      initWithServiceName:_udisksAdaptor.serviceName
                   object:_objectPath
                interface:FS_INTERFACE
                   method:@"Mount"
                arguments:@[ @[ @{@"auth.no_user_interaction" : @"b:true"} ] ]
                signature:@"a{sv}"];
  if (wait) {
    result = [busMessage sendWithConnection:_udisksAdaptor.connection];
    NSDebugLLog(@"UDisks", @"OSEUDisksVolume -mount %@ result: %@", _objectPath, result);
    if ([result isKindOfClass:[NSError class]]) {
      message = [(NSError *)result userInfo][@"Description"];
      [_udisksAdaptor operationWithName:@"Mount"
                                 object:self
                                 failed:YES
                                 status:@"Completed"
                                  title:@"Mount"
                                message:message];
    } else {
      message = [NSString
          stringWithFormat:@"Mount of %@ completed at mount point %@", [self UNIXDevice], result];
      [_udisksAdaptor operationWithName:@"Mount"
                                 object:self
                                 failed:NO
                                 status:@"Completed"
                                  title:@"Mount"
                                message:message];
    }
    [busMessage release];
  } else {
    [busMessage sendAsyncWithConnection:_udisksAdaptor.connection];
    message = @"Asynchronous volume mounting has been called!";
    NSDebugLLog(@"UDisks", @"Warning: %@", message);
    [_udisksAdaptor operationWithName:@"Mount"
                               object:self
                               failed:NO
                               status:@"Completed"
                                title:@"Mount"
                              message:message];
    // `busMessage` should not be released here beacuse of async operation.
  }

  return result;
}

- (BOOL)unmount:(BOOL)wait
{
  NSString *message;
  OSEBusMessage *busMessage;
  id result = nil;
  BOOL isFailed = NO;

  if (!self.isFilesystem || !self.isMounted || self.isSystem) {
    return NO;
  }

  NSDebugLLog(@"UDisks", @"OSEUDisksVolume: unmount: %@", _objectPath);

  message = [NSString stringWithFormat:@"Unmounting volume %@", [self UNIXDevice]];
  [_udisksAdaptor operationWithName:@"Unmount"
                             object:self
                             failed:NO
                             status:@"Started"
                              title:@"Unmount"
                            message:message];

  busMessage = [[OSEBusMessage alloc]
      initWithServiceName:_udisksAdaptor.serviceName
                   object:_objectPath
                interface:FS_INTERFACE
                   method:@"Unmount"
                arguments:@[ @[ @{@"auth.no_user_interaction" : @"b:true"} ] ]
                signature:@"a{sv}"];

  if (wait) {
    result = [busMessage sendWithConnection:_udisksAdaptor.connection];
    [busMessage release];
    NSDebugLLog(@"UDisks", @"OSEUDisksVolume -unmount %@ result: %@", _objectPath, result);
    if ([result isKindOfClass:[NSError class]]) {
      message = [(NSError *)result userInfo][@"Description"];
      isFailed = YES;
    } else {
      message =
          [NSString stringWithFormat:@"Unmount of %@ completed successfully.", [self UNIXDevice]];
    }
  } else {
    [busMessage sendAsyncWithConnection:_udisksAdaptor.connection];
    message = @"Asynchronous volume un-mounting has been called!";
    NSDebugLLog(@"UDisks", @"Warning: %@", message);
    // `busMessage` should not be released here beacuse of async operation.
  }

  if (message) {
    [_udisksAdaptor operationWithName:@"Unmount"
                               object:self
                               failed:isFailed
                               status:@"Completed"
                                title:@"Unmount"
                              message:message];
  }

  return !isFailed;
}

@end
