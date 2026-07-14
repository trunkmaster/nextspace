/* main.m

   Copyright (C) 1999 Free Software Foundation, Inc.

   Author:  Richard frith-Macdonald (richard@brainstorm.co.uk>
   Date: 1999
   
   This file is part of GNUstep.
   
   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.
   
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.
   
   You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
*/
#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#include <InterfaceBuilder/InterfaceBuilder.h>

#include "GormNSBrowser.h"
#include "GormNSTableView.h"
#include "GormNSOutlineView.h"

#include <math.h>


/* --------------------------------------------------------------- 
 * Containers Palette Display
*/

@interface ContainersPalette: IBPalette
{
}
@end

@implementation ContainersPalette

- (void) finishInstantiate
{

  NSView	   *contents;
  NSTableView      *tv;
  NSOutlineView    *ov;
  NSTableColumn    *tc;
  NSSize           contentSize;
  id		   v;

  originalWindow = [[NSWindow alloc] initWithContentRect: 
				       NSMakeRect(0, 0, 272, 192)
				       styleMask: NSBorderlessWindowMask 
					 backing: NSBackingStoreRetained
					   defer: NO];
  [originalWindow setTitle: @"Containers"];
  contents = [originalWindow contentView];

/*******************/
/* First Column... */
/*******************/


  // NSBrowser
  // 124 is the minimum width. Below that the browser doesn't display !!
  v = [[GormNSBrowser alloc] initWithFrame: NSMakeRect(10, 98, 124, 78)];
  [v setHasHorizontalScroller: YES];
  [v setTitled: YES];
  [v loadColumnZero];
  [contents addSubview: v];
  RELEASE(v);
  
  // NSTabView
  v = [[NSTabView alloc] initWithFrame: NSMakeRect(10, 10, 124, 78)];
  [contents addSubview: v];
  {
    NSView *vv;
    NSTabViewItem *tvi;
    tvi = [[NSTabViewItem alloc] initWithIdentifier: @"item 1"];
    [tvi setLabel: @"Item 1"];
    vv = [[NSView alloc] init];
    [vv setAutoresizingMask: 
	 NSViewWidthSizable | NSViewHeightSizable];
    [tvi setView: vv];
    [v addTabViewItem: tvi];
    RELEASE(tvi);
    tvi = [[NSTabViewItem alloc] initWithIdentifier: @"item 2"];
    [tvi setLabel: @"Item 2"];
    vv = [[NSView alloc] init];
    [vv setAutoresizingMask: 
	 NSViewWidthSizable | NSViewHeightSizable];
    [tvi setView: vv];
    [v addTabViewItem: tvi];
    RELEASE(tvi);
  }
  RELEASE(v);
  

/********************/
/* Second Column... */
/********************/


  // NSTableView
  v = [[NSScrollView alloc] initWithFrame: 
			      NSMakeRect(136, 10, 124, 78)];
  [contents addSubview: v];  
  [v setHasVerticalScroller: YES];
  [v setHasHorizontalScroller: NO];
  contentSize = [v contentSize];
  [v setBorderType: NSBezelBorder];

  tv = [[GormNSTableView alloc] initWithFrame:
				  NSZeroRect];

  tc = [[NSTableColumn alloc] initWithIdentifier: @"column1"];
  [[tc headerCell] setStringValue: @" "];
  [tc setWidth: floor(contentSize.width/2)];
  [tc setMinWidth: 20];
  [tc setResizable: YES];
  [tc setEditable: YES];
  [tv addTableColumn: tc];
  RELEASE(tc);

  tc = [[NSTableColumn alloc] initWithIdentifier: @"column2"];
  [[tc headerCell] setStringValue: @" "];
  [tc setWidth: ceil(contentSize.width/2)];
  [tc setMinWidth: 20];
  [tc setResizable: YES];
  [tc setEditable: YES];
  [tv addTableColumn: tc];
  RELEASE(tc);
  
  [v setDocumentView: tv];
  [contents addSubview: v];
  RELEASE(tv);
  RELEASE(v);
  
  // NSOutlineView
  v = [[NSScrollView alloc] initWithFrame: 
			      NSMakeRect(136, 98, 124, 78)];
  [contents addSubview: v];
  [v setHasVerticalScroller: YES];
  [v setHasHorizontalScroller: NO];
  contentSize = [v contentSize];
  [v setBorderType: NSBezelBorder];

  ov = [[GormNSOutlineView alloc] initWithFrame:
				    NSZeroRect];

  tc = [[NSTableColumn alloc] initWithIdentifier: @"classes"];
  [[tc headerCell] setStringValue: @" "];
  [tc setWidth: floor(contentSize.width/2)];
  [tc setMinWidth: 20];
  [tc setResizable: YES];
  [tc setEditable: YES];
  [ov addTableColumn: tc];
  [ov setOutlineTableColumn: tc];
  RELEASE(tc);

  tc = [[NSTableColumn alloc] initWithIdentifier: @"outlets"];
  [[tc headerCell] setStringValue: @" "];
  [tc setWidth: ceil(contentSize.width/2)];
  [tc setMinWidth: 20];
  [tc setResizable: YES];
  [tc setEditable: YES];
  [ov addTableColumn: tc];
  RELEASE(tc);

  tc = [[NSTableColumn alloc] initWithIdentifier: @"actions"];
  [[tc headerCell] setStringValue: @" "];
  [tc setWidth: ceil(contentSize.width/2)];
  [tc setMinWidth: 20];
  [tc setResizable: YES];
  [tc setEditable: YES];
  [ov addTableColumn: tc];
  RELEASE(tc);

  [ov setDrawsGrid: NO];
  [ov setIndentationPerLevel: 10.];
  [ov setIndentationMarkerFollowsCell: YES];
  [ov expandItem: @"NSObject" expandChildren: YES];
  [v setDocumentView: ov];

  RELEASE(ov);
  RELEASE(v);  
}

@end
