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

#import <DesktopKit/NXTFileManager.h>
#import <SystemKit/OSEUDisksAdaptor.h>
#import <SystemKit/OSEUDisksDrive.h>
#import <SystemKit/OSEUDisksVolume.h>

static NSNotificationCenter *notificationCenter;

static GMainLoop       *glib_mainloop;
static UDisksClient    *udisks_client; // used by UDisks callback functions
static OSEUDisksAdaptor *udisksAdaptor; // used by UDisks callback functions

NSString *GSTR_2STR(const gchar *s)
{
  return [NSString stringWithCString:s];
}

NSArray *GARR_2ARR(const gchar *const*s) // TODO: multiple entries
{
  int            el_count = g_strv_length((gchar**)s);
  int            i;
  NSMutableArray *array;

  if (el_count == 0)
    {
      return nil;
    }
  else if (el_count == 1)
    {
      return [NSArray arrayWithObject:[NSString stringWithCString:s[0]]];
    }

  // multiple entries
  array = [NSMutableArray new];
  for (i=0; i < el_count; i++)
    {
      [array addObject:[NSString stringWithCString:s[i]]];
    }

  return array;
}

//-----------------------------------------------------------------------
//--- Monitoring (GLib, GIO, UDisks)
//-----------------------------------------------------------------------

@implementation OSEUDisksAdaptor (Monitoring)

//--- Modified utility functions from 'udisksctl'
static gchar *
variant_to_string_with_indent (GVariant *value,
                               guint     indent)
{
  gchar *value_str;
 
  if (g_variant_is_of_type (value, G_VARIANT_TYPE_STRING))
    {
      value_str = g_variant_dup_string (value, NULL);
    }
  else if (g_variant_is_of_type (value, G_VARIANT_TYPE_BYTESTRING))
    {
      value_str = g_variant_dup_bytestring (value, NULL);
    }
  else if (g_variant_is_of_type (value, G_VARIANT_TYPE_STRING_ARRAY) ||
           g_variant_is_of_type (value, G_VARIANT_TYPE_BYTESTRING_ARRAY))
    {
      const gchar **strv;
      guint m;
      GString *str;
      if (g_variant_is_of_type (value, G_VARIANT_TYPE_BYTESTRING_ARRAY))
        strv = g_variant_get_bytestring_array (value, NULL);
      else
        strv = g_variant_get_strv (value, NULL);
      str = g_string_new (NULL);
      for (m = 0; strv != NULL && strv[m] != NULL; m++)
        {
          if (m > 0)
            g_string_append_printf (str, "\n%*s", indent, "");
          g_string_append (str, strv[m]);
        }
      value_str = g_string_free (str, FALSE);
      g_free (strv);
    }
  else
    {
      gchar *tmp_str;
      value_str = g_variant_print (value, FALSE);
      if (value_str[0] == '\'')
        {
          tmp_str = strndup(value_str+1, strlen(value_str)-2);
          free(value_str);
          value_str = tmp_str;
        }
    }
  return value_str;
}

//--- Interesting functions

// Interesting objects are: Drive, Block, Job
static void
monitor_on_object_added(GDBusObjectManager *manager,
                        GDBusObject *object,
                        gpointer user_data)
{
  const gchar  *object_path;
  UDisksObject *ud_object;
  
  object_path = g_dbus_object_get_object_path(object);
  ud_object = udisks_client_get_object(udisks_client, object_path);
  
  [udisksAdaptor _addUDisksObject:ud_object andNotify:YES];
  
  // g_print("Object Added: %s\n", object_path);
}

// Interesting objects are: Drive, Block, Job
static void
monitor_on_object_removed(GDBusObjectManager *manager,
                           GDBusObject *object,
                           gpointer user_data)
{
  const gchar *object_path;
  
  object_path = g_dbus_object_get_object_path(object);
  
  [udisksAdaptor _removeUDisksObjectWithPath:object_path];

  // g_print("Object Removed: %s\n", g_dbus_object_get_object_path(object));
}

// Interesting objects(properties): Block(mount point)

static void
monitor_on_interface_proxy_properties_changed(GDBusObjectManagerClient *manager,
                                              GDBusObjectProxy *object_proxy,
                                              GDBusProxy *interface_proxy,
                                              GVariant *changed_properties,
                                              const gchar* const *invalidated_properties,
                                              gpointer user_data)
{
  GVariantIter    *iter = NULL;
  const gchar     *property_name = NULL;
  GVariant        *value = NULL;
  const gchar     *value_str = NULL;
  const gchar     *object_path = NULL;
  const gchar     *interface_name = NULL;
  id<UDisksMedia> media;
  NSArray         *removedProps;

  object_path = g_dbus_object_get_object_path(G_DBUS_OBJECT(object_proxy));
  interface_name = g_dbus_proxy_get_interface_name(interface_proxy);
  
  // g_print ("%s: %s: Properties Changed\n", object_path, interface_name);

  g_variant_get(changed_properties, "a{sv}", &iter);
  media = [udisksAdaptor _objectWithUDisksPath:object_path];
  
  while (g_variant_iter_next(iter, "{&sv}", &property_name, &value))
    {
      value_str = variant_to_string_with_indent(value,0);
      // g_print("  %s: '%s'\n", property_name, value_str);
      
      [media setProperty:GSTR_2STR(property_name)
                   value:GSTR_2STR(value_str)
           interfaceName:GSTR_2STR(interface_name)];
      
      g_variant_unref(value);
    }

  // Remove invalidated properties
  removedProps = GARR_2ARR(invalidated_properties);
  if (removedProps)
    {
      [media removeProperties:removedProps
                interfaceName:GSTR_2STR(interface_name)];
    }
}

// 4FUTURE: Interesting objects: Job(object(Block), status, completion, progress)
static void
monitor_on_interface_proxy_signal(GDBusObjectManagerClient *manager,
                                  GDBusObjectProxy         *object_proxy,
                                  GDBusProxy               *interface_proxy,
                                  const gchar              *sender_name,
                                  const gchar              *signal_name,
                                  GVariant                 *parameters,
                                  gpointer                  user_data)
{
  gchar        *param_str;
  UDisksJob    *job;
  const gchar  *object_path;
  UDisksObject *object;
  const gchar *const *job_objects;

  param_str = g_variant_print(parameters, TRUE);
  // g_print ("Signal '%s:%s' on interface proxy %s:%s\n",
  //          signal_name,
  //          param_str,
  //          g_dbus_proxy_get_interface_name(interface_proxy),
  //          g_dbus_object_get_object_path(G_DBUS_OBJECT(object_proxy)));
  g_free (param_str);

  // Get object
  object_path = g_dbus_object_get_object_path(G_DBUS_OBJECT(object_proxy));
  object = udisks_client_get_object(udisks_client, object_path);

  // Job signal
  if ((job = udisks_object_peek_job(object)) != NULL)
    {
      job_objects = udisks_job_get_objects(job);
      // g_print("Job status changed for %s:\n", object_path);
      // g_print("\tObject path: %s\n\tOperation: %s\n\tObject: %s\n"
      //         "\tSignal: %s\n\tParameters: %s\n",
      //         object_path, udisks_job_get_operation(job), job_objects[0],
      //         signal_name, g_variant_print(parameters, TRUE));

      [udisksAdaptor _updateJob:object_path
                        objects:job_objects
                         signal:signal_name
                     parameters:parameters];
    }
                                                      
}

//--- Less interesting functions

static void
monitor_on_interface_proxy_added(GDBusObjectManager *manager,
                                  GDBusObject *object,
                                  GDBusInterface *interface,
                                  gpointer user_data)
{
  const gchar     *interface_name = NULL;
  const gchar     *object_path = NULL;
  id<UDisksMedia> media;

  // g_print ("%s: Added interface %s\n",
  //            g_dbus_object_get_object_path (object),
  //            g_dbus_proxy_get_interface_name (G_DBUS_PROXY (interface)));

  interface_name = g_dbus_proxy_get_interface_name(G_DBUS_PROXY(interface));
  object_path = g_dbus_object_get_object_path (object);
  
  media = [udisksAdaptor _objectWithUDisksPath:object_path];
  
  [media setProperty:nil value:nil interfaceName:GSTR_2STR(interface_name)];
  
  // print_interface_properties (G_DBUS_PROXY (interface), 2);
}

static void
monitor_on_interface_proxy_removed(GDBusObjectManager *manager,
                                    GDBusObject        *object,
                                    GDBusInterface     *interface,
                                    gpointer            user_data)
{
  // g_print ("%s: Removed interface %s\n",
  //            g_dbus_object_get_object_path (object),
  //            g_dbus_proxy_get_interface_name (G_DBUS_PROXY (interface)));
}


// Timer selector
- (void)_glibRunLoopIterate
{
  g_main_context_iteration(g_main_loop_get_context(glib_mainloop), FALSE);
}

- (void)_startEventsMonitor
{
  GDBusObjectManager *udisks_object_manager = NULL;

  // Free with g_object_unref() when done with it.
  udisks_object_manager = udisks_client_get_object_manager(udisks_client);

  // Set events monitoring callbacks
  g_signal_connect(udisks_object_manager,
                   "object-added",
                   G_CALLBACK(monitor_on_object_added),
                   NULL);
  g_signal_connect(udisks_object_manager,
                   "object-removed",
                   G_CALLBACK(monitor_on_object_removed),
                   NULL);
  g_signal_connect(udisks_object_manager,
                   "interface-proxy-properties-changed",
                   G_CALLBACK(monitor_on_interface_proxy_properties_changed),
                   NULL);
  g_signal_connect(udisks_object_manager,
                   "interface-proxy-signal",
                   G_CALLBACK(monitor_on_interface_proxy_signal),
                   NULL);
  
  g_signal_connect(udisks_object_manager,
                   "interface-added",
                   G_CALLBACK(monitor_on_interface_proxy_added),
                   NULL);
  g_signal_connect(udisks_object_manager,
                   "interface-removed",
                   G_CALLBACK(monitor_on_interface_proxy_removed),
                   NULL);

  glib_mainloop = g_main_loop_new(NULL, TRUE);
  
  monitorTimer = [NSTimer
                   scheduledTimerWithTimeInterval:1.0
                                           target:self
                                         selector:@selector(_glibRunLoopIterate)
                                         userInfo:nil
                                          repeats:YES];
}

- (void)_stopEventsMonitor
{
  [monitorTimer invalidate];
}

@end


//-----------------------------------------------------------------------
//--- Volumes (filesystems) information
//-----------------------------------------------------------------------

@implementation OSEUDisksAdaptor (Info)

//--- Convert UDisks objects into NSDictionary
//    Utilities from 'udisksctl'
static NSMutableDictionary *_propertiesForUDisksInterface(GDBusProxy *proxy)
{
  gchar **cached_properties;
  guint n;
  NSMutableDictionary *propertiesDict = [NSMutableDictionary new];

  /* note: this is guaranteed to be sorted */
  cached_properties = g_dbus_proxy_get_cached_property_names(proxy);

  for (n = 0; cached_properties != NULL && cached_properties[n] != NULL; n++)
    {
      const gchar *property_name = cached_properties[n];
      GVariant    *value;
      gchar       *value_str;

      value = g_dbus_proxy_get_cached_property(proxy, property_name);
      value_str = variant_to_string_with_indent(value, 0);

      [propertiesDict setObject:[NSString stringWithCString:value_str]
                         forKey:[NSString stringWithCString:property_name]];

      g_free(value_str);
      g_variant_unref(value);
    }
  g_strfreev(cached_properties);

  return propertiesDict;
}

// /org/freedesktop/UDisks2/drives/WDC_WD10JPVX...
static NSMutableDictionary *_dictionaryFromUDisksObject(UDisksObject *object)
{
  GList               *interface_proxies = NULL;
  GList               *l = NULL;
  GDBusProxy          *iproxy = NULL;
  const gchar         *interface_name = NULL;
  NSMutableDictionary *objectDict;

  // g_return_if_fail(G_IS_DBUS_OBJECT(object));

  objectDict = [NSMutableDictionary new];
  interface_proxies = g_dbus_object_get_interfaces(G_DBUS_OBJECT(object));

  for (l = interface_proxies; l != NULL; l = l->next)
    {
      iproxy = G_DBUS_PROXY(l->data);
      interface_name = g_dbus_proxy_get_interface_name(iproxy);
      
      [objectDict setObject:_propertiesForUDisksInterface(iproxy)
                     forKey:GSTR_2STR(interface_name)];
    }
  
  g_list_foreach(interface_proxies, (GFunc)g_object_unref, NULL);
  g_list_free(interface_proxies);

  return objectDict;
}

//--- Access to properties of gathered objects (drives, volumes)
- (NSString *)propertyWithName:(NSString *)property
                     interface:(NSString *)interface
                        object:(NSDictionary *)object
{
  NSDictionary *interfaceDict;
  NSString     *value = nil;
  NSArray      *arrayValue = nil;
  
  if ((interfaceDict = [object objectForKey:interface]))
    {
      if ((value = [interfaceDict objectForKey:property]))
        {
          if ((arrayValue = [value componentsSeparatedByString:@"\n"]))
            {
              if ([arrayValue count] > 1)
                value = [arrayValue componentsJoinedByString:@","];
              else
                value = [arrayValue objectAtIndex:0];
            }
        }
    }

  return value;
}

- (NSString *)jobProperty:(NSString *)property
                   forJob:(NSDictionary *)job
{
  return [self propertyWithName:property
                      interface:@"org.freedesktop.UDisks2.Job"
                         object:job];
}

// TODO: join with propertyWithName...?
- (id)objectForJob:(NSDictionary *)job
{
  NSString *objectPath = [self jobProperty:@"Objects" forJob:job];
  id theObject;

  if ([objectPath rangeOfString:@"["].location == 0)
    {
      objectPath = [objectPath stringByReplacingOccurrencesOfString:@"[" withString:@""];
      objectPath = [objectPath stringByReplacingOccurrencesOfString:@"]" withString:@""];
      objectPath = [objectPath stringByReplacingOccurrencesOfString:@"'" withString:@""];
    }

  return [self _objectWithUDisksPath:[objectPath cString]];
}

//--- Add/Remove UDisks objects

- (id)_objectWithUDisksPath:(const gchar *)object_path
{
  NSString *objectPath = GSTR_2STR(object_path);
  NSArray  *pathComponents = [objectPath pathComponents];
  NSString *objectType;

  objectType = [pathComponents objectAtIndex:[pathComponents count] - 2];
  
  if ([objectType isEqualToString:@"drives"])
    {
      return [drives objectForKey:objectPath];
    }
  else if ([objectType isEqualToString:@"block_devices"])
    {
      return [volumes objectForKey:objectPath];
    }
  else if ([objectType isEqualToString:@"jobs"])
    {
      return [jobsCache objectForKey:objectPath];
    }
  
  return nil;
}

- (void)_addUDisksObject:(UDisksObject *)object
               andNotify:(BOOL)notify
{
  NSString       *objectPath;
  NSArray        *pathComponents;
  NSString       *objectType;
  NSDictionary   *driveProps, *volumeProps, *job;
  OSEUDisksDrive  *drive;
  OSEUDisksVolume *volume;
      
  objectPath = GSTR_2STR(g_dbus_object_get_object_path(G_DBUS_OBJECT(object)));
  pathComponents = [objectPath pathComponents];
  objectType = [pathComponents objectAtIndex:[pathComponents count] - 2];

  if ([objectType isEqualToString:@"drives"])
    {
      driveProps = _dictionaryFromUDisksObject(object);
      // Missed volumes added here
      drive = [[OSEUDisksDrive alloc] initWithProperties:driveProps
                                             objectPath:objectPath
                                                adaptor:self];
      [drives setObject:drive forKey:objectPath];
      // [drives writeToFile:@"Library/Workspace/Drives.plist" atomically:YES];

      if (notify)
        {
          [notificationCenter postNotificationName:OSEDiskAppeared
                                            object:self
                                          userInfo:driveProps];
        }
    }
  else if ([objectType isEqualToString:@"block_devices"])
    {
      volumeProps = _dictionaryFromUDisksObject(object);
      volume = [[OSEUDisksVolume alloc] initWithProperties:volumeProps
                                               objectPath:objectPath
                                                  adaptor:self];
      [volumes setObject:volume forKey:objectPath];
      // [volumes writeToFile:@"Library/Workspace/Volumes.plist" atomically:YES];

      // Connect the dots. If drive is not yet registered, volume will be added
      // on drive creation (see 'if' above)
      
      if (notify)
        {
          [notificationCenter postNotificationName:NXVolumeAppeared
                                            object:self
                                          userInfo:volumeProps];
          if ([volume isFilesystem])
            {
              // Emits NXVolumeMounted notification
              // We are called by event of inserted device not during initial
              // registraion of objects.
              [volume mount:NO];
            }
        }
    }
  // else if ([objectType isEqualToString:@"jobs"])
  //   {
  //     job = _dictionaryFromUDisksObject(object);
  //     [jobsCache setObject:job forKey:objectPath];
  //     [jobsCache writeToFile:@"Library/Workspace/JobsCache.plist" atomically:YES];
      
  //     if (notify)
  //       {
  //         NSString *op = [self jobProperty:@"Operation" forJob:job];
  //         NSString *operation = nil, *message, *object;

  //         if ([op isEqualToString:@"filesystem-mount"])
  //           {
  //             operation = @"Mount";
  //             object = [(OSEUDisksVolume *)[self objectForJob:job] UNIXDevice];
  //           }
  //         else if ([op isEqualToString:@"filesystem-unmount"])
  //           {
  //             operation = @"Unmount";
  //             object = [(OSEUDisksVolume *)[self objectForJob:job] mountPoints];
  //           }
  //         else if ([op isEqualToString:@"drive-eject"])
  //           {
  //             operation = @"Eject";
  //             object = [(OSEUDisksDrive *)[self objectForJob:job] humanReadableName];
  //           }

  //         if (operation)
  //           {
  //             message = [NSString stringWithFormat:@"%@ing %@...", operation, object];
  //             [self operationWithName:operation
  //                             jobPath:objectPath
  //                              failed:NO
  //                              status:@"Started"
  //                               title:operation
  //                             message:message];
  //           }
  //       }
  //  }
}

// On the event of unsafely disconnected removable drive UDisks make cleanup
// of all objects related to disconnected drive. During cleanup unmount
// notification is not sent. 
// Unsafe detach action chain:
//   * volumes removed - drive added to drivesToCleanup list;
//   * drive removed - if drive in drivesToClean send message to application;
//                     drive deleted from drivesToCleanup list.
- (void)_removeUDisksObjectWithPath:(const gchar *)object_path
{
  NSString            *objectPath = GSTR_2STR(object_path);
  NSArray             *pathComponents = [objectPath pathComponents];
  NSString            *objectType;
  OSEUDisksDrive       *drive;
  OSEUDisksVolume      *volume;
  NSDictionary        *info;
  NSString            *message = nil;
  
  objectType = [pathComponents objectAtIndex:[pathComponents count] - 2];
  
  if ([objectType isEqualToString:@"drives"])
    {
      drive = [drives objectForKey:objectPath];
      
      if ([drivesToCleanup containsObject:objectPath])
        {
          message = [NSString
                          stringWithFormat:
                        @"Disk '%@' with mounted volumes was disconnected.\n"
                      "Eject disk before disconnecting to avoid data loss.",
                      [drive humanReadableName]];
          
          [self operationWithName:@"Detach"
                          object:drive
                           failed:YES
                           status:@"Completed"
                            title:@"Unsafe media detach"
                          message:message];
          [drivesToCleanup removeObject:objectPath];
        }

      if (message)
        {
          info = [NSDictionary dictionaryWithObjectsAndKeys:
                                 @"Info",       @"MessageType",
                               @"Eject Disk", @"MessageTitle",
                               message,       @"Message", nil];
          // OSEDiskDisappeared notification
          [notificationCenter postNotificationName:OSEDiskDisappeared
                                            object:self
                                          userInfo:info];
        }

      [drives removeObjectForKey:objectPath];
      // [drives writeToFile:@"Library/Workspace/Drives.plist" atomically:YES];
      return;
    }
  else if ([objectType isEqualToString:@"block_devices"])
    {
      volume = [volumes objectForKey:objectPath];
      
      if ([volume isMounted])
        {
          [drivesToCleanup addObject:[[volume drive] objectPath]];
        }
      
      // NXVolumeDisappeared notification
      [notificationCenter postNotificationName:NXVolumeDisappeared
                                        object:self
                                      userInfo:[volume properties]];

      [[volume drive] removeVolumeWithKey:objectPath];
      [volumes removeObjectForKey:objectPath];
      // [volumes writeToFile:@"Library/Workspace/Volumes.plist" atomically:YES];
      return;
    }
  else if ([objectType isEqualToString:@"jobs"])
    {
      [jobsCache removeObjectForKey:objectPath];
    }
}

- (void)_registerObjects:(UDisksClient *)client
{
  GList *l;
  GList *objects;

  // Clear cache first
  [drives removeAllObjects];
  [volumes removeAllObjects];
  
  // Get list of UDisksObject (udisks object manager holds list of dbus objects
  // of this type)
  objects =
    g_dbus_object_manager_get_objects(udisks_client_get_object_manager(udisks_client));
  for (l = objects; l != NULL; l = l->next)
    {
      [self _addUDisksObject:UDISKS_OBJECT(l->data) andNotify:NO];
    }
  
  g_list_foreach(objects, (GFunc)g_object_unref, NULL);
  g_list_free(objects);
}

//--- Signals // TODO
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
  if ([name isEqualToString:@"Mount"] || [name isEqualToString:@"Unmount"])
    {
      [info setObject:[object UNIXDevice] forKey:@"UNIXDevice"];
    }
  else if ([name isEqualToString:@"Eject"])
    {
      [info setObject:[object humanReadableName] forKey:@"UNIXDevice"];
    }

  if (failed)
    {
      [info setObject:@"false" forKey:@"Success"];
    }
  else
    {
      [info setObject:@"true" forKey:@"Success"];
    }

  if ([status isEqualToString:@"Started"])
    {
      [notificationCenter postNotificationName:OSEMediaOperationDidStart
                                        object:self
                                      userInfo:info];
    }
  else 
    {
      // "Completed" - operation was started by framework methods.
      // NXVolume* and OSEMediaOperation* notifications will be sent.
      // "Occured" - operation was performed without framework methods (outside)
      // of application. Only NXVolume* notification will be sent.
      if ([name isEqualToString:@"Mount"] || [name isEqualToString:@"Unmount"])
        {
          [info setObject:[object UNIXDevice] forKey:@"UNIXDevice"];
          
          if ([name isEqualToString:@"Mount"] && !failed)
            {
              [info setObject:[object mountPoints] forKey:@"MountPoint"];
              [notificationCenter postNotificationName:NXVolumeMounted
                                                object:self
                                              userInfo:info];
            }
          else if ([name isEqualToString:@"Unmount"] && !failed)
            {
              NSString *mp = [object mountPoints];

              // If "MountPoint" property of NX*Volume already updated
              // get value saved into "OldMountPoint" property
              if (!mp || [mp isEqualToString:@""])
                {
                  mp = [object propertyForKey:@"OldMountPoint"
                                    interface:FS_INTERFACE];
                }
              [info setObject:mp forKey:@"MountPoint"];
              [notificationCenter postNotificationName:NXVolumeUnmounted
                                                object:self
                                              userInfo:info];
            }
        }

      if ([status isEqualToString:@"Completed"])
        {
          [notificationCenter postNotificationName:OSEMediaOperationDidEnd
                                            object:self
                                          userInfo:info];
        }
    }
}

// It's always called by monitor_on_interface_proxy_signal().
- (void)_updateJob:(const gchar *)job_path
           objects:(const gchar *const *)job_objects
            signal:(const gchar *)signal_name
        parameters:(GVariant *)parameters
{
  // NSDictionary    *job = [self _objectWithUDisksPath:job_path];
  // NSString        *operation = [self jobProperty:@"Operation" forJob:job];
  // NSString        *objectName = nil;
  // NSString        *op = nil;
  // NSMutableString *message = nil;
  // NSString        *title = nil;
  // BOOL            isOperationFailed;

  // NSLog(@"_updateJob:objects:%@", GARR_2ARR(job_objects));

  // // TODO: Convert from g* to ObjC types needs review across all OSEUDisks* classes.
  // NSString        *params;
  // NSArray         *paramsArray;
  // // Normalize parameters list before NSString will be converted to NSArray.
  // params = [NSString stringWithCString:g_variant_print(parameters, TRUE)];
  // params = [params stringByReplacingOccurrencesOfString:@"\'" withString:@"\\\""];
  // params = [params stringByReplacingOccurrencesOfString:@"`" withString:@"\\\""];
  // params = [params stringByReplacingOccurrencesOfString:@"\\\"" withString:@""];
  // NSDebugLLog(@"udisks", @"Signal Parameters NSString: %@", params);
  
  // paramsArray = [params propertyList];
  // NSDebugLLog(@"udisks", @"Signal Parameters NSArray: %@", paramsArray);

  // // Status
  // isOperationFailed = [[paramsArray objectAtIndex:0] isEqualToString:@"false"];
  
  // // Operation, JobPath(?)
  // if ([operation isEqualToString:@"filesystem-unmount"])
  //   {
  //     objectName = [(OSEUDisksVolume *)[self objectForJob:job] UNIXDevice];
  //     op = @"Unmount";
  //   }
  // else if ([operation isEqualToString:@"filesystem-mount"])
  //   {
  //     objectName = [(OSEUDisksVolume *)[self objectForJob:job] UNIXDevice];
  //     op = @"Mount";
  //   }
  // // 'Eject' is a special case: contains unmounting all volumes of drive,
  // // eject ('drive-eject') and power off. Thus notifications about start and finish
  // // of eject process are sent by OSEUDisksDrive object.
  // // Except the failed eject process.
  // else if ([operation isEqualToString:@"drive-eject"] && isOperationFailed)
  //   {
  //     objectName = [(OSEUDisksDrive *)[self objectForJob:job] humanReadableName];
  //     op = @"Eject";
  //   }
      
  // if (!strcmp(signal_name, "Completed"))
  //   {
  //     // Message and Title
  //     if (isOperationFailed)
  //       {
  //         //--- "Message"
  //         if ([paramsArray count] > 1)
  //           {
  //             message = [[paramsArray objectAtIndex:1] mutableCopy];
  //             NSUInteger iters = ([message length]/80) - 1, i;

  //             for (i = 1; i <= iters; i++)
  //               {
  //                 [message insertString:@"\n" atIndex:80*i];
  //               }
  //           }
  //         title = [NSString stringWithFormat:@"%@ Error", op];
  //       }
  //     else
  //       {
  //         message = [NSString stringWithFormat:@"%@ing of '%@' finished",
  //                             op, objectName];
  //         title = [NSString stringWithFormat:@"%@ Finished", op];
  //       }

  //     // Send notification
  //     if (op)
  //       {
  //         [self operationWithName:op
  //                         jobPath:[NSString stringWithCString:job_path]
  //                          failed:isOperationFailed
  //                          status:@"Completed"
  //                           title:title
  //                         message:message];
  //       }
  //   }
  // else if (!strcmp(signal_name, "Started"))
  //   {
  //     NSLog(@"Job %s was started!", job_path);
      
  //     message = [NSString stringWithFormat:@"%@ing %@", op, objectName];
      
  //     if (op)
  //       {
  //         [self operationWithName:op
  //                         jobPath:[NSString stringWithCString:job_path]
  //                          failed:isOperationFailed
  //                          status:@"Started"
  //                           title:op
  //                         message:message];
  //       }
  //   }
}

- (NSString *)descriptionForError:(GError *)error
{
  // UDISKS_ERROR_DEVICE_BUSY: Attempting to unmount a device that is busy.
  if (g_error_matches(error, UDISKS_ERROR, UDISKS_ERROR_DEVICE_BUSY))
    {
      return @"Failed to unmount a media that is busy by active process.";
    }
   // UDISKS_ERROR_FAILED: The operation failed.
  else if (g_error_matches(error, UDISKS_ERROR, UDISKS_ERROR_FAILED))
    {
      return @"The operation failed.";
    }
   // UDISKS_ERROR_CANCELLED: The operation was cancelled.
   // UDISKS_ERROR_ALREADY_CANCELLED: The operation has already been cancelled.
  else if (g_error_matches(error, UDISKS_ERROR, UDISKS_ERROR_CANCELLED) ||
           g_error_matches(error, UDISKS_ERROR, UDISKS_ERROR_ALREADY_CANCELLED))
    {
      return @"The operation was canceled.";
    }
   // UDISKS_ERROR_TIMED_OUT: The operation timed out.
  else if (g_error_matches(error, UDISKS_ERROR, UDISKS_ERROR_TIMED_OUT))
    {
      return @"The operation timed out.";
    }
  // UDISKS_ERROR_NOT_AUTHORIZED: Not authorized to perform the requested operation.
  // UDISKS_ERROR_NOT_AUTHORIZED_CAN_OBTAIN: Like %UDISKS_ERROR_NOT_AUTHORIZED
  // but authorization can be obtained through e.g. authentication.
  // UDISKS_ERROR_NOT_AUTHORIZED_DISMISSED: Like %UDISKS_ERROR_NOT_AUTHORIZED but an
  // authentication was shown and the user dimissed it.
  else if (g_error_matches(error, UDISKS_ERROR,UDISKS_ERROR_NOT_AUTHORIZED) ||
           g_error_matches(error, UDISKS_ERROR, UDISKS_ERROR_NOT_AUTHORIZED_CAN_OBTAIN) ||
           g_error_matches(error, UDISKS_ERROR, UDISKS_ERROR_NOT_AUTHORIZED_DISMISSED))
    {
      return @"You do not have permission to perform the requested operation.";
    }
  // UDISKS_ERROR_ALREADY_MOUNTED: The device is already mounted.
  else if (g_error_matches(error, UDISKS_ERROR, UDISKS_ERROR_ALREADY_MOUNTED))
    {
      return @"The device is already mounted.";
    }
  // UDISKS_ERROR_NOT_MOUNTED: The device is not mounted.
  else if (g_error_matches(error, UDISKS_ERROR, UDISKS_ERROR_NOT_MOUNTED))
    {
      return @"The device is not mounted.";
    }
  // UDISKS_ERROR_OPTION_NOT_PERMITTED: Not permitted to use the requested option.
  else if (g_error_matches(error, UDISKS_ERROR, UDISKS_ERROR_OPTION_NOT_PERMITTED))
    {
      return @"You do not have permission to used requested option.";
    }
  // UDISKS_ERROR_MOUNTED_BY_OTHER_USER: The device is mounted by another user.
  else if (g_error_matches(error, UDISKS_ERROR, UDISKS_ERROR_MOUNTED_BY_OTHER_USER))
    {
      return @"The media is mounted by another user.";
    }
  // UDISKS_ERROR_ALREADY_UNMOUNTING: The device is already unmounting.
  else if (g_error_matches(error, UDISKS_ERROR, UDISKS_ERROR_ALREADY_UNMOUNTING))
    {
      return @"The media unmounting is already in progress.";
    }
  // UDISKS_ERROR_NOT_SUPPORTED: The operation is not supported due to missing
  // driver/tool support.
  else if (g_error_matches(error, UDISKS_ERROR, UDISKS_ERROR_NOT_SUPPORTED))
    {
      return @"The operation is not supported due to missing driver/tool support.";
    }
  // UDISKS_ERROR_WOULD_WAKEUP: The operation would wake up a disk that is
  // in a deep-sleep state.
  else if (g_error_matches(error, UDISKS_ERROR, UDISKS_ERROR_NOT_SUPPORTED))
    {
      return @"The operation is not supported due to missing driver/tool support.";
    }

  return nil;
}

@end

//-----------------------------------------------------------------------
//--- Actions
//-----------------------------------------------------------------------

@implementation OSEUDisksAdaptor

- (id)init
{
  GError *udisks_error = NULL;
  
  udisksAdaptor = self = [super init];
  
  notificationCenter = [NSNotificationCenter defaultCenter];
  
  udisks_client = udisks_client_new_sync(NULL, &udisks_error);

  jobsCache = [[NSMutableDictionary alloc] init];

  drives = [[NSMutableDictionary alloc] init];
  volumes = [[NSMutableDictionary alloc] init];
 
  drivesToCleanup = [[NSMutableArray alloc] init];
  monitorTimer = nil;

  // Fill drives and volumes arrays with objects
  [self _registerObjects:udisks_client];

  [self _startEventsMonitor];

  return self;
}

- (void)dealloc
{
  NSDebugLLog(@"udisks", @"OSEUDisksAdaptor: dealloc");
  if ([monitorTimer isValid])
    {
      [self _stopEventsMonitor];
    }
  
  // [jobsCache release];
  
  // [drives release];
  // [volumes release];
  
  // [drivesToCleanup release];
  
  g_object_unref(udisks_client);

  [super dealloc];
}

- (UDisksClient *)udisksClient
{
  return udisks_client;
}

//--- Info

// Returns list of OSEUDisksVolume objects.
// Each object represents mounted volume (fixed and removable).
// If path == nil, returns list of all mounted volumes in system.
- (NSArray *)mountedVolumesForDrive:(NSString *)driveObjectPath
{
  NSMutableArray *mountedVolumes;
  NSEnumerator   *e;
  OSEUDisksDrive  *drive;
  NSArray        *driveVolumes;

  if (driveObjectPath)
    {
      drive = [drives objectForKey:driveObjectPath];
      return [drive mountedVolumes];
    }
  
  mountedVolumes = [NSMutableArray new];
  e = [[drives allValues] objectEnumerator];
  while ((drive = [e nextObject]) != nil)
    {
      driveVolumes = [drive mountedVolumes];
      if (driveVolumes && [driveVolumes count] > 0)
        {
          [mountedVolumes addObjectsFromArray:driveVolumes];
        }
    }
    
  return mountedVolumes;
}

// Returns list of all mounted volumes.
// Scan through local volumes cache to get loop volumes (volumes without drive)
- (NSArray *)mountedVolumes
{
  NSMutableArray *mountedVolumes = [NSMutableArray new];

  for (OSEUDisksVolume *volume in [volumes allValues])
    {
      if ([volume isMounted])
        {
          [mountedVolumes addObject:volume];
        }
    }

  return mountedVolumes;
}

// Returns list of pathnames to mount points of already mounted volumes.
   // NSWorkspace
- (NSArray *)mountedRemovableMedia
{
  NSArray        *mountedVolumes = [self mountedVolumes];
  NSEnumerator   *de;
  OSEUDisksVolume *volume;
  NSMutableArray *mountPaths = [NSMutableArray new];

  de = [mountedVolumes objectEnumerator];
  while ((volume = [de nextObject]) != nil)
    {
      NSDebugLLog(@"udisks", @"Adaptor: mountedRemovableMedia check: %@ (%@)",
                  [volume mountPoints],
                  [[[[volume drive] properties] objectForKey:@"org.freedesktop.UDisks2.Drive"] objectForKey:@"Id"]);
      
      if ([volume isFilesystem] &&
          ([[volume drive] isRemovable] ||
           [[volume drive] isMediaRemovable]))
        {
          [mountPaths addObject:[volume mountPoints]];
        }
    }

  NSDebugLLog(@"udisks", @"Adaptor: mountedRemovableMedia: %@",
              mountPaths);

  return mountPaths;
}

// Returns volume dictionary which mounted at 'path'
// 'path' is not necessary a mount point, it can be some path inside
// mounted filesystem
- (OSEUDisksVolume *)mountedVolumeForPath:(NSString *)filesystemPath
{
  NSEnumerator   *e = [[self mountedVolumes] objectEnumerator];
  OSEUDisksVolume *volume = nil, *volume1 = nil;
  NSString       *mp, *mp1;
  NSString       *mountPoint = nil;

  // Find longest mount point for path
  mp = @"";
  while ((volume1 = [e nextObject]) != nil)
    {
      mountPoint = [volume1 mountPoints];
      // NSLog(@"LongestMP(%@): process MP: %@", filesystemPath, mountPoint);
      mp1 = NXTIntersectionPath(filesystemPath, mountPoint);
      if ([mp1 isEqualToString:mountPoint] && ([mp1 length] >= [mp length]))
        {
          ASSIGN(mp, mp1);
          ASSIGN(volume, volume1);
        }
    }

  NSDebugLLog(@"udisks", @"Longest MP: %@ for path %@",
              [volume mountPoints], filesystemPath);

  // if ([[volume mountPoints] isEqualToString:@"/"])
  //   return nil;
  // else
    return [volume autorelease];
}

// 'path' is not necessary a mount point, it can be some path inside
// mounted filesystem
- (NXTFSType)filesystemTypeAtPath:(NSString *)filesystemPath
{
  OSEUDisksVolume *volume = [self mountedVolumeForPath:filesystemPath];

  if (volume == nil)
    {
      return -1;
    }

  return [volume type];
}

// 'path' is not necessary a mount point, it can be some path inside
// mounted filesystem
- (NSString *)mountPointForPath:(NSString *)filesystemPath
{
  return [[self mountedVolumeForPath:filesystemPath] mountPoints];
}

// It's for 'disktool'
// TODO: remove by fixing 'disktool'
- (NSDictionary *)availableDrives
{
  return drives;
}

// Used by OSEUDisksDrive to collect it's volumes.
// That's why we iterate registered volumes.
- (NSDictionary *)availableVolumesForDrive:(NSString *)driveObjectPath
{
  NSArray             *volumePaths = [volumes allKeys];
  OSEUDisksVolume      *volume;
  NSMutableDictionary *driveVolumes = [NSMutableDictionary new];

  for (NSString *path in volumePaths)
    {
      volume = [volumes objectForKey:path];
      if ([[volume driveObjectPath] isEqualToString:driveObjectPath])
        {
          [driveVolumes setObject:volume forKey:path];
        }
    }
  
  return driveVolumes;
}


//--- Actions

// Unmount filesystem mounted at subpath of 'path'.
// Unmount only if FS resides on removable drive.
// Async - OK.
- (void)unmountRemovableVolumeAtPath:(NSString *)path
{
  OSEUDisksVolume *volume = [self mountedVolumeForPath:path];

  if (volume == nil)
    {
      return;
    }

  [volume unmount:NO];
}

- (NSArray *)_mountNewRemovableVolumesAndWait:(BOOL)wait
{
  NSMutableArray *mountPoints = [[NSMutableArray alloc] init];

  for (OSEUDisksDrive  *drive in [drives allValues])
    {
      if ([drive isRemovable])
        {
          [mountPoints addObjectsFromArray:[drive mountVolumes:wait]];
        }
    }

  // Loop devices is always removable and have no drives
  for (OSEUDisksVolume *volume in [volumes allValues])
    {
      if ([volume isLoopVolume] && [volume isFilesystem])
        {
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
// Returns list of pathnames to newly mounted volumes (operation is synchronous).
// Sync - OK.
   // NSWorkspace
- (NSArray *)mountNewRemovableMedia
{
  return [self _mountNewRemovableVolumesAndWait:YES];
}

// Unmounts and ejects device mounted at 'path'.
// Async - OK.
   // NSWorkspace
- (void)unmountAndEjectDeviceAtPath:(NSString *)path
{
  OSEUDisksVolume *volume, *loopMaster;
  OSEUDisksDrive  *drive;
  
  // 1. Found volume mounted at subpath of 'path'
  volume = [self mountedVolumeForPath:path];

  // 2. Found drive which contains volume
  if (![volume isLoopVolume])
    {
      drive = [drives objectForKey:[volume driveObjectPath]];
      // 3. Unmount all volumes mounted from that drive.
      [drive unmountVolumesAndDetach];
    }
  else
    {
      // 3. Get loop master volume
      loopMaster = [volume masterVolume];
      NSLog(@"Eject loop volume: %@ (%@)", loopMaster, volume);
      // 4. Unmount all loop volumes for that master
      if (loopMaster != volume)
        {
          for (OSEUDisksVolume *vol in [volumes allValues])
            {
              NSLog(@">>%@", [vol UNIXDevice]);
              if ([vol masterVolume] == loopMaster)
                {
                  NSLog(@"Unmount volume %@", [vol UNIXDevice]);
                  [vol unmount:NO];
                }
            }
        }
      // 5. Delete loop master volume
      NSString *objectPath;
      if ([volume isLoopVolume] && !loopMaster)
        objectPath = [volume objectPath];
      else
        objectPath = [loopMaster objectPath];
        
      NSLog(@"Now delete loop device: %@", objectPath);
      [self unsetLoop:objectPath];
    }
}

// Operation is synchronous.
// Async - OK.
- (void)ejectAllRemovables
{
  // Loops first...
  for (OSEUDisksVolume *volume in [volumes allValues])
    {
      if ([volume isLoopVolume])
        {
          [volume unmount:YES];
        }
    }

  //...drives then
  for (OSEUDisksDrive *drive in [drives allValues])
    {
      if ([drive isRemovable])
        {
          [drive unmountVolumesAndDetach];
        }
    }
}

//-- Loops

- (BOOL)mountImageMediaFileAtPath:(NSString *)imageFile
{
  return [self setLoopToFileAtPath:imageFile];
}

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

@end

#endif // WITH_UDISKS
