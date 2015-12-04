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

- (void)setDefault:(id)sender
{
  [ud setBool:[useBoldBtn state] forKey:TerminalFontUseBoldKey];

  // Cursor
  [ud setObject:[Defaults descriptionFromColor:[cursorColorBtn color]]
         forKey:CursorColorKey];
    
  [ud setInteger:[[cursorStyleMatrix selectedCell] tag] forKey:CursorStyleKey];

  // Window
  [ud setObject:[self _descriptionFromColor:[windowBGColorBtn color]]
         forKey:WindowBGColorKey];
  [ud setObject:[self _descriptionFromColor:[windowSelectionColorBtn color]]
         forKey:SelectionBGColorKey];

  // Text
  [ud setObject:[self _descriptionFromColor:[normalTextColorBtn color]]
         forKey:TextNormalColorKey];
  [ud setObject:[self _descriptionFromColor:[blinkTextColorBtn color]]
         forKey:TextBlinkColorKey];
  [ud setObject:[self _descriptionFromColor:[boldTextColorBtn color]]
         forKey:TextBoldColorKey];
  
  [ud setObject:[self _descriptionFromColor:[inverseTextBGColorBtn color]]
         forKey:TextInverseBGColorKey];
  [ud setObject:[self _descriptionFromColor:[inverseTextFGColor color]]
         forKey:TextInverseFGColorKey];
  
  
  [ud synchronize];
  
  [Defaults readColorsDefaults];
}
- (void)showDefault:(id)sender
{
  //Window
  [windowBGColorBtn setColor:[Defaults windowBackgroundColor]];
  [windowSelectionColorBtn setColor:[Defaults windowSelectionColor]];
  [normalTextColorBtn setColor:[Defaults textNormalColor]];
  [blinkTextColorBtn setColor:[Defaults textBlinkColor]];
  [boldTextColorBtn setColor:[Defaults textBoldColor]];
  
  [inverseTextBGColorBtn setColor:[Defaults textInverseBackground]];
  [inverseTextFGColor setColor:[Defaults textInverseForeground]];
  
  [useBoldBtn setState:([Defaults useBoldTerminalFont] == YES)];

  // Cursor
  [cursorColorBtn setColor:[Defaults cursorColor]];
  [cursorStyleMatrix selectCellWithTag:[Defaults cursorStyle]];
}
- (void)setWindow:(id)sender
{
  NSMutableDictionary *prefs;

  if (![sender isKindOfClass:[NSButton class]]) return;
  
  prefs = [NSMutableDictionary new];
  
  [prefs setObject:[self _descriptionFromColor:[cursorColorBtn color]]
            forKey:CursorColorKey];

  [prefs setObject:[NSNumber numberWithInteger:[[cursorStyleMatrix selectedCell] tag]]
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
