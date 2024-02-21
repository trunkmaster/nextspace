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

#include "ColorsPrefs.h"

@implementation ColorsPrefs

// <PrefsModule>
+ (NSString *)name
{
  return @"Colors";
}

- init
{
  self = [super init];

  [NSBundle loadNibNamed:@"Colors" owner:self];

  return self;
}

- (void)awakeFromNib
{
  [[cursorStyleMatrix cellWithTag:0] setRefusesFirstResponder:YES];
  [[cursorStyleMatrix cellWithTag:1] setRefusesFirstResponder:YES];
  [[cursorStyleMatrix cellWithTag:2] setRefusesFirstResponder:YES];
  [[cursorStyleMatrix cellWithTag:3] setRefusesFirstResponder:YES];

  [view retain];
}

- (NSView *)view
{
  return view;
}

- (void)showCursorColorPanel:(id)sender
{
  [[NSColorPanel sharedColorPanel] setShowsAlpha:YES];
}

- (void)_updateControls:(Defaults *)defs
{
  // Window
  [windowBGColorBtn setColor:[defs windowBackgroundColor]];
  [windowSelectionColorBtn setColor:[defs windowSelectionColor]];
  [normalTextColorBtn setColor:[defs textNormalColor]];
  [blinkTextColorBtn setColor:[defs textBlinkColor]];
  [boldTextColorBtn setColor:[defs textBoldColor]];

  [inverseTextBGColorBtn setColor:[defs textInverseBackground]];
  [inverseTextFGColor setColor:[defs textInverseForeground]];

  [useBoldBtn setState:([defs useBoldTerminalFont] == YES)];

  // Cursor
  [cursorColorBtn setColor:[defs cursorColor]];
  [cursorStyleMatrix selectCellWithTag:[defs cursorStyle]];
}

// Injects color settings into default preferences (Terminal.plist
// or session file *.term).
- (void)setDefault:(id)sender
{
  Defaults *defs = [[Preferences shared] mainWindowPreferences];

  [defs setBool:[useBoldBtn state] forKey:TerminalFontUseBoldKey];

  // Cursor
  [defs setCursorColor:[cursorColorBtn color]];
  [defs setCursorStyle:[[cursorStyleMatrix selectedCell] tag]];

  // Window
  [defs setWindowBackgroundColor:[windowBGColorBtn color]];
  [defs setWindowSelectionColor:[windowSelectionColorBtn color]];

  // Text
  [defs setTextNormalColor:[normalTextColorBtn color]];
  [defs setTextBlinklColor:[blinkTextColorBtn color]];
  [defs setTextBoldColor:[boldTextColorBtn color]];

  [defs setTextInverseBackground:[inverseTextBGColorBtn color]];
  [defs setTextInverseForeground:[inverseTextFGColor color]];

  [defs synchronize];
}
// Reads from loaded preferences (Terminal.plist or session file *.term).
- (void)showDefault:(id)sender
{
  [self _updateControls:[[Preferences shared] mainWindowPreferences]];
}
// Show preferences of main window
- (void)showWindow
{
  [self _updateControls:[[Preferences shared] mainWindowLivePreferences]];
}
// Send changed preferences to window. No files changed or updated.
- (void)setWindow:(id)sender
{
  Defaults *prefs;
  NSDictionary *uInfo;

  if (![sender isKindOfClass:[NSButton class]])
    return;

  prefs = [[Defaults alloc] initEmpty];

  [prefs setUseBoldTerminalFont:[useBoldBtn state]];

  // Cursor
  [prefs setCursorColor:[cursorColorBtn color]];
  [prefs setCursorStyle:[[cursorStyleMatrix selectedCell] tag]];

  // Window
  [prefs setWindowBackgroundColor:[windowBGColorBtn color]];
  [prefs setWindowSelectionColor:[windowSelectionColorBtn color]];

  // Text
  [prefs setTextNormalColor:[normalTextColorBtn color]];
  [prefs setTextBlinklColor:[blinkTextColorBtn color]];
  [prefs setTextBoldColor:[boldTextColorBtn color]];

  [prefs setTextInverseBackground:[inverseTextBGColorBtn color]];
  [prefs setTextInverseForeground:[inverseTextFGColor color]];

  uInfo = [NSDictionary dictionaryWithObject:prefs forKey:@"Preferences"];
  [prefs release];

  [[NSNotificationCenter defaultCenter]
      postNotificationName:TerminalPreferencesDidChangeNotification
                    object:[NSApp mainWindow]
                  userInfo:uInfo];
}

@end
