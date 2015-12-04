/* All Rights reserved */

#include "StartupPrefs.h"

@implementation StartupPrefs

// <PrefsModule>
+ (NSString *)name
{
  return @"Startup";
}

- init
{
  self = [super init];

  [NSBundle loadNibNamed:@"Startup" owner:self];

  return self;
}

- (void)awakeFromNib
{
  [actionsMatrix setRefusesFirstResponder:YES];
  [[actionsMatrix cellWithTag:1] setRefusesFirstResponder:YES];
  [[actionsMatrix cellWithTag:2] setRefusesFirstResponder:YES];
  [[actionsMatrix cellWithTag:3] setRefusesFirstResponder:YES];

  [view retain];
}

// <PrefsModule>
- (NSView *)view
{
  return view;
}

- (void)showDefault:(id)sender
{
  [actionsMatrix selectCellWithTag:[Defaults startupAction]];
  [autolaunchBtn setState:[Defaults hideOnAutolaunch]];
}

- (void)setAction:(id)sender
{
  [ud setInteger:[[actionsMatrix selectedCell] tag]
          forKey:StartupActionKey];
  [ud synchronize];
}
- (void)setFilePath:(id)sender
{
  [ud setObject:[filePathField stringValue] forKey:StartupFileKey];
  [ud synchronize]; 
}
- (void)setAutolaunch:(id)sender
{
  [ud setBool:[autolaunchBtn state] forKey:HideOnAutolaunchKey];
  [ud synchronize];  
}

@end
