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

#ifdef WITH_UPOWER

#import <Foundation/NSArray.h>
// #import <Foundation/NSBundle.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimer.h>
#import <Foundation/NSNotification.h>

#import "OSEPower.h"

NSString *OSEPowerLidDidChangeNotification = @"OSEPowerLidDidChangeNotification";

static NSTimer   *monitorTimer;
static GMainLoop *glib_mainloop;
static OSEPower   *power;

@implementation OSEPower

- (id)init
{
  power = self = [super init];
  
  return self;
}

- (void)dealloc
{
  if ([monitorTimer isValid])
    {
      [self stopEventsMonitor];
    }

  g_object_unref(upower_client);
  
  [super dealloc];
}

//-------------------------------------------------------------------------------
// Battery
//-------------------------------------------------------------------------------
+ (unsigned int)batteryLife
{
  return 0;
}

+ (unsigned char)batteryPercent
{
  return 0;
}

+ (BOOL)isUsingBattery
{
  return NO;
}

//-------------------------------------------------------------------------------
// Laptop lid
//-------------------------------------------------------------------------------
+ (BOOL)hasLid
{
  UpClient *up_client = up_client_new();
  BOOL     yn = up_client_get_lid_is_present(up_client);

  g_object_unref(up_client);
    
  return yn;
}

+ (BOOL)isLidClosed
{
  UpClient *up_client = up_client_new();
  BOOL     yn = up_client_get_lid_is_closed(up_client);

  g_object_unref(up_client);
    
  return yn;
}

- (BOOL)hasLid
{
  return up_client_get_lid_is_present(upower_client);
}

- (BOOL)isLidClosed
{
  return up_client_get_lid_is_closed(upower_client);
}

//-------------------------------------------------------------------------------
// UPower D-Bus events
//-------------------------------------------------------------------------------

static void
up_device_added_cb(UpClient *client, UpDevice *device, gpointer user_data)
{
  NSLog(@"OSEPower: device %s added", up_device_to_text(device));
}
static void
up_device_removed_cb(UpClient *client, UpDevice *device, gpointer user_data)
{
  NSLog(@"OSEPower: device %s removed", up_device_to_text(device));
}
static void
up_lid_closed_cb(UpClient *client, gpointer user_data)
{
  NSLog(@"OSEPower: LidClosed property changed");
  [[NSNotificationCenter defaultCenter]
    postNotificationName:OSEPowerLidDidChangeNotification
                  object:power];
}

// Timer selector
- (void)_glibRunLoopIterate
{
  g_main_context_iteration(g_main_loop_get_context(glib_mainloop), FALSE);
}

- (void)startEventsMonitor
{
  upower_client = up_client_new();

  // Set events monitoring callbacks
  g_signal_connect(upower_client, "device-added",
                   G_CALLBACK(up_device_added_cb), NULL);
  g_signal_connect(upower_client, "device-removed",
                   G_CALLBACK(up_device_removed_cb), NULL);
  g_signal_connect(upower_client, "notify::lid-is-closed",
                   G_CALLBACK(up_lid_closed_cb), NULL);

  glib_mainloop = g_main_loop_new(NULL, TRUE);
  
  monitorTimer = [NSTimer
                   scheduledTimerWithTimeInterval:1.0
                                           target:self
                                         selector:@selector(_glibRunLoopIterate)
                                         userInfo:nil
                                          repeats:YES];
}

- (void)stopEventsMonitor
{
  [monitorTimer invalidate];
}

@end

#endif //WITH_UPOWER
