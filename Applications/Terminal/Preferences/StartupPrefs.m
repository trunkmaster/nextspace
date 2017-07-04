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

- (void)showWindow
{
  Defaults *defs = [[Preferences shared] mainWindowLivePreferences];

  [actionsMatrix selectCellWithTag:[defs startupAction]];
  [autolaunchBtn setState:[defs hideOnAutolaunch]];
  [filePathField setStringValue:[defs startupFile]];
}

- (void)setAction:(id)sender
{
  Defaults *defs = [Defaults shared];
  
  [defs setInteger:[[actionsMatrix selectedCell] tag]
            forKey:StartupActionKey];
  [defs synchronize];
}
- (void)setFilePath:(id)sender
{
  Defaults *defs = [[Preferences shared] mainWindowLivePreferences];
  
  [defs setStartupFile:[filePathField stringValue]];
  [defs synchronize];
}
- (void)setAutolaunch:(id)sender
{
  Defaults *defs = [[Preferences shared] mainWindowLivePreferences];
  
  [defs setHideOnAutolaunch:[autolaunchBtn state]];
  [defs synchronize];
}

@end
