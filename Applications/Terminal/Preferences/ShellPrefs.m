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
  // prefs = [[Preferences shared] mainWindowPreferences];
}

- (BOOL)       control:(NSControl *)control
  textShouldEndEditing:(NSText *)fieldEditor
{
  Defaults *defs = [Defaults shared];
  
  [defs setObject:[control stringValue] forKey:ShellKey];
  return YES;
}
- (void)setLoginShell:(id)sender
{
  Defaults *defs = [Defaults shared];
  
  [defs setBool:[loginShellBtn state] forKey:LoginShellKey];
}

@end
