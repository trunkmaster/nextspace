/* 
   GormWindowSizeInspector.m
   
   Copyright (C) 1999-2005 Free Software Foundation, Inc.

   Author:  Richard frith-Macdonald (richard@brainstorm.co.uk>
   Date: 1999
   Author:  Gregory John Casamento <greg_casamento@yahoo.com>
   Date: 2005
   
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

/*
  July 2005 : Split inspector classes into separate files.
  Always use ok: revert: methods
  Clean up
  Author : Fabien Vallon <fabien@sonappart.net>
*/

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#include <GNUstepGUI/GSGormLoading.h>

#include "GormWindowSizeInspector.h"

/*
  IBObjectAdditions category for NSPanel
*/
@implementation	NSPanel (IBObjectAdditionsSize)
- (NSString*) sizeInspectorClassName
{
  return @"GormWindowSizeInspector";
}
@end

/*
  IBObjectAdditions category for NSWindow
*/
@implementation	NSWindow (IBObjectAdditionsSize)
- (NSString*) sizeInspectorClassName
{
  return @"GormWindowSizeInspector";
}
@end

@implementation GormWindowSizeInspector

- (id) init
{
  if ([super init] == nil)
    return nil;

  if ([NSBundle loadNibNamed: @"GormNSWindowSizeInspector" owner: self] == NO)
    {
      NSLog(@"Could not gorm GormNSWindowSizeInspector");
      return nil;
    }

  [[NSNotificationCenter defaultCenter] 
      addObserver: self
         selector: @selector(windowChangeNotification:)
             name: NSWindowDidMoveNotification
           object: object];

  [[NSNotificationCenter defaultCenter] 
      addObserver: self
         selector: @selector(windowChangeNotification:)
             name: NSWindowDidResizeNotification
           object: object];

  return self;
}

- (void) setObject: (id)obj
{
  [super setObject: obj];

  // set up tags...
  [top setTag: GSWindowMaxYMargin];
  [bottom setTag: GSWindowMinYMargin];
  [left setTag: GSWindowMinXMargin];
  [right setTag: GSWindowMaxXMargin];

  // reset information in forms...
}


/* Commit changes that the user makes in the Window Size Inspector */
- (void) ok: (id)sender
{
  /* Size */
  if (sender == sizeForm || sender == originForm)
    {
      NSRect rect;
      rect = NSMakeRect([[originForm cellAtIndex: 0] floatValue],
			[[originForm cellAtIndex: 1] floatValue],
			[[sizeForm cellAtIndex: 0] floatValue],
			[[sizeForm cellAtIndex: 1] floatValue]);

      [object setFrame: rect display: YES];
    }
  /* Autosave Name */
  else if (sender == autosaveName)
    {
      // TODO: is not saved yet (not encoded by object?)
      [object setFrameAutosaveName: [sender stringValue] ];
    }
  /* Min Size */
  else if (sender == minForm)
    {
      NSSize size;
      size = NSMakeSize([[minForm cellAtIndex: 0] floatValue],
			[[minForm cellAtIndex: 1] floatValue]);
      [object setMinSize: size];
    }
  /* Max Size */
  else if (sender == maxForm)
    {
      NSSize size;
      size = NSMakeSize([[maxForm cellAtIndex: 0] floatValue],
			[[maxForm cellAtIndex: 1] floatValue]);
      [object setMaxSize: size];
    }
  
  /* AutoPosition */
  else if ( sender == top || sender == bottom || 
	    sender == left || sender == right )
    {
      unsigned	mask = [sender tag];
      if ([sender state] == NSOnState)
	{
	  mask = [object autoPositionMask] | mask;
	}
      else
	{
	  mask = [object autoPositionMask] & ~mask;
	}
      [object setAutoPositionMask: mask];
    }

  [super ok: sender];
}

/* Sync from object ( NSWindow ) changes to the inspector   */
- (void) revert: (id)sender
{
  NSRect frame;
  NSSize size;
  unsigned int mask;

  if ( object == nil ) 
    return;

  // Abort editing of the fields, so that the new values can be
  // populated.
  [originForm abortEditing];
  [sizeForm abortEditing];
  [minForm abortEditing];
  [maxForm abortEditing];
    
  mask = [object autoPositionMask];

  frame = [object frame];
  [[originForm cellAtIndex: 0] setFloatValue: NSMinX(frame)];
  [[originForm cellAtIndex: 1] setFloatValue: NSMinY(frame)];
  [[sizeForm cellAtIndex: 0] setFloatValue: NSWidth(frame)];
  [[sizeForm cellAtIndex: 1] setFloatValue: NSHeight(frame)];

  // Autosave name
  [autosaveName setStringValue: [object frameAutosaveName] ];

  size = [object minSize];
  [[minForm cellAtIndex: 0] setFloatValue: size.width];
  [[minForm cellAtIndex: 1] setFloatValue: size.height];

  size = [object maxSize];
  [[maxForm cellAtIndex: 0] setFloatValue: size.width];
  [[maxForm cellAtIndex: 1] setFloatValue: size.height];

  if (mask & GSWindowMaxYMargin)
    [top setState: NSOnState];
  else
    [top setState: NSOffState];
  
  if (mask & GSWindowMinYMargin)
    [bottom setState: NSOnState];
  else
    [bottom setState: NSOffState];
  
  if (mask & GSWindowMaxXMargin)
    [right setState: NSOnState];
  else
    [right setState: NSOffState];
  
  if (mask & GSWindowMinXMargin)
    [left setState: NSOnState];
  else
    [left setState: NSOffState];

  [super revert:object];
}

- (void) windowChangeNotification: (NSNotification*)aNotification
{
  [self revert: nil];
}


/* Delegate for textFields /  Forms */
- (void)controlTextDidChange:(NSNotification *)aNotification
{
  [self ok: [aNotification object]];
}
@end
