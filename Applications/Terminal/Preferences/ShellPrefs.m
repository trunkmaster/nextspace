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

- (void)showDefault:(id)sender
{
  [shellField setStringValue:[Defaults shell]];
  [loginShellBtn setState:[Defaults loginShell]];
}

- (BOOL)       control:(NSControl *)control
  textShouldEndEditing:(NSText *)fieldEditor
{
  [ud setObject:[control stringValue] forKey:ShellKey];
  [Defaults readShellDefaults];
  return YES;
}
- (void)setLoginShell:(id)sender
{
  [ud setBool:[loginShellBtn state] forKey:LoginShellKey];
  [Defaults readShellDefaults];
}

@end
