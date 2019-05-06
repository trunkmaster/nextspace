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

#ifdef WITH_HAL

#import <AppKit/NSImage.h>
#import <unistd.h>
#import <DesktopKit/NXFileManager.h>

#import "OSEDeviceManager.h"
#import "NXHALAdaptor.h"

static DBusError error;

static NSFileHandle         *dbusConnectionFH;
static NSNotificationCenter *notificationCenter;
static OSEDeviceManager      *deviceManager;
static NXHALAdaptor         *halAdaptor;

#define UDI_BASE "/org/freedesktop/Hal/devices/"
#define MOUNT_BASE @"/Volumes"

//-----------------------------------------------------------------------
//--- HAL callbacks
//-----------------------------------------------------------------------
static void
device_added(LibHalContext *ctx, const char *udi)
{
  [halAdaptor _proceedEvent:OSEDeviceAdded
                     forUDI:[NSString stringWithCString:udi]
                        key:nil];
}

static void
device_removed(LibHalContext *ctx, const char *udi)
{
  [halAdaptor _proceedEvent:OSEDeviceRemoved
                     forUDI:[NSString stringWithCString:udi]
                        key:nil];
}

static void
device_condition_changed(LibHalContext *ctx,
			  const char    *udi,
			  const char    *condition_name,
			  const char    *condition_detail)
{
  [halAdaptor _proceedEvent:OSEDeviceConditionChanged
                     forUDI:[NSString stringWithCString:udi]
                        key:nil];
}

static void
property_modified(LibHalContext *ctx,
		   const char *udi,
		   const char *key,
		   dbus_bool_t is_removed,
		   dbus_bool_t is_added)
{
  NSString *event = OSEDevicePropertyChanged;
  
  if (is_removed)
    {
      event = OSEDevicePropertyRemoved;
    }
  else if (is_added)
    {
      event = OSEDevicePropertyAdded;
    }
  
  [halAdaptor _proceedEvent:event
                     forUDI:[NSString stringWithCString:udi]
                        key:[NSString stringWithCString:key]];
}

//-----------------------------------------------------------------------
//--- D-BUS callbacks
//-----------------------------------------------------------------------
static dbus_bool_t
add_watch(DBusWatch *watch, void *data)
{
  fprintf(stderr, "OSEDeviceManager: add DBUS watch\n");

  dbusConnectionFH = [[NSFileHandle alloc]
                       initWithFileDescriptor:dbus_watch_get_unix_fd(watch)
                               closeOnDealloc:YES];

  [[NSNotificationCenter defaultCenter]
    addObserver:halAdaptor
       selector:@selector(_messageArrived:)
           name:NSFileHandleDataAvailableNotification
         object:dbusConnectionFH];

  [dbusConnectionFH waitForDataInBackgroundAndNotify];

  return 0;
}

static void
remove_watch(DBusWatch *watch,
	     void      *data)
{
  fprintf(stderr, "OSEDeviceManager: remove DBUS watch\n");
  [[NSNotificationCenter defaultCenter] removeObserver:halAdaptor];
}

static void
watch_toggled(DBusWatch *watch,
	      void      *data)
{
  fprintf(stderr, "OSEDeviceManager: DBUS watch toggled\n");
  remove_watch(watch, data);
  add_watch(watch, data);
}

//-----------------------------------------------------------------------


@implementation NXHALAdaptor (Private)

// Selector which called when new data comes to 'dbusConnectionFH'
// (file descriptor returned by dbus_watch_get_unix_fd())
- (void)_messageArrived:(NSNotification *)aNotif
{
  DBusDispatchStatus dbus_status;

  // NSLog(@"OSEDeviceManager: DBUS message arrived");

  do
    {
      dbus_connection_read_write_dispatch(conn, 1000);
      dbus_status = dbus_connection_get_dispatch_status(conn);
    }
  while (dbus_status == DBUS_DISPATCH_DATA_REMAINS);

  [dbusConnectionFH waitForDataInBackgroundAndNotify];
}

- (void)_proceedEvent:(NSString *)deviceEvent
               forUDI:(NSString *)UDI
                  key:(NSString *)propertyKey
{
  NSDictionary *description = nil;

  fprintf (stderr, "NXHALAdaptor: event: %s device:%s\n",
           [deviceEvent cString], [UDI cString]);

  if ([deviceEvent isEqualToString:OSEDeviceAdded])
    {
      if ([self _deviceWithUDI:UDI hasCapability:@"volume"])
        {
          // NXVolumeAppeared
          if ((description = [self _volumeDescriptionForUDI:UDI]) == nil)
            {
              return;
            }
          [notificationCenter postNotificationName:NXVolumeAppeared
                                            object:deviceManager
                                          userInfo:description];
          // mount appeared volume
          [self _mountVolume:description];
        }
    }
  else if ([deviceEvent isEqualToString:OSEDeviceRemoved])
    {
      if ([self _deviceWithUDI:UDI hasCapability:@"volume"])
        {
          // NXVolumeDisappeared
          description = [self _volumeDescriptionForUDI:UDI];
          [notificationCenter postNotificationName:NXVolumeDisappeared
                                            object:deviceManager
                                          userInfo:description];
        }
    }
  else if ([deviceEvent isEqualToString:OSEDevicePropertyChanged]
           || [deviceEvent isEqualToString:OSEDevicePropertyAdded]
           || [deviceEvent isEqualToString:OSEDevicePropertyRemoved])
    {
      // NSDictionary *dictionary;
      id propVal = [self _propertyValue:propertyKey forUDI:UDI];

       NSLog(@"Property modified(%@): %@ = %@", UDI, propertyKey, propVal);

       if ([propertyKey isEqualToString:@"volume.is_mounted"])
         {
           description = [self _volumeDescriptionForUDI:UDI];
           if ([propVal boolValue])
             {
               [notificationCenter postNotificationName:NXVolumeMounted
                                                 object:deviceManager
                                               userInfo:description];
             }
           else
             {
               [notificationCenter postNotificationName:NXVolumeUnmounted
                                                 object:deviceManager
                                               userInfo:description];
             }
         }
    }
  else if ([deviceEvent isEqualToString:OSEDeviceConditionChanged])
    {
      // dictionary =
      //   [NSDictionary dictionaryWithObjectsAndKeys:
      //                  [NSString stringWithCString:udi],
      //                 @"UDI",
      //                  [NSString stringWithCString:condition_name],
      //                 @"ConditionName",
      //                  [NSString stringWithCString:condition_detail],
      //                 @"ConditionDetail",
      //                 nil];
    }
}

//-----------------------------------------------------------------------
//--- Accessing attributes (properties and capabilities) of HAL object
//-----------------------------------------------------------------------

// Returns array of strings. Each string contains UDI of device.
// All HAL devices UDI starts from string ''
- (NSArray *)_registeredDevices
{
  int            num_devices, i;
  char           **device_names;
  NSMutableArray *devices = [NSMutableArray array];

  dbus_error_init(&error);
  
  device_names = libhal_get_all_devices(hal_ctx, &num_devices, &error);
  if (device_names == NULL)
    {
      NSLog(@"Error getting device list");
      return nil;
    }

  for (i = 0;i < num_devices;i++)
    {
      [devices addObject:[NSString stringWithCString:device_names[i]]];
    }

  // NSLog(@"Array:%@", devices);

  return devices;
}

- (id)_propertyValue:(NSString *)key forUDI:(NSString *)udi
{
  int         type;
  id          property = @"";
  const char  *_udi = (char *)[udi cString];
  const char  *_key = (char *)[key cString];
  char          *dbusStr;
  dbus_bool_t   dbusBool;
  dbus_int32_t  dbusInt;
  dbus_uint64_t dbusLong;
  double        dbusDouble;
  char          **str_list;

  dbus_error_init(&error);
  type = libhal_device_get_property_type(hal_ctx, _udi, _key, &error);
  if (type == LIBHAL_PROPERTY_TYPE_INVALID)
    {
//      NSLog(@"XSHALConnection: requested property type is invalid. Probably device has no property with name: %s", key);
      return property;
    }

  switch (type)
    {
    case LIBHAL_PROPERTY_TYPE_STRING:
      dbusStr =
        libhal_device_get_property_string(hal_ctx, _udi, _key, &error);
      property = [NSString stringWithCString:dbusStr];
      break;
    case LIBHAL_PROPERTY_TYPE_BOOLEAN:
      dbusBool =
        libhal_device_get_property_bool(hal_ctx, _udi, _key, &error);
      property = [NSNumber numberWithBool:dbusBool];
      break;
    case LIBHAL_PROPERTY_TYPE_INT32:
      dbusInt =
        libhal_device_get_property_int(hal_ctx, _udi, _key, &error);
      property = [NSNumber numberWithInt:dbusInt];
      break;
    case LIBHAL_PROPERTY_TYPE_UINT64:
      dbusLong =
        libhal_device_get_property_uint64(hal_ctx, _udi, _key, &error);
      property = [NSNumber numberWithLongLong:dbusLong];
      break;
    case LIBHAL_PROPERTY_TYPE_DOUBLE:
      dbusDouble =
        libhal_device_get_property_double(hal_ctx, _udi, _key, &error);
      property = [NSNumber numberWithDouble:dbusDouble];
      break;
    case LIBHAL_PROPERTY_TYPE_STRLIST:
      break;
    default:
      break;
    }

//  NSLog(@"%s = %@", key, property);

  return property;
}

- (BOOL)_deviceWithUDI:(NSString *)UDI hasCapability:(NSString *)capability
{
  const char *udi = [UDI cString];
  const char *cap = [capability cString];
  
  dbus_error_init(&error);
  
  if (!libhal_device_query_capability(hal_ctx, udi, cap, &error))
    {
      return NO;
    }

  return YES;
}

//-----------------------------------------------------------------------
//--- Volumes (filesystems) attributes
//-----------------------------------------------------------------------

// Fill 'volumes' ivar with all registered NXVolume's (fixed and removable)
- (NSArray *)_availableVolumes
{
  NSMutableArray *volumes = [NSMutableArray new];
  NSArray        *deviceList = [self _registeredDevices];
  NSEnumerator   *e = [deviceList objectEnumerator];
  NSString       *UDI;
  NSDictionary   *volDesc;
  
  while ((UDI = [e nextObject]) != nil)
    {
      if ([self _deviceWithUDI:UDI hasCapability:@"volume"])
        {
          if ((volDesc = [self _volumeDescriptionForUDI:UDI]) != nil)
            {
              [volumes addObject:volDesc];
              // NSLog(@"NXHALAdaptor: +availbale volume with UNIX device: %@",
              //       [volDesc objectForKey:@"UNIXDevice"]);
            }
        }
    }

  return volumes;
}

//{ 
//  FileSystemType = "ufs" | "ntfs" | "fat" | "iso"? | "udf"?;
//  UNIXDevice = "/dev/ada0s1a";
//  FileSystemLabel; // when label wan't set contains UUID
//  MountPoint = "/Volumes/Mobile Storage"; // if not 'nil' it's mounted
//}
//
- (NSDictionary *)_volumeDescriptionForUDI:(NSString *)UDI
{
  NSMutableDictionary *vol;
  id                  prop;
  NSString            *tmp;

  //  NSLog(@"Gather props for UDI: %@", UDI);

  // Device specified by UDI is not volume
  if ([self _deviceWithUDI:UDI hasCapability:@"volume"] == NO)
    {
      return nil;
    }

  // Volme has no filesystem
  if ([self _isVolumeMountable:UDI] == NO)
    {
      return nil;
    }

  // Volume should be ignored
  // if ([[self _propertyValue:@"volume.ignore" forUDI:UDI] boolValue] == YES)
  //   {
  //     return nil;
  //   }

  vol = [NSMutableDictionary dictionary];

  // Fill 
  [vol setObject:UDI forKey:@"UDI"];
  [vol setObject:[self _propertyValue:@"info.parent" forUDI:UDI]
          forKey:@"info.parent"];


  tmp = [self _propertyValue:@"volume.label" forUDI:UDI];
  if ([tmp isEqualToString:@""])
    {
      tmp = [self _propertyValue:@"volume.uuid" forUDI:UDI];
    }
  [vol setObject:tmp
          forKey:@"FileSystemLabel"];
  [vol setObject:[self _propertyValue:@"volume.fstype" forUDI:UDI]
          forKey:@"FileSystemType"];
  [vol setObject:[self _propertyValue:@"block.device" forUDI:UDI]
          forKey:@"UNIXDevice"];
  [vol setObject:[self _propertyValue:@"volume.mount_point" forUDI:UDI]
          forKey:@"MountPoint"];
  
  // prop = [devMan halProperty:UDI withName:@"block.storage_device"];
  // [vol setObject:prop forKey:@"block.storage_device"];
  // prop = [devMan halProperty:UDI withName:@"volume.is_mounted"];
  // [vol setObject:prop forKey:@"volume.is_mounted"];
  // prop = [devMan halProperty:UDI withName:@"volume.is_disc"];
  // [vol setObject:prop forKey:@"volume.is_disc"];
  // prop = [devMan halProperty:UDI withName:@"volume.is_partition"];
  // [vol setObject:prop forKey:@"volume.is_partition"];
  // prop = [devMan halProperty:UDI withName:@"volume.mount.valid_options"];
  // [vol setObject:prop forKey:@"volume.mount.valid_options"];

  // [vol setObject:[self _isDeviceRemovable:UDI] forKey:@"Removable"];
  // [vol setObject:[self _isVolumeMountable:UDI] forKey:@"Mountable"];
  // [vol setObject:[self _isVolumeOptical:UDI] forKey:@"Optical"];

  // Icons
  // tmp = [self _iconNameForFSType:[vol objectForKey:@"FileSystemType"] 
  //       	       removable:[[vol objectForKey:@"Removable"] boolValue]
  //       		    open:NO];
  // [vol setObject:[tmp copy] forKey:@"IconName"];
  // tmp = [self _iconNameForFSType:[vol objectForKey:@"volume.fstype"]
  //       	       removable:[[vol objectForKey:@"Removable"] boolValue]
  //       		    open:YES];
  // [vol setObject:[tmp copy] forKey:@"OpenIconName"];

//  NSLog(@"Volume: %@\n", vol);

  return vol;
}

- (NSDictionary *)_volumeDescriptionForPath:(NSString *)path
{
  NSEnumerator *e = [[self mountedVolumes] objectEnumerator];
  NSDictionary *volDesc;
  NSString     *mp;
  NSString     *mountPoint;

  while ((volDesc = [e nextObject]) != nil)
    {
      mountPoint = [volDesc objectForKey:@"MountPoint"];
      mp = NXIntersectionPath(path, mountPoint);
      if ([mp isEqualToString:mountPoint])
        {
          return volDesc;
        }
    }

  return nil;
}

// It's always FALSE on FreeBSD
- (BOOL)_isDeviceRemovable:(NSString *)UDI
{
  char     *device = (char *)[UDI cString];
  NSString *storageDevice;
  NSNumber *isRemovable;

  storageDevice = [self _propertyValue:@"block.storage_device" forUDI:UDI];
  isRemovable = [self _propertyValue:@"storage.removable"
                              forUDI:storageDevice];

  return ([isRemovable integerValue] == 1) ? YES : NO;
}

- (BOOL)_isVolumeOptical:(NSString *)UDI
{
  char     *device = (char *)[UDI cString];
  NSString *storageType;
  NSString *parentUDI;

  storageType = [self _propertyValue:@"storage.drive_type" forUDI:UDI];
  if ([storageType isEqualToString:@""])  // Try parent
    {
      parentUDI = [self _propertyValue:@"info.parent" forUDI:UDI];
      storageType = [self _propertyValue:@"storage.drive_type"
                                  forUDI:parentUDI];
    }

  if ([storageType isEqualToString:@"cdrom"])
    {
      return YES;
    }

  return NO;
}

- (BOOL)_isVolumeMountable:(NSString *)UDI
{
  NSString *fsUsage;
  BOOL     mountable = NO;

  fsUsage = [self _propertyValue:@"volume.fsusage" forUDI:UDI];
  // NSLog(@"_isVolumeMountable: %@ = %@", UDI, fsUsage);
  if ([fsUsage isEqualToString:@"filesystem"])
    {
      // if ([[self _propertyValue:@"volume.disc.is_svcd" forUDI:UDI] 
      //       boolValue] == YES ||
      //     [[self _propertyValue:@"volume.disc.is_vcd" forUDI:UDI]
      //       boolValue] == YES ||
      //     [[self _propertyValue:@"volume.disc.is_videodvd" forUDI:UDI]
      //       boolValue] == YES)
      //   {
      //     mountable = NO;
      //   }
      // else
      //   {
	  mountable = YES;
	// }
    }

  return mountable;
}


//--- Volumes (filesystems) actions

- (BOOL)_mountVolume:(NSDictionary *)volume
{
  NSString *fsType = [volume objectForKey:@"FileSystemType"];
  NSString *mountPoint = [volume objectForKey:@"MountPoint"];
  NSString *mountOpts;
  NSTask   *task;
  NSArray  *args;
  int      status = 0;

  // NSLog(@"Mount device %@", [volume objectForKey:@"UNIXDevice"]);

  if (![mountPoint isEqualToString:@""] || [fsType isEqualToString:@""])
    {
      return NO;
    }

  // Mount options
  // nil returned. Volume can't be mounted
  mountOpts = [NSString stringWithFormat:@"array:string:"];
  // Mount options
  if ([fsType isEqualToString:@"vfat"] || [fsType isEqualToString:@"fat"])
    {
      mountOpts = [NSString stringWithFormat:@"array:string:-L=en_US.UTF-8"];
    }
  // else if ([fsType isEqualToString:@"ntfs"])
  //   {
  //     mountOpts = [NSString 
  //                   stringWithFormat:@"array:string:uid=%i,nls=utf8", getuid()];
  //   }

  // Mount point
  NSLog(@"--->>>Mounting volume %@ with label: %@",
        [volume objectForKey:@"UNIXDevice"],
        [volume objectForKey:@"FileSystemLabel"]);
  mountPoint = [NSString stringWithFormat:@"string:%@",
                         [volume objectForKey:@"FileSystemLabel"]];

  // dbus-send arguments
  args = [NSArray arrayWithObjects:
                  @"--system", @"--print-reply",
                  @"--dest=org.freedesktop.Hal", [volume objectForKey:@"UDI"],
                  @"org.freedesktop.Hal.Device.Volume.Mount",
                  mountPoint, @"string:", mountOpts, nil];

  
  // Mount point should be updated through 'property_modified' callback
  task = [NSTask launchedTaskWithLaunchPath:@"dbus-send" arguments:args];

//   [task waitUntilExit];

//   status = [task terminationStatus];
//   if (status)
//     {
//       NSLog(@"Mount of %@ failed", [info objectForKey:@"udi"]);
//     }

//   return status;

  return YES;
}


- (BOOL)_unmountVolume:(NSDictionary *)info
{
  NSTask   *task;
  NSArray  *args;
  int      status;

  args = [NSArray arrayWithObjects:
                  @"--system", @"--print-reply",
                  @"--dest=org.freedesktop.Hal", [info objectForKey:@"UDI"],
                  @"org.freedesktop.Hal.Device.Volume.Unmount", 
                  @"array:string:", nil];

  // Mount point should be updated through 'property_modified' callback
  task = [NSTask launchedTaskWithLaunchPath:@"dbus-send" arguments:args];
  [task waitUntilExit];

  status = [task terminationStatus];
  if (status)
    {
      NSLog(@"UnMount of %@ failed", [info objectForKey:@"UDI"]);
    }

  return status;
}

/*
- (BOOL)ejectVolume:(NSDictionary *)info
{
  NSTask  *task;
  NSArray *args;
  int     status;

  // TODO: When written data to media are not synchronized yet D-BUS method
  // execution failed because of timeout. Handle it.
  args = [NSArray arrayWithObjects:
    @"--system", @"--print-reply", @"--reply-timeout=100000", 
    @"--dest=org.freedesktop.Hal", [info objectForKey:@"udi"], 
    @"org.freedesktop.Hal.Device.Volume.Eject", @"array:string:", nil];

  // Mount point should be updated through 'property_modified' callback
  task = [NSTask launchedTaskWithLaunchPath:@"dbus-send" arguments:args];

  // [task waitUntilExit];
  // return [task terminationStatus];

  return YES;
}

- (BOOL)ejectAllRemovables
{
  NSEnumerator *e;
  NSDictionary *volume; 

  if (!volumes)
    {
      return NO;
    }

  e = [volumes objectEnumerator];
  while ((volume = [e nextObject]))
    {
      if ([[volume objectForKey:@"Removable"] boolValue])
	{
	  ejectInProgress = YES;
	  [self ejectVolume:volume];
	  // TODO: If no permission to send 'Eject' messages 'ejectInProgress'
	  // doesn't changed and Workspace stuck here forever
	  // while (ejectInProgress)
	  //   {
	  //     [[NSRunLoop currentRunLoop] 
	  //       runMode:NSDefaultRunLoopMode 
          //       beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
	  //   }
	}
    }

  return YES;
}

//-----------------------------------
- (BOOL)ejectDiskAtPath:(NSString *)path
{
  NSDictionary *volume = [self _volumeForPath:path];

  if (![volume objectForKey:@"Removable"])
    {
      return NO;
    }

  NSLog(@"%@ will be ejected.", [volume objectForKey:@"volume.mount_point"]);

  if (![self ejectVolume:volume])
    {
      NSRunAlertPanel(_(@"Disk Eject"),
		      _(@"Disk at path %@ cannot be ejected this time."), 
		      nil, nil, nil, 
		      [volume objectForKey:@"volume.mount_point"]);
    }

  return YES;
}
*/
@end

@implementation NXHALAdaptor

- (id)initWithDeviceManager:(OSEDeviceManager *)devMan
{
  halAdaptor = self = [super init];
  
  deviceManager = devMan;
  notificationCenter = [NSNotificationCenter defaultCenter];
  
  // Setup DBUS
  dbus_error_init(&error);
  conn = dbus_bus_get(DBUS_BUS_SYSTEM, &error);
  if (conn == NULL)
    {
      NSLog(@"D-BUS connection setup failed. Exiting...");
      return NO;
    }

  dbus_connection_set_watch_functions(conn,
        			      add_watch,
        			      remove_watch,
        			      watch_toggled,
        			      NULL, NULL);
  
  // Setup HAL
  hal_ctx = libhal_ctx_new();
  if (hal_ctx == NULL)
    {
      NSLog(@"HAL setup failed. Exiting...");
      return NO;
    }

  // Setup 
  libhal_ctx_set_dbus_connection(hal_ctx, conn);
  libhal_ctx_init(hal_ctx, &error);

  libhal_ctx_set_device_added(hal_ctx, device_added);
  libhal_ctx_set_device_removed(hal_ctx, device_removed);
  libhal_ctx_set_device_condition(hal_ctx, device_condition_changed);
  libhal_ctx_set_device_property_modified(hal_ctx, property_modified);

  libhal_device_property_watch_all(hal_ctx, &error);

  // Setup D-BUS message queue
  dbus_connection_ref(conn);
  dbus_connection_dispatch(conn);
  dbus_connection_unref(conn);

  return self;
}

- (void)dealloc
{
  // Shutdown DBUS
  dbus_connection_unref(conn);

  // Shutdown HAL
  dbus_error_init(&error);
  libhal_ctx_shutdown(hal_ctx, &error);
  libhal_ctx_free(hal_ctx);

  [super dealloc];
}

//-----------------------------------------------------------------------
//--- Volumes
//-----------------------------------------------------------------------

// Returns dictionaries list of mounted NXVolume's (fixed and removable)
- (NSArray *)mountedVolumes
{
  NSMutableArray *mountedVolumes = [NSMutableArray new];
  NSEnumerator   *e = [[self _availableVolumes] objectEnumerator];
  NSDictionary   *volDesc;
  
  while ((volDesc = [e nextObject]) != nil)
    {
      if (![[volDesc objectForKey:@"MountPoint"] isEqualToString:@""])
        {
          [mountedVolumes addObject:volDesc];
        }
    }
    
  return mountedVolumes;
}

// 'path' is not necessary a mount point, it can be some path inside
// mounted filesystem
- (NXTFSType)fsTypeAtPath:(NSString *)path
{
  NSEnumerator *e = [[self mountedVolumes] objectEnumerator];
  NSDictionary *volDesc;
  NSString     *fsType = nil;
  NSString     *mp;
  NSString     *mountPoint;

  if ((volDesc = [self _volumeDescriptionForPath:path]) == nil)
    {
      return -1;
    }

  fsType = [volDesc objectForKey:@"FileSystemType"];
  
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

  return -1;
}

//--- NSWorkspace

- (void)checkForRemovableMedia
{
  [self mountNewRemovableMedia];
}

// Returns list of pathnames to newly mounted volumes.
- (NSArray *)mountNewRemovableMedia
{
  // Check for unmounted removables and mount them.
  return nil;
}

// Returns list of pathnames to already mounted volumes.
- (NSArray *)mountedRemovableMedia
{
  NSMutableArray *mountPaths = [NSMutableArray new];
  NSEnumerator   *e = [[self mountedVolumes] objectEnumerator];
  NSDictionary   *volDesc;
  
  while ((volDesc = [e nextObject]) != nil)
    {
      [mountPaths addObject:[volDesc objectForKey:@"MountPoint"]];
    }
    
  return mountPaths;
}

// Unmounts and ejects device mounted at 'path'.
// FIXME
- (BOOL)unmountAndEjectDeviceAtPath:(NSString *)path
{
  NSDictionary *volDesc = [self _volumeDescriptionForPath:path];

  if (volDesc)
    {
      return [self _unmountVolume:volDesc];
    }
  
  return NO;
}

@end

#endif
