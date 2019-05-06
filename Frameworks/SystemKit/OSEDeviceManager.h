/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - SystemKit framework
//
// Description: FreeBSD file system event monitor (kevent).
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

// Device events
extern NSString *OSEDeviceAdded;
extern NSString *OSEDeviceRemoved;
extern NSString *OSEDevicePropertyChanged;
extern NSString *OSEDevicePropertyRemoved;
extern NSString *OSEDevicePropertyAdded;
extern NSString *OSEDeviceConditionChanged;

// Class which adopts <DeviceEventsAdaptor> protocol aimed to implement
// interaction with OS's method of getting information about devices and
// device events (add, remove, ).
@protocol DeviceEventsAdaptor
// For future use
@end

@interface OSEDeviceManager : NSObject
{
}

+ (id)defaultManager;

@end
