/*
   "Dock" preferences.
   Manipulates with options of on-screen Dock and saves its state.

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
  [iconBtn setRefusesFirstResponder:YES];
  [iconBtn setButtonType:NSMomentaryLightButton];

  [appList setHeaderView:nil];
  [appList setDelegate:self];
  [appList setDataSource:self];
  [appList deselectAll:self];
  [appList setTarget:self];
  [appList setDoubleAction:@selector(appListDoubleClicked:)];
  [appList setRefusesFirstResponder:YES];

  [appList reloadData];
  [appList selectRow:0 byExtendingSelection:NO];

  [appIconBtn setRefusesFirstResponder:YES];

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
  return WWMDockAppsCount();
}

- (id)           tableView:(NSTableView *)tv
 objectValueForTableColumn:(NSTableColumn *)tc
                       row:(int)row
{
  NSString *appName = WWMDockAppName(row);

  
  if (tc == [appList tableColumnWithIdentifier:@"autostart"])
    {
      if (WWMIsDockAppAutolaunch(row) ||
          [appName isEqualToString:@"Workspace.GNUstep"])
        return [NSImage imageNamed:@"CheckMark"];
      else
        return nil;

      if ([appName isEqualToString:@"Workspace.GNUstep"])
        [[tc dataCellForRow:row] setEnabled:NO];
    }
  else
    {
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
  NSString     *appName = WWMDockAppName(selRow);

  if ([[appName pathExtension] isEqualToString:@"GNUstep"])
    appName = [appName stringByDeletingPathExtension];
  else
    appName = [appName pathExtension];
  
  [nameField setStringValue:appName];
 
  if ([appName isEqualToString:@"Workspace"])
    {
      [autostartBtn setEnabled:NO];
      [lockedBtn setEnabled:NO];
      
      [iconBtn setImage:[NSApp applicationIconImage]];
      [pathField setStringValue:@""];
      [autostartBtn setState:NSOnState];
      [autostartBtn setState:NSOnState];
      [lockedBtn setState:NSOnState];
    }
  else
    {
      [autostartBtn setEnabled:YES];
      [lockedBtn setEnabled:YES];
      
      [iconBtn setImage:WWMDockAppImage(selRow)];
      [pathField setStringValue:WWMDockAppCommand(selRow)];
      [autostartBtn
        setState:WWMIsDockAppAutolaunch(selRow) ? NSOnState : NSOffState];
      [lockedBtn
        setState:WWMIsDockAppLocked(selRow) ? NSOnState : NSOffState];
    }

  if ([appPanel isVisible])
    [self appSettingsPanelUpdate];
}

- (BOOL)tableView:(NSTableView *)tv
  shouldSelectRow:(NSInteger)row
{
  NSString *value = WWMDockAppName(row);

  if (!value || [value isEqualToString:@".NoApplication"])
    return NO;

  return YES;
}

- (void)appListDoubleClicked:(id)sender
{
  WWMSetDockAppAutolaunch([appList selectedRow], ![autostartBtn state]);
  
  [autostartBtn setState:![autostartBtn state]];
  [appList reloadData];
}

// --- Button

- (void)setAppAutostarted:(id)sender
{
  WWMSetDockAppAutolaunch([appList selectedRow], [autostartBtn state]);
  [appList reloadData];
}

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

@implementation DockPrefs (AppSettings)

- (void)appSettingsPanelUpdate
{
  NSInteger selRow = [appList selectedRow];
  NSString  *appName = WWMDockAppName(selRow);

  if ([[appName pathExtension] isEqualToString:@"GNUstep"])
    {
      [appMiddleClickField setEnabled:NO];
      [appDndCommandField setEnabled:NO];
    }
  else
    {
      [appMiddleClickField setEnabled:YES];
      [appDndCommandField setEnabled:YES];
    }
  
  [appNameField setStringValue:appName];
  [appIconBtn setImage:WWMDockAppImage(selRow)];
  [appCommandField setStringValue:WWMDockAppCommand(selRow)];
}

- (void)showAppSettingsPanel:(id)sender
{
  NSString  *appName = WWMDockAppName([appList selectedRow]);

  if (!appName ||
      [appName isEqualToString:@"Workspace.GNUstep"] ||
      [appName isEqualToString:@"Recycler.GNUstep"])
    return;
  
  [self appSettingsPanelUpdate];
  
  [appPanel makeKeyAndOrderFront:[iconBtn window]];
  [appPanel makeFirstResponder:appCommandField];
}

- (void)setAppLocked:(id)sender
{
  WWMSetDockAppLocked([appList selectedRow], [lockedBtn state]);
}

- (void)setAppCommand:(id)sender
{
}

- (void)setAppMiddleClick:(id)sender
{
}

- (void)setDndCommand:(id)sender
{
}

@end
