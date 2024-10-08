/*
  Class:               AppController
  Inherits from:       NSObject
  Class descritopn:    NSApplication delegate

  Copyright (C) 2024 Sergii Stoian

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

#import "AppController.h"
#include "AppKit/NSFontPanel.h"

@implementation AppController : NSObject

- (void)awakeFromNib
{
}

- (void)dealloc
{
  [super dealloc];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
  return NSRunAlertPanel(@"Quit", @"Do you really want to quit?", @"Quit Now!", @"Who knows...",
                          @"No!");
  // return NSRunAlertPanel(@"GNU Preamble",
  //                        @"This program is free software; \nyou can redistribute it and/or modify
  //                        it under the terms of the GNU General Public License as published by the
  //                        Free Software Foundation; \neither version 2 of the License, or (at your
  //                        option) any later version.",
  //                        @"Default", @"Alternate Button", @"Other");
}

//----------------------------------------------------------------------------
#pragma mark - Actions
//----------------------------------------------------------------------------

#pragma mark - Panels

- (void)showFontPanel:(id)sender
{
  NSFontPanel *fontPanel = [NSFontPanel sharedFontPanel];

  if ([NSBundle loadNibNamed:@"PanelOptions" owner:self]) {
    [accessoryView retain];
    [accessoryView removeFromSuperview];
    [fontPanel setAccessoryView:accessoryView];
    [accessoryView release];
  }

  if (fontPanel) {
    [fontPanel orderFront:self];
  }
}

@end
