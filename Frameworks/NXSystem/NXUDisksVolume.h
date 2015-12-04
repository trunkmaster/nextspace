/*
 * NXUDisksVolume.h
 * 
 * Media object which treated by UDisks as 'block_devices' object.
 * Can contain filesystem, swap, extended partition, RAID volume.
 *
 * Copyright, 2015, Serg Stoyan
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

#import <NXSystem/NXMediaManager.h>
#import <NXSystem/NXUDisksAdaptor.h>
#import <NXSystem/NXUDisksDrive.h>

@class NXUDisksDrive;

@interface NXUDisksVolume : NSObject <UDisksMedia>
{
  NXUDisksAdaptor     *adaptor;
  NSMutableDictionary *properties;
  NSString            *objectPath;
  NXUDisksDrive       *drive;

  NSNotificationCenter *notificationCenter;
}

//--- Parent object
- (NXUDisksAdaptor *)adaptor;
- (NXUDisksDrive *)drive;
- (void)setDrive:(NXUDisksDrive *)driveObject;
- (NXUDisksVolume *)masterVolume;
- (NSString *)driveObjectPath;

//--- Accessories
- (NXFSType)type;
- (NSString *)UUID;
- (NSString *)label;
- (NSString *)size;
- (NSString *)UNIXDevice;
- (NSString *)mountPoints;

- (NSString *)partitionType;
- (NSString *)partitionNumber;
- (NSString *)partitionSize;

- (BOOL)isFilesystem;
- (BOOL)isMounted;
- (BOOL)isWritable;

- (BOOL)isLoopVolume;
- (BOOL)isSystem;

//--- Actions

// Creates Job object. Returns mount point.
- (NSString *)mount:(BOOL)wait;

// Creates Job object. Returns YES on success, NO - otherwise.
- (BOOL)unmount:(BOOL)wait;

@end

#endif // WITH_UDISKS
