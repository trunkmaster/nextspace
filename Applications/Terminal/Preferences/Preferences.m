/*
  Copyright (C) 2015 Sergii Stoian <stoyan255@ukr.net>

  This file is a part of Terminal.app. Terminal.app is free software; you
  can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation; version 2
  of the License. See COPYING or main.m for more information.
*/

#import "../Controller.h"
#import "../Controller.h"
#import "Preferences.h"

#import "ColorsPrefs.h"
#import "DisplayPrefs.h"
#import "LinuxPrefs.h"
#import "ShellPrefs.h"
#import "StartupPrefs.h"
#import "TitleBarPrefs.h"
#import "WindowPrefs.h"

// This class manages key/main window state for FontPanel opening
@implementation PreferencesPanel
- (BOOL)canBecomeMainWindow
{
  return NO;
  // return fontPanelOpened;
}
- (void)fontPanelOpened:(BOOL)isOpened
{
  // fontPanelOpened = isOpened;
  if (isOpened == NO)
    {
      [mainWindow makeMainWindow];
      [self makeKeyAndOrderFront:mainWindow];
    }
  else
    {
      // mainWindow = [NSApp mainWindow];
      // [self makeMainWindow];
    }
}
@end

@implementation Preferences

static Preferences *shared = nil;

+ shared
{
  if (shared == nil)
    {
      shared = [self new];
    }
  return shared;
}

- init
{
  self = shared = [super init];
  
  prefModules = [NSDictionary dictionaryWithObjectsAndKeys:
                                [ColorsPrefs new], [ColorsPrefs name],
                              [DisplayPrefs new], [DisplayPrefs name],
                              [LinuxPrefs new], [LinuxPrefs name],
                              [ShellPrefs new], [ShellPrefs name],
                              [StartupPrefs new], [StartupPrefs name],
                              [TitleBarPrefs new], [TitleBarPrefs name],
                              [WindowPrefs new], [WindowPrefs name],
                              nil];
  [prefModules retain];

  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(mainWindowDidChange:)
           name:NSWindowDidBecomeMainNotification
         object:nil];

  mainWindow = [NSApp mainWindow];

  return self;
}

- (void)activatePanel
{
  if (window == nil)
    {
      [NSBundle loadNibNamed:@"PreferencesPanel" owner:self];
    }
  else
    {
      [self switchMode:modeBtn];
    }
  [window makeKeyAndOrderFront:nil];
}

- (void)awakeFromNib
{
  [window setFrameAutosaveName:@"Preferences"];
  [modeBtn selectItemAtIndex:0];
  [self switchMode:modeBtn];
}

- (void)closePanel
{
  [window close];
}


- (void)switchMode:(id)sender
{
  id <PrefsModule> module;
  NSView           *mView;

  module = [prefModules objectForKey:[sender titleOfSelectedItem]];
  mView = [module view];
  if ([modeContentBox contentView] != mView)
    {
      [(NSBox *)modeContentBox setContentView:mView];
    }
  [module showWindow];
}

- (void)mainWindowDidChange:(NSNotification *)notif
{
  id <PrefsModule> module;

  // NSLog(@"Preferences: main window now: %@", [[notif object] title]);

  if ([[NSApp delegate] preferencesForWindow:[notif object] live:NO] == nil)
    {
      // NSLog(@"Preferences: main window is not terminal window.");
      return;
    }

  if (mainWindow == [notif object])
    {
      // NSLog(@"Preferences: main terminal window left unchanged.");
      return;
    }
  
  mainWindow = [notif object];
  
  module = [prefModules objectForKey:[modeBtn titleOfSelectedItem]];
  [module showWindow];
}

- (Defaults *)mainWindowPreferences
{
  Defaults *prefs;
  
  prefs = [[NSApp delegate] preferencesForWindow:mainWindow live:NO];

  if (!prefs) // should never happen - live:NO means "startup preferences"
    prefs = [Defaults shared];

  return prefs;
}

- (Defaults *)mainWindowLivePreferences
{
  Defaults *prefs;
  
  prefs = [[NSApp delegate] preferencesForWindow:mainWindow live:YES];

  // TODO: should we return defaults if no live preferences returned (no
  // changes to preferences has happened)?
  // FTOH, this method should be called by Preferences.bundle modules only.
  // Modules will only read live preferences and never directly write them.
  // Calling this method called to be sure that if livePreferences exists -
  // read preferences from it.
  // If module wants to change default preferences must call
  // 'mainWindowPreferences' (implemented above).
  if (!prefs)
    prefs = [Defaults shared];

  return prefs;
}

@end
