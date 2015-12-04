/*
 * NXUDisksAdaptor.h
 *
 * Provides integration with UDisks subsystem.
 * Construct network of objects: NXUDisksDrive, NXUDisksVolume.
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

#import <Foundation/Foundation.h>
#import <NXSystem/NXMediaManager.h>

#import <udisks/udisks.h>

@interface NXUDisksAdaptor : NSObject <MediaManager>
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

@interface NXUDisksAdaptor (Info)

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
                 adaptor:(NXUDisksAdaptor *)udisksAdaptor;

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
