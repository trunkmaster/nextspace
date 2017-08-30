/* All Rights reserved */

#include "ShellPrefs.h"

@implementation ShellPrefs

// <PrefsModule>
+ (NSString *)name
{
  return @"Shell";
}

- init
{
  self = [super init];

  [NSBundle loadNibNamed:@"Shell" owner:self];

  return self;
}

- (void)awakeFromNib
{
  [view retain];

  // Fill in Shell popup button with items from /etc/shells
  // Omit 'nologin' as shell.
  NSString  *shells = [NSString stringWithContentsOfFile:@"/etc/shells"];
  NSString  *lString;
  NSRange   lRange;
  NSUInteger index, stringLength = [shells length];

  [shellPopup removeAllItems];
  for (index=0; index < stringLength;)
    {
      lRange = [shells lineRangeForRange:NSMakeRange(index, 0)];
      lRange.length -= 1; // Do not include new line char
      lString = [shells substringFromRange:lRange];
      [shellPopup addItemWithTitle:lString];
      index = lRange.location + lRange.length + 1;
    }
  [shellPopup addItemWithTitle:@"Arbitrary Command"];
}

// <PrefsModule>
- (NSView *)view
{
  return view;
}

- (void)showWindow
{
  Defaults  *defs = [[Preferences shared] mainWindowPreferences];
  NSString  *shellStr = [defs shell];
  NSInteger shellIndex;

  shellIndex = [shellPopup indexOfItemWithTitle:shellStr];
  if (shellIndex == -1)
    {
      [shellPopup selectItemWithTitle:@"Arbitrary Command"];
      [loginShellBtn setEnabled:NO];
      
      [commandLabel setEnabled:YES];
      [commandField setEnabled:YES];
      [commandField setStringValue:shellStr];
    }
  else
    {
      [shellPopup selectItemWithTitle:shellStr];
      [loginShellBtn setEnabled:YES];
      [loginShellBtn setState:[defs loginShell]];
      
      [commandLabel setEnabled:NO];
      [commandField setEnabled:NO];
      [commandField setStringValue:@""];      
    }
}

- (BOOL)       control:(NSControl *)control
  textShouldEndEditing:(NSText *)fieldEditor
{
  Defaults *defs = [[Preferences shared] mainWindowLivePreferences];
  
  [defs setShell:[control stringValue]];
  return YES;
}
- (void)setLoginShell:(id)sender
{
  Defaults *defs = [[Preferences shared] mainWindowLivePreferences];
  
  [defs setLoginShell:[loginShellBtn state]];
}

@end
