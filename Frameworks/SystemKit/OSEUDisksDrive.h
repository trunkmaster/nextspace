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
 * Object which represents physical storage device.
 * UDisks base path is: "/org/freedesktop/UDisks2/drives/<name of drive>".
 */

#ifdef WITH_UDISKS

#import <SystemKit/OSEMediaManager.h>
#import <SystemKit/OSEUDisksAdaptor.h>
#import <SystemKit/OSEUDisksVolume.h>

@class OSEUDisksVolume;

@interface OSEUDisksDrive : NSObject <UDisksMedia>
{
  OSEUDisksAdaptor      *adaptor;
  NSMutableDictionary  *properties;
  NSString             *objectPath;
  
  NSMutableDictionary  *volumes;

  NSNotificationCenter *notificationCenter;

  NSMutableArray *mountedVolumesToDetach;
  BOOL           needsDetach;
}

//--- Object network
- (NSDictionary *)volumes;
- (void)addVolume:(OSEUDisksVolume *)volume withPath:(NSString *)volumePath;
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
