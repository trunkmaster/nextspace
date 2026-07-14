/* GormViewSizeInspector.m
 *
 * Copyright (C) 1999 Free Software Foundation, Inc.
 *
 * Author:	Richard Frith-Macdonald <richard@brainstrom.co.uk>
 * Date:	1999
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

#include <InterfaceBuilder/InterfaceBuilder.h>

#include "GormPrivate.h"
#include "GormViewKnobs.h"
#include "GormViewSizeInspector.h"
#include "GormViewWindow.h"

@implementation GormViewSizeInspector

NSImage	*eHCoil = nil;
NSImage	*eVCoil = nil;
NSImage	*eHLine = nil;
NSImage	*eVLine = nil;
NSImage	*mHCoil = nil;
NSImage	*mVCoil = nil;
NSImage	*mHLine = nil;
NSImage	*mVLine = nil;

+ (void) initialize
{
  if (self == [GormViewSizeInspector class])
    {
      NSBundle	*bundle = [NSBundle bundleForClass: self];
      NSString	*path;

      path = [bundle pathForImageResource: @"GormEHCoil"];
      eHCoil = [[NSImage alloc] initWithContentsOfFile: path];
      path = [bundle pathForImageResource: @"GormEVCoil"];
      eVCoil = [[NSImage alloc] initWithContentsOfFile: path];
      path = [bundle pathForImageResource: @"GormEHLine"];
      eHLine = [[NSImage alloc] initWithContentsOfFile: path];
      path = [bundle pathForImageResource: @"GormEVLine"];
      eVLine = [[NSImage alloc] initWithContentsOfFile: path];
      path = [bundle pathForImageResource: @"GormMHCoil"];
      mHCoil = [[NSImage alloc] initWithContentsOfFile: path];
      path = [bundle pathForImageResource: @"GormMVCoil"];
      mVCoil = [[NSImage alloc] initWithContentsOfFile: path];
      path = [bundle pathForImageResource: @"GormMHLine"];
      mHLine = [[NSImage alloc] initWithContentsOfFile: path];
      path = [bundle pathForImageResource: @"GormMVLine"];
      mVLine = [[NSImage alloc] initWithContentsOfFile: path];
    }
}

- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  RELEASE(window);
  [super dealloc];
}

- (id) init
{
  self = [super init];
  if (self != nil)
    {
      NSBundle	*bundle = [NSBundle bundleForClass: [self class]];
      if ([bundle loadNibNamed: @"GormViewSizeInspector" 
			 owner: self
	       topLevelObjects: NULL] == NO)
	{
	  NSLog(@"Could not open gorm GormViewSizeInspector");
	  NSLog(@"self %@", self);
	  return nil;
	}

      // set the tags...
      [top setTag: NSViewMaxYMargin];  
      [bottom setTag: NSViewMinYMargin];
      [right setTag: NSViewMaxXMargin];
      [left setTag: NSViewMinXMargin];
      [width setTag: NSViewWidthSizable];
      [height setTag: NSViewHeightSizable];

      [[NSNotificationCenter defaultCenter] 
        addObserver: self
           selector: @selector(viewFrameChangeNotification:)
               name: NSViewFrameDidChangeNotification
             object: nil];
      [[NSNotificationCenter defaultCenter] 
	addObserver: self
	   selector: @selector(controlTextDidEndEditing:)
	       name: NSControlTextDidEndEditingNotification
	     object: nil];

    }
  return self;
}

- (void) _setValuesFromControl: control
{
  if (control == sizeForm)
    {
      id<IBDocuments> document = [(id<IB>)[NSApp delegate] activeDocument];
      NSRect rect;

      // Update the document as edited...
      [document touch];

      rect = NSMakeRect([[control cellAtIndex: 0] floatValue],
                        [[control cellAtIndex: 1] floatValue],
                        [[control cellAtIndex: 2] floatValue],
                        [[control cellAtIndex: 3] floatValue]);

      if (NSEqualRects(rect, [object frame]) == NO)
	{
	  NSRect oldFrame = [object frame];

	  [object setFrame: rect];
	  [object display];

	  if ([object superview])
	    [[object superview] displayRect:
				  GormExtBoundsForRect(oldFrame)];
	  [[object superview] lockFocus];
	  GormDrawKnobsForRect([object frame]);
	  GormShowFastKnobFills();
	  [[object superview] unlockFocus];
	  [[object window] flushWindow];
	}
    }
}

- (void) _getValuesFromObject: anObject
{
  NSRect frame;

  if (anObject != object)
    return;

  [sizeForm setEnabled: YES];

  // stop editing so that the new values can be populated.
  [sizeForm abortEditing];

  frame = [anObject frame];
  [[sizeForm cellAtIndex: 0] setFloatValue: NSMinX(frame)];
  [[sizeForm cellAtIndex: 1] setFloatValue: NSMinY(frame)];
  [[sizeForm cellAtIndex: 2] setFloatValue: NSWidth(frame)];
  [[sizeForm cellAtIndex: 3] setFloatValue: NSHeight(frame)];
}

- (void) controlTextDidEndEditing: (NSNotification*)aNotification
{
  id notifier = [aNotification object];
  [super ok: notifier];
  [self _setValuesFromControl: notifier];
}

- (void) viewFrameChangeNotification: (NSNotification*)aNotification
{
  id notifier = [aNotification object];
  
  [self _getValuesFromObject: notifier];
}

- (void) setAutosize: (id)sender
{
  unsigned	mask = [sender tag];
  id<IBDocuments> document = [(id<IB>)[NSApp delegate] activeDocument];
  [document touch];
  if ([sender state] == NSOnState)
    {
      mask = [object autoresizingMask] | mask;
    }
  else
    {
      mask = [object autoresizingMask] & ~mask;
    }
  [object setAutoresizingMask: mask];
}

- (void) setObject: (id)anObject
{
  if ((object != nil) && (anObject != object))
    [object setPostsFrameChangedNotifications: NO];

  if (anObject != nil && anObject != object)
    {
      NSRect frame;
      unsigned	mask = [anObject autoresizingMask];

      ASSIGN(object, anObject);
      if (mask & NSViewMaxYMargin)
	[top setState: NSOnState];
      else
	[top setState: NSOffState];

      if (mask & NSViewMinYMargin)
	[bottom setState: NSOnState];
      else
	[bottom setState: NSOffState];

      if (mask & NSViewMaxXMargin)
	[right setState: NSOnState];
      else
	[right setState: NSOffState];

      if (mask & NSViewMinXMargin)
	[left setState: NSOnState];
      else
	[left setState: NSOffState];

      if (mask & NSViewWidthSizable)
	[width setState: NSOnState];
      else
	[width setState: NSOffState];

      if (mask & NSViewHeightSizable)
	[height setState: NSOnState];
      else
	[height setState: NSOffState];

      frame = [anObject frame];
      [[sizeForm cellAtIndex: 0] setFloatValue: NSMinX(frame)];
      [[sizeForm cellAtIndex: 1] setFloatValue: NSMinY(frame)];
      [[sizeForm cellAtIndex: 2] setFloatValue: NSWidth(frame)];
      [[sizeForm cellAtIndex: 3] setFloatValue: NSHeight(frame)];
      [anObject setPostsFrameChangedNotifications: YES];

      /*
      if([[anObject window] isKindOfClass: [GormViewWindow class]] ||
	 [anObject window] == nil)
	{ 
	  [[sizeForm cellAtIndex: 0] setEnabled: NO]; 
	  [[sizeForm cellAtIndex: 1] setEnabled: NO]; 
	  [[sizeForm cellAtIndex: 2] setEnabled: NO]; 
	  [[sizeForm cellAtIndex: 3] setEnabled: NO]; 

	  [[sizeForm cellAtIndex: 0] setEditable: NO]; 
	  [[sizeForm cellAtIndex: 1] setEditable: NO]; 
	  [[sizeForm cellAtIndex: 2] setEditable: NO]; 
	  [[sizeForm cellAtIndex: 3] setEditable: NO]; 
	}
      else
      */
	{
	  [[sizeForm cellAtIndex: 0] setEnabled: YES]; 
	  [[sizeForm cellAtIndex: 1] setEnabled: YES]; 
	  [[sizeForm cellAtIndex: 2] setEnabled: YES]; 
	  [[sizeForm cellAtIndex: 3] setEnabled: YES]; 

	  [[sizeForm cellAtIndex: 0] setEditable: YES]; 
	  [[sizeForm cellAtIndex: 1] setEditable: YES]; 
	  [[sizeForm cellAtIndex: 2] setEditable: YES]; 
	  [[sizeForm cellAtIndex: 3] setEditable: YES]; 
	}
    }
}
@end
