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
}

- (NSString *)moduleName
{
  return _(@"Docked Applications");
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
- (void)appListClicked:(id)sender
{
}

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
      if ([[dockItem objectForKey:@"AutoLaunch"] isEqualToString:@"Yes"])
        {
          return [NSImage imageNamed:@"commonSwitchOn"];
        }
      else
        {
          return [NSImage imageNamed:@"commonSwitchOff"];
        }
    }
  else
    {
      return [dockItem objectForKey:@"Name"];
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
  NSTableView *tv = [aNotification object];

  NSLog(@"Selection Did Change: %@", [tv className]);
  
  // if (tv == layoutList)
  //   {
  //     NSInteger selRow = [tv selectedRow];
  
  //     [layoutRemoveBtn setEnabled:[tv numberOfRows] > 1 ? YES : NO];
  //     [layoutUpBtn setEnabled:(selRow == 0) ? NO : YES];
  //     [layoutDownBtn setEnabled:(selRow == [tv numberOfRows]-1) ? NO : YES];
  //   }
}

// --- Button

- (void)revert:sender
{
//   [sender setEnabled:NO];
//   [[NXDefaults userDefaults] removeObjectForKey:BrowserViewerColumnWidth];
//   [[NSNotificationCenter defaultCenter]
//     postNotificationName:BrowserViewerColumnWidthDidChangeNotification
// 		  object:self];

//   [self setupArrows];
}

@end
