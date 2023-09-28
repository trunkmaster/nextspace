/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Description: Workspaces preferences.
//
// Copyright (C) 2018 Sergii Stoian
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
#import <DesktopKit/DesktopKit.h>

#import <Preferences/PrefsModule.h>

@interface DesktopsPrefs : NSObject <PrefsModule>
{
  // Workspaces
  id window;
  id box;

  id desktopsBox;
  id dt1, dt2, dt3, dt4, dt5, dt6, dt7, dt8, dt9, dt10;
  id desktopsNumber;
  id nameField;
  id changeNameBtn;
  id switchKey;
  id directSwitchKey;
  id showInDockBtn;

  NSUInteger desktopsCount;
  NSMutableArray *desktopReps;
  NSButton *selectedDesktopRep;
  NSMutableArray *wmStateDesktops;
}

- (void)arrangeDesktopReps;
- (void)revert:sender;

@end
