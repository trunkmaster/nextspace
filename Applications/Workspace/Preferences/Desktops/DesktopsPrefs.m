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

#import "DesktopsPrefs.h"
#import <SystemKit/OSEDefaults.h>
#import <Workspace+WM.h>
#import <Controller.h>

#include <core/wuserdefaults.h>
#include <desktop.h>

@interface DesktopsPrefs (Private)
- (NSString *)_wmStatePath;
- (NSDictionary *)_wmState;
@end

@implementation DesktopsPrefs (Private)

- (NSString *)_wmStatePath
{
  CFStringRef stringRef;
  const char *wm_path;
  NSString *path;

  stringRef = WMUserDefaultsCopyStringForDomain(CFSTR("WMState.plist"));
  if (!stringRef)
    return nil;

  wm_path = CFStringGetCStringPtr(stringRef, kCFStringEncodingUTF8);
  path = [NSString stringWithCString:wm_path];
  CFRelease(stringRef);

  NSDebugLLog(@"Preferences", @"WMState path: %@", path);

  return path;
}

- (NSDictionary *)_wmState
{
  NSDictionary *wmState;

  // Defaults existance handled by WM.
  wmState = [[NSDictionary alloc] initWithContentsOfFile:[self _wmStatePath]];

  return [wmState autorelease];
}

@end

@implementation DesktopsPrefs

- (void)dealloc
{
  NSDebugLLog(@"DesktopsPrefs", @"DesktopsPrefs: dealloc");

  [box release];
  [desktopReps release];
  [wmStateDesktops release];

  [super dealloc];
}

- (void)awakeFromNib
{
  // get the box and destroy the bogus window
  [box retain];
  [box removeFromSuperview];

  // Names and Numbers
  desktopReps = [[NSMutableArray alloc]
      initWithObjects:dt1, dt2, dt3, dt4, dt5, dt6, dt7, dt8, dt9, dt10, nil];

  wmStateDesktops =
      [[NSMutableArray alloc] initWithArray:[[self _wmState] objectForKey:@"Desktops"]];
  desktopsCount = (wmStateDesktops && [wmStateDesktops count] > 0) ? [wmStateDesktops count] : 1;
  for (int i = 9; i >= desktopsCount; i--) {
    [[desktopReps objectAtIndex:i] removeFromSuperview];
  }

  [desktopsNumber selectItemWithTag:desktopsCount];
  [nameField setStringValue:@""];

  // Show In Dock button
  [showInDockBtn setRefusesFirstResponder:YES];
  [showInDockBtn setState:[[OSEDefaults userDefaults] boolForKey:@"ShowDesktopInDock"]];

  DESTROY(window);
}

// --- Protocol
- (NSString *)moduleName
{
  return _(@"Desktops");
}

- (NSView *)view
{
  if (box == nil) {
    [NSBundle loadNibNamed:@"Desktops" owner:self];
  }

  return box;
}

- (void)revert:sender
{
  NSDictionary *wmDefaults;
  NSString *shortcut;
  NSArray *modifiers;

  wmDefaults = [[NSDictionary alloc] initWithDictionary:[self _wmState]];

  if (!wmDefaults)
    return;

  if (wmStateDesktops)
    [wmStateDesktops release];

  wmStateDesktops = [[NSMutableArray alloc] initWithArray:[wmDefaults objectForKey:@"Desktops"]];
  [self arrangeDesktopReps];
  [[desktopReps objectAtIndex:wDefaultScreen()->current_desktop] performClick:self];

  NSDebugLLog(@"Preferences", @"switchKey = %@ (%li/%li), directSwitchKey = %@ (%li/%li)",
              [switchKey className], [[switchKey selectedItem] tag], [switchKey numberOfItems],
              [directSwitchKey className], [[directSwitchKey selectedItem] tag],
              [directSwitchKey numberOfItems]);

  // Shortcuts
  shortcut = [wmDefaults objectForKey:@"NextWorkspaceKey"];
  modifiers = [shortcut componentsSeparatedByString:@"+"];
  if ([[modifiers objectAtIndex:0] isEqualToString:@"Mod4"]) {
    [switchKey selectItemWithTag:0];
  } else if ([[modifiers objectAtIndex:0] isEqualToString:@"Mod1"]) {
    [switchKey selectItemAtIndex:2];
  } else {
    [switchKey selectItemAtIndex:1];
  }

  shortcut = [wmDefaults objectForKey:@"Workspace1Key"];
  modifiers = [shortcut componentsSeparatedByString:@"+"];
  if ([[modifiers objectAtIndex:0] isEqualToString:@"Mod4"]) {
    [directSwitchKey selectItemWithTag:0];
  } else if ([[modifiers objectAtIndex:0] isEqualToString:@"Mod1"]) {
    [directSwitchKey selectItemWithTag:2];
  } else {
    [directSwitchKey selectItemWithTag:1];
  }

  [wmDefaults release];
}

// --- Utility
- (void)arrangeDesktopReps
{
  NSRect repFrame = [[desktopReps objectAtIndex:0] frame];
  NSUInteger repsWidth = (desktopsCount * repFrame.size.width) + ((desktopsCount - 1) * 4);
  CGFloat boxWidth = [desktopsBox frame].size.width;
  NSPoint repPoint = repFrame.origin;
  NSButton *rep;

  repPoint.x = (boxWidth - repsWidth) / 2;
  for (int i = 0; i < desktopsCount; i++) {
    rep = [desktopReps objectAtIndex:i];
    [rep setFrameOrigin:repPoint];
    repPoint.x += [rep frame].size.width + 4;
  }
  [desktopsBox setNeedsDisplay:YES];
}

// --- Names and Numbers
- (void)selectWorkspace:(id)sender
{
  NSButton *button = nil;
  NSString *name = nil;

  for (int i = 0; i < desktopsCount; i++) {
    button = [desktopReps objectAtIndex:i];
    NSDebugLLog(@"Preferences", @"%d - Sender: %@, Button: %@", i, [sender title], [button title]);
    if (sender == button) {
      [sender setState:NSOnState];
      if (wmStateDesktops && [wmStateDesktops count] > i) {
        name = [[wmStateDesktops objectAtIndex:i] objectForKey:@"Name"];
      }
      if (!name) {
        name = [NSString stringWithFormat:@"Desktop %d", i + 1];
      }
      [nameField setStringValue:name];
      selectedDesktopRep = sender;
    } else {
      NSDebugLLog(@"Preferences", @"%d -  Button: %@ set to NSOffState", i, [button title]);
      [button setState:NSOffState];
    }
  }
}

- (void)changeName:(id)sender
{
  NSInteger index = [desktopReps indexOfObject:selectedDesktopRep];
  NSString *name = [nameField stringValue];
  WScreen *scr = wDefaultScreen();

  wDesktopRename(wDefaultScreen(), [desktopReps indexOfObject:selectedDesktopRep], [name cString]);
  [changeNameBtn setEnabled:NO];

  wDesktopSaveState(scr);
  WMUserDefaultsWrite(scr->session_state, CFSTR("WMState"));
  [wmStateDesktops replaceObjectAtIndex:index withObject:@{@"Name" : name}];
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
  NSDictionary *wsInfo = nil;
  NSString *wsName = nil;

  NSDebugLLog(@"Preferences", @"Text changed in %@", [[aNotification object] className]);
  if ([aNotification object] != nameField) {
    return;
  }

  if ([wmStateDesktops count] > 0) {
    wsInfo = [wmStateDesktops objectAtIndex:[desktopReps indexOfObject:selectedDesktopRep]];
  }
  wsName = [nameField stringValue];

  if ([wsName rangeOfCharacterFromSet:[NSCharacterSet alphanumericCharacterSet]].location !=
          NSNotFound &&
      (!wsInfo || [wsName isEqualTo:[wsInfo objectForKey:@"Name"]] == NO)) {
    [changeNameBtn setEnabled:YES];
  } else {
    [changeNameBtn setEnabled:NO];
  }
}

- (void)setWorkspaceQuantity:(id)sender
{
  NSInteger wsCountNew = [[sender selectedItem] tag];
  int diff = wsCountNew - desktopsCount;
  WScreen *scr = wDefaultScreen();

  if (diff < 0) {  // remove WS
    for (int i = desktopsCount; i > wsCountNew; i--) {
      wDesktopDelete(wDefaultScreen(), i);
      [[desktopReps objectAtIndex:i - 1] removeFromSuperview];
    }
  } else {
    wDesktopMake(wDefaultScreen(), diff);
    for (int i = desktopsCount; i < wsCountNew; i++) {
      [desktopsBox addSubview:[desktopReps objectAtIndex:i]];
    }
    [desktopsBox setNeedsDisplay:YES];
  }

  wDesktopSaveState(scr);
  WMUserDefaultsWrite(scr->session_state, CFSTR("WMState"));

  [wmStateDesktops setArray:[[self _wmState] objectForKey:@"Desktops"]];

  // Select last WS rep button if selected one was removed
  if ([desktopReps indexOfObject:selectedDesktopRep] >= wsCountNew) {
    [self selectWorkspace:[desktopReps objectAtIndex:wsCountNew - 1]];
  }
  desktopsCount = wsCountNew;

  [self arrangeDesktopReps];
}

// --- Shortcuts
- (void)setSwitchShortcut:(id)sender
{
  NSInteger selectedItemTag = [[sender selectedItem] tag];
  NSMutableDictionary *wmDefaults;
  NSString *prefix;

  wmDefaults = [[NSMutableDictionary alloc] initWithDictionary:[self _wmState]];
  if (!wmDefaults) {
    wmDefaults = [[NSMutableDictionary alloc] init];
  }

  switch (selectedItemTag) {
    case 0:  // Alternate + Control + Arrow Keys
      prefix = @"Super+Control";
      break;
    case 1:  // Control + Arrow Keys (default)
      prefix = @"Control";
      break;
    case 2:  // Command + Control + Arrow Keys
      prefix = @"Alt+Control";
      break;
  }

  [wmDefaults setObject:[NSString stringWithFormat:@"%@+Right", prefix] forKey:@"NextWorkspaceKey"];
  [wmDefaults setObject:[NSString stringWithFormat:@"%@+Left", prefix] forKey:@"PrevWorkspaceKey"];
  [wmDefaults writeToFile:[self _wmStatePath] atomically:YES];
  [wmDefaults release];
}
- (void)setDirectSwitchShortcut:(id)sender
{
  NSMutableDictionary *wmDefaults;
  NSString *prefix;

  wmDefaults = [[NSMutableDictionary alloc] initWithDictionary:[self _wmState]];
  if (!wmDefaults) {
    wmDefaults = [NSMutableDictionary new];
  }

  switch ([[sender selectedItem] tag]) {
    case 0:  // Alternate + Control + Number Keys
      prefix = @"Super+Control";
      break;
    case 1:  // Control + Number Keys (default)
      prefix = @"Control";
      break;
    case 2:  // Command + Control + Number Keys
      prefix = @"Alt+Control";
      break;
  }

  for (int i = 1; i < 10; i++) {
    [wmDefaults setObject:[NSString stringWithFormat:@"%@+%i", prefix, i]
                   forKey:[NSString stringWithFormat:@"Workspace%iKey", i]];
  }
  [wmDefaults setObject:[NSString stringWithFormat:@"%@+0", prefix] forKey:@"Workspace10Key"];
  [wmDefaults writeToFile:[self _wmStatePath] atomically:YES];
  [wmDefaults release];
}

// ---
- (void)setShowInDock:(id)sender
{
  [[OSEDefaults userDefaults] setBool:[sender state] ? YES : NO forKey:@"ShowWorkspaceInDock"];
  if ([sender state]) {
    [[NSApp delegate] createWorkspaceBadge];
  } else {
    [[NSApp delegate] destroyWorkspaceBadge];
  }
}

@end
