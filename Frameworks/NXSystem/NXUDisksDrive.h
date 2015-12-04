/*
 * NXUDisksDrive.h
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

#import <NXSystem/NXMediaManager.h>
#import <NXSystem/NXUDisksAdaptor.h>
#import <NXSystem/NXUDisksVolume.h>

@class NXUDisksVolume;

@interface NXUDisksDrive : NSObject <UDisksMedia>
{
  NXUDisksAdaptor      *adaptor;
  NSMutableDictionary  *properties;
  NSString             *objectPath;
  
  NSMutableDictionary  *volumes;

  NSNotificationCenter *notificationCenter;

  NSMutableArray *mountedVolumesToDetach;
  BOOL           needsDetach;
}

//--- Object network
- (NSDictionary *)volumes;
- (void)addVolume:(NXUDisksVolume *)volume withPath:(NSString *)volumePath;
- (void)removeVolumeWithKey:(NSString *)key;
- (NSString *)objectPath;

//--- Attributes
- (NSString *)UNIXDevice;
- (NSString *)humanReadableName; // vendor, model
- (BOOL)isRemovable;
- (BOOL)isEjectable;
- (BOOL)canPowerOff;

// valuable for optical disks
- (BOOL)isOptical;
- (BOOL)hasMedia;
- (BOOL)isMediaRemovable;
- (BOOL)isOpticalBlank;
- (NSString *)numberOfAudioTracks;
- (NSString *)numberOfDataTracks;

//--- Actions
- (NSArray *)mountedVolumes;
- (NSArray *)mountVolumes:(BOOL)wait;
- (BOOL)unmountVolumes:(BOOL)wait;
- (void)unmountVolumesAndDetach;
- (BOOL)eject:(BOOL)wait;
- (BOOL)powerOff:(BOOL)wait;

@end

#endif //WITH_UDISKS
