/*
  WMInspector.m

  Concrete class for file contents inspectors.

  Copyright (C) 2014 Sergii Stoian

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

#import <NXFoundation/NXBundle.h>
#import <NXFoundation/NXFileManager.h>

#import <dispatch/dispatch.h>

#import <Workspace.h>
#import "Inspector.h"

static Inspector *inspectorPanel = nil;

@implementation WMInspector

// Class Methods

+ new
{
  inspectorPanel = [Inspector sharedInspector];

  return [super new];
}

- (void)dealloc
{
  NSDebugLLog(@"Inspector", @"WMInspector: dealloc");

  // release controls here
  TEST_RELEASE(inspectorPanel);

  [super dealloc];
}

// Public Methods

- ok:sender
{
  [inspectorPanel ok:sender];
  return self;
}

- okButton
{
  return [inspectorPanel okButton];
}

- revert:sender
{
  // Buttons state and title, window edited state
  [inspectorPanel revert:self];
  return self;
}

- revertButton
{
  return [inspectorPanel revertButton];
}

- (unsigned)selectionCount
{
  return [inspectorPanel selectionCount];
}

- selectionPathsInto:(char *)pathString separator:(char)character
{
  [inspectorPanel selectionPathsInto:pathString separator:character];
  return self;
}

- getSelectedPath:(NSString **)pathString andFiles:(NSArray **)fileArray
{
  [inspectorPanel getSelectedPath:pathString andFiles:fileArray];
  return self;
}

- textDidChange:sender
{
  return [inspectorPanel textDidChange:sender];
}

- touch:sender
{
  [inspectorPanel touch:sender];
  return self;
}

// Returns window of current content inspector.
// Caller access to window's contents view and title then.
- window
{
  return window;
}

@end
