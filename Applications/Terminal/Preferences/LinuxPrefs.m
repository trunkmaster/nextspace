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

#include "LinuxPrefs.h"

static NSString *characterSet;

typedef struct {
  NSString *name;
  NSString *display_name;
} character_set_choice_t;

static character_set_choice_t cs_choices[] = {{@"UTF-8",      __(@"Unicode")},
                                              {@"ISO-8859-1", __(@"West Europe, Latin-1")},
                                              {@"ISO-8859-2", __(@"East Europe, Latin-2")},
                                              {@"BIG-5",      __(@"Traditional Chinese")},
                                              {nil,           __(@"Custom, leave unchanged")},
                                              {nil,           nil}};

@implementation LinuxPrefs

// <PrefsModule>
+ (NSString *)name
{
  return @"Linux Emulation";
}

- init
{
  self = [super init];

  [NSBundle loadNibNamed:@"Linux" owner:self];

  return self;
}

- (void)awakeFromNib
{
  int i;
  character_set_choice_t *c;

  [charsetBtn removeAllItems];
  for (i = 0, c = cs_choices; c->display_name; i++, c++) {
    NSString *title;
    if (c->name) {
      title = [NSString stringWithFormat:@"%@ (%@)", c->display_name, c->name];
    } else {
      title = c->display_name;
    }
    [charsetBtn addItemWithTitle:title];
  }
  [view retain];

  for (id c in [alternateKeyMtrx cells]) {
    [c setRefusesFirstResponder:YES];
  }
}

// <PrefsModule>
- (NSView *)view
{
  return view;
}

- (void)_updateControls:(Defaults *)defs
{
  int i;
  character_set_choice_t *c;
  NSString *characterSet = [defs characterSet];

  for (i = 0, c = cs_choices; c->name; i++, c++) {
    if (c->name && [c->name caseInsensitiveCompare:characterSet] == NSOrderedSame)
      break;
  }
  [charsetBtn selectItemAtIndex:i];

  [handleMulticellBtn setState:([defs useMultiCellGlyphs] == YES)];

  [escapeKeyBtn setState:[defs doubleEscape]];
  [alternateKeyMtrx selectCellWithTag:[defs alternateAsMeta] ? 1 : 0];
}

- (void)setDefault:(id)sender
{
  Defaults *defs = [[Preferences shared] mainWindowPreferences];
  int i = [charsetBtn indexOfSelectedItem];

  if (cs_choices[i].name != nil) {
    [defs setCharacterSet:cs_choices[i].name];
  } else {
    [defs setCharacterSet:nil];
  }
  [defs setUseMultiCellGlyphs:[handleMulticellBtn state]];

  [defs setDoubleEscape:[escapeKeyBtn state]];
  [defs setAlternateAsMeta:[[alternateKeyMtrx selectedCell] tag]];

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
// TODO
- (void)setWindow:(id)sender
{
  Defaults *prefs;
  NSDictionary *uInfo;

  if (![sender isKindOfClass:[NSButton class]])
    return;

  prefs = [[Defaults alloc] initEmpty];

  // Character Set
  [prefs setCharacterSet:cs_choices[[charsetBtn indexOfSelectedItem]].name];
  [prefs setUseMultiCellGlyphs:[handleMulticellBtn state]];

  // Escape Key
  [prefs setDoubleEscape:[escapeKeyBtn state]];

  // Alternate Key
  [prefs setAlternateAsMeta:[[alternateKeyMtrx selectedCell] tag]];

  uInfo = [NSDictionary dictionaryWithObject:prefs forKey:@"Preferences"];
  [prefs release];

  [[NSNotificationCenter defaultCenter]
      postNotificationName:TerminalPreferencesDidChangeNotification
                    object:[NSApp mainWindow]
                  userInfo:uInfo];
}

// Actions
- (void)setCharset:(id)sender
{
  NSString *csName;
  Defaults *defs = [[Preferences shared] mainWindowPreferences];

  csName = cs_choices[[charsetBtn indexOfSelectedItem]].name;
  [defs setCharacterSet:csName];
  [defs synchronize];
}

- (void)setMultiCellGlyphs:(id)sender
{
  Defaults *defs = [[Preferences shared] mainWindowPreferences];

  [defs setUseMultiCellGlyphs:[handleMulticellBtn state]];
  [defs synchronize];
}

- (void)setEscapeKey:(id)sender
{
  Defaults *defs = [[Preferences shared] mainWindowPreferences];

  [defs setDoubleEscape:[escapeKeyBtn state]];
  [defs synchronize];
}

- (void)setAlternateKey:(id)sender
{
  Defaults *defs = [[Preferences shared] mainWindowPreferences];

  [defs setAlternateAsMeta:[[alternateKeyMtrx selectedCell] tag]];
  [defs synchronize];
}

@end
