/* -*- mode: objc -*- */
//
// Project: Preferences
//
// Class representing display in Screen preferences
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

#import <AppKit/AppKit.h>

#import <Screen.h>

@interface DisplayBox : NSBox
{
  ScreenPreferences *owner;
  
  NSTextField *nameField;
  NSColor     *bgColor;
  NSColor     *fgColor;
  
  BOOL isMainDisplay;
  BOOL isActiveDisplay;
  BOOL isSelected;
}

@property NSRect displayFrame;
@property (assign) NSString *displayName;
@property (readonly) OSEDisplay *display;

- initWithFrame:(NSRect)frameRect
        display:(OSEDisplay *)aDisplay
          owner:(id)prefs; // ugly

- (void)setActive:(BOOL)active;
- (BOOL)isActive;
- (void)setMain:(BOOL)isMain;
- (BOOL)isMain;
- (void)setSelected:(BOOL)selected;
- (NSPoint)centerPoint;

@end
