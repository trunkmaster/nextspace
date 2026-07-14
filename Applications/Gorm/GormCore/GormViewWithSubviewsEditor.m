/* GormViewWithSubviewsEditor.m
 *
 * Copyright (C) 2002 Free Software Foundation, Inc.
 *
 * Author:	Pierre-Yves Rivaille <pyrivail@ens-lyon.fr>
 * Date:	2002
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
#include <GormCore/GormViewWithSubviewsEditor.h>
#include <GormCore/GormFontViewController.h>
#include <GormCore/GormViewKnobs.h>

@class GormEditorToParent;

@interface GormViewEditor (Private)
- (NSRect) _displayMovingFrameWithHint: (NSRect) frame
                     andPlacementInfo: (GormPlacementInfo *)gpi;
@end

@implementation GormViewWithSubviewsEditor

- (id) initWithObject: (id)anObject 
	   inDocument: (id<IBDocuments>)aDocument
{
  opened = NO;
  openedSubeditor = nil;

  if ((self = [super initWithObject: anObject
		     inDocument: aDocument]) == nil)
    {
      return nil;
    }
  
  selection = [[NSMutableArray alloc] initWithCapacity: 5];
  [self registerForDraggedTypes: [NSArray arrayWithObjects:
					    IBViewPboardType, 
					  GormLinkPboardType, 
					  IBFormatterPboardType, 
					  nil]];
  return self;
}

- (void) close
{
  if (closed == NO)
    {
      [self deactivate];
      
      [self closeSubeditors];
      [document editor: self didCloseForObject: _editedObject];
      closed = YES;
    }
  else
    {
      NSDebugLog(@"%@ close but already closed", self);
    }
}

- (void) deactivateSubeditors
{
  NSArray *subeditorConnections = 
    [NSArray arrayWithArray: [document connectorsForDestination: self
				       ofClass: [GormEditorToParent class]]];  
  NSInteger count = [subeditorConnections count];
  NSInteger i = 0;

  for ( i = 0; i < count; i ++ )
    {
      [[[subeditorConnections objectAtIndex: i] source] deactivate];
    }
}

- (void) closeSubeditors
{
  NSArray *subeditorConnections = 
    [NSArray arrayWithArray: [document connectorsForDestination: self
				       ofClass: [GormEditorToParent class]]];
  NSInteger count = [subeditorConnections count];
  NSInteger i = 0;

  for ( i = 0; i < count; i ++ )
    {
      [[[subeditorConnections objectAtIndex: i] source] close];
    }
}

- (BOOL) canBeOpened
{
  return YES;
}

- (BOOL) isOpened
{
  return opened;
}


- (void) setOpened: (BOOL) value
{
  opened = value;

  if (value == YES)
    {
      [self silentlyResetSelection];
      // [document setSelectionFromEditor: self];      
    }
  else
    {
      if (openedSubeditor != nil)
	{
	  [self makeSubeditorResign];
	  [self silentlyResetSelection];
	}
      else
	{
	  [self silentlyResetSelection];
	}
      [self setNeedsDisplay: YES];
    }
}

/*
 *  
 */
- (void) openParentEditor
{
  if ([parent respondsToSelector: @selector(setOpenedSubeditor:)])
    {
      [parent setOpenedSubeditor: self];
    }
}

- (void) setOpenedSubeditor: (GormViewWithSubviewsEditor *) newEditor
{
  [self silentlyResetSelection];

  if (opened == NO)
    {
      [self openParentEditor];
    }

  opened = YES;

  if (newEditor != openedSubeditor)
    {
      [self makeSubeditorResign];
    }
  
  openedSubeditor = newEditor;

  [self setNeedsDisplay: YES];
}

/*
 *  take the selection from the subeditors
 */
- (void) makeSubeditorResign
{
  if (openedSubeditor != nil)
    {
      [openedSubeditor makeSubeditorResign];
      [openedSubeditor setOpened: NO];
      openedSubeditor = nil;
    }
}


- (void) makeSelectionVisible: (BOOL) value
{
}

- (void) changeFont: (id)sender
{
  NSEnumerator *enumerator = [[self selection] objectEnumerator];
  id anObject;
  NSFont *newFont;

  while ((anObject = [enumerator nextObject]))
    {
      if ([anObject respondsToSelector: @selector(font)]
	  && [anObject respondsToSelector: @selector(setFont:)])
	{
	  newFont = [sender convertFont: [anObject font]];
	  newFont = [[GormFontViewController sharedGormFontViewController] 
	    convertFont: newFont];
	  [anObject setFont: newFont];
	}
    }

  return;
}

- (NSArray*) selection
{
  NSInteger i;
  NSInteger count = [selection count];
  NSMutableArray *result = [NSMutableArray arrayWithCapacity: count];
  
  if (count != 0)
    {
      for (i = 0; i < count; i++)
	{
	  if ([[selection objectAtIndex: i] 
		respondsToSelector: @selector(editedObject)])
	    [result addObject: [[selection objectAtIndex: i] editedObject]];
	  else
	    [result addObject: [selection objectAtIndex: i]];
	}
    }
  else
    {
      if ([self respondsToSelector: @selector(editedObject)])
	[result addObject: [self editedObject]];
      else
	[result addObject: self];
    }

  return result;
}

- (void) selectObjects: (NSArray *) objects
{
  NSInteger i;
  NSInteger count = [objects count];
  TEST_RELEASE(selection);
  
  selection = [[NSMutableArray alloc] initWithCapacity: [objects count]];

  for (i = 0; i < count; i++)
    {
      [selection addObject: [objects objectAtIndex: i]];
    }

  [self makeSubeditorResign];

  opened = YES;

  [self openParentEditor];

  [document setSelectionFromEditor: self];

  [self setNeedsDisplay: YES];
}

- (void) silentlyResetSelection
{
  TEST_RELEASE(selection);
  
  selection = [[NSMutableArray alloc] initWithCapacity: 5];
  
}

- (void) copySelection
{
  if ([selection count] > 0)
    {
      [document copyObjects: [self selection]
		       type: IBViewPboardType
	       toPasteboard: [NSPasteboard generalPasteboard]];
    }
}

- (BOOL) acceptsFirstResponder
{
  return YES;
}

- (void) drawSelection
{
  // doesn nothing.
}

- (NSUInteger) selectionCount
{
  return [selection count];
}

- (NSDragOperation) draggingEntered: (id<NSDraggingInfo>)sender
{
  NSRect rect = [_editedObject bounds];
  NSPoint loc = [sender draggingLocation];
  NSPasteboard	*dragPb;
  NSArray	*types;
  
  dragPb = [sender draggingPasteboard];
  types = [dragPb types];
  loc = [_editedObject convertPoint: loc fromView: nil];

  if ([types containsObject: GormLinkPboardType] == YES)
    {
      return [super draggingEntered: sender];
    }

  if (NSMouseInRect(loc, [_editedObject bounds], NO) == NO)
    {
      return NSDragOperationNone;
    }
  else
    {
      rect.origin.x += 3;
      rect.origin.y += 2;
      rect.size.width -= 5;
      rect.size.height -= 5;
      
      [_editedObject lockFocus];
      
      [[NSColor darkGrayColor] set];
      NSFrameRectWithWidth(rect, 2);
      
      [_editedObject unlockFocus];
      [[self window] flushWindow];
      return NSDragOperationCopy;
    }
}

- (void) draggingExited: (id<NSDraggingInfo>)sender
{
  NSPasteboard	*dragPb;
  NSArray	*types;
  NSRect         rect;

  dragPb = [sender draggingPasteboard];
  types = [dragPb types];
  
  if ([types containsObject: GormLinkPboardType] == YES)
    {
      [super draggingExited: sender];
      return;
    }


  rect = [_editedObject bounds];
  rect.origin.x += 3;
  rect.origin.y += 2;
  rect.size.width -= 5;
  rect.size.height -= 5;
 
  rect.origin.x --;
  rect.size.width ++;
  rect.size.height ++;

  [[self window] disableFlushWindow];
  [self displayRect: 
	  [_editedObject convertRect: rect
			 toView: self]];
  [[self window] enableFlushWindow];
  [[self window] flushWindow];
}

- (NSDragOperation) draggingUpdated: (id<NSDraggingInfo>)sender
{
  NSPoint loc = [sender draggingLocation];
  NSRect rect = [_editedObject bounds];
  NSPasteboard	*dragPb;
  NSArray	*types;
  
  dragPb = [sender draggingPasteboard];
  types = [dragPb types];
  loc = [_editedObject 
	  convertPoint: loc fromView: nil];

  if ([types containsObject: GormLinkPboardType] == YES)
    {
      return [super draggingUpdated: sender];
    }

  rect.origin.x += 3;
  rect.origin.y += 2;
  rect.size.width -= 5;
  rect.size.height -= 5;

  if (NSMouseInRect(loc, [_editedObject bounds], NO) == NO)
    {
      [[self window] disableFlushWindow];
      rect.origin.x --;
      rect.size.width ++;
      rect.size.height ++;
      [self displayRect: 
	      [_editedObject convertRect: rect
			     toView: self]];
      [[self window] enableFlushWindow];
      [[self window] flushWindow];
      return NSDragOperationNone;
    }
  else
    {
      [_editedObject lockFocus];
      
      [[NSColor darkGrayColor] set];
      NSFrameRectWithWidth(rect, 2);
      
      [_editedObject unlockFocus];
      [[self window] flushWindow];
      return NSDragOperationCopy;
    }
}

- (BOOL) prepareForDragOperation: (id<NSDraggingInfo>)sender
{
  NSString		*dragType;
  NSArray *types;
  NSPasteboard		*dragPb;

  dragPb = [sender draggingPasteboard];

  types = [dragPb types];
  
  if ([types containsObject: IBViewPboardType] == YES)
    {
      dragType = IBViewPboardType;
    }
  else if ([types containsObject: GormLinkPboardType] == YES)
    {
      dragType = GormLinkPboardType;
      return [super prepareForDragOperation: sender];
    }
  else
    {
      dragType = nil;
    }

  if (dragType == IBViewPboardType)
    {
      /*
       * We can accept views dropped anywhere.
       */
      NSPoint		loc = [sender draggingLocation];
      loc = [_editedObject  
	      convertPoint: loc fromView: nil];
      if (NSMouseInRect(loc, [_editedObject bounds], NO) == NO)
	{
	  return NO;
	}
      
      return YES;
    }
  
  return NO;
}

- (BOOL) performDragOperation: (id<NSDraggingInfo>)sender
{
  NSString		*dragType;
  NSPasteboard		*dragPb;
  NSArray *types;

  dragPb = [sender draggingPasteboard];

  types = [dragPb types];
  
  if ([types containsObject: IBViewPboardType] == YES)
    {
      dragType = IBViewPboardType;
    }
  else if ([types containsObject: GormLinkPboardType] == YES)
    {
      dragType = GormLinkPboardType;
    }
  else
    {
      dragType = nil;
    }

  if (dragType == IBViewPboardType)
    {
      NSPoint		loc = [sender draggingLocation];
      NSArray		*views;
      NSEnumerator	*enumerator;
      NSView		*sub;

      /*
       * Ask the document to get the dragged views from the pasteboard and add
       * them to it's collection of known objects.
       */
      views = [document pasteType: IBViewPboardType
		   fromPasteboard: dragPb
			   parent: _editedObject];
      /*
       * Now make all the views subviews of ourself, setting their origin to
       * be the point at which they were dropped (converted from window
       * coordinates to our own coordinates).
       */
      loc = [_editedObject convertPoint: loc fromView: nil];
      if (NSMouseInRect(loc, [_editedObject bounds], NO) == NO)
	{
	  // Dropped outside our view frame
	  NSLog(@"Dropped outside current edit view");
	  dragType = nil;
	  return NO;
	}
      enumerator = [views objectEnumerator];
      while ((sub = [enumerator nextObject]) != nil)
	{
	  NSRect	rect = [sub frame];
	  
	  rect.origin = [_editedObject
			  convertPoint: [sender draggedImageLocation]
			  fromView: nil];
	  rect.origin.x = (int) rect.origin.x;
	  rect.origin.y = (int) rect.origin.y;
	  rect.size.width = (int) rect.size.width;
	  rect.size.height = (int) rect.size.height;
	  [sub setFrame: rect];

	  [_editedObject addSubview: sub];
	  
	  {
	    id editor;
	    editor = [document editorForObject: sub 
			       inEditor: self 
			       create: YES];
	    [self selectObjects: 
		    [NSArray arrayWithObject: editor]];
	  }
	}
    }

  return YES;
}

- (void) handleMouseOnKnob: (IBKnobPosition) knob
		    ofView: (GormViewEditor *) view
		 withEvent: (NSEvent *) theEvent
{
  NSPoint	mouseDownPoint = [[view superview]
				   convertPoint: [theEvent locationInWindow]
				   fromView: nil];
  NSDate	*future = [NSDate distantFuture];
  BOOL		acceptsMouseMoved;
  unsigned	eventMask;
  NSEvent	*e;
  NSEventType	eType;
  NSRect	r = [view frame];
  NSPoint	maxMouse;
  NSPoint	minMouse;
  NSRect	firstRect = [view frame];
  NSRect	lastRect = [view frame];
  NSPoint	lastPoint = mouseDownPoint;
  NSPoint	point = mouseDownPoint;
  NSView        *superview;
  GormPlacementInfo *gpi;

  eventMask = NSLeftMouseUpMask | NSLeftMouseDraggedMask
    | NSMouseMovedMask | NSPeriodicMask;
  
  // Save window state info.
  acceptsMouseMoved = [[self window] acceptsMouseMovedEvents];
  [[self window] setAcceptsMouseMovedEvents: YES];

  superview = [view superview];
  [superview lockFocus];

  _displaySelection = NO;

  /*
   * Get size limits for resizing or moving and calculate maximum
   * and minimum mouse positions that won't cause us to exceed
   * those limits.
   */
  {
    NSSize	max = [view maximumSizeFromKnobPosition: knob];
    NSSize	min = [view minimumSizeFromKnobPosition: knob];
	  
    r = [superview frame];
      
    minMouse = NSMakePoint(NSMinX(r), NSMinY(r));
    maxMouse = NSMakePoint(NSMaxX(r), NSMaxY(r));
    r = [view frame];
    switch (knob)
      {
      case IBBottomLeftKnobPosition:
	maxMouse.x = NSMaxX(r) - min.width;
	minMouse.x = NSMaxX(r) - max.width;
	maxMouse.y = NSMaxY(r) - min.height;
	minMouse.y = NSMaxY(r) - max.height;
	break;
	      
      case IBMiddleLeftKnobPosition:
	maxMouse.x = NSMaxX(r) - min.width;
	minMouse.x = NSMaxX(r) - max.width;
	break;
	      
      case IBTopLeftKnobPosition:
	maxMouse.x = NSMaxX(r) - min.width;
	minMouse.x = NSMaxX(r) - max.width;
	maxMouse.y = NSMinY(r) + max.height;
	minMouse.y = NSMinY(r) + min.height;
	break;
	      
      case IBTopMiddleKnobPosition:
	maxMouse.y = NSMinY(r) + max.height;
	minMouse.y = NSMinY(r) + min.height;
	break;
	      
      case IBTopRightKnobPosition:
	maxMouse.x = NSMinX(r) + max.width;
	minMouse.x = NSMinX(r) + min.width;
	maxMouse.y = NSMinY(r) + max.height;
	minMouse.y = NSMinY(r) + min.height;
	break;
	      
      case IBMiddleRightKnobPosition:
	maxMouse.x = NSMinX(r) + max.width;
	minMouse.x = NSMinX(r) + min.width;
	break;
	      
      case IBBottomRightKnobPosition:
	maxMouse.x = NSMinX(r) + max.width;
	minMouse.x = NSMinX(r) + min.width;
	maxMouse.y = NSMaxY(r) - min.height;
	minMouse.y = NSMaxY(r) - max.height;
	break;
	      
      case IBBottomMiddleKnobPosition:
	maxMouse.y = NSMaxY(r) - min.height;
	minMouse.y = NSMaxY(r) - max.height;
	break;

      case IBNoneKnobPosition:
	break;	/* NOT REACHED */
      }
  }



  /* Set the arrows cursor in case it might be something else */
  [[NSCursor arrowCursor] push];

  /*
   * Track mouse movements until left mouse up.
   * While we keep track of all mouse movements, we only act on a
   * movement when a periodic event arives (every 20th of a second)
   * in order to avoid excessive amounts of drawing.
   */
  [NSEvent startPeriodicEventsAfterDelay: 0.1 withPeriod: 0.05];
  e = [NSApp nextEventMatchingMask: eventMask
	     untilDate: future
	     inMode: NSEventTrackingRunLoopMode
	     dequeue: YES];
  eType = [e type];

  if ([view respondsToSelector: @selector(initializeResizingInFrame:withKnob:)])
    {
      gpi = [(id)view initializeResizingInFrame: superview
		  withKnob: knob];
    }
  else
    {
      gpi = nil;
    }

  while (eType != NSLeftMouseUp)
    {
      if (eType != NSPeriodic)
	{
	  point = [superview convertPoint: [e locationInWindow]
			     fromView: nil];
	  /*
	  if (edit_view != self)
	    point = _constrainPointToBounds(point, [edit_view bounds]);
	  */
	}
      else if (NSEqualPoints(point, lastPoint) == NO)
	{
	  [[self window] disableFlushWindow];

	  {
	    float	xDiff;
	    float	yDiff;

	    if (point.x < minMouse.x)
	      point.x = minMouse.x;
	    if (point.y < minMouse.y)
	      point.y = minMouse.y;
	    if (point.x > maxMouse.x)
	      point.x = maxMouse.x;
	    if (point.y > maxMouse.y)
	      point.y = maxMouse.y;

	    xDiff = point.x - lastPoint.x;
	    yDiff = point.y - lastPoint.y;
	    lastPoint = point;

	    {
	      r = GormExtBoundsForRect(r/*constrainRect*/);
	      r.origin.x--;
	      r.origin.y--;
	      r.size.width += 2;
	      r.size.height += 2;
	      //	      [superview displayRect: r];
	      r = lastRect;
	      switch (knob)
		{
		case IBBottomLeftKnobPosition:
		  r.origin.x += xDiff;
		  r.origin.y += yDiff;
		  r.size.width -= xDiff;
		  r.size.height -= yDiff;
		  break;
			    
		case IBMiddleLeftKnobPosition:
		  r.origin.x += xDiff;
		  r.size.width -= xDiff;
		  break;

		case IBTopLeftKnobPosition:
		  r.origin.x += xDiff;
		  r.size.width -= xDiff;
		  r.size.height += yDiff;
		  break;
			    
		case IBTopMiddleKnobPosition:
		  r.size.height += yDiff;
		  break;

		case IBTopRightKnobPosition:
		  r.size.width += xDiff;
		  r.size.height += yDiff;
		  break;

		case IBMiddleRightKnobPosition:
		  r.size.width += xDiff;
		  break;

		case IBBottomRightKnobPosition:
		  r.origin.y += yDiff;
		  r.size.width += xDiff;
		  r.size.height -= yDiff;
		  break;

		case IBBottomMiddleKnobPosition:
		  r.origin.y += yDiff;
		  r.size.height -= yDiff;
		  break;

		case IBNoneKnobPosition:
		  break;	/* NOT REACHED */
		}

	      lastRect = r;

	      if ([view respondsToSelector: 
			  @selector(updateResizingWithFrame:andEvent:andPlacementInfo:)])
		{
		  [view updateResizingWithFrame: r
			andEvent: theEvent
			andPlacementInfo: gpi];
		}

	    }
	    /*
	     * Flush any drawing performed for this event.
	     */
	    [[self window] enableFlushWindow];
	    [[self window] flushWindow];
	  }
	}

      e = [NSApp nextEventMatchingMask: eventMask
		 untilDate: future
		 inMode: NSEventTrackingRunLoopMode
		 dequeue: YES];
      eType = [e type];
    }
  
  [NSEvent stopPeriodicEvents];
  [NSCursor pop];
  /* Typically after a view has been dragged in a window, NSWindow
	 sends a spurious moustEntered event. Sending the mouseUp
	 event back to the NSWindow resets the NSWindow's idea of the
	 last mouse point so it doesn't think that the mouse has
	 entered the view (since it was always there, it's just that
	 the view moved).  */
  [[self window] postEvent: e atStart: NO];

  {
    NSRect	redrawRect = NSZeroRect;

    /*
     * This was a subview resize, so we must clean up by removing
     * the highlighted knob and the wireframe around the view.
     */

    [view updateResizingWithFrame: r
	  andEvent: theEvent
	  andPlacementInfo: gpi];
    
    [view validateFrame: r
	  withEvent: theEvent
	  andPlacementInfo: gpi];

    r = GormExtBoundsForRect(lastRect);
    r.origin.x--;
    r.origin.y--;
    r.size.width += 2;
    r.size.height += 2;
    /*
     * If this was a simple resize, we must redraw the union of
     * the original frame, and the final frame, and the area
     * where we were drawing the wireframe and handles.
     */
    redrawRect = NSUnionRect(r, redrawRect);
    redrawRect = NSUnionRect(firstRect, redrawRect);
  }

  
  if (NSEqualPoints(point, mouseDownPoint) == NO)
    {
      /*
       * A subview was moved or resized, so we must mark the
       * doucment as edited.
	   */
      [document touch];
    }

  [superview unlockFocus];
  _displaySelection = YES;
  
  [self setNeedsDisplay: YES];
  /*
   * Restore state to what it was on entry.
   */
  [[self window] setAcceptsMouseMovedEvents: acceptsMouseMoved];

}

- (void) handleMouseOnView: (GormViewEditor *) view
		 withEvent: (NSEvent *) theEvent
{
  NSPoint	mouseDownPoint = [[view superview]
				   convertPoint: [theEvent locationInWindow]
				   fromView: nil];
  NSDate	*future = [NSDate distantFuture];
  NSView	*subview;
  BOOL		acceptsMouseMoved;
  BOOL		dragStarted = NO;
  unsigned	eventMask;
  NSEvent	*e;
  NSEventType	eType;
  NSRect	r;
  NSPoint	maxMouse;
  NSPoint	minMouse;
  NSPoint	lastPoint = mouseDownPoint;
  NSPoint	point = mouseDownPoint;
  NSView        *superview;
  NSEnumerator		*enumerator;
  NSRect        oldMovingFrame;
  NSRect        suggestedFrame;
  GormPlacementInfo *gpi = nil;
  BOOL shouldUpdateSelection = YES;
  BOOL mouseDidMove = NO;

  eventMask = NSLeftMouseUpMask | NSLeftMouseDraggedMask
    | NSMouseMovedMask | NSPeriodicMask;
  
  // Save window state info.
  acceptsMouseMoved = [[self window] acceptsMouseMovedEvents];
  [[self window] setAcceptsMouseMovedEvents: YES];

  if (view == nil)
    {
      return;
    }

  if ([theEvent modifierFlags] & NSShiftKeyMask)
    {
      if ([selection containsObject: view])
	{
	  NSMutableArray *newSelection = [selection mutableCopy];
	  [newSelection removeObjectIdenticalTo: view];
	  [self selectObjects: newSelection];
	  RELEASE(newSelection);
	  return;
	}
      else
	{
	  NSArray *newSelection;
	  newSelection = [selection arrayByAddingObject: view];
	  [self selectObjects: newSelection];
	}
      shouldUpdateSelection = NO;
    }
  else
    {
      if ([selection containsObject: view])
	{
	  if ([selection count] == 1)
	    shouldUpdateSelection = NO;
	}
      else
	{
	  shouldUpdateSelection = NO;
	  [self selectObjects: [NSArray arrayWithObject: view]];
	}
    }

  superview = [view superview];
  [superview lockFocus];
  
  {
    NSRect	vf = [view frame];
    NSRect	sf = [superview bounds];
    NSPoint	tr = NSMakePoint(NSMaxX(vf), NSMaxY(vf));
    NSPoint	bl = NSMakePoint(NSMinX(vf), NSMinY(vf));
    
    enumerator = [selection objectEnumerator];
    while ((subview = [enumerator nextObject]) != nil)
      {
	if (subview != view)
	  {
	    float	tmp;
	    
	    vf = [subview frame];
	    tmp = NSMaxX(vf);
	    if (tmp > tr.x)
	      tr.x = tmp;
	    tmp = NSMaxY(vf);
	    if (tmp > tr.y)
	      tr.y = tmp;
	    tmp = NSMinX(vf);
	    if (tmp < bl.x)
	      bl.x = tmp;
	    tmp = NSMinY(vf);
	    if (tmp < bl.y)
	      bl.y = tmp;
	  }
      }
    minMouse.x = point.x - bl.x;
    minMouse.y = point.y - bl.y;
    maxMouse.x = NSMaxX(sf) - tr.x + point.x;
    maxMouse.y = NSMaxY(sf) - tr.y + point.y;
  }

  if ([selection count] == 1)
    {
      oldMovingFrame = [[selection objectAtIndex: 0] frame];
      gpi = [[selection objectAtIndex: 0] initializeResizingInFrame: 
					     [self superview]
					   withKnob: IBNoneKnobPosition];
      suggestedFrame = oldMovingFrame;
    }
  
  // Set the arrows cursor in case it might be something else
  [[NSCursor arrowCursor] push];

  
  // Track mouse movements until left mouse up.
  // While we keep track of all mouse movements, we only act on a
  // movement when a periodic event arives (every 20th of a second)
  // in order to avoid excessive amounts of drawing.
  [NSEvent startPeriodicEventsAfterDelay: 0.1 withPeriod: 0.05];
  e = [NSApp nextEventMatchingMask: eventMask
	     untilDate: future
	     inMode: NSEventTrackingRunLoopMode
	     dequeue: YES];

  eType = [e type];

  {

    while ((eType != NSLeftMouseUp) && !mouseDidMove)
      {
	if (eType != NSPeriodic)
	  {
	    point = [superview convertPoint: [e locationInWindow]
			       fromView: nil];
	    if (NSEqualPoints(mouseDownPoint, point) == NO)
	      mouseDidMove = YES;
	  }
	e = [NSApp nextEventMatchingMask: eventMask
		   untilDate: future
		   inMode: NSEventTrackingRunLoopMode
		   dequeue: YES];
	eType = [e type];
      }
  }

  while (eType != NSLeftMouseUp)
    {
      if (eType != NSPeriodic)
	{
	  point = [superview convertPoint: [e locationInWindow]
			     fromView: nil];
	}
      else if (NSEqualPoints(point, lastPoint) == NO)
	{
	  [[self window] disableFlushWindow];

	  {
	    float	xDiff;
	    float	yDiff;

	    if (point.x < minMouse.x)
	      point.x = minMouse.x;
	    if (point.y < minMouse.y)
	      point.y = minMouse.y;
	    if (point.x > maxMouse.x)
	      point.x = maxMouse.x;
	    if (point.y > maxMouse.y)
	      point.y = maxMouse.y;

	    xDiff = point.x - lastPoint.x;
	    yDiff = point.y - lastPoint.y;
	    lastPoint = point;

	    if (dragStarted == NO)
	      {
		// Remove selection knobs before moving selection.
		dragStarted = YES;
		_displaySelection = NO;
		[self setNeedsDisplay: YES];
	      }

  	    if ([selection count] == 1)
  	      {
		id obj = [selection objectAtIndex: 0];
		if([obj isKindOfClass: [NSView class]])
		  {
		    [[selection objectAtIndex: 0] 
		      setFrameOrigin:
			NSMakePoint(NSMaxX([self bounds]),
				    NSMaxY([self bounds]))];
		    [superview display];
		    
		    r = oldMovingFrame;
		    r.origin.x += xDiff;
		    r.origin.y += yDiff;
		    r.origin.x = (int) r.origin.x;
		    r.origin.y = (int) r.origin.y;
		    r.size.width = (int) r.size.width;
		    r.size.height = (int) r.size.height;
		    oldMovingFrame = r;
		    
		    //case guideLine
		    if ( _followGuideLine )
		      {
			suggestedFrame = [obj _displayMovingFrameWithHint: r
					      andPlacementInfo: gpi];
		      }
		    else 
		      {
			suggestedFrame = NSMakeRect (NSMinX(r), 
						     NSMinY(r),
						     NSMaxX(r) - NSMinX(r),
						     NSMaxY(r) - NSMinY(r));
		      }
		    
		    [obj setFrame: suggestedFrame];
		    [obj setNeedsDisplay: YES];
		    
		  }
	      }
	    else
	      {
		enumerator = [selection objectEnumerator];		
		while ((subview = [enumerator nextObject]) != nil)
		  {
		    NSRect	oldFrame = [subview frame];
		    
		    r = oldFrame;
		    r.origin.x += xDiff;
		    r.origin.y += yDiff;
		    r.origin.x = (int) r.origin.x;
		    r.origin.y = (int) r.origin.y;
		    r.size.width = (int) r.size.width;
		    r.size.height = (int) r.size.height;
		    [subview setFrame: r];
		    [superview setNeedsDisplayInRect: oldFrame];
		    [subview setNeedsDisplay: YES];
		  }
	      }
	    
	    /*
	     * Flush any drawing performed for this event.
	     */
	    [[self window] displayIfNeeded];
	    [[self window] enableFlushWindow];
	    [[self window] flushWindow];
	  }
	}
      e = [NSApp nextEventMatchingMask: eventMask
		 untilDate: future
		 inMode: NSEventTrackingRunLoopMode
		 dequeue: YES];
      eType = [e type];
    }

  _displaySelection = YES;

  if ([selection count] == 1)
    [[selection objectAtIndex: 0] setFrame: suggestedFrame];

  if (mouseDidMove == NO && shouldUpdateSelection == YES)
    {
      [self selectObjects: [NSArray arrayWithObject: view]];
    }

  [self setNeedsDisplay: YES];
  [NSEvent stopPeriodicEvents];
  [NSCursor pop];
  /* Typically after a view has been dragged in a window, NSWindow
     sends a spurious mouseEntered event. Sending the mouseUp
     event back to the NSWindow resets the NSWindow's idea of the
     last mouse point so it doesn't think that the mouse has
     entered the view (since it was always there, it's just that
     the view moved).  */
  [[self window] postEvent: e atStart: NO];
  
  
  if (NSEqualPoints(point, mouseDownPoint) == NO)
    {
      // A subview was moved or resized, so we must mark the doucment as edited.
      [document touch];
    }

  [superview unlockFocus];

  // Restore window state to what it was when entering the method.
  [[self window] setAcceptsMouseMovedEvents: acceptsMouseMoved];
 
}



@end
