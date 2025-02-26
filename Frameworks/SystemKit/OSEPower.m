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

#import "OSEBusConnection.h"
#import "OSEBusMessage.h"
#import "OSEPower.h"

//-------------------------------------------------------------------------------
#pragma mark - Notifications
//-------------------------------------------------------------------------------
NSString *OSEPowerPropertiesDidChangeNotification = @"OSEPowerPropertiesDidChangeNotification";
NSString *OSEPowerLidDidChangeNotification = @"OSEPowerLidDidChangeNotification";
NSString *OSEPowerDeviceDidAddNotification = @"OSEPowerDeviceDidAddNotification";
NSString *OSEPowerDeviceDidRemoveNotification = @"OSEPowerDeviceDidRemoveNotification";

//-------------------------------------------------------------------------------
#pragma mark - OSEPower implementation
//-------------------------------------------------------------------------------
static OSEPower *systemPower = nil;

@implementation OSEPower (Private)

- (id)_propertyValueWithName:(NSString *)propertyName ofClass:(Class)resultClass 
{
  OSEBusMessage *message;
  id result = nil;

  message = [[OSEBusMessage alloc] initWithService:self
                                         interface:@"org.freedesktop.DBus.Properties"
                                            method:@"Get"
                                         arguments:@[ @"org.freedesktop.UPower", propertyName ]
                                         signature:@"ss"];
  result = [message send];
  [message release];

  if (result != nil) {
    if ([result isKindOfClass:resultClass]) {
      return result;
    } else {
      [result release];
      result = nil;
    }
  }

  return result;
}

@end

@implementation OSEPower

+ (id)sharedPower
{
  if (systemPower == nil) {
    systemPower = [[[self alloc] init] autorelease];
  }

  // NSDebugLLog(@"dealloc", @"OSEPower +shared: retain count %lu", [systemPower retainCount]);

  return systemPower;
}

- (id)init
{
  if (systemPower != nil) {
    return systemPower;
  }

  [super init];

  self.objectPath = @"/org/freedesktop/UPower";
  self.serviceName = @"org.freedesktop.UPower";

  return self;
}

- (void)dealloc
{
  NSDebugLLog(@"dealloc", @"OSEPower: -dealloc (retain count: %lu) (connection retain count: %lu)",
              [self retainCount], [self.connection retainCount]);
  systemPower = nil;
  [super dealloc];
}

//-------------------------------------------------------------------------------
#pragma mark - Battery
//-------------------------------------------------------------------------------
// TODO
- (unsigned int)batteryLife
{
  return 0;
}
// TODO
- (unsigned char)batteryPercent
{
  return 0;
}

- (BOOL)isUsingBattery
{
  BOOL isOnBattery = NO;
  NSNumber *result = [self _propertyValueWithName:@"OnBattery" ofClass:[NSNumber class]];

  if (result != nil) {
    isOnBattery = [result boolValue];
    [result release];
  }

  return isOnBattery;
}

//-------------------------------------------------------------------------------
#pragma mark - Laptop lid
//-------------------------------------------------------------------------------
- (BOOL)isLidPresent
{
  BOOL isLidPresent = NO;
  NSNumber *result = [self _propertyValueWithName:@"LidIsPresent" ofClass:[NSNumber class]];

  if (result != nil) {
    isLidPresent = [result boolValue];
    [result release];
  }

  return isLidPresent;
}

- (BOOL)isLidClosed
{
  BOOL isLidClosed = NO;
  NSNumber *result = [self _propertyValueWithName:@"LidIsClosed" ofClass:[NSNumber class]];

  if (result != nil) {
    isLidClosed = [result boolValue];
    [result release];
  }

  return isLidClosed;
}

//-------------------------------------------------------------------------------
#pragma mark - UPower D-Bus events
//-------------------------------------------------------------------------------
- (void)handleLidNotification:(NSDictionary *)info
{
  NSDebugLLog(@"UPower", @"UPower received notification with user info: %@", info);

  NSArray *message = info[@"Message"];  // s a{sv} as
  NSArray *properties = message[1];     // a{sv}
  id propertyValue;

  // NSLog(@"\t Properties has been changed for interface %@:", message[0]);
  for (NSDictionary *property in properties) {
    for (NSString *propertyName in [property allKeys]) {
      // propertyValue = property[propertyName];
      // NSLog(@"\t\t %@ = %@", propertyName, propertyValue);
      if ([propertyName isEqualToString:@"LidIsClosed"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:OSEPowerLidDidChangeNotification
                                                            object:self
                                                          userInfo:property];
      }
    }
  }
}

- (void)deviceAdded:(NSNotification *)aNotif
{
  NSDebugLLog(@"UPower", @"UPower received notification DeviceAdded: %@", aNotif.userInfo);

  [[NSNotificationCenter defaultCenter] postNotificationName:OSEPowerDeviceDidAddNotification
                                                      object:self
                                                    userInfo:aNotif.userInfo];
}

- (void)deviceRemoved:(NSNotification *)aNotif
{
  NSDebugLLog(@"UPower", @"UPower received notification with object: %@", aNotif.userInfo);

  [[NSNotificationCenter defaultCenter] postNotificationName:OSEPowerDeviceDidRemoveNotification
                                                      object:self
                                                    userInfo:aNotif.userInfo];
}

- (void)startEventsMonitor
{
  [self.connection addSignalObserver:self
                            selector:@selector(handleLidNotification:)
                              signal:@"PropertiesChanged"
                              object:self.objectPath
                           interface:@"org.freedesktop.DBus.Properties"];

  [self.connection addSignalObserver:self
                            selector:@selector(deviceAdded:)
                              signal:@"DeviceAdded"
                              object:self.objectPath
                           interface:@"org.freedesktop.UPower"];
  [self.connection addSignalObserver:self
                            selector:@selector(deviceRemoved:)
                              signal:@"DeviceRemoved"
                              object:self.objectPath
                           interface:@"org.freedesktop.UPower"];
}

- (void)stopEventsMonitor
{
  [self.connection removeSignalObserver:self
                                 signal:@"PropertiesChanged"
                                 object:self.objectPath
                              interface:@"org.freedesktop.DBus.Properties"];
  [self.connection removeSignalObserver:self
                                 signal:@"DeviceAdded"
                                 object:self.objectPath
                              interface:@"org.freedesktop.UPower"];
  [self.connection removeSignalObserver:self
                                 signal:@"DeviceRemoved"
                                 object:self.objectPath
                              interface:@"org.freedesktop.UPower"];
}

@end
