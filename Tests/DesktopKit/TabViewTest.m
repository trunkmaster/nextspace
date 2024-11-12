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

  // NXTTabView *tabView = [[NXTTabView alloc] initWithFrame:NSMakeRect(0, 0, 355, 240)];
  // NXTTabView *tabView = [[NXTTabView alloc] initWithFrame:NSMakeRect(2, 2, 351, 236)];
  NXTTabView *tabView = [[NXTTabView alloc] initWithFrame:NSMakeRect(-1, -2, 359, 242)];
  tabView.unselectedBackgroundColor = [NSColor grayColor];
  tabView.selectedBackgroundColor = [NSColor lightGrayColor];
  // [tabView setFont:[NSFont boldSystemFontOfSize:12]];
  [tabView setAllowsTruncatedLabels:YES];
  [tabView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

  NXTTabViewItem *item;
  NSView *subview;
  item = [[NXTTabViewItem alloc] initWithIdentifier:@"0"];
  item.label = @"Instances";
  subview = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 100, (359 - 40), 21)];
  [subview setAutoresizingMask:NSViewWidthSizable];
  [item setView:subview];
  [subview release];
  [tabView addTabViewItem:item];

  item = [[NXTTabViewItem alloc] initWithIdentifier:@"1"];
  item.label = @"Classes";
  NSBox *box = [[NSBox alloc] initWithFrame:NSMakeRect(0, 1, 359-2, 242 - 28)];
  NSScrollView *sv = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 359, 242 - 27)];

  [box setBorderType:NSLineBorder];
  [box setTitlePosition:NSNoTitle];
  [box setContentViewMargins:NSMakeSize(0, 0)];
  [box setAutoresizingMask:NSViewHeightSizable | NSViewWidthSizable];

  [sv setHasVerticalScroller:YES];
  [sv setHasHorizontalScroller:NO];
  [sv setBackgroundColor:[NSColor whiteColor]];
  [sv setAutoresizingMask:NSViewHeightSizable | NSViewWidthSizable];
  [box addSubview:sv];
  [sv release];

  [item setView:box];
  [box release];
  [tabView addTabViewItem:item];

  item = [[NXTTabViewItem alloc] initWithIdentifier:@"2"];
  item.label = @"Images";
  [tabView addTabViewItem:item];

  item = [[NXTTabViewItem alloc] initWithIdentifier:@"3"];
  item.label = @"Sounds";
  [tabView addTabViewItem:item];

  // item = [[NXTTabViewItem alloc] initWithIdentifier:@"4"];
  // item.label = @"LogngTitle";
  // [tabView addTabViewItem:item];

  // item = [[NXTTabViewItem alloc] initWithIdentifier:@"5"];
  // item.label = @"VeryLogngTitle";
  // [tabView addTabViewItem:item];

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
