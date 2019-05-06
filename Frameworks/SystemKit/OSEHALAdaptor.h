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

#import <Foundation/Foundation.h>
#import <hal/libhal.h>

@interface NXHALAdaptor : NSObject <DeviceEventsAdaptor>
{
  DBusConnection *conn;
  LibHalContext  *hal_ctx;

  // NSMutableArray *volumes;
}

@end

@interface NXHALAdaptor (Private)

- (void)_messageArrived:(NSNotification *)aNotif;
- (void)_proceedEvent:(NSString *)deviceEvent
               forUDI:(NSString *)udi
                  key:(NSString *)key;

//--- Accessing attributes (properties and capabilities) of HAL object
- (NSArray *)_registeredDevices;
- (id)_propertyValue:(NSString *)key forUDI:(NSString *)udi;
- (BOOL)_deviceWithUDI:(NSString *)UDI hasCapability:(NSString *)capability;

//--- Accessing volumes (filesystems) attributes
- (NSArray *)_availableVolumes;
- (NSDictionary *)_volumeDescriptionForUDI:(NSString *)UDI;
- (NSDictionary *)_volumeDescriptionForPath:(NSString *)path;

- (BOOL)_isDeviceRemovable:(NSString *)UDI;
- (BOOL)_isVolumeOptical:(NSString *)UDI;
- (BOOL)_isVolumeMountable:(NSString *)UDI;

@end
