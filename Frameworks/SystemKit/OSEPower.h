/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - SystemKit framework
//
// Copyright (C) 2024-present Sergii Stoian
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
 * OSEPower class provides information about UPower service
 * objects: laptop LID, battery. Should be used to initiate
 * changing of power profile of system (tuned) and actions:
 * shutdown, restart, hibernate and sleep.
 */

#import <Foundation/Foundation.h>

#import <SystemKit/OSEBusService.h>

@interface OSEPower : OSEBusService
{
}

// LID information
@property (readonly) BOOL isLidPresent;
@property (readonly) BOOL isLidClosed;

+ (id)sharedPower;

// Battery information
@property (readonly) BOOL isUsingBattery;
- (unsigned int)batteryLife;
- (unsigned char)batteryPercent;

// Monitor for D-Bus messages
- (void)startEventsMonitor;
- (void)stopEventsMonitor;

@end

//-------------------------------------------------------------------------------
#pragma mark - Notifications
//-------------------------------------------------------------------------------
extern NSString *OSEPowerPropertiesDidChangeNotification;
extern NSString *OSEPowerLidDidChangeNotification;
extern NSString *OSEPowerDeviceDidAddNotification;
extern NSString *OSEPowerDeviceDidRemoveNotification;

