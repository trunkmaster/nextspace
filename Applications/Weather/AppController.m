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

//#import <NXAppKit/NXAlert.h>

#import "AppController.h"
#import "WeatherView.h"
#import "YahooForecast.h"
#import "OWMForecast.h"

static NSUserDefaults *defaults = nil;

@implementation AppController

- (id)init
{
  if (!(self = [super init]))
    {
      return nil;
    }

  if (!defaults)
    {
      defaults = [NSUserDefaults standardUserDefaults];
    }

  // prefsController = nil;

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

  timer = [NSTimer scheduledTimerWithTimeInterval:1800.0
                                           target:self
                                         selector:@selector(updateWeather:)
                                         userInfo:nil
                                          repeats:YES];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notify
{

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
  // [prefsController release];
}

- (void)applicationDidBecomeActive:(NSNotification*)aNotification
{
  // NSLog(@"Application became active!");
  // if (prefsController)
  //   {
  //     [[prefsController window] makeKeyWindow];
  //   }
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
  NSDictionary   *weather;
  
  // if (forecast == nil) {
  //   forecast = [[YahooForecast alloc] init];
  // }
  if (forecast == nil) {
    forecast = [[OWMForecast alloc] init];
  }

  weather = [forecast fetchWeather];

  // weather = [forecast fetchWeatherWithWOEID:@"924938"
  //                                   zipCode:@""
  //                                     units:@"c"];

  if (weather && [[weather objectForKey:@"ErrorText"] length] == 0) {
    NSLog(@"Got weather forecast. %@", weather);
    // [weatherView setImage:[weather objectForKey:@"Image"]];
    [weatherView setTemperature:[weather objectForKey:@"Temperature"]];
    [weatherView setHumidity:[weather objectForKey:@"Humidity"]];
    [weatherView setNeedsDisplay:YES];
  }
  else {
    NSLog(@"Error getting data: %@", [weather objectForKey:@"ErrorText"]);
  }
}

@end
