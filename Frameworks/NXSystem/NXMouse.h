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

#import <Foundation/Foundation.h>
#import <NXFoundation/NXDefaults.h>

@interface NXMouse : NSObject
{
  NSUserDefaults	*gsDefaults;
  NXDefaults		*nxDefaults;
  NSMutableDictionary	*wmDefaults;
  NSString		*wmDefaultsPath;
  
  NSInteger	acceleration;
  NSInteger	threshold;
  NSInteger	doubleClickTime;
  NSInteger	wheelScrollLines;
  BOOL		isMenuButtonEnabled;
  NSInteger	menuButtonEvent;
}

- (NSInteger)acceleration;
- (NSInteger)accelerationThreshold;
- (void)setAcceleration:(NSInteger)speed threshold:(NSInteger)pixels;

- (NSInteger)doubleClickTime;
- (void)setDoubleClickTime:(NSUInteger)miliseconds;

- (NSInteger)wheelScrollLines;
- (void)setWheelScrollLines:(NSInteger)lines;

- (BOOL)isMenuButtonEnabled;
- (NSUInteger)menuButton;
- (void)setMenuButtonEnabled:(BOOL)enabled
                  menuButton:(NSUInteger)eventType;

- (NSArray *)availableCursorThemes;
- (NSString *)cursorTheme;
- (void)setCursorTheme:(NSString *)themeName;

- (void)saveToDefaults;

@end

extern NSString *Acceleration;
extern NSString *Threshold;
extern NSString *DoubleClickTime;
extern NSString *WheelScroll;
extern NSString *MenuButtonEnabled;
extern NSString *MenuButtonHand;
extern NSString *CursorTheme;
