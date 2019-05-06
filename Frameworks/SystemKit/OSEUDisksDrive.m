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

#ifdef WITH_UDISKS

#import <udisks/udisks.h>

#import <SystemKit/OSEUDisksDrive.h>

@implementation OSEUDisksDrive

- (void)_dumpProperties
{
  NSString *fileName;
  NSMutableDictionary *props = [properties mutableCopy];

  fileName = [NSString stringWithFormat:@"Library/Workspace/Drive_%@",
                       [objectPath lastPathComponent]];
  if (volumes)
    {
      [props setObject:volumes forKey:@"_VolumeObjects"];
    }
  [props writeToFile:fileName atomically:YES];
  [props release];
}

//-------------------------------------------------------------------------------
//--- UDisksMedia protocol
//-------------------------------------------------------------------------------
- (id)initWithProperties:(NSDictionary *)props
              objectPath:(NSString *)path
                 adaptor:(OSEUDisksAdaptor *)udisksAdaptor
{
  self = [super init];
  
  adaptor = udisksAdaptor;
  
  properties = [props mutableCopy];
  objectPath = [path copy];

  volumes = [[NSMutableDictionary alloc] init];

  notificationCenter = [NSNotificationCenter defaultCenter];

  // Collect missed volumes
  [volumes addEntriesFromDictionary:[adaptor availableVolumesForDrive:objectPath]];
  // Set myself as drive to volumes
  for (OSEUDisksVolume *volume in [volumes allValues])
    {
      [volume setDrive:self];
    }
  
  // [self _dumpProperties];

  return self;
}

- (void)setProperty:(NSString *)property
              value:(NSString *)value
      interfaceName:(NSString *)interface
{
  NSMutableDictionary *interfaceDict;

  // Get dictionary which contains changed property
  interfaceDict = [[properties objectForKey:interface] mutableCopy];
  
  // Update property
  [interfaceDict setObject:value forKey:property];
  [properties setObject:interfaceDict forKey:interface];
  [interfaceDict release];
  
  // [self _dumpProperties];
}

- (void)removeProperties:(NSArray *)props
           interfaceName:(NSString *)interface
{
  NSDebugLLog(@"udisks", @"Drive: remove properties: %@ for interface: %@",
              props, interface);
}

- (NSDictionary *)properties
{
  return properties;
}

- (NSString *)propertyForKey:(NSString *)key interface:(NSString *)interface
{
  NSDictionary *interfaceDict;
  NSString     *value;
  NSArray      *arrayValue;

  if (interface)
    {
      interfaceDict = [properties objectForKey:interface];
      value = [interfaceDict objectForKey:key];
    }
  else
    {
      value = [properties objectForKey:key];
    }

  if ((arrayValue = [value componentsSeparatedByString:@"\n"]))
    {
      if ([arrayValue count] > 1)
        value = [arrayValue componentsJoinedByString:@","];
      else
        value = [arrayValue objectAtIndex:0];
    }

  return value;
}

- (BOOL)boolPropertyForKey:(NSString *)key interface:(NSString *)interface
{
  if ([[self propertyForKey:key interface:interface] isEqualToString:@"true"])
    return YES;
  else
    return NO;
}

- (void)dealloc
{
  [properties release];
  [objectPath release];
  [volumes release];
  
  [super dealloc];
}

//-------------------------------------------------------------------------------
//--- Object network
//-------------------------------------------------------------------------------
- (NSDictionary *)volumes
{
  return volumes;
}

- (void)addVolume:(OSEUDisksVolume *)volume withPath:(NSString *)volumePath
{
  [volumes setObject:volume forKey:volumePath];
  // [self _dumpProperties];
}

- (void)removeVolumeWithKey:(NSString *)key
{
  [volumes removeObjectForKey:key];
}

- (NSString *)objectPath
{
  return objectPath;
}

//-------------------------------------------------------------------------------
//--- Attributes
//-------------------------------------------------------------------------------
- (NSString *)UNIXDevice
{
  return nil;
}

// vendor, model
- (NSString *)humanReadableName
{
  NSString *name;

  name = [self propertyForKey:@"Media" interface:DRIVE_INTERFACE];
  if (!name || [name isEqualToString:@""])
    {
      name = [self propertyForKey:@"Model" interface:DRIVE_INTERFACE];
    }
    
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

// valuable for optical disks
- (BOOL)isOptical
{
  return [self boolPropertyForKey:@"Optical" interface:DRIVE_INTERFACE];
}

- (BOOL)hasMedia
{
  return [self boolPropertyForKey:@"MediaAvailable" interface:DRIVE_INTERFACE];
}

- (BOOL)isMediaRemovable
{
  return [self boolPropertyForKey:@"MediaRemovable" interface:DRIVE_INTERFACE];
}

- (BOOL)isOpticalBlank
{
  return [self boolPropertyForKey:@"OpticalBlank" interface:DRIVE_INTERFACE];
}

- (NSString *)numberOfAudioTracks
{
  return [self propertyForKey:@"OpticalNumAudioTracks" interface:DRIVE_INTERFACE];
}

- (NSString *)numberOfDataTracks
{
  return [self propertyForKey:@"OpticalNumDataTracks" interface:DRIVE_INTERFACE];
}

//-------------------------------------------------------------------------------
//--- Actions
//-------------------------------------------------------------------------------
- (NSArray *)mountedVolumes
{
  NSMutableArray *mountedVolumes = [[NSMutableArray alloc] init];
  NSEnumerator   *e = [[volumes allValues] objectEnumerator];
  OSEUDisksVolume *volume;

  while ((volume = [e nextObject]) != nil)
    {
      if ([volume isMounted])
        {
          [mountedVolumes addObject:volume];
        }
    }
    
  NSDebugLLog(@"udisks", @"Drive: %@ mountedVolumes: %@",
              [objectPath lastPathComponent], mountedVolumes);
  
  return [mountedVolumes autorelease];
}

- (NSArray *)mountVolumes:(BOOL)wait
{
  NSMutableArray *mountPoints = [[NSMutableArray alloc] init];
  NSEnumerator   *e = [[volumes allValues] objectEnumerator];
  OSEUDisksVolume *volume;
  NSString       *mp;

  NSDebugLLog(@"udisks", @"OSEUDisksDrive: %@ mountVolumes: %@", objectPath, volumes);
  
  while ((volume = [e nextObject]) != nil)
    {
      if ((mp = [volume mount:wait]) != nil)
        {
          [mountPoints addObject:mp];
        }
    }

  return [mountPoints autorelease];
}

- (BOOL)unmountVolumes:(BOOL)wait
{
  NSEnumerator   *e = [[volumes allValues] objectEnumerator];
  OSEUDisksVolume *volume;

  NSDebugLLog(@"udisks", @"Drive: unmount volumes: %@", volumes);
  
  while ((volume = [e nextObject]) != nil)
    {
      if (![volume unmount:wait])
        {
          return NO;
        }
    }

  return YES;
}

NSLock *driveLock = nil;
- (void)volumeDidUnmount:(NSNotification *)notif
{
  if (!driveLock)
    driveLock = [[NSLock alloc] init];

  if ([driveLock tryLock] == NO)
    return;
  
  if (needsDetach)
    {
      NSString *volumeDevice = [[notif userInfo] objectForKey:@"UNIXDevice"];
      for (OSEUDisksVolume *volume in mountedVolumesToDetach)
        {
          // NSLog(@"Volume2Detach: %@", [volume UNIXDevice]);
          if ([[volume UNIXDevice] isEqualToString:volumeDevice])
            {
              // NSLog(@"Volume detached: %@", [volume UNIXDevice]);
              [mountedVolumesToDetach removeObject:volume];
              break;
            }
        }

      // NSLog(@"OSEUDisksDrive: mounted volumes to detach: %@", mountedVolumesToDetach);

      // All volumes unounted proceed with eject & powerOff.
      if ([mountedVolumesToDetach count] <= 0)
        {
          NSString *message = @"";
          
          if (![self isEjectable] && ![self canPowerOff])
            {
      
              message = [NSString stringWithFormat:@"You can safely remove the card"
                                  " '%@' now.", [self humanReadableName]];
            }
          else
            {
              [self eject:YES];
              [self powerOff:YES];
              if (![self isOptical] && [self hasMedia])
                {
                  message = [NSString stringWithFormat:@"You can safely disconnect"
                                      " the disk '%@' now.", [self humanReadableName]];
                }
            }
          [adaptor operationWithName:@"Eject"
                              object:self
                              failed:NO
                              status:@"Completed"
                               title:@"Disk Eject"
                             message:message];
          [[NSNotificationCenter defaultCenter] removeObserver:self];
          needsDetach = NO;
          [mountedVolumesToDetach release];
        }
    }
  [driveLock unlock];
}

// 1. Send OSEDiskOperationDidStart for drive.
// 2. Put mountedVolumes into cache (needsDetachMountedVolumes). Set needsDetach = YES.
// 3. Unmount volumes. Each volume sends DidStart/DidEnd for volume.
// 4. Catch DidEnd for volume and remove volume from cache.
// 5. When cache become empty proceed with eject: and powerOff:.
// Sync - OK.
- (void)unmountVolumesAndDetach
{
  // 1.
  NSString *message;
  message = [NSString stringWithFormat:@"Ejecting %@...",
                      [self humanReadableName]];
  [adaptor operationWithName:@"Eject"
                      object:self
                      failed:NO
                      status:@"Started"
                       title:@"Disk Eject"
                     message:message];

  // 2.
  mountedVolumesToDetach = [[NSMutableArray alloc]
                             initWithArray:[self mountedVolumes]];
  needsDetach = YES;

  // 2.1 Subscribe to notifications
  [notificationCenter addObserver:self
                         selector:@selector(volumeDidUnmount:)
                             name:NXVolumeUnmounted
                           object:adaptor];

  // 3.
  if (![self unmountVolumes:YES])
    {
      message = [NSString stringWithFormat:@"Failed to eject '%@'",
                          [self humanReadableName]];
      [adaptor operationWithName:@"Eject"
                          object:self
                          failed:YES
                          status:@"Completed"
                           title:@"Disk Eject"
                         message:message];
    }

  // 4. & 5. are in [self volumeDidUnmount:].
}

- (BOOL)eject:(BOOL)wait
{
  UDisksObject *ud_object;
  UDisksDrive  *ud_drive;
  gboolean      ud_result = 0;

  if (![self isEjectable] || ![self hasMedia])
    return NO;

  ud_object = udisks_client_get_object([adaptor udisksClient],
                                       [objectPath cString]);
  ud_drive = udisks_object_peek_drive(ud_object);

  NSDebugLLog(@"udisks", @"Drive: Eject the Drive: %@", objectPath);
  
  if (wait)
    {
      ud_result =
        udisks_drive_call_eject_sync(ud_drive,
                                     g_variant_new("a{sv}", NULL),
                                     NULL,            // GCancellable *
                                     NULL);           // GError **
    }
  else
    {
      // udisks_drive_call_eject(ud_drive,
      //                         g_variant_new("a{sv}", NULL),
      //                         NULL,             // GCancellable *
      //                         eject_callback, // GAsyncReadyCallback
      //                         NULL);            // gpointer user_data
    }
  
  g_object_unref(ud_object);
  
  return ud_result;
}

- (BOOL)powerOff:(BOOL)wait
{
  UDisksObject *ud_object;
  UDisksDrive  *ud_drive;
  gboolean      ud_result = 0;

  if (![self canPowerOff])
    return NO;

  ud_object = udisks_client_get_object([adaptor udisksClient], [objectPath cString]);
  ud_drive = udisks_object_peek_drive(ud_object);

  NSDebugLLog(@"udisks", @"NXUDA: Power Off the Drive: %@", objectPath);

  if (wait)
    {
      ud_result = udisks_drive_call_power_off_sync(ud_drive,
                                                   g_variant_new("a{sv}", NULL),
                                                   NULL,            // GCancellable *
                                                   NULL);           // GError **
    }
  else
    {
      // udisks_drive_call_power_off(ud_drive,
      //                             g_variant_new("a{sv}", NULL),
      //                             NULL,             // GCancellable *
      //                             unmount_callback, // GAsyncReadyCallback
      //                             NULL);            // gpointer user_data
    }
  
  g_object_unref(ud_object);
  
  return ud_result;
}

@end

#endif //WITH_UDISKS
