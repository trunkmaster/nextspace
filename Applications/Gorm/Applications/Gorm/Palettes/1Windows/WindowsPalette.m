/* 
   main.m

   Copyright (C) 1999-2005 Free Software Foundation, Inc.

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

#include <InterfaceBuilder/InterfaceBuilder.h>
#include <GormCore/GormCore.h>

#include "GormWindowSizeInspector.h"
#include "WindowsPalette.h"

@interface GormWindowMaker : NSObject <NSCoding>
{
}
@end

@implementation	GormWindowMaker
- (void) encodeWithCoder: (NSCoder*)aCoder
{
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  id w;
  unsigned style = ( NSTitledWindowMask | NSClosableWindowMask
		     | NSResizableWindowMask | NSMiniaturizableWindowMask);
  NSRect        screenRect = [[NSScreen mainScreen] frame];
  float  x = (screenRect.size.width - 500)/2;
  float  y = (screenRect.size.height - 300)/2;
  NSRect        windowRect = NSMakeRect(x,y,500,300);

  w = [[GormNSWindow alloc] initWithContentRect: windowRect 
			    styleMask: style 
			    backing: NSBackingStoreRetained
			    defer: NO];

  [w setFrame: windowRect display: YES];
  [w setTitle: @"Window"];
  [w orderFront: self];
  RELEASE(self);
  return w;
}
@end

@interface GormPanelMaker : NSObject <NSCoding>
{
}
@end

@implementation	GormPanelMaker
- (void) encodeWithCoder: (NSCoder*)aCoder
{
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  id		w;
  unsigned	style = NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask;
  NSRect        screenRect = [[NSScreen mainScreen] frame];
  float         
    x = (screenRect.size.width - 500)/2, 
    y = (screenRect.size.height - 300)/2;
  NSRect        windowRect = NSMakeRect(x,y,500,300);
  
  w = [[GormNSPanel alloc] initWithContentRect: windowRect 
			   styleMask: style 
			   backing: NSBackingStoreRetained
			   defer: NO];
  [w setFrame: windowRect display: YES];
  [w setTitle: @"Panel"];
  [w orderFront: self];
  RELEASE(self);
  return w;
}
@end

@implementation WindowsPalette
- (void) finishInstantiate
{
  NSView	*contents;
  id		w;
  id		v;
  NSBundle	*bundle = [NSBundle bundleForClass: [self class]];
  NSString	*path = [bundle pathForImageResource: @"WindowDrag"];
  NSImage	*dragImage = [[NSImage alloc] initWithContentsOfFile: path];
  NSString	*drawerPath = [bundle pathForImageResource: @"Drawer"];
  NSImage	*drawerImage = [[NSImage alloc] initWithContentsOfFile: drawerPath];
  NSFont        *systemFont = [NSFont boldSystemFontOfSize: [NSFont systemFontSize]];
  RELEASE(originalWindow);
  originalWindow = [[NSWindow alloc] initWithContentRect: 
				       NSMakeRect(0, 0, 272, 192)
				     styleMask: NSBorderlessWindowMask 
				     backing: NSBackingStoreRetained
				     defer: NO];
  [originalWindow setTitle: @"Windows"];
  contents = [originalWindow contentView];

  w = [[GormWindowMaker alloc] init];
  v = [[NSButton alloc] initWithFrame: NSMakeRect(35, 100, 80, 64)];
  [v setFont: systemFont];
  [v setBordered: NO];
  [v setImage: dragImage];
  [v setImagePosition: NSImageOverlaps];
  [v setTitle: @"Window"];
  [contents addSubview: v];
  [self associateObject: w
	type: IBWindowPboardType
	with: v];
  RELEASE(v);
  RELEASE(w);

  w = [[GormPanelMaker alloc] init];
  v = [[NSButton alloc] initWithFrame: NSMakeRect(155, 100, 80, 64)];
  [v setFont: systemFont];
  [v setBordered: NO];
  [v setImage: dragImage];
  [v setImagePosition: NSImageOverlaps];
  [v setTitle: @"Panel"];
  [contents addSubview: v];
  [self associateObject: w
	type: IBWindowPboardType
	with: v];
  RELEASE(v);
  RELEASE(w);

  w = [[NSDrawer alloc] init];
  v = [[NSButton alloc] initWithFrame: NSMakeRect(95, 30, 80, 64)];
  [v setFont: systemFont];
  [v setBordered: NO];
  [v setImage: drawerImage];
  [v setImagePosition: NSImageOverlaps];
  [v setTitle: @"Drawer"];
  [contents addSubview: v];
  [self associateObject: w
	type: IBObjectPboardType
	with: v];
  RELEASE(v);
  RELEASE(w);

  RELEASE(dragImage);
  RELEASE(drawerImage);
}
@end

@implementation NSWindow (GormPrivate)
+ (id) allocSubstitute
{
  return [GormNSWindow alloc];
}
@end

@implementation NSPanel (GormPrivate)
+ (id) allocSubstitute
{
  return [GormNSPanel alloc];
}
@end

