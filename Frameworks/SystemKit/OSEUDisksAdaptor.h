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
 * Provides integration with UDisks subsystem.
 * Construct network of objects: OSEUDisksDrive, OSEUDisksVolume.
 */

#ifdef WITH_UDISKS

#import <Foundation/Foundation.h>
#import <SystemKit/OSEMediaManager.h>

#import <udisks/udisks.h>

@interface OSEUDisksAdaptor : NSObject <MediaManager>
{
  NSMutableDictionary *jobsCache;

  NSMutableDictionary *drives;
  NSMutableDictionary *volumes;

  NSMutableArray      *drivesToCleanup; // unsafely detached drives
  
  NSTimer             *monitorTimer;
}

- (UDisksClient *)udisksClient;

- (NSDictionary *)availableDrives;
- (NSDictionary *)availableVolumesForDrive:(NSString *)driveObjectPath;
- (NSArray *)mountedVolumesForDrive:(NSString *)driveObjectPath;

- (BOOL)setLoopToFileAtPath:(NSString *)imageFile;
- (BOOL)unsetLoop:(NSString *)objectPath;

@end

@interface OSEUDisksAdaptor (Info)

- (id)_objectWithUDisksPath:(const gchar *)object_path;

- (void)_addUDisksObject:(UDisksObject *)object
               andNotify:(BOOL)notify;
- (void)_removeUDisksObjectWithPath:(const gchar *)object_path;

- (void)operationWithName:(NSString *)name
                   object:(id)object
                   failed:(BOOL)failed
                   status:(NSString *)status
                    title:(NSString *)title
                  message:(NSString *)message;

- (void)_updateJob:(const gchar *)job_path
           objects:(const gchar *const *)job_objects
            signal:(const gchar *)signal_name
        parameters:(GVariant *)parameters;

- (NSString *)descriptionForError:(GError *)error;

@end

#define DRIVE_INTERFACE     @"org.freedesktop.UDisks2.Drive"
#define ATA_INTERFACE       @"org.freedesktop.UDisks2.Drive.Ata"

#define BLOCK_INTERFACE     @"org.freedesktop.UDisks2.Block"
#define PARTITION_INTERFACE @"org.freedesktop.UDisks2.Partition"
#define PTABLE_INTERFACE    @"org.freedesktop.UDisks2.PartitionTable"
#define FS_INTERFACE        @"org.freedesktop.UDisks2.Filesystem"
#define LOOP_INTERFACE      @"org.freedesktop.UDisks2.Loop"

@protocol UDisksMedia <NSObject>

- (id)initWithProperties:(NSDictionary *)props
              objectPath:(NSString *)path
                 adaptor:(OSEUDisksAdaptor *)udisksAdaptor;

- (void)setProperty:(NSString *)property
              value:(NSString *)value
      interfaceName:(NSString *)interface;

- (void)removeProperties:(NSArray *)properties
           interfaceName:(NSString *)interface;

- (NSDictionary *)properties;
- (NSString *)propertyForKey:(NSString *)key interface:(NSString *)interface;
- (BOOL)boolPropertyForKey:(NSString *)key interface:(NSString *)interface;

- (NSString *)objectPath;

@end

#endif //WITH_UDISKS
