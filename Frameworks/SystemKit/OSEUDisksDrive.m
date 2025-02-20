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
#include "Foundation/NSString.h"

#import "OSEUDisksDrive.h"
#import "OSEUDisksVolume.h"

@implementation OSEUDisksDrive

//-------------------------------------------------------------------------------
#pragma mark - UDisksMedia protocol
//-------------------------------------------------------------------------------
- (void)_dumpProperties
{
  NSString *fileName;
  NSMutableDictionary *props = [_properties mutableCopy];
  NSDictionary *_volumes = [_udisksAdaptor availableVolumesForDrive:_objectPath];

  fileName =
      [NSString stringWithFormat:@"Library/Workspace/Drive_%@", [_objectPath lastPathComponent]];
  if (_volumes) {
    [props setObject:_volumes forKey:@"_VolumeObjects"];
  }
  [props writeToFile:fileName atomically:YES];
  [props release];
}

- (void)dealloc
{
  NSDebugLLog(@"dealloc", @"OSEUDisksDrive -dealloc %@", self.objectPath);
  [_properties release];
  [_objectPath release];
  // [_volumes release];

  [super dealloc];
}

- (id)initWithProperties:(NSDictionary *)properties
              objectPath:(NSString *)path
                 adaptor:(OSEUDisksAdaptor *)adaptor
{
  self = [super init];

  _properties = [properties mutableCopy];
  _objectPath = [path copy];
  // _volumes = [[NSMutableDictionary alloc] init];
  self.udisksAdaptor = adaptor;

  notificationCenter = [NSNotificationCenter defaultCenter];

  // [self _dumpProperties];

  return self;
}

- (void)setSignalsObserving
{
  // Do nothing
}

- (void)removeSignalsObserving
{
  // Do nothing
}

- (void)setProperty:(NSString *)property value:(NSString *)value interfaceName:(NSString *)interface
{
  NSMutableDictionary *interfaceDict;

  // Get dictionary which contains changed property
  interfaceDict = [[_properties objectForKey:interface] mutableCopy];

  // Update property
  [interfaceDict setObject:value forKey:property];
  [_properties setObject:interfaceDict forKey:interface];
  [interfaceDict release];

  // [self _dumpProperties];
}

- (void)removeProperties:(NSArray *)props interfaceName:(NSString *)interface
{
  NSDebugLLog(@"UDisks", @"Drive: remove properties: %@ for interface: %@", props, interface);
}

- (id)propertyForKey:(NSString *)key interface:(NSString *)interface
{
  NSDictionary *interfaceDict;
  id value;

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
#pragma mark - Attributes
//-------------------------------------------------------------------------------

// vendor, model
- (NSString *)humanReadableName
{
  NSString *name;

  // name = [self propertyForKey:@"Media" interface:DRIVE_INTERFACE];
  // if (!name || [name isEqualToString:@""]) {
    name = [self propertyForKey:@"Model" interface:DRIVE_INTERFACE];
  // }

  return name;
}

- (BOOL)isRemovable
{
  return [self boolPropertyForKey:@"Removable" interface:DRIVE_INTERFACE];
}

- (BOOL)isEjectable
{
  return [self boolPropertyForKey:@"Ejectable" interface:DRIVE_INTERFACE];
}

- (BOOL)canPowerOff
{
  return [self boolPropertyForKey:@"CanPowerOff" interface:DRIVE_INTERFACE];
}

- (BOOL)hasMedia
{
  return [self boolPropertyForKey:@"MediaAvailable" interface:DRIVE_INTERFACE];
}

// valuable for optical disks
- (BOOL)isOptical
{
  return [self boolPropertyForKey:@"Optical" interface:DRIVE_INTERFACE];
}

- (BOOL)isMediaRemovable
{
  return [self boolPropertyForKey:@"MediaRemovable" interface:DRIVE_INTERFACE];
}

- (BOOL)isOpticalBlank
{
  return [self boolPropertyForKey:@"OpticalBlank" interface:DRIVE_INTERFACE];
}

- (NSNumber *)numberOfAudioTracks
{
  return [self propertyForKey:@"OpticalNumAudioTracks" interface:DRIVE_INTERFACE];
}

- (NSNumber *)numberOfDataTracks
{
  return [self propertyForKey:@"OpticalNumDataTracks" interface:DRIVE_INTERFACE];
}

//-------------------------------------------------------------------------------
#pragma mark - Actions
//-------------------------------------------------------------------------------
- (NSArray *)mountedVolumes
{
  NSDictionary *_volumes = [_udisksAdaptor availableVolumesForDrive:_objectPath];
  NSMutableArray *mountedVolumes = [NSMutableArray array];
  OSEUDisksVolume *volume;

  for (NSString *key in [_volumes allKeys]) {
    volume = _volumes[key];
    if ([volume isMounted]) {
      [mountedVolumes addObject:volume];
    }
  }

  NSDebugLLog(@"UDisks", @"Drive: %@ mountedVolumes: %@", [_objectPath lastPathComponent],
              mountedVolumes);

  return mountedVolumes;
}

- (NSArray *)mountVolumes:(BOOL)wait
{
  NSDictionary *_volumes = [_udisksAdaptor availableVolumesForDrive:_objectPath];
  NSMutableArray *mountPoints = [NSMutableArray array];
  OSEUDisksVolume *volume;
  NSString *mp;

  NSDebugLLog(@"UDisks", @"OSEOSEUDisksDrive: %@ mountVolumes: %@", _objectPath, _volumes);

  for (NSString *key in [_volumes allKeys]) {
    volume = _volumes[key];
    if (volume != nil && (mp = [volume mount:wait]) != nil) {
      [mountPoints addObject:mp];
    }
  }

  return mountPoints;
}

- (BOOL)unmountVolumes:(BOOL)wait
{
  NSArray *mountedVolumes = [self mountedVolumes];

  for (OSEUDisksVolume *volume in mountedVolumes) {
    if (![volume unmount:wait]) {
      return NO;
    }
  }

  return YES;
}

NSLock *driveLock = nil;
- (void)volumeDidUnmount:(NSNotification *)notif
{
  if (!driveLock) {
    driveLock = [[NSLock alloc] init];
  }

  if ([driveLock tryLock] == NO) {
    NSLog(@"OSEUDisksDrive-volumeDidUnmount - failed to get lock!");
    return;
  }

  if (needsDetach) {
    NSString *volumeDevice = [[notif userInfo] objectForKey:@"UNIXDevice"];
    for (OSEUDisksVolume *volume in mountedVolumesToDetach) {
      // NSLog(@"Volume2Detach: %@", [volume UNIXDevice]);
      if ([[volume UNIXDevice] isEqualToString:volumeDevice]) {
        // NSLog(@"Volume detached: %@", [volume UNIXDevice]);
        [mountedVolumesToDetach removeObject:volume];
        break;
      }
    }

    // NSLog(@"OSEOSEUDisksDrive: mounted volumes to detach: %@", mountedVolumesToDetach);
  }
  [driveLock unlock];
}

// 1. Put mountedVolumes into cache (needsDetachMountedVolumes). Set needsDetach = YES.
// 2. Send OSEDiskOperationDidStart for drive.
// 3. Unmount volumes. Each volume sends DidStart/DidEnd for volume.
// 4. Catch DidEnd for volume and remove volume from cache.
// 5. When cache become empty proceed with eject: and powerOff:.
// Sync - OK.
// Not implemented
- (void)unmountVolumesAndDetach
{
  NSArray *mountedVolumes;
  NSString *message = nil;
  NSString *driveName;

  NSDebugLLog(@"UDisks", @"OSEOSEUDisksDrive -unmountVolumesAndDetach: %@.",
              self.humanReadableName);

  // 1.
  mountedVolumes = [self mountedVolumes];
  if (mountedVolumes == nil || mountedVolumes.count == 0) {
    NSDebugLLog(@"UDisks", @"OSEOSEUDisksDrive -unmountVolumesAndDetach nothing to unmount.");
    return;
  }
  // mountedVolumesToDetach = [[NSMutableArray alloc] initWithArray:mountedVolumes];
  // needsDetach = YES;

  // 2.1 Subscribe to notification
  // [notificationCenter addObserver:self
  //                        selector:@selector(volumeDidUnmount:)
  //                            name:OSEMediaVolumeDidUnmountNotification
  //                          object:_udisksAdaptor];

  // 3.
  // [self unmountVolumes:YES];
  // if ([mountedVolumesToDetach count] <= 0) {
  if ([self unmountVolumes:YES] != NO) {
    BOOL canPowerOff = [self canPowerOff];

    // NSLog(@"%@ - Ejectable: %@, CanPowerOff: %@", [self humanReadableName],
    //       [self isEjectable] ? @"Yes" : @"No", canPowerOff ? @"Yes" : @"No");
    if ([self isEjectable] != NO || [self hasMedia]) {
      [self eject:YES];
    }
    if (canPowerOff != NO) {
      [self powerOff:YES];
    }

    driveName = [self humanReadableName];
    if ([self isEjectable] == NO && [self canPowerOff] == NO) {
      message = [NSString stringWithFormat:@"You can safely remove the card '%@' now.", driveName];
    } else if ([self isOptical] == NO) {
      message = [NSString stringWithFormat:@"You can safely disconnect '%@' now.", driveName];
    }
    if (message) {
      // No background operations at this point but we notify Workspace about media detach.
      [_udisksAdaptor operationWithName:@"Detach"
                                 object:self
                                 failed:NO
                                 status:@"Completed"
                                  title:@"Eject"
                                message:message];
    }
  }

  // [[NSNotificationCenter defaultCenter] removeObserver:self];
  // needsDetach = NO;
  // [mountedVolumesToDetach release];

  // // 4. & 5. are in [self volumeDidUnmount:].
}

// Not implemented
- (BOOL)eject:(BOOL)wait
{
  NSString *message;
  OSEBusMessage *busMessage;
  id result = nil;
  BOOL isFailed = NO;

  if ([self isEjectable] == NO) {
    return NO;
  }

  NSDebugLLog(@"UDisks", @"OSEOSEUDisksDrive: eject: %@", _objectPath);

  message = [NSString stringWithFormat:@"Ejecting drive %@", [self humanReadableName]];
  [_udisksAdaptor operationWithName:@"Eject"
                             object:self
                             failed:NO
                             status:@"Started"
                              title:@"Eject"
                            message:message];

  if (wait) {
    busMessage = [[OSEBusMessage alloc]
        initWithServiceName:_udisksAdaptor.serviceName
                     object:_objectPath
                  interface:DRIVE_INTERFACE
                     method:@"Eject"
                  arguments:@[ @[ @{@"auth.no_user_interaction" : @"b:true"} ] ]
                  signature:@"a{sv}"];
    result = [busMessage sendWithConnection:_udisksAdaptor.connection];
    [busMessage release];

    NSDebugLLog(@"UDisks", @"OSEUDisksDrive -eject result: %@", result);
    if ([result isKindOfClass:[NSError class]]) {
      message = [(NSError *)result userInfo][@"Description"];
      isFailed = YES;
    } else {
      message = [NSString stringWithFormat:@"Eject of %@ completed [OSEUDisksDrive eject:]",
                                           [self humanReadableName]];
    }
  } else {
    NSDebugLLog(@"UDisks", @"Warning: Asynchronous drive ejecting is not implemented!");
    message = [NSString stringWithFormat:@"Eject of %@ completed successfuly [OSEUDisksDrive eject:]",
                                         [self humanReadableName]];
  }

  [_udisksAdaptor operationWithName:@"Eject"
                             object:self
                             failed:isFailed
                             status:@"Completed"
                              title:@"Eject"
                            message:message];

  return !isFailed;
}

// Not implemented
- (BOOL)powerOff:(BOOL)wait
{
  NSString *message;
  OSEBusMessage *busMessage;
  id result = nil;
  BOOL isFailed = NO;

  if (![self canPowerOff]) {
    return NO;
  }

  NSDebugLLog(@"UDisks", @"OSEOSEUDisksDrive: powerOff the drive %@", _objectPath);

  message = [NSString stringWithFormat:@"Powering off the drive %@", [self humanReadableName]];
  [_udisksAdaptor operationWithName:@"PowerOff"
                             object:self
                             failed:NO
                             status:@"Started"
                              title:@"PowerOff"
                            message:message];
  
  if (wait) {
    busMessage = [[OSEBusMessage alloc]
        initWithServiceName:_udisksAdaptor.serviceName
                     object:_objectPath
                  interface:DRIVE_INTERFACE
                     method:@"PowerOff"
                  arguments:@[ @[ @{@"auth.no_user_interaction" : @"b:true"} ] ]
                  signature:@"a{sv}"];
    result = [busMessage sendWithConnection:_udisksAdaptor.connection];
    [busMessage release];

    NSDebugLLog(@"UDisks", @"OSEUDisksDrive -poweroff result: %@", result);
    if ([result isKindOfClass:[NSError class]]) {
      message = [(NSError *)result userInfo][@"Description"];
      isFailed = YES;
    } else {
      message = [NSString
          stringWithFormat:@"Drive `%@` Power Off completed successfuly [OSEUDisksDrive powerOff:].", [self humanReadableName]];
    }
  } else {
    NSDebugLLog(@"UDisks", @"Warning: Asynchronous Drive PowerOff is not implemented!");
  }

  [_udisksAdaptor operationWithName:@"PowerOff"
                             object:self
                             failed:isFailed
                             status:@"Completed"
                              title:@"PowerOff"
                            message:message];

  return !isFailed;
}

@end
