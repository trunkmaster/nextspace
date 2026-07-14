/* GormFilesOwner.m
 *
 * Copyright (C) 1999 Free Software Foundation, Inc.
 *
 * Author:	Richard Frith-Macdonald <richard@brainstrom.co.uk>
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	1999, 2004
 * 
 * This file is part of GNUstep.
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <AppKit/AppKit.h>
#include <AppKit/NSNibConnector.h>

#include "GormPrivate.h"
#include "GormCustomView.h"

// @class GormCustomView;

@implementation	GormFilesOwner
- (NSString*) className
{
  return className;
}

- (void) dealloc
{
  RELEASE(className);
  [super dealloc];
}

- (NSImage*) imageForViewer
{
  static NSImage	*image = nil;

  if (image == nil)
    {
      NSBundle	*bundle = [NSBundle bundleForClass: [self class]];
      NSString	*path = [bundle pathForImageResource: @"GormFilesOwner"];

      image = [[NSImage alloc] initWithContentsOfFile: path];
    }
  return image;
}

- (id) init
{
  self = [super init];
  [self setClassName: @"NSApplication"];
  return self;
}

- (NSString*) inspectorClassName
{
  return @"GormFilesOwnerInspector";
}

- (NSString*) classInspectorClassName
{
  return @"GormFilesOwnerInspector";
}

- (void) setClassName: (NSString*)aName
{
  ASSIGN(className, aName);
}

- (void) encodeWithCoder: (NSCoder *)coder
{
  if([coder allowsKeyedCoding])
    {
      [coder encodeObject: className forKey: @"NSClassName"];
    }
}

/*
- (id) initWithCoder: (NSCoder *)coder
{
  [NSException raise: NSInvalidArgumentException
	       format: @"Keyed coding not implemented for %@.", 
	       NSStringFromClass([self class])];
  return nil; // never reached, but keeps gcc happy.
}
*/
@end

@implementation GormFilesOwnerInspector
- (NSInteger) browser: (NSBrowser*)sender numberOfRowsInColumn: (NSInteger)column
{
  return [classes count];
}

- (NSString*) browser: (NSBrowser*)sender titleOfColumn: (NSInteger)column
{
  return @"Class";
}

- (void) browser: (NSBrowser*)sender
 willDisplayCell: (id)aCell
	   atRow: (NSInteger)row
	  column: (NSInteger)col
{
  if (row >= 0 && row < [classes count])
    {
      [aCell setStringValue: [classes objectAtIndex: row]];
      [aCell setEnabled: YES];
    }
  else
    {
      [aCell setStringValue: @""];
      [aCell setEnabled: NO];
    }
  [aCell setLeaf: YES];
}

- (void) dealloc
{
  RELEASE(classes);
  [super dealloc];
}

- (void) _classAdded: (NSNotification *)notification
{
  [self setObject: object];
}

- (void) _classDeleted: (NSNotification *)notification
{
  [self setObject: object];
}

- (id) init
{
  self = [super init];
  if (self != nil)
    {
      NSView		*contents;
      NSRect		rect;
      NSRect            browserRect;

      rect = NSMakeRect(0, 0, IVW, IVH);
      window = [[NSWindow alloc] initWithContentRect: rect
					   styleMask: NSBorderlessWindowMask 
					     backing: NSBackingStoreRetained
					       defer: NO];
      contents = [window contentView];

      browserRect = NSMakeRect(31,56,203,299);
      browser = [[NSBrowser alloc] initWithFrame: browserRect];
      [browser setAutoresizingMask: NSViewWidthSizable|NSViewHeightSizable];
      [browser setMaxVisibleColumns: 1];
      [browser setAllowsMultipleSelection: NO];
      [browser setHasHorizontalScroller: NO];
      [browser setDelegate: self];
      [browser setTarget: self];
      [browser setAction: @selector(takeClassFrom:)];

      [contents addSubview: browser];
      RELEASE(browser);

      // add observers for relavent notifications.
      [[NSNotificationCenter defaultCenter]
	addObserver: self
	selector: @selector(_classAdded:)
	name: GormDidAddClassNotification
	object: [(id<GormAppDelegate>)[NSApp delegate] classManager]];

      [[NSNotificationCenter defaultCenter]
	addObserver: self
	selector: @selector(_classDeleted:)
	name: GormDidDeleteClassNotification
	object: [(id<GormAppDelegate>)[NSApp delegate] classManager]];
    }
  return self;
}

- (void) setObject: (id)anObject
{
  // filter the classes to view only when a custom view is selected.
  if([anObject isKindOfClass: [GormCustomView class]])
    {
      ASSIGN(classes, AUTORELEASE([[[(id<GormAppDelegate>)[NSApp delegate] classManager] allSubclassesOf: @"NSView"] mutableCopy]));
    }
  else
    {
      ASSIGN(classes, AUTORELEASE([[[(id<GormAppDelegate>)[NSApp delegate] classManager] allClassNames] mutableCopy]));
    }

  // remove the first responder, since we don't want the user to choose this.
  [classes removeObject: @"FirstResponder"];

  if (anObject != nil)
    {
      NSArray	 *array;
      NSUInteger pos;

      ASSIGN(object, anObject);
      hasConnections = NO;

      /*
       * Create list of existing connections for selected object.
       */
      array = [[(id<IB>)[NSApp delegate] activeDocument] connectorsForSource: object
					      ofClass: [NSNibOutletConnector class]];
      if ([array count] > 0)
	hasConnections = YES;
      array = [[(id<IB>)[NSApp delegate] activeDocument] connectorsForDestination: object
					      ofClass: [NSNibControlConnector class]];
      if ([array count] > 0)
	hasConnections = YES;

      [browser loadColumnZero];
      pos = [classes indexOfObject: [object className]];
      if (pos != NSNotFound)
	{
	  [browser selectRow: pos inColumn: 0];
	}
    }
}

- (void) takeClassFrom: (id)sender
{
  NSString	*title = [[browser selectedCell] stringValue];

  NSDebugLog(@"Selected %d, %@", (int)[browser selectedRowInColumn: 0], title);
  if (hasConnections > 0 && [title isEqual: [object className]] == NO)
    {
      if (NSRunAlertPanel(nil, _(@"This operation will break existing connection"),
			  _(@"OK"), _(@"Cancel"), nil) != NSAlertDefaultReturn)
	{
	  unsigned	pos = [classes indexOfObject: [object className]];

	  [browser selectRow: pos inColumn: 0];
	  return;
	}
      else
	{
	  NSArray	*array;
	  id		doc = [(id<IB>)[NSApp delegate] activeDocument];
	  unsigned	i;

	  array = [doc connectorsForSource: object
		       ofClass: [NSNibOutletConnector class]];
	  for (i = 0; i < [array count]; i++)
	    {
	      id<IBConnectors>	con = [array objectAtIndex: i];

	      [doc removeConnector: con];
	    }
	  array = [doc connectorsForDestination: object
		       ofClass: [NSNibControlConnector class]];
	  for (i = 0; i < [array count]; i++)
	    {
	      id<IBConnectors>	con = [array objectAtIndex: i];

	      [doc removeConnector: con];
	    }
	  hasConnections = NO;
	}
    }
  [super ok: sender];
  [object setClassName: title];
}
@end
