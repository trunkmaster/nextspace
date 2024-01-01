/*
  Class:               Appcontroller
  Inherits from:       NSObject
  Class descritopn:    NSApplication delegate

  Copyright (C) 2016 Sergii Stoian

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
  if (weatherView)
    return;
  
  weatherView = [[WeatherView alloc] initWithFrame:NSMakeRect(0, 0, 64, 64)];
  [[NSApp iconWindow] setContentView:weatherView];

  timer = [NSTimer scheduledTimerWithTimeInterval:900.0
                                           target:self
                                         selector:@selector(updateWeather:)
                                         userInfo:nil
                                          repeats:YES];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notify
{
  [self loadBundles];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotif
{
  [self updateWeather:nil];
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

- (void)showPreferencesWindow
{
  // if (prefsController == nil)
  //   {
  //     prefsController = [[PrefsController alloc] init];
  //     if ([NSBundle loadNibNamed:@"PrefsWindow" owner:self] == NO)
  //       {
  //         NSLog(@"Error loading NIB PrefsWindow");
  //         return;
  //       }
  //   }

  [NSApp activateIgnoringOtherApps:YES];
  // [[prefsController window] makeKeyAndOrderFront:self];
}

- (void)updateWeather:(NSTimer *)timer
{
  NSDictionary *weather;
  NSString *fetcherName;
  NSImage *conditionImage;

  if (forecastFetcher == nil) {
    fetcherName = [[NSUserDefaults standardUserDefaults] objectForKey:@"Fetcher"];
    if (fetcherName) {
      forecastFetcher = [forecastModules objectForKey:fetcherName];
    }
    if (forecastFetcher == nil) {
      forecastFetcher = [forecastModules objectForKey:[[forecastModules allKeys] firstObject]];
    }
  }

  [forecastFetcher setCityByName:@"Kyiv"];
  weather = [forecastFetcher fetchWeather];
  NSLog(@"Weather data from %@: %@", [[forecastFetcher class] className], weather);

  if (weather && [[weather objectForKey:@"ErrorText"] length] == 0) {
    NSLog(@"Got weather forecast. %@", weather);
    conditionImage = [weather objectForKey:@"Image"];
    if (conditionImage != nil) {
      [weatherView setImage:conditionImage];
    } else {
      [weatherView setImage:[NSApp applicationIconImage]];
    }
    [weatherView setTemperature:[weather objectForKey:@"Temperature"]];
    [weatherView setHumidity:[weather objectForKey:@"Humidity"]];
    [weatherView setNeedsDisplay:YES];
  }
  else {
    NSLog(@"Error getting data: %@", [weather objectForKey:@"ErrorText"]);
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
  NSLog(@"Registered bundles: %@", bRegistry);
  modules = [[NXTBundle shared] loadRegisteredBundles:bRegistry
                                                 type:@"Weather"
                                             protocol:@protocol(WeatherProvider)];
  NSLog(@"Loaded number of bundles: %lu - %@", [modules count], [modules firstObject]);
  for (id<WeatherProvider> provider in modules) {
    [loadedModules setObject:provider forKey:provider.name];
  }
  forecastModules = [[NSDictionary alloc] initWithDictionary:loadedModules];
  [loadedModules release];
}

@end
