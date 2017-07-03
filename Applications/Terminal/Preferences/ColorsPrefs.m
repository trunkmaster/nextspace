/* All Rights reserved */

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

// Overwrites default preferences (~/Library/Preferences/Terminal.plist).
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
// Reads from default preferences (~/Library/Preferences/Terminal.plist).
- (void)showDefault:(id)sender
{
  Defaults *defs = [[Preferences shared] mainWindowPreferences];
  
  //Window
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
// Show preferences of main window
- (void)showWindow
{
  Defaults *prefs = [[Preferences shared] mainWindowLivePreferences];

  //Window
  [windowBGColorBtn setColor:[prefs windowBackgroundColor]];
  [windowSelectionColorBtn setColor:[prefs windowSelectionColor]];
  [normalTextColorBtn setColor:[prefs textNormalColor]];
  [blinkTextColorBtn setColor:[prefs textBlinkColor]];
  [boldTextColorBtn setColor:[prefs textBoldColor]];
  
  [inverseTextBGColorBtn setColor:[prefs textInverseBackground]];
  [inverseTextFGColor setColor:[prefs textInverseForeground]];
  
  [useBoldBtn setState:([prefs useBoldTerminalFont] == YES)];

  // Cursor
  [cursorColorBtn setColor:[prefs cursorColor]];
  [cursorStyleMatrix selectCellWithTag:[prefs cursorStyle]];
}
// Send changed preferences to window. No files changed or updated.
- (void)setWindow:(id)sender
{
  Defaults     *prefs;
  NSDictionary *uInfo;

  if (![sender isKindOfClass:[NSButton class]]) return;
  
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
