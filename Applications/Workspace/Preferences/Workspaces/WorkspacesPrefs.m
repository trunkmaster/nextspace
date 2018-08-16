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
#include <workspace.h>
#import <Controller.h>

@implementation WorkspacesPrefs

- (void)dealloc
{
  NSDebugLLog(@"WorkspacesPrefs", @"WorkspacesPrefs: dealloc");

  [box release];
  [wsReps release];
  [wmStateWS release];
  
  [super dealloc];
}

- (void)awakeFromNib
{
  NSButton *rep;
  
  // get the box and destroy the bogus window
  [box retain];
  [box removeFromSuperview];

  [showInDockBtn setRefusesFirstResponder:YES];
  [showInDockBtn
    setState:[[NXDefaults userDefaults] boolForKey:@"ShowWorkspaceInDock"]];

  wsReps = [[NSMutableArray alloc]
                initWithObjects:ws1,ws2,ws3,ws4,ws5,ws6,ws7,ws8,ws9,ws10,nil];

  wmStateWS = [[NSMutableArray alloc]
                        initWithArray:[WWMDockState() objectForKey:@"Workspaces"]];
  wsCount = [wmStateWS count];
  for (int i = 9; i >= 0; i--) {
    rep = [wsReps objectAtIndex:i];
    if (i < wsCount) {
      [rep release];
    }
    else {
      [rep removeFromSuperview];
      // [wsReps removeObjectAtIndex:i];
    }
  }

  [wsNumber selectItemWithTag:wsCount];
  
  [nameField setStringValue:@""];

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

// --- Utility
- (void)arrangeWorkspaceReps
{
  NSRect     repFrame = [[wsReps objectAtIndex:0] frame];
  NSUInteger repsWidth = (wsCount * repFrame.size.width) + ((wsCount-1) * 6);
  CGFloat    boxWidth = [wsBox frame].size.width;
  NSPoint    repPoint = repFrame.origin;
  NSButton   *rep;

  repPoint.x = (boxWidth - repsWidth) / 2;
  for (int i=0; i < wsCount; i++) {
    rep = [wsReps objectAtIndex:i];
    [rep setFrameOrigin:repPoint];
    repPoint.x += [rep frame].size.width + 6;
  }
  [box setNeedsDisplay:YES];
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
  NSButton *button;
  NSString *name;

  // NSLog(@"selectWorkspace: sender == %@ (%@) buttons # %lu", [sender className], sender, [wsButtons count]);
  for (int i=0; i < wsCount; i++) {
    button = [wsReps objectAtIndex:i];
    [button setState:(sender == button) ? NSOnState : NSOffState];
    if ([sender isEqualTo:button] != NO) {
      name = [[wmStateWS objectAtIndex:i] objectForKey:@"Name"];
      [nameField setStringValue:name];
      selectedWSRep = button;
    }
  }
}

- (void)changeName:(id)sender
{
  NSInteger index = [wsReps indexOfObject:selectedWSRep];
  NSString  *name = [nameField stringValue];
  
  wWorkspaceRename(wScreenWithNumber(0), [wsReps indexOfObject:selectedWSRep],
                   [name cString]);
  
  WWMDockStateSave();
  [wmStateWS replaceObjectAtIndex:index withObject:@{@"Name":name}];
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
  NSDictionary *wsInfo;
  NSString     *wsName;

  // NSLog(@"Text changed in %@", [object className]);
  if ([aNotification object] != nameField)
    return;

  wsInfo = [wmStateWS objectAtIndex:[wsReps indexOfObject:selectedWSRep]];
  wsName = [nameField stringValue];
  
  if ([wsName rangeOfCharacterFromSet:[NSCharacterSet alphanumericCharacterSet]].location != NSNotFound &&
      [wsName isEqualTo:[wsInfo objectForKey:@"Name"]] == NO) {
    [changeNameBtn setEnabled:YES];
  }
  else {
    [changeNameBtn setEnabled:NO];
  }
}

- (void)revert:sender
{
  if (wmStateWS) [wmStateWS release];
  
  wmStateWS = [[NSMutableArray alloc]
                initWithArray:[WWMDockState() objectForKey:@"Workspaces"]];

  [self arrangeWorkspaceReps];  
}

@end
