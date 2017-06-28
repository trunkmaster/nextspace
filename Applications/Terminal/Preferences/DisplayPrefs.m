/* All Rights reserved */

#import "DisplayPrefs.h"

@implementation DisplayPrefs

// <PrefsModule>
+ (NSString *)name
{
  return @"Display";
}

- init
{
  self = [super init];

  [NSBundle loadNibNamed:@"Display" owner:self];

  return self;
}

- (void)awakeFromNib
{
  [[bufferLengthMatrix cellWithTag:0] setRefusesFirstResponder:YES];
  [[bufferLengthMatrix cellWithTag:1] setRefusesFirstResponder:YES];

  [scrollBottomBtn setRefusesFirstResponder:YES];

  [self showDefault:self];
  
  [view retain];
}

// <PrefsModule>
- (NSView *)view
{
  return view;
}

// Actions
- (void)setBufferEnabled:(id)sender
{
  if ([bufferEnabledBtn state] == NSOffState)
    {
      [bufferLengthMatrix setEnabled:NO];
      [bufferLengthField setEnabled:NO];
    }
  else
    {
      [bufferLengthMatrix setEnabled:YES];
      if ([bufferLengthMatrix selectedColumn] == 0)
        {
          [bufferLengthField setEnabled:NO];
        }
      else
        {
          [bufferLengthField setEnabled:YES];
          [[view window] makeFirstResponder:bufferLengthField];
        }
    }
}

// Write values to UserDefaults
- (void)setDefault:(id)sender
{
  Defaults *defs = [Defaults shared];
  
  if ([bufferEnabledBtn state] == NSOffState)
    [defs setBool:NO forKey:ScrollBackEnabledKey];
  else
    [defs setBool:YES forKey:ScrollBackEnabledKey];


  if ([bufferLengthMatrix selectedColumn] == 0)
    {
      [defs setBool:YES forKey:ScrollBackUnlimitedKey];
    }
  else
    {
      // set length to value of textfield in UserDefaults
      [defs setBool:NO forKey:ScrollBackUnlimitedKey];
      [defs setInteger:[bufferLengthField intValue]
              forKey:ScrollBackLinesKey];
    }
  [self setBufferEnabled:bufferEnabledBtn];

  if ([scrollBottomBtn state] == NSOffState)
    [defs setBool:NO forKey:ScrollBottomOnInputKey];
  else
    [defs setBool:YES forKey:ScrollBottomOnInputKey];

  [defs synchronize];
  [defs readDisplayDefaults];
}
// Reset onscreen controls to values stored in UserDefaults
- (void)showDefault:(id)sender
{
  Defaults *defs = [Defaults shared];
  
  if ([defs scrollBackEnabled] == NO)
    {
      [bufferEnabledBtn setState:NSOffState];
    }
  else
    {
      int sbLines = [defs scrollBackLines];
      
      [bufferEnabledBtn setState:NSOnState];
      
      if ([defs scrollBackUnlimited] == YES)
        [bufferLengthMatrix selectCellWithTag:0];
      else
        [bufferLengthMatrix selectCellWithTag:1];
      
      [bufferLengthField setIntegerValue:sbLines];
    }
  
  [self setBufferEnabled:bufferEnabledBtn];
  [scrollBottomBtn setState:[defs scrollBottomOnInput]];
}

- (void)showWindow
{
  // prefs = [[Preferences shared] mainWindowPreferences];
}
// Set values set to visible window
- (void)setWindow:(id)sender
{
  NSDictionary *prefs;
  NSString     *scrollBottom = @"YES";
  NSString     *sbEnabled = @"YES";
  NSString     *sbLines = @"0";

  if (![sender isKindOfClass:[NSButton class]]) return;

  scrollBottom = ([scrollBottomBtn state] == NSOffState) ? @"NO" : @"YES";
  
  if ([bufferEnabledBtn state] == NSOffState)
    {
      sbEnabled = @"NO";
    }
  else
    {
      if ([bufferLengthMatrix selectedColumn] == 0)
        sbLines = [NSString stringWithFormat:@"%i", INT_MAX];
      else
        sbLines = [bufferLengthField stringValue];
    }

  prefs = [NSDictionary dictionaryWithObjectsAndKeys:
                          scrollBottom, ScrollBottomOnInputKey,
                        sbEnabled, ScrollBackEnabledKey,
                        sbLines, ScrollBackLinesKey, nil];
  
  [[NSNotificationCenter defaultCenter]
    postNotificationName:TerminalPreferencesDidChangeNotification
                  object:[NSApp mainWindow]
                userInfo:prefs];
}

@end
