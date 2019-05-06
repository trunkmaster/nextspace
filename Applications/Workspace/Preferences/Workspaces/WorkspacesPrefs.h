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

@interface WorkspacesPrefs : NSObject <PrefsModule>
{
  // Workspaces
  id window;
  id box;

  id wsBox;
  id ws1, ws2, ws3, ws4, ws5, ws6, ws7, ws8, ws9, ws10;
  id wsNumber;
  id nameField;
  id changeNameBtn;
  id switchKey;
  id directSwitchKey;
  id showInDockBtn;

  NSUInteger     wsCount;
  NSMutableArray *wsReps;
  NSButton       *selectedWSRep;
  NSMutableArray *wmStateWS;
}

- (void)arrangeWorkspaceReps;
- (void)revert:sender;

@end
