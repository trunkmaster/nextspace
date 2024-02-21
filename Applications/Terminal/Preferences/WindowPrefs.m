/*
  Copyright (c) 2017 Sergii Stoian <stoyan255@gmail.com>

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

#import "WindowPrefs.h"
#import "../TerminalWindow.h"

@implementation WindowPrefs

// <PrefsModule>
+ (NSString *)name
{
  return @"Window";
}

- (NSView *)view
{
  return view;
}

- init
{
  self = [super init];

  [NSBundle loadNibNamed:@"Window" owner:self];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(showWindow)
                                               name:TerminalWindowSizeDidChangeNotification
                                             object:nil];

  return self;
}

- (void)awakeFromNib
{
  for (id cell in [shellExitMatrix cells]) {
    [cell setRefusesFirstResponder:YES];
  }
  [view retain];
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

- (void)setFont:(id)sender
{
  NSFontManager *fm = [NSFontManager sharedFontManager];
  NSFontPanel *fp = [fm fontPanel:YES];

  [fm setSelectedFont:[fontField font] isMultiple:NO];
  [fp setDelegate:self];

  // Tell PreferencesPanel about font panel opening
  // if ([[view window] isVisible] == YES)
  //   {
  //     [(PreferencesPanel *)[view window] fontPanelOpened:YES];
  //   }

  // [fp makeKeyAndOrderFront:self];
  [fp orderFront:self];
}

- (void)changeFont:(id)sender  // Font panel callback
{
  NSFont *f = [sender convertFont:[fontField font]];

  // NSLog(@"Preferences: changeFont:%@", [sender className]);

  if (!f) {
    return;
  }
  [fontField
      setStringValue:[NSString stringWithFormat:@"%@ %0.1f pt.", [f fontName], [f pointSize]]];
  [fontField setFont:f];

  return;
}

- (void)_updateControls:(Defaults *)prefs
{
  NSFont *font;

  [columnsField setIntegerValue:[prefs windowWidth]];
  [rowsField setIntegerValue:[prefs windowHeight]];

  [shellExitMatrix selectCellWithTag:[prefs windowCloseBehavior]];

  font = [prefs terminalFont];
  [fontField setFont:font];
  [fontField
      setStringValue:[NSString stringWithFormat:@"%@ %.1f pt.", [font fontName], [font pointSize]]];
}

// Write to:
// 	~/L/P/Terminal.plist if window use NSUserDefaults
// 	~/L/Terminal/<name>.term if window use loaded startup file
- (void)setDefault:(id)sender
{
  Defaults *prefs = [[Preferences shared] mainWindowPreferences];

  [prefs setWindowWidth:[columnsField intValue]];
  [prefs setWindowHeight:[rowsField intValue]];

  [prefs setWindowCloseBehavior:[[shellExitMatrix selectedCell] tag]];

  [prefs setTerminalFont:[fontField font]];

  [prefs synchronize];
}
- (void)showDefault:(id)sender
{
  [self _updateControls:[[Preferences shared] mainWindowPreferences]];
}

// Get current/live (may be changed) preferences
- (void)showWindow
{
  [self _updateControls:[[Preferences shared] mainWindowLivePreferences]];
}
// Fill empty Defaults with this module values and send it to window
// with notification.
- (void)setWindow:(id)sender
{
  Defaults *prefs;
  NSDictionary *uInfo;

  if (![sender isKindOfClass:[NSButton class]]) {
    return;
  }

  prefs = [[Defaults alloc] initEmpty];

  [prefs setWindowHeight:[rowsField intValue]];
  [prefs setWindowWidth:[columnsField intValue]];
  [prefs setWindowCloseBehavior:[[shellExitMatrix selectedCell] tag]];
  [prefs setTerminalFont:[fontField font]];

  uInfo = [NSDictionary dictionaryWithObject:prefs forKey:@"Preferences"];
  [prefs release];

  [[NSNotificationCenter defaultCenter]
      postNotificationName:TerminalPreferencesDidChangeNotification
                    object:[NSApp mainWindow]
                  userInfo:uInfo];
}

@end

@implementation WindowPrefs (FontPanelDelegate)

- (void)windowWillClose:(NSNotification *)aNotification
{
  // Tell PreferencesPanel about font panel closing
  // TODO: Actually this must handled by WindowMaker
  if ([[view window] isVisible] == YES) {
    [(PreferencesPanel *)[view window] fontPanelOpened:NO];
  }
}

@end
