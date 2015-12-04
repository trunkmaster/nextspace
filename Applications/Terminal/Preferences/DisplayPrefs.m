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
  if ([bufferEnabledBtn state] == NSOffState)
    [ud setBool:NO forKey:ScrollBackEnabledKey];
  else
    [ud setBool:YES forKey:ScrollBackEnabledKey];


  if ([bufferLengthMatrix selectedColumn] == 0)
    {
      [ud setBool:YES forKey:ScrollBackUnlimitedKey];
    }
  else
    {
      // set length to value of textfield in UserDefaults
      [ud setBool:NO forKey:ScrollBackUnlimitedKey];
      [ud setInteger:[bufferLengthField intValue]
              forKey:ScrollBackLinesKey];
    }
  [self setBufferEnabled:bufferEnabledBtn];

  if ([scrollBottomBtn state] == NSOffState)
    [ud setBool:NO forKey:ScrollBottomOnInputKey];
  else
    [ud setBool:YES forKey:ScrollBottomOnInputKey];

  [ud synchronize];
  [Defaults readDisplayDefaults];
}
// Reset onscreen controls to values stored in UserDefaults
- (void)showDefault:(id)sender
{
  if ([Defaults scrollBackEnabled] == NO)
    {
      [bufferEnabledBtn setState:NSOffState];
    }
  else
    {
      int sbLines = [Defaults scrollBackLines];
      
      [bufferEnabledBtn setState:NSOnState];
      
      if ([Defaults scrollBackUnlimited] == YES)
        [bufferLengthMatrix selectCellWithTag:0];
      else
        [bufferLengthMatrix selectCellWithTag:1];
      
      [bufferLengthField setIntegerValue:sbLines];
    }
  
  [self setBufferEnabled:bufferEnabledBtn];
  [scrollBottomBtn setState:[Defaults scrollBottomOnInput]];
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
