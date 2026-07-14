/* GormNSMenu.m

   Copyright (C) 2002 Free Software Foundation, Inc.

   Author: Pierre-Yves Rivaille <pyrivail@ens-lyon.fr>
   Date: 2002
   
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

#include "GormNSMenuView.h"
#include "GormNSMenu.h"

@interface GormNSMenuWindow : NSPanel
@end

@implementation GormNSMenuWindow
- (BOOL)canBecomeMainWindow
{
  return NO;
}
- (BOOL)canBecomeKeyWindow
{
  return YES;
}

- (void)resignMainWindow
{
  [super resignMainWindow];
  if ([[self menu] _ownedByPopUp])
    {
      [[NSRunLoop currentRunLoop]
	performSelector: @selector(close)
	target: [self menu]
	argument: nil
	order: 500000
	modes: [NSArray arrayWithObjects: NSDefaultRunLoopMode, 
			NSModalPanelRunLoopMode,
			NSEventTrackingRunLoopMode, 
			nil]];
    }
}

- (void) sendEvent: (NSEvent*)theEvent
{
  NSEventType   type;

  type = [theEvent type];
  if (type == NSLeftMouseDown)
    {
      [self makeMainWindow];
      [self makeKeyWindow];
    }

  [super sendEvent: theEvent];
}


- (void) dealloc
{
  [self setMenu: nil];
  [super dealloc];
}
@end

@interface NSMenu (GormNSMenuPrivate)
- (NSString*) _locationKey;
@end

@implementation GormNSMenu
+ (GormNSMenu *) menuWithMenu: (NSMenu *)menu
{
  GormNSMenu *newMenu = [[GormNSMenu alloc] init];
  NSEnumerator *en = [[menu itemArray] objectEnumerator];
  NSMenuItem *item = nil;
 
  while((item = [en nextObject]) != nil)
    {
      [newMenu addItem: [item copy]];
    }

  [newMenu setTitle: [menu title]];

  return newMenu;
}

- (id) initWithTitle: (NSString *)aTitle
{
  if((self = [super initWithTitle: aTitle]) != nil)
    {
      [self setMenuRepresentation: 
	      [[GormNSMenuView alloc] initWithFrame: NSZeroRect]];
    }
  return self;
}

- (id) initWithCoder: (NSCoder *)coder
{
  if((self = [super initWithCoder: coder]) != nil)
    {
      NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
      [nc addObserver: self
	  selector: @selector(handleNotification:)
	  name: IBSelectionChangedNotification
	  object: nil];
    }

  return self;
}

- (void) handleNotification: (NSNotification *)notification
{
  id<IBEditors> object = [notification object];
  if(object != nil)
    {
      // don't call, unless it does respond...
      if([(id)object respondsToSelector: @selector(editedObject)])
	{
	  id edited = [object editedObject];
	  if(self != edited && [self _ownedByPopUp])
	    {
	      if([[self window] isVisible])
		{
		  [self close];
		}
	    }
	}
      else
	{
	  // Close anyway if the editor doesn't respond.
	  if([[self window] isVisible])
	    {
	      [self close];
	    }
	}
    }
}

- (BOOL) performKeyEquivalent: (NSEvent*)theEvent
{
  return NO;
}

- (NSPanel*) _createWindow
{
  NSPanel *win = [[GormNSMenuWindow alloc] 
		   initWithContentRect: NSZeroRect
		   styleMask: NSBorderlessWindowMask
		   backing: NSBackingStoreBuffered
		   defer: YES];
 
  [win setLevel: NSSubmenuWindowLevel];
  [win setExcludedFromWindowsMenu: YES];

  return win;
}

- (NSString *)className
{
  return @"NSMenu";
}

#ifdef DEBUG
// These methods are purely for debugging purposes...
/*
- (void) display
{
  NSDebugLog(@"In GormNSMenu display...");
  [super display];
}

- (id) retain
{
  NSLog(@"Being retained... %d: %@", [self retainCount], self);
  return [super retain];
}

- (oneway void) release
{
  NSLog(@"Being released... %d: %@", [self retainCount], self);
  [super release];
}
*/
#endif

- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self
					name: IBSelectionChangedNotification
					object: nil];
  [super dealloc];
}

// Override -autoenablesItems to disable menu validation for design menus in
// Gorm. This avoids disabling menu items by default in Gorm documents.
- (BOOL) realAutoenablesItems
{
  return [super autoenablesItems];
}

- (BOOL) autoenablesItems
{
  return NO;
}

- (NSString*) _locationKey
{
  if ([self supermenu] == nil)
    {
      if ([NSApp mainMenu] == self)
	{
	  return @"\033";	/* Root menu.	*/
	}
      else
	{
	  return nil;		/* Unused menu.	*/
	}
    }
  else if ([[self supermenu] supermenu] == nil)
    {
      return [NSString stringWithFormat: @"\033%@", [self title]];
    }
  else
    {
      return [[[self supermenu] _locationKey] stringByAppendingFormat: @"\033%@",
	[self title]];
    }
}
@end

@implementation NSMenu (GormNSMenu)
+ (id) allocSubstitute
{
  return [GormNSMenu alloc];
}
@end
