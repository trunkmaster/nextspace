/*
  Copyright (C) 2015 Sergii Stoian <stoyan255@ukr.net>

  This file is a part of Terminal.app. Terminal.app is free software; you
  can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation; version 2
  of the License. See COPYING or main.m for more information.
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
  BOOL     fontPanelOpened;
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
