/*
  Copyright (c) 2024-present Sergii Stoian <stoyan255@gmail.com>

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import "ActivityPrefs.h"

@implementation ActivityPrefs

#pragma mark - PrefsModule protocol

+ (NSString *)name
{
  return @"Activity Monitor";
}

- (NSView *)view
{
  return view;
}

// Show preferences of main window
- (void)showWindow
{
  Defaults *defaults = [[Preferences shared] mainWindowPreferences];

  [activityMonitorButton setState:[defaults isActivityMonitorEnabled]];
  [backgroundProcessesButton setState:[defaults isBackgroundProcessesClean]];
}

#pragma mark - ActivityPrefs

- init
{
  self = [super init];

  if ([NSBundle loadNibNamed:@"ActivityMonitor" owner:self] == NO) {
    NSLog(@"Failed to load ActivityMonitor NIB.");
  }

  return self;
}

- (void)awakeFromNib
{
  [view retain];
  [view removeFromSuperview];
  [window release];

  [cleanCommandsList loadColumnZero];
  [cleanCommandsList setHasHorizontalScroller:NO];
  [cleanCommandField setStringValue:@""];
}

- (IBAction)addCleanCommand:(id)sender
{
  Defaults *defaults = [[Preferences shared] mainWindowPreferences];
  NSMutableArray *commandsList = [[defaults cleanCommands] mutableCopy];

  [commandsList addObject:[cleanCommandField stringValue]];
  [defaults setCleanCommands:commandsList];
  [defaults synchronize];

  [commandsList release];
  [cleanCommandField setStringValue:@""];
  [cleanCommandsList reloadColumn:0];
}

- (IBAction)removeCleanCommand:(id)sender
{
  Defaults *defaults = [[Preferences shared] mainWindowPreferences];
  NSMutableArray *commandsList = [[defaults cleanCommands] mutableCopy];

  [commandsList removeObject:[[cleanCommandsList selectedCell] stringValue]];
  [defaults setCleanCommands:commandsList];
  [defaults synchronize];

  [commandsList release];
  [cleanCommandsList reloadColumn:0];
}

- (IBAction)setActivityMonitor:(id)sender
{
  Defaults *defaults = [[Preferences shared] mainWindowPreferences];
  [defaults setIsActivityMonitorEnabled:[activityMonitorButton state] ? YES : NO];
  [defaults synchronize];
}

- (IBAction)setBackgroundProcesses:(id)sender
{
  Defaults *defaults = [[Preferences shared] mainWindowPreferences];
  [defaults setIsBackgroundProcessesClean:[backgroundProcessesButton state] ? YES : NO];
  [defaults synchronize];
}

@end

@implementation ActivityPrefs (BrowserDelegate)

- (NSString *)browser:(NSBrowser *)sender titleOfColumn:(NSInteger)column
{
  return @"\"Clean\" Commands";
}

- (NSInteger)browser:(NSBrowser *)sender numberOfRowsInColumn:(NSInteger)column
{
  Defaults *defaults = [[Preferences shared] mainWindowPreferences];
  NSArray *commandsList = [defaults cleanCommands];

  return [[defaults cleanCommands] count];
}

- (void)browser:(NSBrowser *)sender
    willDisplayCell:(id)cell
              atRow:(NSInteger)row
             column:(NSInteger)column
{
  Defaults *defaults = [[Preferences shared] mainWindowPreferences];
  NSString *command = [[defaults cleanCommands] objectAtIndex:row];

  if (command) {
    [cell setTitle:command];
    [cell setRefusesFirstResponder:YES];
    [cell setLeaf:YES];
  }
}

@end