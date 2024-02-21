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

#import "ShellPrefs.h"
#import "../Controller.h"

@implementation ShellPrefs

// <PrefsModule>
+ (NSString *)name
{
  return @"Shell";
}

- init
{
  self = [super init];

  [NSBundle loadNibNamed:@"Shell" owner:self];

  return self;
}

- (void)awakeFromNib
{
  [view retain];

  [shellPopup removeAllItems];
  [shellPopup addItemsWithTitles:[[NSApp delegate] shellList]];
  [shellPopup addItemWithTitle:@"Command"];
}

// <PrefsModule>
- (NSView *)view
{
  return view;
}

- (void)_updateControls:(Defaults *)defs
{
  NSString *shellStr;
  NSInteger shellIndex;

  if (defs) {
    shellStr = [defs shell];
    shellIndex = [shellPopup indexOfItemWithTitle:shellStr];

    if ([shellStr isEqualToString:@"Command"] || shellIndex == -1) {
      [shellPopup selectItemWithTitle:@"Command"];
      [commandField setStringValue:shellStr];
    } else {
      [shellPopup selectItemWithTitle:shellStr];
      [loginShellBtn setState:[defs loginShell]];
    }
  }

  shellStr = [shellPopup titleOfSelectedItem];
  if ([shellStr isEqualToString:@"Command"]) {
    [loginShellBtn setEnabled:NO];
    [loginShellBtn setState:0];

    [commandLabel setEnabled:YES];
    [commandField setEnabled:YES];
  } else {
    [loginShellBtn setEnabled:YES];

    [commandLabel setEnabled:NO];
    [commandField setEnabled:NO];
    [commandField setStringValue:@""];
  }
}

- (void)showWindow
{
  [self _updateControls:[[Preferences shared] mainWindowLivePreferences]];
}

// Controls actions

// Write values to UserDefaults
- (void)setDefault:(id)sender
{
  Defaults *defs = [[Preferences shared] mainWindowPreferences];
  NSString *shellStr = [shellPopup titleOfSelectedItem];

  if ([shellStr isEqualToString:@"Command"]) {
    [defs setShell:[commandField stringValue]];
    [defs setLoginShell:NO];
  } else {
    [defs setShell:shellStr];
    [defs setLoginShell:[loginShellBtn state]];
  }
  [defs synchronize];
}
// Reset onscreen controls to values stored in UserDefaults
- (void)showDefault:(id)sender
{
  [self _updateControls:[[Preferences shared] mainWindowPreferences]];
}

// Modify live preferences through notification
- (void)setWindow:(id)sender
{
  Defaults *prefs;
  NSDictionary *uInfo;
  NSString *shellStr;

  if (![sender isKindOfClass:[NSButton class]])
    return;

  prefs = [[Defaults alloc] initEmpty];

  shellStr = [shellPopup titleOfSelectedItem];
  if ([shellStr isEqualToString:@"Command"]) {
    [prefs setShell:[commandField stringValue]];
    [prefs setLoginShell:NO];
  } else {
    [prefs setShell:shellStr];
    [prefs setLoginShell:[loginShellBtn state]];
  }

  uInfo = [NSDictionary dictionaryWithObject:prefs forKey:@"Preferences"];
  [prefs release];

  [[NSNotificationCenter defaultCenter]
      postNotificationName:TerminalPreferencesDidChangeNotification
                    object:[NSApp mainWindow]
                  userInfo:uInfo];
}

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
{
  return YES;
}

- (void)setShell:(id)sender
{
  [self _updateControls:nil];
}

@end
