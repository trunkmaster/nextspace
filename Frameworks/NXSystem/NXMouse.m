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

#import <GNUstepGUI/GSDisplayServer.h>
#import <X11/Xlib.h>

NSString *Acceleration = @"NXMouseAcceleration";
NSString *Threshold = @"NXMouseThreshold";
NSString *DoubleClickTime = @"NXMouseDoubleClickTime";
NSString *WheelScroll = @"NXMouseWheelScroll";
NSString *CursorTheme = @"NXMouseCursorTheme";

@implementation NXMouse

- (NSInteger)acceleration
{
  Display *dpy = [GSCurrentServer() serverDevice];
  int     accel_numerator, accel_denominator, threshold;

  XGetPointerControl(dpy, &accel_numerator, &accel_denominator, &threshold);

  return accel_numerator/accel_denominator;
}
- (NSInteger)accelerationThreshold
{
  Display *dpy = [GSCurrentServer() serverDevice];
  int     accel_numerator, accel_denominator, threshold;

  XGetPointerControl(dpy, &accel_numerator, &accel_denominator, &threshold);

  return threshold;
}
- (void)setAcceleration:(NSInteger)speed threshold:(NSInteger)pixels
{
  Display   *dpy = [GSCurrentServer() serverDevice];
  NSInteger accel_numerator, accel_denominator, threshold;
  BOOL      changeAcceleration = (speed > 0) ? YES : NO;
  BOOL      changeTreshold = (pixels > 0) ? YES : NO;

  XChangePointerControl(dpy, changeAcceleration, changeTreshold,
                        speed, 1, pixels);
}

- (NSInteger)doubleClickTime
{
  return 250;
}
- (void)setDoubleClickTime:(NSUInteger)miliseconds
{
}

- (NSInteger)wheelScrollLines
{
  return 3;
}

@end
