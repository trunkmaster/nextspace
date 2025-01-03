/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Copyright (C) 2014 Sergii Stoian
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

#import "FileCopyPrefs.h"
#import <SystemKit/OSEDefaults.h>

@implementation FileCopyPrefs

- (void)dealloc
{
  NSDebugLLog(@"FileCopyPrefs", @"FileCopyPrefs: dealloc");

  //[[NSNotificationCenter defaultCenter] removeObserver:self];

  TEST_RELEASE(box);

  [super dealloc];
}

- (void)awakeFromNib
{
  NSString *action;
  NSInteger tag = 0;

  // get the box and destroy the bogus window
  [box retain];
  [box removeFromSuperview];
  DESTROY(bogusWindow);

  // initialize button matrix state
  action = [[OSEDefaults userDefaults] objectForKey:@"DefaultSymlinkAction"];
  if ([action isEqualToString:@"ask"]) {
    tag = 0;
  } else if ([action isEqualToString:@"NEWLINK"]) {
    tag = 1;
  } else if ([action isEqualToString:@"COPY"]) {
    tag = 2;
  } else if ([action isEqualToString:@"SKIP"]) {
    tag = 3;
  }

  [buttonMatrix selectCellWithTag:tag];

  NSEnumerator *e = [[buttonMatrix cells] objectEnumerator];
  NSButton *b;
  while (b = [e nextObject]) {
    [b setRefusesFirstResponder:YES];
  }
}

// --- PrefsModule protocol

- (NSString *)moduleName
{
  return _(@"File Copy Options");
}

- (NSView *)view
{
  if (box == nil) {
    [NSBundle loadNibNamed:@"FileCopyPrefs" owner:self];
  }

  return box;
}

- (void)revert:(id)sender
{
  // Do nothing
}

// --- Buttons

- (void)setSymlinkAction:(id)sender
{
  NSInteger tag = [[sender selectedCell] tag];
  NSString *action;

  switch (tag) {
    case 0:  // ask
      action = @"ask";
      break;
    case 1:  // make a new link
      action = @"NEWLINK";
      break;
    case 2:  // copy the original
      action = @"COPY";
      break;
    case 3:  // skip the link
      action = @"SKIP";
      break;
    default:  // ask
      action = @"ask";
  }

  [[OSEDefaults userDefaults] setObject:action forKey:@"DefaultSymlinkAction"];

  // Don't send notification. FileOperation always read setting from defaults.
}

@end
