/*
  Copyright (c) 2015-2017 Sergii Stoian <stoyan255@gmail.com>

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

#import <AppKit/AppKit.h>

#import "../Defaults.h"

@protocol PrefsModule

// Name that will be added to popup button
+ (NSString *)name;
// Returns view which contains controls to manipulate preferences
- (NSView *)view;
// Show preferences of main window
- (void)showWindow;

// The following methods are not defined by protocol by must carry the following
// meaning:
// - (void)setDefault:(id)sender;
// 	Overwrites default preferences (~/Library/Preferences/Terminal.plist).
// - (void)showDefault:(id)sender;
// 	Reads from default preferences.
// - (void)setWindow:(id)sender;
// 	Send changed preferences to window. No files changed or updated.

// Leave these here for informational purposes.
// + (NSImage *)icon;
// + (NSString *)shortcut;
// + (NSUInteger)priority;
// - (BOOL)willShow;
// - (BOOL)willHide;
// - (BOOL)isEdited;

@end

@interface PreferencesPanel : NSPanel
{
  BOOL fontPanelOpened;
  NSWindow *mainWindow;
}

- (void)fontPanelOpened:(BOOL)isOpened;

@end

@interface Preferences : NSObject
{
  NSDictionary *prefModules;
  id window;
  id modeBtn;
  id modeContentBox;

  NSWindow *mainWindow;
}

+ shared;

- (void)activatePanel;
- (void)closePanel;
- (void)switchMode:(id)sender;

- (Defaults *)mainWindowPreferences;
- (Defaults *)mainWindowLivePreferences;

@end
