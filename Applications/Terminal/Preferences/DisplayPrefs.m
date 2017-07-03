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
  Defaults *defs = [[Preferences shared] mainWindowPreferences];
  
  if ([bufferEnabledBtn state] == NSOffState)
    [defs setScrollBackEnabled:NO];
  else
    [defs setScrollBackEnabled:YES];

  if ([bufferLengthMatrix selectedColumn] == 0)
    {
      [defs setScrollBackUnlimited:YES];
    }
  else
    {
      // set length to value of textfield in UserDefaults
      [defs setScrollBackUnlimited:NO];
      [defs setScrollBackLines:[bufferLengthField intValue]];
    }
  
  [self setBufferEnabled:bufferEnabledBtn];

  if ([scrollBottomBtn state] == NSOffState)
    [defs setScrollBottomOnInput:NO];
  else
    [defs setScrollBottomOnInput:YES];

  [defs synchronize];
}
// Reset onscreen controls to values stored in UserDefaults
- (void)showDefault:(id)sender
{
  Defaults *defs = [[Preferences shared] mainWindowPreferences];
  
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
  Defaults *defs = [[Preferences shared] mainWindowLivePreferences];
  
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
// Set values set to visible window
- (void)setWindow:(id)sender
{
  Defaults     *prefs;
  NSDictionary *uInfo;
  NSUInteger   sbLines;

  if (![sender isKindOfClass:[NSButton class]]) return;

  prefs = [[Defaults alloc] initEmpty];

  [prefs
    setScrollBottomOnInput:([scrollBottomBtn state] == NSOffState) ? NO : YES];
  
  if ([bufferEnabledBtn state] == NSOffState)
    {
      [prefs setScrollBackEnabled:NO];
    }
  else
    {
      [prefs setScrollBackEnabled:YES];
      
      if ([bufferLengthMatrix selectedColumn] == 0)
        sbLines = INT_MAX;
      else
        sbLines = [bufferLengthField integerValue];

      [prefs setScrollBackLines:sbLines];
    }

  uInfo = [NSDictionary dictionaryWithObject:prefs forKey:@"Preferences"];
  [prefs release];
  
  [[NSNotificationCenter defaultCenter]
    postNotificationName:TerminalPreferencesDidChangeNotification
                  object:[NSApp mainWindow]
                userInfo:uInfo];
}

@end
