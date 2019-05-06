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

#import "OSEMouse.h"

#import <X11/Xlib.h>
#import <X11/Xcursor/Xcursor.h>

NSString *OSEMouseAcceleration = @"MouseAcceleration";
NSString *OSEMouseThreshold = @"MouseThreshold";
NSString *OSEMouseDoubleClickTime = @"MouseDoubleClickTime";
NSString *OSEMouseWheelScroll = @"MouseWheelScroll";
NSString *OSEMouseWheelControlScroll = @"MouseWheelControlScroll";
NSString *OSEMouseMenuButtonEnabled = @"MenuButtonEnabled";
NSString *OSEMouseMenuButtonHand = @"MenuButtonHand";
NSString *OSEMouseCursorTheme = @"MouseCursorTheme";

@implementation OSEMouse

- (id)init
{
  NSString *wmdFormat;
  
  self = [super init];
  
  gsDefaults = [NSUserDefaults standardUserDefaults];
  nxDefaults = [NXTDefaults globalUserDefaults];
  
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

// Acceleration
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
  NXTDefaults *defs = [NXTDefaults globalUserDefaults];

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
  NXTDefaults *defs = [NXTDefaults globalUserDefaults];

  XChangePointerControl(dpy, changeAcceleration, changeTreshold,
                        speed, 1, pixels);
  XCloseDisplay(dpy);

  // NEXTSPACE
  [defs setInteger:speed forKey:OSEMouseAcceleration];
  [defs synchronize];

  // GNUstep
  [self _setGSDefaultsObject:[NSNumber numberWithInteger:pixels]
                      forKey:@"GSMouseMoveThreshold"];
}

// Double click
- (NSInteger)doubleClickTime
{
  NSInteger time;

  time = [gsDefaults integerForKey:@"GSDoubleClickTime"];
  if (time == 0)
    {
      time = [nxDefaults integerForKey:OSEMouseDoubleClickTime];
      if (time ==0 || time == -1)
        time = 300;
    }

  return time;
}
- (void)setDoubleClickTime:(NSUInteger)miliseconds
{
  doubleClickTime = miliseconds;
}

// Scroll wheel
- (NSInteger)wheelScrollLines
{
  NSInteger  lines;
  
  lines = [gsDefaults integerForKey:@"GSMouseScrollMultiplier"];
  if (lines == 0)
    {
      lines = [nxDefaults integerForKey:OSEMouseWheelScroll];
      if (lines == 0 || lines == -1)
        lines = 3;
    }
  
  return lines;
}
- (void)setWheelScrollLines:(NSInteger)lines
{
  wheelScrollLines = lines;
}
- (NSInteger)wheelControlScrollLines
{
  NSInteger  lines;
  
  lines = [nxDefaults integerForKey:OSEMouseWheelControlScroll];
  if (lines == 0 || lines == -1)
    lines = 1;
  
  return lines;
}
- (void)setWheelControlScrollLines:(NSInteger)lines
{
  wheelControlScrollLines = lines;
}

// Menu button
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
      s = [nxDefaults objectForKey:OSEMouseMenuButtonEnabled];
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
      event = [nxDefaults integerForKey:OSEMouseWheelScroll];
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

- (NSPoint)locationOnScreen
{
  Display	*dpy;
  Window	root_window, rwindow, cwindow;
  int		root_x, root_y, win_x, win_y;
  unsigned int	mask;
    
  dpy = XOpenDisplay(NULL);
  
  root_window = RootWindow(dpy, DefaultScreen(dpy));
  XQueryPointer(dpy, root_window, &rwindow, &cwindow,
                &root_x, &root_y, &win_x, &win_y, &mask);
  
  XCloseDisplay(dpy);

  return NSMakePoint((CGFloat)root_x, (CGFloat)root_y);
}

// TODO
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

// TODO
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
  if (acceleration != [nxDefaults integerForKey:OSEMouseAcceleration])
    {
      [nxDefaults setInteger:acceleration forKey:OSEMouseAcceleration];
      [nxDefaults synchronize];
    }

  // Threshold
  if (threshold != [nxDefaults integerForKey:OSEMouseThreshold])
    {
      [nxDefaults setInteger:threshold forKey:OSEMouseThreshold];
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
  if (doubleClickTime != [nxDefaults integerForKey:OSEMouseDoubleClickTime])
    {
      [nxDefaults setInteger:doubleClickTime forKey:OSEMouseDoubleClickTime];
    }

  // Mouse Wheel Scrolls
  if (wheelScrollLines != [gsDefaults integerForKey:@"GSMouseScrollMultiplier"])
    {
      [self _setGSDefaultsObject:[NSNumber numberWithInteger:wheelScrollLines]
                          forKey:@"GSMouseScrollMultiplier"];
      sendNotification = YES;
    }
  if (wheelScrollLines != [nxDefaults integerForKey:OSEMouseWheelScroll])
    {
      [nxDefaults setInteger:wheelScrollLines forKey:OSEMouseWheelScroll];
    }
  if (wheelControlScrollLines != [nxDefaults integerForKey:OSEMouseWheelControlScroll])
    {
      [nxDefaults setInteger:wheelControlScrollLines forKey:OSEMouseWheelControlScroll];
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
  if (menuButtonEvent != [nxDefaults integerForKey:OSEMouseMenuButtonHand])
    {
      [nxDefaults setInteger:menuButtonEvent forKey:OSEMouseMenuButtonHand];
    }
  if (isMenuButtonEnabled != [nxDefaults boolForKey:OSEMouseMenuButtonEnabled])
    {
      [nxDefaults setBool:isMenuButtonEnabled forKey:OSEMouseMenuButtonEnabled];
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
