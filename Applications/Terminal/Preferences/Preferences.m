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

#import "../Controller.h"
#import "Preferences.h"

#import "ColorsPrefs.h"
#import "DisplayPrefs.h"
#import "LinuxPrefs.h"
#import "SelectionPrefs.h"
#import "ShellPrefs.h"
#import "StartupPrefs.h"
#import "TitleBarPrefs.h"
#import "WindowPrefs.h"
#import "ActivityPrefs.h"

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
  if (isOpened == NO) {
    [mainWindow makeMainWindow];
    [self makeKeyAndOrderFront:mainWindow];
  }
  // else
  //   {
  //     mainWindow = [NSApp mainWindow];
  //     [self makeMainWindow];
  //   }
}
@end

@implementation Preferences

static Preferences *shared = nil;

+ shared
{
  if (shared == nil) {
    shared = [self new];
  }
  return shared;
}

- init
{
  self = shared = [super init];

  prefModules = @{
    [ActivityPrefs name] : [ActivityPrefs new],
    [ColorsPrefs name] : [ColorsPrefs new],
    [DisplayPrefs name] : [DisplayPrefs new],
    [LinuxPrefs name] : [LinuxPrefs new],
    [ShellPrefs name] : [ShellPrefs new],
    [StartupPrefs name] : [StartupPrefs new],
    [TitleBarPrefs name] : [TitleBarPrefs new],
    [SelectionPrefs name] : [SelectionPrefs new],
    [WindowPrefs name] : [WindowPrefs new]
  };
  [prefModules retain];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(mainWindowDidChange:)
                                               name:NSWindowDidBecomeMainNotification
                                             object:nil];

  mainWindow = [NSApp mainWindow];

  return self;
}

- (void)activatePanel
{
  if (window == nil) {
    [NSBundle loadNibNamed:@"PreferencesPanel" owner:self];
  } else {
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
  id<PrefsModule> module;
  NSView *moduleView;

  module = [prefModules objectForKey: [sender titleOfSelectedItem]];
  moduleView = [module view];
  if ([modeContentBox contentView] != moduleView) {
    [(NSBox *)modeContentBox setContentView:moduleView];
  }
  [module showWindow];
}

- (void)mainWindowDidChange:(NSNotification *)notif
{
  id<PrefsModule> module;

  NSLog(@"Preferences: main window now: %@", [[notif object] title]);

  if ([[NSApp delegate] preferencesForWindow:[notif object] live:NO] == nil) {
    // NSLog(@"Preferences: main window is not terminal window.");
    return;
  }

  if (mainWindow == [notif object]) {
    // NSLog(@"Preferences: main terminal window left unchanged.");
    return;
  }

  mainWindow = [notif object];

  module = [prefModules objectForKey: [modeBtn titleOfSelectedItem]];
  [module showWindow];
}

- (Defaults *)mainWindowPreferences
{
  Defaults *prefs;

  prefs = [[NSApp delegate] preferencesForWindow:mainWindow live:NO];

  // This is the case: no terminal windows opened.
  if (!prefs) {
    prefs = [Defaults shared];
  }
  return prefs;
}

// This method should be called by Preferences.bundle modules only.
// Modules will only read live preferences and never directly write them.
// This method should be called to be sure if livePreferences exists -
// and read them.
// If module wants to change default preferences must call
// 'mainWindowPreferences' (implemented above).
- (Defaults *)mainWindowLivePreferences
{
  Defaults *prefs;

  prefs = [[NSApp delegate] preferencesForWindow:mainWindow live:YES];

  if (!prefs) {
    prefs = [[NSApp delegate] preferencesForWindow:mainWindow live:NO];
  }
  // Caller wants live preferences but there's no main window visible.
  // Sample case: no Terminal window exist and Terminal Prefernces panel was
  // opened.
  if (!prefs) {
    prefs = [self mainWindowPreferences];
  }
  return prefs;
}

@end
