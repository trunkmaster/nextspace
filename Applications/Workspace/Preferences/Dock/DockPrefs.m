/*
   "Dock" preferences.

   Copyright (C) 2018 Sergii Stoian

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPXSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import "DockPrefs.h"
#import <NXFoundation/NXDefaults.h>
#import <Workspace+WindowMaker.h>

@implementation DockPrefs

- (void)dealloc
{
  NSDebugLLog(@"DockPrefs", @"DockPrefs: dealloc");

  TEST_RELEASE(box);

  [super dealloc];
}

- (void)awakeFromNib
{
  // get the box and destroy the bogus window
  [box retain];
  [box removeFromSuperview];
  DESTROY(window);

  [showOnHiddenDockBtn setRefusesFirstResponder:YES];
  [autostartBtn setRefusesFirstResponder:YES];
  [lockedBtn setRefusesFirstResponder:YES];
  [appiconBtn setRefusesFirstResponder:YES];

  [appList setHeaderView:nil];
  [appList setDelegate:self];
  [appList setDataSource:self];
  [appList deselectAll:self];
  [appList setTarget:self];
  [appList setAction:@selector(appListClicked:)];

  [appList reloadData];
  [appList selectRow:0 byExtendingSelection:NO];
}

- (NSString *)moduleName
{
  return _(@"Dock");
}

- (NSView *)view
{
  if (box == nil)
    {
      [NSBundle loadNibNamed:@"DockPrefs" owner:self];
    }

  return box;
}

//
// Table delegate methods
//
- (int)numberOfRowsInTableView:(NSTableView *)tv
{
  if (!dockState)
    dockState = WWMStateDockAppsLoad();
  
  return [dockState count];
}

- (id)           tableView:(NSTableView *)tv
 objectValueForTableColumn:(NSTableColumn *)tc
                       row:(int)row
{
  NSDictionary *dockItem = [dockState objectAtIndex:row];
  
  if (tc == [appList tableColumnWithIdentifier:@"autostart"])
    {
      if ([[dockItem objectForKey:@"AutoLaunch"] isEqualToString:@"Yes"] ||
          [[dockItem objectForKey:@"Name"] isEqualToString:@"Workspace.GNUstep"])
        return [NSImage imageNamed:@"CheckMark"];
      else
        return nil;
    }
  else
    {
      NSString *appName = [dockItem objectForKey:@"Name"];

      if ([[appName pathExtension] isEqualToString:@"GNUstep"])
        appName = [appName stringByDeletingPathExtension];
      else
        appName = [appName pathExtension];
      
      if ([appName isEqualToString:@"Workspace"])
        {
          [[tc dataCellForRow:row] setEnabled:NO];
        }
      else
        {
          [[tc dataCellForRow:row] setEnabled:YES];
        }
      
      return appName;
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
  NSTableView  *tv = [aNotification object];
  NSInteger    selRow = [tv selectedRow];
  NSDictionary *dockItem = [dockState objectAtIndex:selRow];
  NSString     *appName = [dockItem objectForKey:@"Name"];

  if ([[appName pathExtension] isEqualToString:@"GNUstep"])
    appName = [appName stringByDeletingPathExtension];
  else
    appName = [appName pathExtension];
  
  [appNameField setStringValue:appName];
 
  if ([appName isEqualToString:@"Workspace"])
    {
      [appiconBtn setImage:[NSApp applicationIconImage]];
      [appPathField setStringValue:@"/usr/NextSpace/Apps/Workspace.app"];
      [autostartBtn setState:NSOnState];
      [lockedBtn setState:NSOnState];
    }
  else
    {
      [appiconBtn setImage:WWMImageForDockedApp(selRow)];
      [appPathField setStringValue:[dockItem objectForKey:@"Command"]];
      [autostartBtn
        setState:([[dockItem objectForKey:@"AutoLaunch"] isEqualToString:@"Yes"]) ? NSOnState : NSOffState];
      [lockedBtn
        setState:([[dockItem objectForKey:@"Lock"] isEqualToString:@"Yes"]) ? NSOnState : NSOffState];
    }
}

// --- Button

- (void)revert:sender
{
  NSInteger selRow = [appList selectedRow];
  
  [appList reloadData];

  if (selRow > [appList numberOfRows]-1)
    [appList selectRow:0 byExtendingSelection:NO];
  else
    [appList selectRow:selRow byExtendingSelection:NO];
}

@end
