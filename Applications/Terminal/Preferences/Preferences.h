/*
  Copyright (C) 2015 Sergii Stoian <stoyan255@ukr.net>

  This file is a part of Terminal.app. Terminal.app is free software; you
  can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation; version 2
  of the License. See COPYING or main.m for more information.
*/

#import <AppKit/AppKit.h>

@protocol PrefsModule

+ (NSString *)name;
// + (NSImage *)icon; // TODO
// + (NSString *)shortcut; // TODO
// + (NSUInteger)priority; // TODO
- (NSView *)view;
// - (BOOL)willShow; // TODO
// - (BOOL)willHide; // TODO
- (void)showDefault:(id)sender;
// - (BOOL)isEdited; // TODO

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
}

- (void)activatePanel;
- (void)closePanel;
- (void)switchMode:(id)sender;

@end

#import "../Defaults.h"
