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

- (void)setDefault:(id)sender
{
  Defaults *defs = [Defaults shared];
  NSFont   *font;
  
  [defs setInteger:[columnsField intValue] forKey:WindowWidthKey];
  [defs setInteger:[rowsField intValue] forKey:WindowHeightKey];

  [defs setInteger:[[shellExitMatrix selectedCell] tag]
          forKey:WindowCloseBehaviorKey];

  font = [fontField font];
  [defs setObject:[font fontName] forKey:TerminalFontKey];
  [defs setInteger:(int)[font pointSize] forKey:TerminalFontSizeKey];

  [defs synchronize];
  [defs readWindowDefaults];
}
- (void)showDefault:(id)sender
{
  Defaults *defs = [Defaults shared];
  NSFont   *font;
  
  [columnsField setIntegerValue:[defs windowWidth]];
  [rowsField setIntegerValue:[defs windowHeight]];

  [shellExitMatrix selectCellWithTag:[defs windowCloseBehavior]];

  font = [defs terminalFont];
  [fontField setFont:font];
  [fontField setStringValue:[NSString stringWithFormat:@"%@ %.1f pt.",
                                      [font fontName], [font pointSize]]];  
}

- (void)showWindow
{
  id prefs = [[Preferences shared] mainWindowPreferences];

}
- (void)setWindow:(id)sender
{
  NSMutableDictionary *prefs;
  NSNumber            *wcb;

  if (![sender isKindOfClass:[NSButton class]]) return;
  
  prefs = [NSMutableDictionary new];
  
  // NSLog(@"Preferences:Window setWindow: %@ (sender:%@)",
  //       [[[NSApp mainWindow] windowController] className],
  //       [sender className]);

  [prefs setObject:[columnsField stringValue] forKey:WindowWidthKey];
  [prefs setObject:[rowsField stringValue] forKey:WindowHeightKey];

  wcb = [NSNumber numberWithInt:[[shellExitMatrix selectedCell] tag]];
  [prefs setObject:wcb forKey:WindowCloseBehaviorKey];

  [prefs setObject:[fontField font] forKey:TerminalFontKey];

  [[NSNotificationCenter defaultCenter]
    postNotificationName:TerminalPreferencesDidChangeNotification
                  object:[NSApp mainWindow]
                userInfo:prefs];
}

@end

@implementation WindowPrefs (FontPanelDelegate)

- (void)windowWillClose:(NSNotification*)aNotification
{
  // Tell PreferencesPanel about font panel closing
  [(PreferencesPanel *)[view window] fontPanelOpened:NO];
}

@end
