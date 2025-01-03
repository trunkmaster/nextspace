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
#import <SystemKit/OSEDefaults.h>
#import "Processes/ProcessManager.h"
#import <Workspace+WM.h>
#import <WMNotificationCenter.h>

#include <core/string_utils.h>
#include <core/wuserdefaults.h>
#include <screen.h>
#include <dock.h>

// --- Appicons getters/setters of on-screen Dock

NSInteger WMDockAppsCount(void)
{
  WScreen *scr = wDefaultScreen();
  WDock *dock = scr->dock;

  if (!dock)
    return 0;
  else
    return dock->max_icons;
  // return dock->icon_count;
}
NSString *WMDockAppName(int position)
{
  WAppIcon *appicon = wDockAppiconAtSlot(wDefaultScreen()->dock, position);

  if (appicon) {
    return [NSString stringWithFormat:@"%s.%s", appicon->wm_instance, appicon->wm_class];
  } else {
    return @".NoApplication";
  }
}
NSImage *WMDockAppImage(int position)
{
  WAppIcon *btn = wDockAppiconAtSlot(wDefaultScreen()->dock, position);
  NSString *iconPath;
  NSString *appName;
  NSDictionary *appDesc;
  NSImage *icon = nil;

  if (btn) {
    // NSDebugLLog(@"Preferences", @"W+W: icon image file: %s", btn->icon->file);
    if (btn->icon->file) {  // Docked and not running application
      iconPath = [NSString stringWithCString:btn->icon->file];
      icon = [[NSImage alloc] initWithContentsOfFile:iconPath];
      [icon autorelease];
    } else {
      if (!strcmp(btn->wm_class, "GNUstep")) {
        appName = [NSString stringWithCString:btn->wm_instance];
      } else {
        appName = [NSString stringWithCString:btn->wm_class];
      }

      appDesc = [[ProcessManager shared] _applicationWithName:appName];

      if (!strcmp(btn->wm_class, "GNUstep")) {
        icon = [[NSApp delegate] iconForFile:[appDesc objectForKey:@"NSApplicationPath"]];
      } else {
        icon = [appDesc objectForKey:@"NSApplicationIcon"];
      }
    }
    if (!icon) {
      icon = [NSImage imageNamed:@"NXUnknownApplication"];
    }
  }

  return icon;
}
// void WMSetDockAppImage(NSString *path, int position, BOOL save) {...} -> Workspace+WM
void WMSetDockAppImage(NSString *path, int position, BOOL save)
{
  WAppIcon *btn;
  RImage *rimage;

  btn = wDockAppiconAtSlot(wDefaultScreen()->dock, position);
  if (!btn) {
    return;
  }

  if (btn->icon->file) {
    wfree(btn->icon->file);
  }
  btn->icon->file = wstrdup([path cString]);

  rimage = WSLoadRasterImage(btn->icon->file);
  if (!rimage) {
    return;
  }

  if (btn->icon->file_image) {
    RReleaseImage(btn->icon->file_image);
    btn->icon->file_image = NULL;
  }
  btn->icon->file_image = RRetainImage(rimage);

  // Write to WM's 'WMWindowAttributes' file
  if (save == YES) {
    CFMutableDictionaryRef winAttrs, appAttrs;
    CFStringRef appKey, iconFile;

    winAttrs = w_global.domain.window_attrs->dictionary;

    appKey = CFStringCreateWithFormat(kCFAllocatorDefault, 0, CFSTR("%s.%s"), btn->wm_instance,
                                      btn->wm_class);
    appAttrs = (CFMutableDictionaryRef)CFDictionaryGetValue(winAttrs, appKey);
    if (!appAttrs) {
      appAttrs = CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks,
                                           &kCFTypeDictionaryValueCallBacks);
    }
    iconFile =
        CFStringCreateWithCString(kCFAllocatorDefault, btn->icon->file, kCFStringEncodingUTF8);
    CFDictionarySetValue(appAttrs, CFSTR("Icon"), iconFile);
    CFRelease(iconFile);
    CFDictionarySetValue(appAttrs, CFSTR("AlwaysUserIcon"), CFSTR("YES"));

    if (position == 0) {
      CFDictionarySetValue(winAttrs, CFSTR("Logo.WMDock"), appAttrs);
      CFDictionarySetValue(winAttrs, CFSTR("Logo.WMPanel"), appAttrs);
    }

    CFDictionarySetValue(winAttrs, appKey, appAttrs);
    CFRelease(appKey);
    CFRelease(appAttrs);
    WMUserDefaultsWrite(winAttrs, CFSTR("WMWindowAttributes"));
  }

  wIconUpdate(btn->icon);
}
// BOOL WMIsDockAppAutolaunch(int position) {...} -> Workspace+WM
BOOL WMIsDockAppAutolaunch(int position)
{
  WAppIcon *appicon = wDockAppiconAtSlot(wDefaultScreen()->dock, position);

  if (!appicon || appicon->flags.auto_launch == 0) {
    return NO;
  } else {
    return YES;
  }
}
void WMSetDockAppAutolaunch(int position, BOOL autolaunch)
{
  WAppIcon *appicon = wDockAppiconAtSlot(wDefaultScreen()->dock, position);

  if (appicon) {
    appicon->flags.auto_launch = (autolaunch == YES) ? 1 : 0;
    wScreenSaveState(wDefaultScreen());
  }
}
BOOL WMIsDockAppLocked(int position)
{
  WAppIcon *appicon = wDockAppiconAtSlot(wDefaultScreen()->dock, position);

  if (!appicon || appicon->flags.lock == 0) {
    return NO;
  } else {
    return YES;
  }
}
void WMSetDockAppLocked(int position, BOOL lock)
{
  WAppIcon *appicon = wDockAppiconAtSlot(wDefaultScreen()->dock, position);

  if (appicon) {
    appicon->flags.lock = (lock == YES) ? 1 : 0;
    wScreenSaveState(wDefaultScreen());
  }
}
NSString *WMDockAppCommand(int position)
{
  WAppIcon *appicon = wDockAppiconAtSlot(wDefaultScreen()->dock, position);

  if (appicon) {
    return [NSString stringWithCString:appicon->command];
  } else {
    return nil;
  }
}
void WMSetDockAppCommand(int position, const char *command)
{
  WAppIcon *appicon = wDockAppiconAtSlot(wDefaultScreen()->dock, position);

  if (appicon) {
    wfree(appicon->command);
    appicon->command = wstrdup(command);
    wScreenSaveState(wDefaultScreen());
  }
}
NSString *WMDockAppPasteCommand(int position)
{
  WAppIcon *appicon = wDockAppiconAtSlot(wDefaultScreen()->dock, position);

  if (appicon) {
    return [NSString stringWithCString:appicon->paste_command];
  } else {
    return nil;
  }
}
void WMSetDockAppPasteCommand(int position, const char *command)
{
  WAppIcon *appicon = wDockAppiconAtSlot(wDefaultScreen()->dock, position);

  if (appicon) {
    wfree(appicon->paste_command);
    appicon->paste_command = wstrdup(command);
    wScreenSaveState(wDefaultScreen());
  }
}
NSString *WMDockAppDndCommand(int position)
{
  WAppIcon *appicon = wDockAppiconAtSlot(wDefaultScreen()->dock, position);

  if (appicon) {
    return [NSString stringWithCString:appicon->dnd_command];
  } else {
    return nil;
  }
}
void WMSetDockAppDndCommand(int position, const char *command)
{
  WAppIcon *appicon = wDockAppiconAtSlot(wDefaultScreen()->dock, position);

  if (appicon) {
    wfree(appicon->dnd_command);
    appicon->dnd_command = wstrdup(command);
    wScreenSaveState(wDefaultScreen());
  }
}

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

  [[[NSApp delegate] notificationCenter]
      addObserver:self
         selector:@selector(revert:)
             name:CF_NOTIFICATION(WMDidChangeDockContentNotification)
           object:nil];
}

- (NSString *)moduleName
{
  return _(@"Dock");
}

- (NSView *)view
{
  if (box == nil) {
    [NSBundle loadNibNamed:@"DockPrefs" owner:self];
  }

  return box;
}

//
// Table delegate methods
//
- (int)numberOfRowsInTableView:(NSTableView *)tv
{
  WScreen *scr = wDefaultScreen();
  WDock *dock = scr->dock;

  if (!dock) {
    return 0;
  } else {
    return dock->max_icons;
    // return dock->icon_count;
  }
}

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tc row:(int)row
{
  NSString *appName = WMDockAppName(row);

  if (tc == [appList tableColumnWithIdentifier:@"autostart"]) {
    if (WMIsDockAppAutolaunch(row))
      return [NSImage imageNamed:@"CheckMark"];
    else
      return nil;
  } else {
    if ([[appName pathExtension] isEqualToString:@"GNUstep"])
      appName = [appName stringByDeletingPathExtension];
    else
      appName = [appName pathExtension];

    if ([appName isEqualToString:@"Workspace"] || [appName isEqualToString:@"Recycler"]) {
      [[tc dataCellForRow:row] setEnabled:NO];
    } else {
      [[tc dataCellForRow:row] setEnabled:YES];
    }

    return appName;
  }
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
  NSTableView *tv = [aNotification object];
  NSInteger selRow = [tv selectedRow];
  NSString *appName = WMDockAppName(selRow);

  if ([[appName pathExtension] isEqualToString:@"GNUstep"])
    appName = [appName stringByDeletingPathExtension];
  else
    appName = [appName pathExtension];

  [nameField setStringValue:appName];
  [autostartBtn setEnabled:YES];

  if ([appName isEqualToString:@"Workspace"]) {
    [iconBtn setImage:[NSApp applicationIconImage]];
    [pathField setStringValue:@""];
  } else {
    [iconBtn setImage:WMDockAppImage(selRow)];
    [pathField setStringValue:WMDockAppCommand(selRow)];
  }
  [autostartBtn setState:WMIsDockAppAutolaunch(selRow) ? NSOnState : NSOffState];

  if ([appPanel isVisible]) {
    [self appSettingsPanelUpdate];
  }
}

- (BOOL)tableView:(NSTableView *)tv shouldSelectRow:(NSInteger)row
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

  if (selRow > [appList numberOfRows] - 1)
    [appList selectRow:0 byExtendingSelection:NO];
  else
    [appList selectRow:selRow byExtendingSelection:NO];
}

@end

@implementation DockPrefs (AppSettings)

- (void)appSettingsPanelUpdate
{
  NSInteger selRow = [appList selectedRow];
  NSString *appName = WMDockAppName(selRow);

  [appNameField setStringValue:appName];
  [appIconView setImage:WMDockAppImage(selRow)];
  [appCommandField setStringValue:WMDockAppCommand(selRow)];
  [appLockedBtn setState:WMIsDockAppLocked(selRow)];

  if ([appName isEqualToString:@"Workspace.GNUstep"] ||
      [appName isEqualToString:@"Recycler.GNUstep"]) {
    [appCommandField setEnabled:NO];
    [appCommandField setStringValue:@"NEXTSPACE internal"];
    [appLockedBtn setEnabled:NO];
  }

  if ([[appName pathExtension] isEqualToString:@"GNUstep"]) {
    [appMiddleClickField setEnabled:NO];
    [appDndCommandField setEnabled:NO];
    [appMiddleClickField setStringValue:@""];
    [appDndCommandField setStringValue:@""];
  } else {
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
  NSString *appName = WMDockAppName([appList selectedRow]);

  if (!appName || [appName isEqualToString:@"Workspace.GNUstep"] ||
      [appName isEqualToString:@"Recycler.GNUstep"])
    return;

  [self appSettingsPanelUpdate];

  // [appPanel makeKeyAndOrderFront:[iconBtn window]];
  [appPanel orderFront:[iconBtn window]];
  [appPanel makeFirstResponder:appCommandField];
}

- (void)setAppIcon:(id)sender
{
  NSInteger selRow = [appList selectedRow];
  NSInteger result;
  NSOpenPanel *openPanel;
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
  WMSetDockAppCommand([appList selectedRow], [[sender stringValue] cString]);
}

- (void)setAppPasteCommand:(id)sender
{
  WMSetDockAppPasteCommand([appList selectedRow], [[sender stringValue] cString]);
}

- (void)setAppDndCommand:(id)sender
{
  WMSetDockAppDndCommand([appList selectedRow], [[sender stringValue] cString]);
}

// NSWindow delegate method
- (void)windowWillClose:(NSNotification *)notif
{
  // if ([notif object] != appPanel)
  //   return;
  [[box window] makeKeyAndOrderFront:self];
}

@end
