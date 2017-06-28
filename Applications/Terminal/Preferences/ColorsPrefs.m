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

- (NSDictionary *)_descriptionFromColor:(NSColor *)color
{
  NSColor *rgbColor =  [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
  NSNumber *redComponent;
  NSNumber *greenComponent;
  NSNumber *blueComponent;
  NSNumber *alphaComponent;

  redComponent = [NSNumber numberWithFloat:[rgbColor redComponent]];
  greenComponent = [NSNumber numberWithFloat:[rgbColor greenComponent]];
  blueComponent = [NSNumber numberWithFloat:[rgbColor blueComponent]];
  alphaComponent = [NSNumber numberWithFloat:[rgbColor alphaComponent]];

  return [NSDictionary dictionaryWithObjectsAndKeys:
                         redComponent, @"Red",
                       greenComponent, @"Green",
                       blueComponent,  @"Blue",
                       alphaComponent, @"Alpha",
                       nil];
}

- (NSColor *)_colorFromDescription:(NSDictionary *)desc
{

  return [NSColor
           colorWithCalibratedRed:[[desc objectForKey:@"Red"] floatValue]
                            green:[[desc objectForKey:@"Green"] floatValue]
                             blue:[[desc objectForKey:@"Blue"] floatValue]
                            alpha:[[desc objectForKey:@"Alpha"] floatValue]];
}

// Overwrites default preferences (~/Library/Preferences/Terminal.plist).
- (void)setDefault:(id)sender
{
  Defaults *defs = [Defaults shared];
  
  [defs setBool:[useBoldBtn state] forKey:TerminalFontUseBoldKey];

  // Cursor
  [defs setObject:[self _descriptionFromColor:[cursorColorBtn color]]
           forKey:CursorColorKey];
    
  [defs setInteger:[[cursorStyleMatrix selectedCell] tag] forKey:CursorStyleKey];

  // Window
  [defs setObject:[self _descriptionFromColor:[windowBGColorBtn color]]
         forKey:WindowBGColorKey];
  [defs setObject:[self _descriptionFromColor:[windowSelectionColorBtn color]]
         forKey:SelectionBGColorKey];

  // Text
  [defs setObject:[self _descriptionFromColor:[normalTextColorBtn color]]
         forKey:TextNormalColorKey];
  [defs setObject:[self _descriptionFromColor:[blinkTextColorBtn color]]
         forKey:TextBlinkColorKey];
  [defs setObject:[self _descriptionFromColor:[boldTextColorBtn color]]
         forKey:TextBoldColorKey];
  
  [defs setObject:[self _descriptionFromColor:[inverseTextBGColorBtn color]]
         forKey:TextInverseBGColorKey];
  [defs setObject:[self _descriptionFromColor:[inverseTextFGColor color]]
         forKey:TextInverseFGColorKey];
  
  [defs synchronize];
  
  [defs readColorsDefaults];
}
// Reads from default preferences (~/Library/Preferences/Terminal.plist).
- (void)showDefault:(id)sender
{
  Defaults *defs = [Defaults shared];
  
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
  id prefs = [[Preferences shared] mainWindowPreferences];

  if (!prefs)
    NSLog(@"Main window preferences is empty. Do not update section.");
  else
    NSLog(@"Main window preferences: %@", prefs);
  
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
  NSMutableDictionary *prefs;

  if (![sender isKindOfClass:[NSButton class]]) return;
  
  prefs = [NSMutableDictionary new];
  
  [prefs setObject:[self _descriptionFromColor:[cursorColorBtn color]]
            forKey:CursorColorKey];

  [prefs
    setObject:[NSNumber numberWithInteger:[[cursorStyleMatrix selectedCell] tag]]
       forKey:CursorStyleKey];
  
  [prefs setObject:[self _descriptionFromColor:[windowBGColorBtn color]]
            forKey:WindowBGColorKey];
  [prefs setObject:[self _descriptionFromColor:[windowSelectionColorBtn color]]
            forKey:SelectionBGColorKey];

  [prefs setObject:[self _descriptionFromColor:[normalTextColorBtn color]]
            forKey:TextNormalColorKey];
  [prefs setObject:[self _descriptionFromColor:[blinkTextColorBtn color]]
            forKey:TextBlinkColorKey];
  [prefs setObject:[self _descriptionFromColor:[boldTextColorBtn color]]
            forKey:TextBoldColorKey];
  
  [prefs setObject:[self _descriptionFromColor:[inverseTextBGColorBtn color]]
            forKey:TextInverseBGColorKey];
  [prefs setObject:[self _descriptionFromColor:[inverseTextFGColor color]]
            forKey:TextInverseFGColorKey];

  [[NSNotificationCenter defaultCenter]
    postNotificationName:TerminalPreferencesDidChangeNotification
                  object:[NSApp mainWindow]
                userInfo:prefs];
}

@end
