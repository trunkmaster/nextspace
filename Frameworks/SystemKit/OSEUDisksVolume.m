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

#import <SystemKit/OSEUDisksVolume.h>

@implementation OSEUDisksVolume

- (void)_dumpProperties
{
  NSString *fileName;
  NSMutableDictionary *props = [properties mutableCopy];
  
  fileName = [NSString stringWithFormat:@"Library/Workspace/Volume_%@",
                       [objectPath lastPathComponent]];
  if (drive)
    {
      [props setObject:drive forKey:@"_DriveObject"];
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
  
  notificationCenter = [NSNotificationCenter defaultCenter];

  OSEUDisksDrive *d;
  if ((d = [[adaptor availableDrives] objectForKey:[self driveObjectPath]]) != nil)
    {
      [self setDrive:d];
      [drive addVolume:self withPath:objectPath];
    }

  // [self _dumpProperties];
  
  return self;
}

- (void)dealloc
{
  [properties release];
  [objectPath release];
  
  TEST_RELEASE(drive);
  
  [super dealloc];
}

// Change properties
- (void)setProperty:(NSString *)property
              value:(NSString *)value
      interfaceName:(NSString *)interface
{
  NSMutableDictionary *interfaceDict;
  NSMutableDictionary *info;

  // Get dictionary which contains changed property
  if (!(interfaceDict = [[properties objectForKey:interface] mutableCopy]))
    {
      interfaceDict = [NSMutableDictionary new];
    }
  else if ([[interfaceDict objectForKey:property] isEqualToString:value])
    {
      // Protect from generating actions on double-setting properties
      return;
    }
  
  if ([property isEqualToString:@"MountPoints"] &&
      [interfaceDict objectForKey:@"MountPoints"])
    {
      [interfaceDict setObject:[interfaceDict objectForKey:@"MountPoints"]
                        forKey:@"OldMountPoint"];
    }
  
  // Update property
  if (value)
    {
      [interfaceDict setObject:value forKey:property];
    }
  [properties setObject:interfaceDict forKey:interface];
  [interfaceDict release];

  // Mounted state of volume changed
  if ([property isEqualToString:@"MountPoints"])
    {
      if ([value isEqualToString:@""])
        {
          [adaptor operationWithName:@"Unmount"
                              object:self
                              failed:NO
                              status:@"Occured"
                               title:@"Unmount"
                             message:@"Volume unmounted at system level."];
        }
      else
        {
          [adaptor operationWithName:@"Mount"
                              object:self
                              failed:NO
                              status:@"Occured"
                               title:@"Mount"
                             message:@"Volume mounted at system level."];
        }
    }

  // Optical drive gets media or block device was formatted.
  if ([property isEqualToString:@"IdUsage"] &&
      [value isEqualToString:@"filesystem"])
    {
      [self mount:NO];
    }

  // [self _dumpProperties];
}

- (void)removeProperties:(NSArray *)props
           interfaceName:(NSString *)interface
{
  NSDebugLLog(@"udisks", @"Volume: remove properties: %@ for interface: %@",
        props, interface);
}

// Access to properties
- (NSDictionary *)properties
{
  return properties;
}

- (NSString *)propertyForKey:(NSString *)key interface:(NSString *)interface
{
  NSDictionary *interfaceDict;
  NSString     *value;

  if (interface)
    {
      interfaceDict = [properties objectForKey:interface];
      value = [interfaceDict objectForKey:key];
    }
  else
    {
      value = [properties objectForKey:key];
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


//-------------------------------------------------------------------------------
//--- Parent object
//-------------------------------------------------------------------------------
- (OSEUDisksAdaptor *)adaptor
{
  return adaptor;
}

- (OSEUDisksDrive *)drive
{
  return drive;
}

- (void)setDrive:(OSEUDisksDrive *)driveObject
{
  ASSIGN(drive, driveObject);
  // [self _dumpProperties];
}

// Master volume represents drive partition table e.g. '/dev/sda'.
- (OSEUDisksVolume *)masterVolume
{
  NSString *masterPath;

  masterPath = [self propertyForKey:@"Table" interface:PARTITION_INTERFACE];

  if (!masterPath)
    return nil;
  
  return [adaptor _objectWithUDisksPath:[masterPath cString]];
}

- (NSString *)objectPath
{
  return objectPath;
}

- (NSString *)driveObjectPath
{
  return [self propertyForKey:@"Drive" interface:BLOCK_INTERFACE];
}

//-------------------------------------------------------------------------------
//--- General properties
//-------------------------------------------------------------------------------
- (NXTFSType)type
{
  NSString *fsType = [self propertyForKey:@"IdType" interface:BLOCK_INTERFACE];
  
  // Return NXTFSType filesystem name
  if ([fsType isEqualToString:@"msdosfs"] ||
      [fsType isEqualToString:@"vfat"] ||
      [fsType isEqualToString:@"fat"])
    {
      return NXTFSTypeFAT;
    }
  else if ([fsType isEqualToString:@"ntfs"])
    {
      return NXTFSTypeNTFS;
    }
  else if ([fsType isEqualToString:@"iso9660"])
    {
      return NXTFSTypeISO;
    }
  else if ([fsType isEqualToString:@"ufs"])
    {
      return NXTFSTypeUFS;
    }
  else if ([fsType isEqualToString:@"udf"])
    {
      return NXTFSTypeUDF;
    }
  else if ([fsType isEqualToString:@"swap"])
    {
      return NXTFSTypeSwap;
    }

  return -1;
}

- (NSString *)UUID
{
  return [self propertyForKey:@"IdUUID" interface:BLOCK_INTERFACE];
}

- (NSString *)label
{
  return [self propertyForKey:@"IdLabel" interface:BLOCK_INTERFACE];
}

- (NSString *)size
{
  return [self propertyForKey:@"Size" interface:BLOCK_INTERFACE];
}

- (NSString *)UNIXDevice
{
  return [self propertyForKey:@"Device" interface:BLOCK_INTERFACE];
}

- (NSString *)mountPoints
{
  return [self propertyForKey:@"MountPoints" interface:FS_INTERFACE];
}

// Partition table
- (NSString *)partitionType
{
  return [self propertyForKey:@"Type" interface:PARTITION_INTERFACE];
}

- (NSString *)partitionNumber
{
  return [self propertyForKey:@"Number" interface:PARTITION_INTERFACE];
}

- (NSString *)partitionSize
{
  return [self propertyForKey:@"Size" interface:PARTITION_INTERFACE];
}

// Extented
- (BOOL)isFilesystem
{
  NSString *usage = [self propertyForKey:@"IdUsage" interface:BLOCK_INTERFACE];
  BOOL     isFilesystem = [usage isEqualToString:@"filesystem"];

  // NSLog(@"isFilesystem: %@ = %@", objectPath, [properties objectForKey:FS_INTERFACE]);
  
  if ([properties objectForKey:FS_INTERFACE] == nil)
    {
      isFilesystem = NO;
    }
  
  return isFilesystem;
}

- (BOOL)isMounted
{
  // Don't call [self isFilesystem] because CD has IdUsage=""
  // if (![self isFilesystem] ||
  if (![self mountPoints] ||
      [[self mountPoints] isEqualToString:@""])
    {
      return NO;
    }

  return YES;
}

- (BOOL)isWritable
{
  return ![self boolPropertyForKey:@"ReadOnly" interface:BLOCK_INTERFACE];
}

// OSEUDisksVolume which represents mapped image file
- (BOOL)isLoopVolume
{
  NSString *drivePath = [self propertyForKey:@"Drive" interface:BLOCK_INTERFACE];

  return [drivePath isEqualToString:@"/"];
}

- (BOOL)isSystem
{
  if ([self boolPropertyForKey:@"HintSystem" interface:BLOCK_INTERFACE] &&
      ![self isLoopVolume] && [self masterVolume] != self &&
      ![self boolPropertyForKey:@"HintAuto" interface:BLOCK_INTERFACE])
    {
      return YES;
    }
      
  return NO;
}

//--- Actions

// Callback for async mount operation
static void mount_callback(UDisksFilesystem *filesystem,
                           GAsyncResult *res,
                           OSEUDisksVolume *volume)
{
  GError *error = NULL;
  gchar *mount_point;
  OSEUDisksAdaptor *adaptor = [volume adaptor];
  
  udisks_filesystem_call_mount_finish(filesystem, &mount_point, res, &error);
  
  if (error != NULL && error->code != 0)
    {
      NSLog(@"[OSEUDisksVolume mount_callback()] error: %i message: %@",
            error->code, [adaptor descriptionForError:error]);
      [adaptor operationWithName:@"Mount"
                          object:volume
                          failed:YES
                          status:@"Completed"
                           title:@"Mount error"
                         message:[adaptor descriptionForError:error]];
    }
  else
    {
      NSString *message;
      message = [NSString stringWithFormat:@"Mount of %@ completed at mount point %s",
                          [volume UNIXDevice], mount_point];

      // TODO: do not generate extra notifications
      [volume setProperty:@"MountPoints"
                    value:[[NSString stringWithCString:mount_point] stringByResolvingSymlinksInPath]
            interfaceName:FS_INTERFACE];
      
      [adaptor operationWithName:@"Mount"
                          object:volume
                          failed:NO
                          status:@"Completed"
                           title:@"Mount"
                         message:message];
    }
}

- (NSString *)mount:(BOOL)wait
{
  UDisksObject     *ud_object;
  UDisksFilesystem *ud_filesystem;
  gchar            *ud_mount_point;
  gboolean          ud_result = 0;
  GError           *error = NULL;
  NSString         *message;

  if (![self isFilesystem] || [self isMounted] || [self isSystem])
    {
      return nil;
    }

  ud_object = udisks_client_get_object([adaptor udisksClient], [objectPath cString]);
  ud_filesystem = udisks_object_peek_filesystem(ud_object);

  NSDebugLLog(@"udisks", @"OSEUDisksVolume: mountVolume: %@", objectPath);

  message = [NSString stringWithFormat:@"Mounting volume %@", [self UNIXDevice]];
  [adaptor operationWithName:@"Mount"
                      object:self
                      failed:NO
                      status:@"Started"
                       title:@"Mount"
                     message:message];
  if (wait)
    {
      // GVariantBuilder *options = g_variant_builder_new(G_VARIANT_TYPE("a{sv}"));
      // g_variant_builder_add(options, "{sv}",
      //                       "options", g_variant_new_string("ro"));
 
      ud_result = udisks_filesystem_call_mount_sync(ud_filesystem,
                                                    g_variant_new("a{sv}", NULL),
                                                    &ud_mount_point,    // gchar **
                                                    NULL,               // GCancellable *
                                                    &error);            // GError **
      if (error != NULL && error->code != 0)
        {
          [adaptor operationWithName:@"Mount"
                              object:self
                              failed:YES
                              status:@"Completed"
                               title:@"Mount"
                             message:[adaptor descriptionForError:error]];
        }
      else
        {
          message = [NSString stringWithFormat:@"Mount of %@ completed at mount point %s",
                              [self UNIXDevice], ud_mount_point];
          [adaptor operationWithName:@"Mount"
                              object:self
                              failed:NO
                              status:@"Completed"
                               title:@"Mount"
                             message:message];
        }
    }
  else
    {

      udisks_filesystem_call_mount(ud_filesystem,
                                   g_variant_new("a{sv}", NULL),
                                   NULL,                   // GCancellable *
                                   (GAsyncReadyCallback)mount_callback,
                                   self);               // gpointer user_data
      // [adaptor operationWithName:] will be sent in mount_callback()
    }
  
  g_object_unref(ud_object);

  if (ud_result)
    return [NSString stringWithCString:ud_mount_point];
  else
    return nil;
}

// Callback for async mount operation
static void unmount_callback(UDisksFilesystem *filesystem,
                             GAsyncResult *res,
                             OSEUDisksVolume *volume)
{
  GError *error = NULL;
  OSEUDisksAdaptor *adaptor = [volume adaptor];

  udisks_filesystem_call_unmount_finish(filesystem, res, &error);

  if (error != NULL && error->code != 0)
    {
      NSLog(@"[OSEUDisksVolume unmount_callback()] error: %i message: %@",
            error->code, [adaptor descriptionForError:error]);
      [adaptor operationWithName:@"Unmount"
                          object:volume
                          failed:YES
                          status:@"Completed"
                           title:@"Unmount error"
                         message:[adaptor descriptionForError:error]];
    }
  else
    {
      NSString *message;
      message = [NSString stringWithFormat:@"Unmount of %@ completed successfully.",
                          [volume UNIXDevice]];
      [adaptor operationWithName:@"Unmount"
                          object:volume
                          failed:NO
                          status:@"Completed"
                           title:@"Unmount"
                         message:message];
    }
}

- (BOOL)unmount:(BOOL)wait
{
  UDisksObject     *ud_object;
  UDisksFilesystem *ud_filesystem;
  gboolean          ud_result = 0;
  GError           *error = NULL;
  NSString         *message;

  if (![self isFilesystem] || ![self isMounted])
    {
      return YES;
    }

  ud_object = udisks_client_get_object([adaptor udisksClient],
                                       [objectPath cString]);
  ud_filesystem = udisks_object_peek_filesystem(ud_object);

  NSDebugLLog(@"udisks", @"OSEUDisksVolume: unMountVolume: %@", objectPath);

  message = [NSString stringWithFormat:@"Unmounting volume %@",
                      [self UNIXDevice]];
  [adaptor operationWithName:@"Unmount"
                      object:self
                      failed:NO
                      status:@"Started"
                       title:@"Unmount"
                     message:message];
  if (wait)
    {
      ud_result =
        udisks_filesystem_call_unmount_sync(ud_filesystem,
                                            g_variant_new("a{sv}", NULL),
                                            NULL,   // GCancellable *
                                            &error);  // GError **
      if (error != NULL && error->code != 0)
        {
          [adaptor operationWithName:@"Unmount"
                              object:self
                              failed:YES
                              status:@"Completed"
                               title:@"Unmount"
                             message:[adaptor descriptionForError:error]];
        }
      else
        {
          message = [NSString
                      stringWithFormat:@"Unmount of %@ completed successfully.",
                      [self UNIXDevice]];
          [adaptor operationWithName:@"Unmount"
                              object:self
                              failed:NO
                              status:@"Completed"
                               title:@"Unmount"
                             message:message];
        }
    }
  else
    {
      udisks_filesystem_call_unmount(ud_filesystem,
                                     g_variant_new("a{sv}", NULL),
                                     NULL,             // GCancellable *
                                     (GAsyncReadyCallback)unmount_callback,
                                     self);            // gpointer user_data
      // [adaptor operationWithName:] will be sent in mount_callback()
    }
  
  g_object_unref(ud_object);

  return ud_result;
}

@end

#endif // WITH_UDISKS
