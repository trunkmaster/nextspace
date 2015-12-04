/*
 * NXUDisksDrive.m
 *
 * Object which represents physical storage device.
 * UDisks base path is: "/org/freedesktop/UDisks2/drives/<name of drive>".
 *
 * Copyright 2015, Serg Stoyan
 * All right reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 *
 * Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifdef WITH_UDISKS

#import <udisks/udisks.h>

#import "NXUDisksDrive.h"

@implementation NXUDisksDrive

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
                 adaptor:(NXUDisksAdaptor *)udisksAdaptor
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
  for (NXUDisksVolume *volume in [volumes allValues])
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

- (void)addVolume:(NXUDisksVolume *)volume withPath:(NSString *)volumePath
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
  NXUDisksVolume *volume;

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
  NXUDisksVolume *volume;
  NSString       *mp;

  NSDebugLLog(@"udisks", @"NXUDisksDrive: %@ mountVolumes: %@", objectPath, volumes);
  
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
  NXUDisksVolume *volume;

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
      for (NXUDisksVolume *volume in mountedVolumesToDetach)
        {
          // NSLog(@"Volume2Detach: %@", [volume UNIXDevice]);
          if ([[volume UNIXDevice] isEqualToString:volumeDevice])
            {
              // NSLog(@"Volume detached: %@", [volume UNIXDevice]);
              [mountedVolumesToDetach removeObject:volume];
              break;
            }
        }

      // NSLog(@"NXUDisksDrive: mounted volumes to detach: %@", mountedVolumesToDetach);

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

// 1. Send NXDiskOperationDidStart for drive.
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
