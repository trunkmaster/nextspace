/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Copyright (C) 2018 Sergii Stoian
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free
// Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
//

#import "DockPrefs.h"
#import <DesktopKit/NXTDefaults.h>
#import <Workspace+WM.h>

@implementation DockPrefsAppicon
- (void)setCursor:(NSCursor *)c
{
  _cursor = c;
}
// NSView override
- (void)resetCursorRects
{
  if (!_cursor)
    _cursor = [NSCursor arrowCursor];

  [[self superview] addCursorRect:[self frame] cursor:_cursor];
}
@end

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
  [iconBtn setRefusesFirstResponder:YES];
  [iconBtn setButtonType:NSMomentaryLightButton];
  [iconBtn setCursor:[NSCursor pointingHandCursor]];

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
  [appLockedBtn setRefusesFirstResponder:YES];

  [[NSNotificationCenter defaultCenter] addObserver:appList
                                           selector:@selector(reloadData)
                                               name:@"WMDockContentDidChange"
                                             object:nil];
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
  return WMDockAppsCount();
}

- (id)           tableView:(NSTableView *)tv
 objectValueForTableColumn:(NSTableColumn *)tc
                       row:(int)row
{
  NSString *appName = WMDockAppName(row);

  
  if (tc == [appList tableColumnWithIdentifier:@"autostart"])
    {
      if (WMIsDockAppAutolaunch(row))
        return [NSImage imageNamed:@"CheckMark"];
      else
        return nil;
    }
  else
    {
      if ([[appName pathExtension] isEqualToString:@"GNUstep"])
        appName = [appName stringByDeletingPathExtension];
      else
        appName = [appName pathExtension];
      
      if ([appName isEqualToString:@"Workspace"] ||
          [appName isEqualToString:@"Recycler"])
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
  NSString     *appName = WMDockAppName(selRow);

  if ([[appName pathExtension] isEqualToString:@"GNUstep"])
    appName = [appName stringByDeletingPathExtension];
  else
    appName = [appName pathExtension];
  
  [nameField setStringValue:appName];
  [autostartBtn setEnabled:YES];
 
  if ([appName isEqualToString:@"Workspace"]) {
    [iconBtn setImage:[NSApp applicationIconImage]];
    [pathField setStringValue:@""];
  }
  else {
    [iconBtn setImage:WMDockAppImage(selRow)];
    [pathField setStringValue:WMDockAppCommand(selRow)];
  }
  [autostartBtn
      setState:WMIsDockAppAutolaunch(selRow) ? NSOnState : NSOffState];
  
  if ([appPanel isVisible]) {
    [self appSettingsPanelUpdate];
  }
}

- (BOOL)tableView:(NSTableView *)tv
  shouldSelectRow:(NSInteger)row
{
  NSString *value = WMDockAppName(row);

  if (!value || [value isEqualToString:@".NoApplication"] ||
      [value isEqualToString:@"Recycler.GNUstep"])
    return NO;

  return YES;
}

- (void)appListDoubleClicked:(id)sender
{
  WMSetDockAppAutolaunch([appList selectedRow], ![autostartBtn state]);
  
  [autostartBtn setState:![autostartBtn state]];
  [appList reloadData];
}

// --- Button

- (void)setAppAutostarted:(id)sender
{
  WMSetDockAppAutolaunch([appList selectedRow], [autostartBtn state]);
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
  NSString  *appName = WMDockAppName(selRow);

  [appNameField setStringValue:appName];
  [appIconView setImage:WMDockAppImage(selRow)];
  [appCommandField setStringValue:WMDockAppCommand(selRow)];
  [appLockedBtn setState:WMIsDockAppLocked(selRow)];
  
  if ([appName isEqualToString:@"Workspace.GNUstep"] ||
      [appName isEqualToString:@"Recycler.GNUstep"])
    {
      [appCommandField setEnabled:NO];
      [appCommandField setStringValue:@"NEXTSPACE internal"];
      [appLockedBtn setEnabled:NO];
    }

  if ([[appName pathExtension] isEqualToString:@"GNUstep"])
    {
      [appMiddleClickField setEnabled:NO];
      [appDndCommandField setEnabled:NO];
      [appMiddleClickField setStringValue:@""];
      [appDndCommandField setStringValue:@""];
    }
  else
    {
      [appLockedBtn setEnabled:YES];
      [appCommandField setEnabled:YES];
      [appMiddleClickField setEnabled:YES];
      [appDndCommandField setEnabled:YES];
      [appMiddleClickField setStringValue:WMDockAppPasteCommand(selRow)];
      [appDndCommandField setStringValue:WMDockAppDndCommand(selRow)];
    }  
}

- (void)showAppSettingsPanel:(id)sender
{
  NSString  *appName = WMDockAppName([appList selectedRow]);

  if (!appName ||
      [appName isEqualToString:@"Workspace.GNUstep"] ||
      [appName isEqualToString:@"Recycler.GNUstep"])
    return;
  
  [self appSettingsPanelUpdate];
  
  // [appPanel makeKeyAndOrderFront:[iconBtn window]];
  [appPanel orderFront:[iconBtn window]];
  [appPanel makeFirstResponder:appCommandField];
}

- (void)setAppIcon:(id)sender
{
  NSInteger      selRow = [appList selectedRow];
  NSInteger      result;
  NSOpenPanel    *openPanel;
  NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];

  openPanel = [NSOpenPanel openPanel];
  [openPanel setAllowsMultipleSelection:NO];
  
  result = [openPanel runModalForDirectory:[defs objectForKey:@"OpenDir"]
                                      file:nil
                                     types:[NSImage imageFileTypes]];
  if (result == NSOKButton) {
    [defs setObject:[openPanel directory] forKey:@"OpenDir"];
    WMSetDockAppImage([[openPanel filenames] lastObject], selRow, YES);
    [appIconView setImage:WMDockAppImage(selRow)];
    [iconBtn setImage:WMDockAppImage(selRow)];
  }  
}

- (void)setAppLocked:(id)sender
{
  WMSetDockAppLocked([appList selectedRow], [sender state]);
}

- (void)setAppCommand:(id)sender
{
  WMSetDockAppCommand([appList selectedRow],
                       [[sender stringValue] cString]);
}

- (void)setAppPasteCommand:(id)sender
{
  WMSetDockAppPasteCommand([appList selectedRow],
                            [[sender stringValue] cString]);
}

- (void)setAppDndCommand:(id)sender
{
  WMSetDockAppDndCommand([appList selectedRow],
                          [[sender stringValue] cString]);
}

// NSWindow delegate method
- (void)windowWillClose:(NSNotification *)notif
{
  // if ([notif object] != appPanel)
  //   return;
  [[box window] makeKeyAndOrderFront:self];
}

@end
