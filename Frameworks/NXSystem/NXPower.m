/*
 * NXPower.m - UPower and 'tuned' interactions.
 *
 * Copyright 2016, Serg Stoyan
 * All rights reserved.
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
#ifdef WITH_UPOWER

#import <Foundation/NSArray.h>
// #import <Foundation/NSBundle.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimer.h>
#import <Foundation/NSNotification.h>

#import "NXPower.h"

NSString *NXPowerLidDidChangeNotification = @"NXPowerLidDidChangeNotification";

static NSTimer   *monitorTimer;
static GMainLoop *glib_mainloop;
static NXPower   *power;

@implementation NXPower

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
  NSLog(@"NXPower: device %s added", up_device_to_text(device));
}
static void
up_device_removed_cb(UpClient *client, UpDevice *device, gpointer user_data)
{
  NSLog(@"NXPower: device %s removed", up_device_to_text(device));
}
static void
up_lid_closed_cb(UpClient *client, gpointer user_data)
{
  NSLog(@"NXPower: LidClosed property changed");
  [[NSNotificationCenter defaultCenter]
    postNotificationName:NXPowerLidDidChangeNotification
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
