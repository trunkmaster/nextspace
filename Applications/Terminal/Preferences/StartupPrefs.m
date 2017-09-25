/*
  Copyright (C) 2015 Sergii Stoian <stoyan255@ukr.net>

  This file is a part of Terminal.app. Terminal.app is free software; you
  can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation; version 2
  of the License. See COPYING or main.m for more information.
*/

#include "StartupPrefs.h"

@implementation StartupPrefs

// <PrefsModule>
+ (NSString *)name
{
  return @"Startup";
}

- init
{
  self = [super init];

  [NSBundle loadNibNamed:@"Startup" owner:self];

  return self;
}

- (void)awakeFromNib
{
  [actionsMatrix setRefusesFirstResponder:YES];
  [[actionsMatrix cellWithTag:1] setRefusesFirstResponder:YES];
  [[actionsMatrix cellWithTag:2] setRefusesFirstResponder:YES];
  [[actionsMatrix cellWithTag:3] setRefusesFirstResponder:YES];

  [view retain];
}

// <PrefsModule>
- (NSView *)view
{
  return view;
}

- (void)showWindow
{
  Defaults *defs = [Defaults shared];

  [actionsMatrix selectCellWithTag:[defs startupAction]];
  [autolaunchBtn setState:[defs hideOnAutolaunch]];
  [filePathField setStringValue:[defs startupFile]];
}

- (void)setAction:(id)sender
{
  Defaults *defs = [Defaults shared];
  
  [defs setInteger:[[actionsMatrix selectedCell] tag]
            forKey:StartupActionKey];
  [defs synchronize];
}
- (void)setFilePath:(id)sender
{
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  NSString    *sessionDir, *path;
  Defaults    *defs = [Defaults shared];

  [panel setCanChooseDirectories:NO];
  [panel setAllowsMultipleSelection:NO];
  [panel setTitle:@"Set Startup File"];
  [panel setShowsHiddenFiles:NO];

  if ((sessionDir = [Defaults sessionsDirectory]) == nil)
    return;

  if ([panel runModalForDirectory:sessionDir
                             file:@"Default.term"
                            types:[NSArray arrayWithObject:@"term"]]
      == NSOKButton)
    {
      if ((path = [panel filename]) != nil)
        {
          [filePathField setStringValue:path];
          [defs setStartupFile:path];
          [defs synchronize];
        }
    }
}
- (void)setAutolaunch:(id)sender
{
  Defaults *defs = [[Preferences shared] mainWindowLivePreferences];
  
  [defs setHideOnAutolaunch:[autolaunchBtn state]];
  [defs synchronize];
}

@end
