/*
   "Workspaces" preferences.
   Manipulates with options of on-screen Workspaces and saves its state.

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

#import "WorkspacesPrefs.h"
#import <NXFoundation/NXDefaults.h>
#import <Workspace+WindowMaker.h>
#import <Controller.h>

@implementation WorkspacesPrefs

- (void)dealloc
{
  NSDebugLLog(@"WorkspacesPrefs", @"WorkspacesPrefs: dealloc");

  [box release];
  [wsButtons release];
  [wmStateWorkspaces release];
  
  [super dealloc];
}

- (void)awakeFromNib
{
  NSUInteger wsCount;
  NSButton   *button;
  
  // get the box and destroy the bogus window
  [box retain];
  [box removeFromSuperview];

  [showInDockBtn setRefusesFirstResponder:YES];
  [showInDockBtn
    setState:[[NXDefaults userDefaults] boolForKey:@"ShowWorkspaceInDock"]];

  wsButtons = [[NSMutableArray alloc]
                initWithObjects:ws1,ws2,ws3,ws4,ws5,ws6,ws7,ws8,ws9,ws10,nil];

  wmStateWorkspaces = [[NSMutableArray alloc]
                        initWithArray:[WWMDockState() objectForKey:@"Workspaces"]];
  wsCount = [wmStateWorkspaces count];
  for (int i = 9; i >= 0; i--) {
    button = [wsButtons objectAtIndex:i];
    if (i < wsCount) {
      [button release];
    }
    else {
      [button removeFromSuperview];
      [wsButtons removeObjectAtIndex:i];
    }
  }

  DESTROY(window);
}

- (NSString *)moduleName
{
  return _(@"Workspaces");
}

- (NSView *)view
{
  if (box == nil)
    {
      [NSBundle loadNibNamed:@"WorkspacesPrefs" owner:self];
    }

  return box;
}

//
// Table delegate methods
//
- (int)numberOfRowsInTableView:(NSTableView *)tv
{
  return 0;
}

- (id)           tableView:(NSTableView *)tv
 objectValueForTableColumn:(NSTableColumn *)tc
                       row:(int)row
{
  // NSString *appName = WWMWorkspacesAppName(row);
  
  // if (tc == [appList tableColumnWithIdentifier:@"autostart"])
  //   {
  //     if (WWMIsWorkspacesAppAutolaunch(row) ||
  //         [appName isEqualToString:@"Workspace.GNUstep"] ||
  //         [appName isEqualToString:@"Recycler.GNUstep"])
  //       return [NSImage imageNamed:@"CheckMark"];
  //     else
  //       return nil;

  //     if ([appName isEqualToString:@"Workspace.GNUstep"] ||
  //         [appName isEqualToString:@"Recycler.GNUstep"])
  //       [[tc dataCellForRow:row] setEnabled:NO];
  //   }
  // else
  //   {
  //     if ([[appName pathExtension] isEqualToString:@"GNUstep"])
  //       appName = [appName stringByDeletingPathExtension];
  //     else
  //       appName = [appName pathExtension];
      
  //     if ([appName isEqualToString:@"Workspace"] ||
  //         [appName isEqualToString:@"Recycler"])
  //       {
  //         [[tc dataCellForRow:row] setEnabled:NO];
  //       }
  //     else
  //       {
  //         [[tc dataCellForRow:row] setEnabled:YES];
  //       }
      
  //     return appName;
  //   }
  return nil;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
  // NSTableView  *tv = [aNotification object];
  // NSInteger    selRow = [tv selectedRow];
  // NSString     *appName = WWMWorkspacesAppName(selRow);

  // if ([[appName pathExtension] isEqualToString:@"GNUstep"])
  //   appName = [appName stringByDeletingPathExtension];
  // else
  //   appName = [appName pathExtension];
  
  // [nameField setStringValue:appName];
 
  // if ([appName isEqualToString:@"Workspace"])
  //   {
  //     [autostartBtn setEnabled:NO];
      
  //     [iconBtn setImage:[NSApp applicationIconImage]];
  //     [pathField setStringValue:@""];
  //     [autostartBtn setState:NSOnState];
  //     [autostartBtn setState:NSOnState];
  //   }
  // else
  //   {
  //     [autostartBtn setEnabled:YES];
      
  //     [iconBtn setImage:WWMWorkspacesAppImage(selRow)];
  //     [pathField setStringValue:WWMWorkspacesAppCommand(selRow)];
  //     [autostartBtn
  //       setState:WWMIsWorkspacesAppAutolaunch(selRow) ? NSOnState : NSOffState];
  //   }

  // if ([appPanel isVisible])
  //   [self appSettingsPanelUpdate];
}

- (BOOL)tableView:(NSTableView *)tv
  shouldSelectRow:(NSInteger)row
{
  // NSString *value = WWMWorkspacesAppName(row);

  // if (!value || [value isEqualToString:@".NoApplication"])
  //   return NO;

  return YES;
}

- (void)appListDoubleClicked:(id)sender
{
  // WWMSetWorkspacesAppAutolaunch([appList selectedRow], ![autostartBtn state]);
  
  // [autostartBtn setState:![autostartBtn state]];
  // [appList reloadData];
}

// --- Actions

- (void)setShowInDock:(id)sender
{
  [[NXDefaults userDefaults] setBool:[sender state] ? YES : NO
                              forKey:@"ShowWorkspaceInDock"];
  [[NSApp delegate] updateWorkspaceBadge];
}

- (void)selectWorkspace:(id)sender
{
  // NSLog(@"selectWorkspace: sender == %@ (%@) buttons # %lu", [sender className], sender, [wsButtons count]);
  for (NSButton *button in wsButtons) {
    // NSLog(@"selectWorkspace: process %@", [button title]);
    [button setState:(sender == button) ? NSOnState : NSOffState];
    if ([sender isEqualTo:button] != NO) {
      NSLog(@"Clicked WS button: %@", [button title]);
      [nameField setStringValue:[[wmStateWorkspaces objectAtIndex:[wsButtons indexOfObject:button]] objectForKey:@"Name"]];
      selectedWorkspace = button;
    }
  }
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
  id object = [aNotification object];

  NSLog(@"Text changed in %@", [object className]);
  if (object != nameField)
    return;
}

- (void)revert:sender
{
  // NSInteger selRow = [appList selectedRow];
  
  // [appList reloadData];

  // if (selRow > [appList numberOfRows]-1)
  //   [appList selectRow:0 byExtendingSelection:NO];
  // else
  //   [appList selectRow:selRow byExtendingSelection:NO];
}

@end
