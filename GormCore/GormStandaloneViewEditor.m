/* GormStandaloneViewEditor.m
 *
 * Copyright (C) 2009 Free Software Foundation, Inc.
 *
 * Author:	Gregory Casamento <greg.casamento@gmail.com>
 * Date:	2009
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

#include <GormCore/GormPrivate.h>
#include <GormCore/GormStandaloneViewEditor.h>
#include <GormCore/GormDefines.h>
#include <GormCore/GormViewKnobs.h>

static NSImage *verticalImage;
static NSImage *horizontalImage;

@class GormEditorToParent;

@implementation GormStandaloneViewEditor

- (void) mouseDown: (NSEvent *) theEvent
{
  BOOL onKnob = NO;

  if ([parent respondsToSelector: @selector(selection)] &&
      [[parent selection] containsObject: _editedObject])
    {
      IBKnobPosition	knob = IBNoneKnobPosition;
      NSPoint mouseDownPoint = 
	[self convertPoint: [theEvent locationInWindow]
	      fromView: nil];
      knob = GormKnobHitInRect([self bounds], 
			       mouseDownPoint);
      if (knob != IBNoneKnobPosition)
	onKnob = YES;
    }
  if (onKnob == YES)
    {
      if (parent)
	return [parent mouseDown: theEvent];
      else
	return [self noResponderFor: @selector(mouseDown:)];
    }
  
  if ([parent isOpened] == NO)
    {
      NSDebugLog(@"md %@ calling my parent %@", self, parent);
      [parent mouseDown: theEvent];
      return;
    }

  // are we on the knob of a selected view ?
  {
    NSInteger count = [selection count];
    NSInteger i;
    GormViewEditor *knobView = nil;
    IBKnobPosition	knob = IBNoneKnobPosition;
    NSPoint mouseDownPoint;

    for ( i = 0; i < count; i++ )
      {
	mouseDownPoint = [[[selection objectAtIndex: i] superview] 
			   convertPoint: [theEvent locationInWindow]
			   fromView: nil];

	knob = GormKnobHitInRect([[selection objectAtIndex: i] frame], 
				 mouseDownPoint);
	  
	if (knob != IBNoneKnobPosition)
	  {
	    knobView = [selection objectAtIndex: i];
	    [self selectObjects: [NSMutableArray arrayWithObject: knobView]];
	    // we should set knobView as the only view selected
	    break;
	  }
      }
    
    if ( openedSubeditor != nil )
      {
	mouseDownPoint = [[openedSubeditor superview] 
			   convertPoint: [theEvent locationInWindow]
			   fromView: nil];

	knob = GormKnobHitInRect([openedSubeditor frame], 
				 mouseDownPoint);
	if (knob != IBNoneKnobPosition)
	  {
	    knobView = openedSubeditor;
	    // we should take back the selection
	    // we should select openedSubeditor only
	    [self selectObjects: [NSMutableArray arrayWithObject: knobView]];
	    [[self window] disableFlushWindow];
	    [self display];
	    [[self window] enableFlushWindow];
	    [[self window] flushWindow];
	  }
      }


    if (knobView != nil)
      {
	[self handleMouseOnKnob: knob
	      ofView: knobView
	      withEvent: theEvent];
	[self setNeedsDisplay: YES];
	return;
      }
  }

  // get the view we are on
  {
    GormViewEditor *editorView;

    {
      NSPoint mouseDownPoint;
      NSView *result = nil;
      GormViewEditor *theParent = nil;
      
      mouseDownPoint = [self
			 convertPoint: [theEvent locationInWindow]
			 fromView: nil];
      
      result = [_editedObject hitTest: mouseDownPoint];
      
      // we should get a result which is a direct subeditor
      {
	id temp = result;

	if ([temp isKindOfClass: [GormViewEditor class]])
	  theParent = [(GormViewEditor *)temp parent];
	while ((temp != nil) && (theParent != self) && (temp != self))
	  {
	    temp = [temp superview];
	    while (![temp isKindOfClass: [GormViewEditor class]])
	      {
		temp = [temp superview];
	      }
	    theParent = [(GormViewEditor *)temp parent];
	  }
	if (temp != nil)
	  {
	    result = temp;
	  }
	else
	  {
	    NSDebugLog(@"WARNING -- strange case");
	    result = self;
	  }
      }


      if ([result isKindOfClass: [GormViewEditor class]])
	{
	}
      else
	{
	  result = nil;
	}

      // this is the direct subeditor the mouse was clicked on
      // (or self)
      editorView = (GormViewEditor *)result;
    }

    if (([theEvent clickCount] == 2) 
	&& [editorView isKindOfClass: [GormViewWithSubviewsEditor class]]
	&& ([(id)editorView canBeOpened] == YES)
	&& (editorView != self))
      // Let's open a subeditor       
      {
	[(GormViewWithSubviewsEditor *) editorView setOpened: YES];
	[self silentlyResetSelection];
	openedSubeditor = (GormViewWithSubviewsEditor *) editorView;
	[self setNeedsDisplay: YES];
	return;
      }

    if (editorView != self)
      {
	[self handleMouseOnView: editorView
	      withEvent: theEvent];
      }
    else // editorView == self
      {
	NSEvent *e;
	unsigned eventMask;
	NSDate *future = [NSDate distantFuture];
	NSRect oldRect = NSZeroRect;
	NSPoint p, oldp;
	NSRect r = NSZeroRect;
	float x, y, w, h;
	
	oldp = [self convertPoint: [theEvent locationInWindow] fromView: nil];

	eventMask = NSLeftMouseUpMask | NSLeftMouseDraggedMask;

	
	if (!([theEvent modifierFlags] & NSShiftKeyMask))
	  [self selectObjects: [NSMutableArray array]];
	[[self window] disableFlushWindow];
	[self setNeedsDisplay: YES];
	[self displayIfNeeded];
	[[self window] enableFlushWindow];
	[[self window] flushWindowIfNeeded];

	e = [NSApp nextEventMatchingMask: eventMask
		   untilDate: future
		   inMode: NSEventTrackingRunLoopMode
		   dequeue: YES];
	[self lockFocus];
	while ([e type] != NSLeftMouseUp)
	  {
	    p = [self convertPoint: [e locationInWindow] fromView: nil];
	    
	    x = (p.x >= oldp.x) ? oldp.x : p.x;
	    y = (p.y >= oldp.y) ? oldp.y : p.y;
	    w = max(p.x, oldp.x) - min(p.x, oldp.x);
	    w = (w == 0) ? 1 : w;
	    h = max(p.y, oldp.y) - min(p.y, oldp.y);
	    h = (h == 0) ? 1 : h;
	    
	    r = NSMakeRect(x, y, w, h);

	    if (NSEqualRects(oldRect, NSZeroRect) == NO)
	      {
		[verticalImage 
		  compositeToPoint: NSMakePoint(NSMinX(oldRect), NSMinY(oldRect))
		  fromRect: NSMakeRect(0.0, 0.0, 1.0, oldRect.size.height)
		  operation: NSCompositeCopy];
		[verticalImage
		  compositeToPoint: NSMakePoint(NSMaxX(oldRect)-1, NSMinY(oldRect))
		  fromRect: NSMakeRect(1.0, 0.0, 1.0, oldRect.size.height)
		  operation: NSCompositeCopy];
		
		[horizontalImage 
		  compositeToPoint: NSMakePoint(NSMinX(oldRect), NSMinY(oldRect))
		  fromRect: NSMakeRect(0.0, 0.0, oldRect.size.width, 1.0)
		  operation: NSCompositeCopy];
		[horizontalImage
		  compositeToPoint: NSMakePoint(NSMinX(oldRect), NSMaxY(oldRect)-1)
		  fromRect: NSMakeRect(0.0, 1.0, oldRect.size.width, 1.0)
		  operation: NSCompositeCopy];
	      }

	    {
	      NSRect wr;
	      wr = [self convertRect: r
			 toView: nil];
	      
	      [verticalImage lockFocus];
	      NSCopyBits([[self window] gState],
			 NSMakeRect(NSMinX(wr), NSMinY(wr),
				    1.0, r.size.height),
			 NSMakePoint(0.0, 0.0));
	      NSCopyBits([[self window] gState],
			 NSMakeRect(NSMaxX(wr)-1, NSMinY(wr),
				    1.0, r.size.height),
			 NSMakePoint(1.0, 0.0));
	      [verticalImage unlockFocus];

	      [horizontalImage lockFocus];
	      NSCopyBits([[self window] gState],
			 NSMakeRect(NSMinX(wr), NSMinY(wr),
				    r.size.width, 1.0),
			 NSMakePoint(0.0, 0.0));
	      NSCopyBits([[self window] gState],
			 NSMakeRect(NSMinX(wr), NSMaxY(wr)-1,
				    r.size.width, 1.0),
			 NSMakePoint(0.0, 1.0));
	      [horizontalImage unlockFocus];
	    }
	    
	    [[NSColor darkGrayColor] set];
	    NSFrameRect(r);
	    oldRect = r;
	    
	    [[self window] enableFlushWindow];
	    
	    [[self window] flushWindow];
	    [[self window] disableFlushWindow];


	    e = [NSApp nextEventMatchingMask: eventMask
		       untilDate: future
		       inMode: NSEventTrackingRunLoopMode
		       dequeue: YES];
	  }

	if (NSEqualRects(r, NSZeroRect) == NO)
	  {
	    [verticalImage 
	      compositeToPoint: NSMakePoint(NSMinX(r), NSMinY(r))
	      fromRect: NSMakeRect(0.0, 0.0, 1.0, r.size.height)
	      operation: NSCompositeCopy];
	    [verticalImage
	      compositeToPoint: NSMakePoint(NSMaxX(r)-1, NSMinY(r))
	      fromRect: NSMakeRect(1.0, 0.0, 1.0, r.size.height)
	      operation: NSCompositeCopy];
	    
	    [horizontalImage 
	      compositeToPoint: NSMakePoint(NSMinX(r), NSMinY(r))
	      fromRect: NSMakeRect(0.0, 0.0, r.size.width, 1.0)
	      operation: NSCompositeCopy];
	    [horizontalImage
	      compositeToPoint: NSMakePoint(NSMinX(r), NSMaxY(r)-1)
	      fromRect: NSMakeRect(0.0, 1.0, r.size.width, 1.0)
	      operation: NSCompositeCopy];
	  }


	{
	  NSMutableArray *array;
	  NSEnumerator *enumerator;
	  NSView *subview;


	  if ([theEvent modifierFlags] & NSShiftKeyMask)
	    array = [NSMutableArray arrayWithArray: selection];
	  else
	    array = [NSMutableArray arrayWithCapacity: 8];
	  enumerator = [[_editedObject subviews] objectEnumerator];
	  while ((subview = [enumerator nextObject]) != nil)
	    {
	      if ((NSIntersectsRect(r, [subview frame]) == YES)
		  && [subview isKindOfClass: [GormViewEditor class]])
		{
		  [array addObject: subview];
		}
	    }

	  if ([array count] > 0)
	    {
	      [self selectObjects: array];
	    }
	  [self displayIfNeeded];
	  
	  [self unlockFocus];
	  [[self window] enableFlushWindow];
	  
	  [[self window] flushWindow];
	}

      }
    
  }
}

@end
