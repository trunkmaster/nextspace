/* All Rights reserved */

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

  return self;
}

- (void)awakeFromNib
{
  [shellExitMatrix setRefusesFirstResponder:YES];
  [[shellExitMatrix cellWithTag:0] setRefusesFirstResponder:YES];
  [[shellExitMatrix cellWithTag:1] setRefusesFirstResponder:YES];
  [[shellExitMatrix cellWithTag:2] setRefusesFirstResponder:YES];
  
  [view retain];
}

- (void)setFont:(id)sender
{
  NSFontManager *fm = [NSFontManager sharedFontManager];
  NSFontPanel   *fp = [fm fontPanel:YES];
  
  [fm setSelectedFont:[fontField font] isMultiple:NO];
  [fp setDelegate:self];

  // Tell PreferencesPanel about font panel opening
  [(PreferencesPanel *)[view window] fontPanelOpened:YES];
 
  [fp makeKeyAndOrderFront:self];
}

- (void)changeFont:(id)sender // Font panel callback
{
  NSFont *f = [sender convertFont:[fontField font]];

  // NSLog(@"Preferences: changeFont:%@", [sender className]);

  if (!f) return;

  [fontField setStringValue:[NSString stringWithFormat: @"%@ %0.1f pt.",
                                      [f fontName], [f pointSize]]];
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
  [fontField setStringValue:[NSString stringWithFormat:@"%@ %.1f pt.",
                                      [font fontName], [font pointSize]]];
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
  [prefs readWindowDefaults];
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
// Fill empty Defaults with this module values and send it ti window
// with notification.
- (void)setWindow:(id)sender
{
  Defaults     *prefs;
  NSDictionary *uInfo;

  if (![sender isKindOfClass:[NSButton class]])
    return;
  
  prefs = [[Defaults alloc] initEmpty];
  
  // NSLog(@"Preferences:Window setWindow: %@ (sender:%@)",
  //       [[[NSApp mainWindow] windowController] className],
  //       [sender className]);

  [prefs setWindowHeight:[columnsField intValue]];
  [prefs setWindowWidth:[rowsField intValue]];
  // [prefs setObject:[columnsField stringValue] forKey:WindowWidthKey];
  // [prefs setObject:[rowsField stringValue] forKey:WindowHeightKey];

  // wcb = [NSNumber numberWithInt:[[shellExitMatrix selectedCell] tag]];
  // [prefs setObject:wcb forKey:WindowCloseBehaviorKey];
  [prefs setWindowCloseBehavior:[[shellExitMatrix selectedCell] tag]];

  // [prefs setObject:[fontField font] forKey:TerminalFontKey];
  [prefs setTerminalFont:[fontField font]];

  NSLog(@"WindowPrefs: setWindow: %@", [prefs defaults]);

  uInfo = [NSDictionary dictionaryWithObject:prefs forKey:@"Preferences"];
  
  [[NSNotificationCenter defaultCenter]
    postNotificationName:TerminalPreferencesDidChangeNotification
                  object:[NSApp mainWindow]
                userInfo:uInfo];
  // [prefs release];
}

@end

@implementation WindowPrefs (FontPanelDelegate)

- (void)windowWillClose:(NSNotification*)aNotification
{
  // Tell PreferencesPanel about font panel closing
  [(PreferencesPanel *)[view window] fontPanelOpened:NO];
}

@end
