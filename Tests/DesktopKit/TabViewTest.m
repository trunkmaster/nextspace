/*
  Descritopn: Testing GNUstep drawing operations.

  Copyright (c) 2019 Sergii Stoian

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

#import <AppKit/AppKit.h>
#import <DesktopKit/NXTTabView.h>
#import "TabViewTest.h"

@implementation TabViewTest : NSObject

- (id)init
{
  window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 355, 240)
                                       styleMask:(NSTitledWindowMask | NSResizableWindowMask |
                                                  NSClosableWindowMask | NSMiniaturizableWindowMask)
                                         backing:NSBackingStoreRetained
                                           defer:YES];
  [window setMinSize:NSMakeSize(355, 240)];
  [window setTitle:@"TabView test"];
  [window setReleasedWhenClosed:YES];
  [window setDelegate:self];

  // TabView *tabView = [[TabView alloc] initWithFrame:NSMakeRect(0, 0, 355, 240)];
  // TabView *tabView = [[TabView alloc] initWithFrame:NSMakeRect(2, 2, 351, 236)];
  NXTTabView *tabView = [[NXTTabView alloc] initWithFrame:NSMakeRect(-1, -2, 359, 242)];
  tabView.unselectedBackgroundColor = [NSColor grayColor];
  tabView.selectedBackgroundColor = [NSColor lightGrayColor];
  [tabView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

  NXTTabViewItem *item;
  item = [[NXTTabViewItem alloc] initWithIdentifier:@"Model"];
  item.label = @"Model";
  [tabView addTabViewItem:item];

  item = [[NXTTabViewItem alloc] initWithIdentifier:@"Repeat"];
  item.label = @"Repeat";
  [tabView addTabViewItem:item];

  item = [[NXTTabViewItem alloc] initWithIdentifier:@"Layouts"];
  item.label = @"Layouts";
  [tabView addTabViewItem:item];

  item = [[NXTTabViewItem alloc] initWithIdentifier:@"Shortcuts"];
  item.label = @"Shortcuts";
  [tabView addTabViewItem:item];

  item = [[NXTTabViewItem alloc] initWithIdentifier:@"Keypad"];
  item.label = @"Keypad";
  [tabView addTabViewItem:item];

  item = [[NXTTabViewItem alloc] initWithIdentifier:@"Modifiers"];
  item.label = @"Modifiers";
  [tabView addTabViewItem:item];

  [[window contentView] addSubview:tabView];

  [window center];
  [window orderFront:nil];
  [window makeKeyWindow];

  return self;
}

- (void)show
{
  [window makeKeyAndOrderFront:self];
}

@end
