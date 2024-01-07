/*
  Weather application controller

  Copyright (C) 2023-present Sergii Stoian <stoyan255@gmail.com>

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import <DesktopKit/NXTBundle.h>
#include "WeatherView.h"
#import <DesktopKit/NXTAlert.h>

#import "Preferences.h"
#import "AppController.h"

static NSUserDefaults *defaults = nil;

@implementation AppController

- (id)init
{
  if (!(self = [super init])) {
    return nil;
  }

  if (!defaults) {
    defaults = [NSUserDefaults standardUserDefaults];
  }

  return self;
}

- (void)dealloc
{
  [timer invalidate];
  [timer release];
  
  [super dealloc];
}

- (void)awakeFromNib
{
  if (weatherView) {
    return;
  }

  weatherView = [[WeatherView alloc] initWithFrame:NSMakeRect(0, 0, 64, 64)];
  [[NSApp iconWindow] setContentView:weatherView];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notify
{
  NSString *fetcherName;

  [self loadBundles];

  if (weatherProvider == nil) {
    fetcherName = [[NSUserDefaults standardUserDefaults] objectForKey:@"Fetcher"];
    if (fetcherName) {
      weatherProvider = [forecastModules objectForKey:fetcherName];
    }
    if (weatherProvider == nil) {
      weatherProvider = [forecastModules objectForKey:[[forecastModules allKeys] firstObject]];
    }
  }

  if ([weatherProvider setLocationByName:[[[NSTimeZone defaultTimeZone] name] lastPathComponent]] !=
      NO) {
    // if ([weatherProvider setLocationByName:@"Copenhagen"] != NO) {
    [weatherView setLocationName:weatherProvider.locationName];
  }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotif
{
  timer = [NSTimer scheduledTimerWithTimeInterval:900.0
                                           target:self
                                         selector:@selector(updateWeather:)
                                         userInfo:nil
                                          repeats:YES];
  [self updateWeather:timer];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
  return YES;
}

- (void)applicationWillTerminate:(NSNotification *)aNotif
{
}

- (void)applicationDidBecomeActive:(NSNotification*)aNotification
{
}

- (BOOL)application:(NSApplication *)application openFile:(NSString *)fileName
{
  return YES;
}

- (void)showPreferencesWindow:(id)sender
{
  if (prefences == nil) {
    prefences = [[Preferences alloc] initWithProvider:weatherProvider];
  }

  [[prefences window] makeKeyAndOrderFront:self];
}

- (void)updateWeather:(NSTimer *)theTimer
{
  if (weatherProvider.locationName == nil) {
    if (theTimer != nil) {
      [theTimer invalidate];
      theTimer = nil;
    }
    [self showPreferencesWindow:self];
    NXTRunAlertPanel(@"Weather", @"No location was set. Please set it in preferences.",
                     @"Preferences", @"Cancel", nil);
    return;
  }
  
  [weatherView setLocationName:weatherProvider.locationName];
  if ([weatherProvider fetchWeather] != NO) {
    if (weatherProvider.current.image != nil) {
      [weatherView setImage:weatherProvider.current.image];
    } else {
      [weatherView setImage:[NSApp applicationIconImage]];
    }
    [weatherView setTemperature:weatherProvider.current.temperature];
    [weatherView setNeedsDisplay:YES];
    NSLog(@"Got forecast: %@", weatherProvider.forecast);
  }
  else {
    NSLog(@"Error getting data: %@", weatherProvider.current.error);
  }
}

//
// Modules
//
- (void)loadBundles
{
  NSDictionary *bRegistry;
  NSArray *modules;
  NSMutableDictionary *loadedModules = [[NSMutableDictionary alloc] init];

  bRegistry = [[NXTBundle shared] registerBundlesOfType:@"provider"
                                                 atPath:[[NSBundle mainBundle] bundlePath]];
  // NSLog(@"Registered bundles: %@", bRegistry);
  modules = [[NXTBundle shared] loadRegisteredBundles:bRegistry
                                                 type:@"Weather"
                                             protocol:@protocol(WeatherProtocol)];
  // NSLog(@"Loaded number of bundles: %lu - %@", [modules count], [modules firstObject]);
  for (WeatherProvider *provider in modules) {
    [loadedModules setObject:provider forKey:provider.name];
  }
  forecastModules = [[NSDictionary alloc] initWithDictionary:loadedModules];
  [loadedModules release];
}

@end
