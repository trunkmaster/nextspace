/*
  Class:		NXMouse
  Inherits from:	NSObject
  Class descritopn:	Mouse configuration manipulation (speed, 
			double click time, cursor themes)

  Copyright (C) 2017 Sergii Stoian <stoyan255@ukr.net>

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

#import "NXMouse.h"

#import <X11/Xlib.h>

NSString *Acceleration = @"NXMouseAcceleration";
NSString *Threshold = @"NXMouseThreshold";
NSString *DoubleClickTime = @"NXMouseDoubleClickTime";
NSString *WheelScroll = @"NXMouseWheelScroll";
NSString *MenuButtonEnabled = @"NXMenuButtonEnabled";
NSString *MenuButtonHand = @"NXMenuButtonHand";
NSString *CursorTheme = @"NXMouseCursorTheme";

@implementation NXMouse

- (id)init
{
  self = [super init];
  
  userDefaults = [NSUserDefaults standardUserDefaults];
  
  return self;
}

- (void)dealloc
{
  [super dealloc];
}

- (void)_setWMDefaultsObject:(id)object forKey:(NSString *)key
{
  NSString *wmdFormat = @"%@/Library/Preferences/.WindowMaker/WindowMaker";
  NSString *wmdPath;
  NSMutableDictionary *wmDefaults;

  wmdPath = [NSString stringWithFormat:wmdFormat, NSHomeDirectory()];
  wmDefaults = [NSMutableDictionary dictionaryWithContentsOfFile:wmdPath];
  
  [wmDefaults setObject:[object stringValue] forKey:key];
  [wmDefaults writeToFile:wmdPath atomically:YES];
  
  [wmDefaults release];              
}

- (void)_setGSDefaultsObject:(id)object forKey:(NSString *)key
{
  NSMutableDictionary *globalDomain;
  
  globalDomain = [[userDefaults persistentDomainForName:NSGlobalDomain]
                   mutableCopy];
  
  [globalDomain setObject:object forKey:key];
  [userDefaults setPersistentDomain:globalDomain forName:NSGlobalDomain];
  [userDefaults synchronize];
  
  [globalDomain release];
  
  [[NSDistributedNotificationCenter defaultCenter]
               postNotificationName:@"GSMouseOptionsDidChangeNotification"
                             object:nil];
}

- (NSInteger)acceleration
{
  Display    *dpy;
  int        accel_numerator, accel_denominator, threshold;
  NSInteger  accel;
  NXDefaults *defs = [NXDefaults globalUserDefaults];

  dpy = XOpenDisplay(NULL);
  XGetPointerControl(dpy, &accel_numerator, &accel_denominator, &threshold);
  XCloseDisplay(dpy);

  accel = accel_numerator/accel_denominator;

  if (accel != [defs integerForKey:Acceleration])
    {
      [defs setInteger:accel forKey:Acceleration];
      [defs synchronize];
    }

  return accel;
}
- (NSInteger)accelerationThreshold
{
  Display    *dpy;
  int        accel_numerator, accel_denominator, threshold;
  NXDefaults *defs = [NXDefaults globalUserDefaults];

  dpy = XOpenDisplay(NULL);
  XGetPointerControl(dpy, &accel_numerator, &accel_denominator, &threshold);
  XCloseDisplay(dpy);

  if (threshold != [defs integerForKey:Threshold])
    {
      [defs setInteger:threshold forKey:Threshold];
      [defs synchronize];
    }
  if (threshold != [userDefaults integerForKey:@"GSMouseMoveThreshold"])
    {
      [self _setGSDefaultsObject:[NSNumber numberWithInteger:threshold]
                          forKey:@"GSMouseMoveThreshold"];
    }
  
  return threshold;
}
- (void)setAcceleration:(NSInteger)speed threshold:(NSInteger)pixels
{
  Display    *dpy = XOpenDisplay(NULL);
  NSInteger  accel_numerator, accel_denominator, threshold;
  BOOL       changeAcceleration = (speed > 0) ? YES : NO;
  BOOL       changeTreshold = (pixels > 0) ? YES : NO;
  NXDefaults *defs = [NXDefaults globalUserDefaults];

  XChangePointerControl(dpy, changeAcceleration, changeTreshold,
                        speed, 1, pixels);
  XCloseDisplay(dpy);

  // NEXTSPACE
  [defs setInteger:speed forKey:Acceleration];
  [defs synchronize];

  // GNUstep
  [self _setGSDefaultsObject:[NSNumber numberWithInteger:pixels]
                      forKey:@"GSMouseMoveThreshold"];
}

- (NSInteger)doubleClickTime
{
  NSInteger  clickTime;
  BOOL       mustUpdateDefaults = NO;
  
  clickTime = [userDefaults integerForKey:@"GSDoubleClickTime"];
  if (clickTime == 0)
    {
      mustUpdateDefaults = YES;
      clickTime = [[NXDefaults globalUserDefaults]
                    integerForKey:DoubleClickTime];
      if (clickTime == -1)
        clickTime = 300;
    }

  if (mustUpdateDefaults == YES)
    {
      [self setDoubleClickTime:clickTime];
    }
  
  return clickTime;
}
- (void)setDoubleClickTime:(NSUInteger)miliseconds
{
  NSNumber   *value = [NSNumber numberWithInteger:miliseconds];
  NXDefaults *defs = [NXDefaults globalUserDefaults];
  
  // GNUstep
  [self _setGSDefaultsObject:value forKey:@"GSDoubleClickTime"];
  
  // WindowMaker:
  [self _setWMDefaultsObject:value forKey:@"DoubleClickTime"];

  // NEXTSPACE: in case if GNUstep file was edited outside of NEXTSPACE.
  [defs setInteger:miliseconds forKey:DoubleClickTime];
  [defs synchronize];
}

- (NSInteger)wheelScrollLines
{
  NSInteger  lines;
  BOOL       mustUpdateDefaults = NO;
  NXDefaults *defs = [NXDefaults globalUserDefaults];
  
  lines = [userDefaults integerForKey:@"GSMouseScrollMultiplier"];
  if (lines == 0)
    {
      mustUpdateDefaults = YES;
      lines = [[NXDefaults globalUserDefaults] integerForKey:WheelScroll];
      if (lines == -1)
        lines = 3;
    }
  
  if (mustUpdateDefaults == YES)
    {
      [self setWheelScrollLines:lines];
    }
  
  return lines;
}
- (void)setWheelScrollLines:(NSInteger)lines
{
  NXDefaults *defs = [NXDefaults globalUserDefaults];
  
  // GNUstep
  [self _setGSDefaultsObject:[NSNumber numberWithInteger:lines]
                      forKey:@"GSMouseScrollMultiplier"];
  
  // NEXTSPACE: in case if GNUstep file was edited outside of NEXTSPACE.
  [defs setInteger:lines forKey:WheelScroll];
  [defs synchronize];
}

- (BOOL)isMenuButtonEnabled
{
  BOOL enabled = YES;

 
  return enabled;
}
- (void)setMenuButtonEnabled:(BOOL)enabled
                  menuButton:(NSEventType)eventType
{
  NSString *string = enabled ? @"YES" : @"NO";

  [self _setGSDefaultsObject:[NSNumber numberWithInteger:eventType]
                      forKey:@"GSMenuButtonEvent"];
  [self _setGSDefaultsObject:string forKey:@"GSMenuButtonEnabled"];
}


@end
