/*
  Class:		NXMouse
  Inherits from:	NSObject
  Class descritopn:	Mouse configuration manipulation (speed, 
			double click time, cursor themes)

  Copyright (C) 2017 Sergii Stoian <stoyan255@gmail.com>

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
#import <X11/Xcursor/Xcursor.h>

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
  NSString *wmdFormat;
  
  self = [super init];
  
  gsDefaults = [NSUserDefaults standardUserDefaults];
  nxDefaults = [NXDefaults globalUserDefaults];
  
  wmdFormat = @"%@/Library/Preferences/.WindowMaker/WindowMaker";
  wmDefaultsPath = [[NSString alloc] initWithFormat:wmdFormat,
                                     NSHomeDirectory()];
  wmDefaults = [[NSMutableDictionary alloc]
                 initWithContentsOfFile:wmDefaultsPath];
  
  acceleration = [self acceleration];
  threshold = [self accelerationThreshold];
  doubleClickTime = [self doubleClickTime];
  wheelScrollLines = [self wheelScrollLines];
  isMenuButtonEnabled = [self isMenuButtonEnabled];
  menuButtonEvent = [self menuButton];

  [self saveToDefaults];
  
  return self;
}

- (void)dealloc
{
  [wmDefaultsPath release];
  [wmDefaults release];
  [super dealloc];
}

- (NSInteger)acceleration
{
  Display    *dpy;
  int        accel_numerator, accel_denominator, accel_threshold;
  NSInteger  accel;

  dpy = XOpenDisplay(NULL);
  XGetPointerControl(dpy, &accel_numerator, &accel_denominator,
                     &accel_threshold);
  XCloseDisplay(dpy);

  accel = accel_numerator/accel_denominator;

  return accel;
}
- (NSInteger)accelerationThreshold
{
  Display    *dpy;
  int        accel_numerator, accel_denominator, accel_threshold;
  NXDefaults *defs = [NXDefaults globalUserDefaults];

  dpy = XOpenDisplay(NULL);
  XGetPointerControl(dpy, &accel_numerator, &accel_denominator,
                     &accel_threshold);
  XCloseDisplay(dpy);

  return accel_threshold;
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
  NSInteger time;

  time = [gsDefaults integerForKey:@"GSDoubleClickTime"];
  if (time == 0)
    {
      time = [nxDefaults integerForKey:DoubleClickTime];
      if (time == -1)
        time = 300;
    }

  return time;
}
- (void)setDoubleClickTime:(NSUInteger)miliseconds
{
  doubleClickTime = miliseconds;
}

- (NSInteger)wheelScrollLines
{
  NSInteger  lines;
  
  lines = [gsDefaults integerForKey:@"GSMouseScrollMultiplier"];
  if (lines == 0)
    {
      lines = [nxDefaults integerForKey:WheelScroll];
      if (lines == -1)
        lines = 3;
    }
  
  return lines;
}
- (void)setWheelScrollLines:(NSInteger)lines
{
  wheelScrollLines = lines;
}

- (BOOL)isMenuButtonEnabled
{
  BOOL     enabled = YES;
  NSString *s;

  s = [gsDefaults objectForKey:@"GSMenuButtonEnabled"];
  if (s != nil)
    {
      enabled = [s isEqualToString:@"YES"];
    }
  else
    {
      s = [nxDefaults objectForKey:MenuButtonEnabled];
      if (s != nil)
        enabled = [s isEqualToString:@"YES"];
    }
 
  return enabled;
}
- (NSUInteger)menuButton
{
  NSInteger event;
  
  event = [gsDefaults integerForKey:@"GSMouseScrollMultiplier"];
  if (event == 0)
    {
      event = [nxDefaults integerForKey:WheelScroll];
      if (event == -1)
        event = 3; // NSRightMouseDown
    }
  
  return event;
}
- (void)setMenuButtonEnabled:(BOOL)enabled
                  menuButton:(NSUInteger)eventType
{
  isMenuButtonEnabled = enabled;
  menuButtonEvent = eventType;
}

- (NSArray *)availableCursorThemes
{
  // NSArray 		*themePaths;
  // NSFileManager		*fm = [NSFileManager defaultManager];
  // NSEnumerator		*e;
  // NSMutableArray	*themes;

  // themePaths = [NSArray arrayWithObjects:@"/usr/share/icons", @"~/.icons"];

  return [NSArray arrayWithObjects:@"default", @"Adwaita", @"Bluecurve",
                  @"Bluecurve-inverse", @"LBluecurve", @"LBluecurve-inverse",
                  nil];
}

- (NSString *)cursorTheme
{
  Display 	*dpy = XOpenDisplay(NULL);
  NSString	*themeName = nil;
  
  // XcursorSetTheme(dpy, "Blecurve");
  themeName = [NSString stringWithCString:XcursorGetTheme(dpy)];
  fprintf(stderr, "Cursor theme: %s\n", XcursorGetTheme(dpy));
  XCloseDisplay(dpy);

  return themeName;
}

- (void)setCursorTheme:(NSString *)themeName
{
  Display *dpy = XOpenDisplay(NULL);
  XcursorBool res;
  
  res = XcursorSetTheme(dpy, [themeName cString]);
  Cursor handle = XcursorLibraryLoadCursor(dpy, "left_ptr");
  XDefineCursor(dpy, RootWindow(dpy, 0), handle);
  XFreeCursor(dpy, handle);
  XFlush(dpy);
  XCloseDisplay(dpy);
}


- (void)_setGSDefaultsObject:(id)object forKey:(NSString *)key
{
  NSMutableDictionary *globalDomain;
  
  globalDomain = [[gsDefaults persistentDomainForName:NSGlobalDomain]
                   mutableCopy];
  
  [globalDomain setObject:object forKey:key];
  [gsDefaults setPersistentDomain:globalDomain forName:NSGlobalDomain];
  [gsDefaults synchronize];
  
  [globalDomain release];
}

- (void)saveToDefaults
{
  BOOL sendNotification = NO;
  
  // Acceleration
  if (acceleration != [nxDefaults integerForKey:Acceleration])
    {
      [nxDefaults setInteger:acceleration forKey:Acceleration];
      [nxDefaults synchronize];
    }

  // Threshold
  if (threshold != [nxDefaults integerForKey:Threshold])
    {
      [nxDefaults setInteger:threshold forKey:Threshold];
      [nxDefaults synchronize];
    }
  if (threshold != [gsDefaults integerForKey:@"GSMouseMoveThreshold"])
    {
      [self _setGSDefaultsObject:[NSNumber numberWithInteger:threshold]
                          forKey:@"GSMouseMoveThreshold"];
      sendNotification = YES;
    }
  
  // Double-Click Delay
  if (doubleClickTime != [gsDefaults integerForKey:@"GSDoubleClickTime"])
    {
      [self _setGSDefaultsObject:[NSNumber numberWithInteger:doubleClickTime]
                          forKey:@"GSDoubleClickTime"];
      sendNotification = YES;
    }
  if (doubleClickTime !=
      [[wmDefaults objectForKey:@"DoubleClickTime"] integerValue])
    {
      [wmDefaults setObject:[NSString stringWithFormat:@"%li",doubleClickTime]
                     forKey:@"DoubleClickTime"];
      [wmDefaults writeToFile:wmDefaultsPath atomically:YES];
    }
  if (doubleClickTime != [nxDefaults integerForKey:DoubleClickTime])
    {
      [nxDefaults setInteger:doubleClickTime forKey:DoubleClickTime];
    }

  // Mouse Wheel Scrolls
  if (wheelScrollLines != [gsDefaults integerForKey:@"GSMouseScrollMultiplier"])
    {
      [self _setGSDefaultsObject:[NSNumber numberWithInteger:wheelScrollLines]
                          forKey:@"GSMouseScrollMultiplier"];
      sendNotification = YES;
    }
  if (wheelScrollLines != [nxDefaults integerForKey:WheelScroll])
    {
      [nxDefaults setInteger:wheelScrollLines forKey:WheelScroll];
    }

  // Menu Button
  NSString *s = isMenuButtonEnabled ? @"YES" : @"NO";
  if (![[gsDefaults objectForKey:@"GSMenuButtonEnabled"] isEqualToString:s])
    {
      [self _setGSDefaultsObject:s forKey:@"GSMenuButtonEnabled"];
      sendNotification = YES;
    }
  if (menuButtonEvent != [gsDefaults integerForKey:@"GSMenuButtonEvent"])
    {
      [self _setGSDefaultsObject:[NSNumber numberWithInteger:menuButtonEvent]
                          forKey:@"GSMenuButtonEvent"];
      sendNotification = YES;
    }
  s = isMenuButtonEnabled ? @"NO" : @"YES";
  if (![[wmDefaults objectForKey:@"DisableWSMouseActions"] isEqualToString:s])
    {
      [wmDefaults setObject:s forKey:@"DisableWSMouseActions"];
      [wmDefaults writeToFile:wmDefaultsPath atomically:YES];
    }
  if (menuButtonEvent != [nxDefaults integerForKey:MenuButtonHand])
    {
      [nxDefaults setInteger:menuButtonEvent forKey:MenuButtonHand];
    }
  if (isMenuButtonEnabled != [nxDefaults boolForKey:MenuButtonEnabled])
    {
      [nxDefaults setBool:isMenuButtonEnabled forKey:MenuButtonEnabled];
    }

  // Notify GNUstep backend about mouse preferences change
  if (sendNotification == YES)
    {
      [[NSDistributedNotificationCenter defaultCenter]
               postNotificationName:@"GSMouseOptionsDidChangeNotification"
                             object:nil];
    }
}

@end
