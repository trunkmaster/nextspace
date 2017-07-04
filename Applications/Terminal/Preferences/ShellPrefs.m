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
}

// <PrefsModule>
- (NSView *)view
{
  return view;
}

- (void)showWindow
{
  Defaults *defs = [[Preferences shared] mainWindowLivePreferences];

  [shellField setStringValue:[defs shell]];
  [loginShellBtn setState:[defs loginShell]];
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
