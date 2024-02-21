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

#include "SelectionPrefs.h"

@implementation SelectionPrefs

// <PrefsModule>
+ (NSString *)name
{
  return @"Selection";
}

- init
{
  self = [super init];

  [NSBundle loadNibNamed:@"Selection" owner:self];

  return self;
}

- (void)awakeFromNib
{
  [view retain];
}

// <PrefsModule>
- (NSView *)view
{
  return view;
}

- (void)_updateControls:(Defaults *)defs
{
  NSString *characters = [defs wordCharacters];
  [wordCharactersField setStringValue:characters];
}

- (void)setDefault:(id)sender
{
  Defaults *defs = [[Preferences shared] mainWindowPreferences];

  [defs setWordCharacters:[wordCharactersField stringValue]];

  [defs synchronize];
}
- (void)showDefault:(id)sender
{
  [self _updateControls:[[Preferences shared] mainWindowPreferences]];
}

- (void)showWindow
{
  [self _updateControls:[[Preferences shared] mainWindowLivePreferences]];
}

- (void)setWindow:(id)sender
{
  Defaults *prefs;
  NSDictionary *uInfo;

  prefs = [[Defaults alloc] initEmpty];

  [prefs setWordCharacters:[wordCharactersField stringValue]];

  uInfo = [NSDictionary dictionaryWithObject:prefs forKey:@"Preferences"];
  [prefs release];

  [[NSNotificationCenter defaultCenter]
      postNotificationName:TerminalPreferencesDidChangeNotification
                    object:[NSApp mainWindow]
                  userInfo:uInfo];
}

// Actions
- (void)setWordCharacters:(id)sender
{
  [self setWindow:sender];
}

@end
