/* GormMatrixEditor.m - Editor for matrices.
 *
 * Copyright (C) 2001 Free Software Foundation, Inc.
 *
 * Authors:	Adam Fedor <fedor@gnu.org>
 *              Pierre-Yves Rivaille <pyrivail@ens-lyon.fr>
 * Date:	Sep 2001
 *              Aug 2002
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

#include <InterfaceBuilder/InterfaceBuilder.h>

#include "GormPrivate.h"
#include "GormImage.h"
#include "GormViewEditor.h"
#include "GormMatrixEditor.h"
#include "GormViewWithSubviewsEditor.h"
#include "GormPlacementInfo.h"
#include "GormFontViewController.h"
#include "GormViewKnobs.h"

#define _EO ((NSMatrix*)_editedObject)

@interface GormViewEditor (Private)
- (void) _displayFrame: (NSRect) frame
     withPlacementInfo: (GormPlacementInfo*)gpi;
@end

@implementation NSMatrix (IBObjectAdditions)
- (NSString*) editorClassName
{
  return @"GormMatrixEditor";
}
@end

@interface NSForm (GormAdditions)
- (CGFloat) titleWidth;
@end

@implementation NSForm (GormAdditions)

- (CGFloat)titleWidth
{
  NSInteger i, count = [self numberOfRows];
  float new_title_width = 0;
  float candidate_title_width = 0;

  // Compute max of title width in the cells
  for (i = 0; i < count; i++)
    {
      candidate_title_width = [_cells[i][0] titleWidth];
      if (candidate_title_width > new_title_width)  
	new_title_width = candidate_title_width;
    }
  return new_title_width;
}

@end

@implementation	GormMatrixEditor

- (void) copySelection
{
  if (selected != nil)
    {
      [document copyObjects: [self selection]
		       type: IBViewPboardType
	       toPasteboard: [NSPasteboard generalPasteboard]];
    }
}

- (void) deleteSelection
{
  NSDebugLog(@"Cannot delete Matrix cell\n");
}

static BOOL done_editing;

- (void) handleNotification: (NSNotification*)aNotification
{
  NSString	*name = [aNotification name];
  if ([name isEqual: NSControlTextDidEndEditingNotification] == YES)
    {
      done_editing = YES;
    }
  else
    NSLog(@"GormMatrixEditor got unhandled notification %@", name);
}


/*
 *	Initialisation
 */
- (id) initWithObject: (id)anObject inDocument: (id<IBDocuments>)aDocument
{
  NSMutableArray *draggedTypes = [NSMutableArray array];

  opened = NO;
  selected = nil;
  selectedCol = -1;
  selectedRow = -1;
  _displaySelection = YES;
  self = [super initWithObject: anObject 
		inDocument: aDocument];

  // dragged types...
  [draggedTypes addObject: GormImagePboardType];
  [draggedTypes addObject: GormLinkPboardType];
  [draggedTypes addObject: GormSoundPboardType];

  // register...
  [self registerForDraggedTypes: draggedTypes];

  return self;
}

/* Called when we double-click on a text/editable cell or form. Overlay
   a text field so the user can edit the title. */
- (void) editTitleWithEvent: (NSEvent *)theEvent
{
  NSInteger row, col;
  unsigned eventMask;
  id edit_view;
  BOOL isForm;
  NSRect                 frame;
  NSTextField           *editField;
  NSDate		*future = [NSDate distantFuture];
  NSNotificationCenter  *nc = [NSNotificationCenter defaultCenter];

  isForm = [_EO isKindOfClass: [NSForm class]];
  if (isForm == NO && [selected type] != NSTextCellType)
    return;

  // get the superview we are to edit from.
  edit_view = [_EO superview];

  [_EO getRow: &row column: &col ofCell: selected];
  frame = [_EO cellFrameAtRow: row column: col];
  frame.origin.x += NSMinX([_EO frame]);
  if (isForm)
    frame.size.width = [(NSForm *)_EO titleWidth];
  else
    frame = [selected titleRectForBounds: frame];
  if ([_EO isFlipped])
    {
      frame.origin.y = NSMaxY([_EO frame]) - NSMaxY(frame);
    }
  else
    {
      frame.origin.y = NSMinY([_EO frame]) + NSMinY(frame);
    }

  /* Now create an edit field and allow the user to edit the text */
  editField = [[NSTextField alloc] initWithFrame: frame];
  [editField setEditable: YES];
  [editField setSelectable: YES];
  [editField setBezeled: NO];
  [editField setEnabled: YES];
  if (isForm)
    [editField setStringValue: [(NSFormCell *)selected title]];
  else
    [editField setStringValue: [selected stringValue]];
  [edit_view addSubview: editField];
  // [edit_view displayRect: frame];
  [edit_view display];
  [[edit_view window] flushWindow];
  [nc addObserver: self
         selector: @selector(handleNotification:)
             name: NSControlTextDidEndEditingNotification
           object: nil];

  /* Do some modal editing */
  [editField selectText: self];
  eventMask = NSLeftMouseDownMask |  NSLeftMouseUpMask  |
  NSKeyDownMask  |  NSKeyUpMask  | NSFlagsChangedMask;

  done_editing = NO;
  while (!done_editing)
    {
      NSEvent *e;
      NSEventType eType;
      e = [NSApp nextEventMatchingMask: eventMask
		 untilDate: future
		 inMode: NSEventTrackingRunLoopMode
		 dequeue: YES];
      eType = [e type];
      switch (eType)
	{
	case NSLeftMouseDown:
	  {
	    NSPoint dp =  [edit_view convertPoint: [e locationInWindow]
				fromView: nil];
	    if (NSMouseInRect(dp, frame, NO) == NO)
	      {
		done_editing = YES;
		break;
	      }
	  }
	  [[editField currentEditor] mouseDown: e];
	  break;
	case NSLeftMouseUp:
	  [[editField currentEditor] mouseUp: e];
	  break;
	case NSLeftMouseDragged:
	  [[editField currentEditor] mouseDragged: e];
	  break;
	case NSKeyDown:
	  [[editField currentEditor] keyDown: e];
	  break;
	case NSKeyUp:
	  [[editField currentEditor] keyUp: e];
	  break;
	case NSFlagsChanged:
	  [[editField currentEditor] flagsChanged: e];
	  break;
	default:
	  NSLog(@"Internal Error: Unhandled event during editing: %@", e);
	  break;
	}
    }

  [nc removeObserver: self
                name: NSControlTextDidEndEditingNotification
              object: nil];

  [self makeSelectionVisible: NO];
  if (isForm)
    {
      /* Set the new title and resize the form to match the titles */
      CGFloat oldTitleWidth, titleWidth;
      NSRect oldFrame;
      oldTitleWidth = [(NSForm *)_EO titleWidth];
      [(NSFormCell *)selected setTitle: [editField stringValue]];
      [(NSForm *)_EO calcSize];
      titleWidth = [(NSForm *)_EO titleWidth];
      oldFrame = frame = [_EO frame];
      frame.origin.x -= (titleWidth - oldTitleWidth);
      frame.size.width += (titleWidth - oldTitleWidth);
      [(NSForm *)_EO setEntryWidth: NSWidth(frame)];
      [(NSForm *)_EO setFrame: frame];
      frame = NSUnionRect(frame, oldFrame);
    }
  else
    [selected setStringValue: [editField stringValue]];
  
  [edit_view removeSubview: editField];
  [edit_view displayRect: frame];
  [self makeSelectionVisible: YES];

  RELEASE(editField);
}

- (BOOL) canBeOpened
{
  return YES;
}

- (void) setOpened: (BOOL) value
{
  if (value)
    {
      opened = YES;
    }
  else
    {
      opened = NO;
      selected = nil;
      selectedCol = -1;
      selectedRow = -1;
    }
}

- (void) mouseDown: (NSEvent *)theEvent
{
  BOOL onKnob = NO;

  {
    if ([[parent selection] containsObject: _EO])
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
	if (_next_responder)
	  return [_next_responder mouseDown: theEvent];
	else
	  return [self noResponderFor: @selector(mouseDown:)];
      }
  }
  
  if (opened == NO)
    {
      [super mouseDown: theEvent];
      return;
    }
  

  {
    NSInteger row, col;
    NSPoint mouseDownPoint = 
      [_EO 
	convertPoint: [theEvent locationInWindow]
	fromView: nil];

    if ([_EO 
	  getRow: &row 
	  column: &col 
	  forPoint: mouseDownPoint] == YES)
      {
	selectedRow = row;
	selectedCol = col;
	selected = [_EO cellAtRow: row
				  column: col];
	
	[document setSelectionFromEditor: self];
	if (selected != nil && ([theEvent clickCount] == 2) )
	  {
	    [self editTitleWithEvent: theEvent];
	    return;
	  }
	
	[self setNeedsDisplay: YES];
      }
    else
      {
	selected = nil;
	selectedRow = -1;
	selectedCol = -1;
	[document setSelectionFromEditor: self];
      }
  }
}

- (void) makeSelectionVisible: (BOOL)flag
{
  if (selected != nil)
    {
      NSInteger row, col;
      if ([_EO getRow: &row column: &col ofCell: selected])
	{
	  NSRect frame = [_EO cellFrameAtRow: row column: col];
	  if (flag == YES)
	    [_EO selectCellAtRow: row column: col];
	  [_EO lockFocus];
	  [[NSColor controlShadowColor] set];
	  NSHighlightRect(frame);
	  [_EO unlockFocus];
	}
    }
  else
    {
      [_EO deselectAllCells];
    }
  [_EO display];
  [[_EO window] flushWindow];
}


- (void) selectObjects: (NSArray*)anArray
{
  id	obj = [anArray lastObject];
  [self makeSelectionVisible: NO];
  selected = obj;
  [document setSelectionFromEditor: self];
  [self makeSelectionVisible: YES];
}

- (NSArray*) selection
{
  if (selected == nil)
    return [NSArray arrayWithObject: _EO];
  else
    return [NSArray arrayWithObject: selected];
}

- (BOOL) acceptsTypeFromArray: (NSArray*)types
{
  return ([types containsObject: IBObjectPboardType] || [types containsObject: GormImagePboardType]);
}

- (void) postDraw: (NSRect) rect
{
  if (_displaySelection)
    {
      if ((selectedRow != -1) && (selectedCol != -1))
	{
	  NSDebugLog(@"highlighting %@",
		NSStringFromRect([_EO 
				       cellFrameAtRow: selectedRow
				       column: selectedCol]));
	  [[NSColor blackColor] set];
	  NSHighlightRect([_EO 
			    convertRect:
			      [_EO 
					   cellFrameAtRow: selectedRow
					   column: selectedCol]
			    toView: self]);
					 
	}
    }
}

- (NSRect) _constrainedFrame: (NSRect) frame
		   withEvent: (NSEvent *)theEvent
		     andKnob: (IBKnobPosition) knob
{
  NSInteger width;
  NSInteger height;
      
  if ([theEvent modifierFlags] & NSAlternateKeyMask)
    {
      NSInteger rows = [_EO numberOfRows];
      NSInteger cols = [_EO numberOfColumns];
      NSSize interSize = [_EO intercellSpacing];
      
      NSInteger colWidth = ([_EO frame].size.width - 
		      (cols - 1) * interSize.width) / cols;
      NSInteger rowHeight = ([_EO frame].size.height - 
		       (rows - 1) * interSize.height) / rows;
	
      NSInteger widthIncrement = colWidth + interSize.width;
      NSInteger heightIncrement = rowHeight + interSize.height;
      
      if (frame.size.width < colWidth)
	{
	  width = colWidth;
	  rows = 1;
	}
      else
	{
	  width = frame.size.width - [_EO frame].size.width;
	  rows = width / widthIncrement;
	  width = rows * widthIncrement + [_EO frame].size.width;
	}

      if (frame.size.height < rowHeight)
	{
	  height = rowHeight;
	  cols = 1;
	}
      else
	{
	  height = frame.size.height - [_EO frame].size.height;
	  cols = height / heightIncrement;
	  height = cols * heightIncrement + [_EO frame].size.height;
	}
    }
  else if ([theEvent modifierFlags] & NSControlKeyMask)
    {
      NSInteger rows = [_EO numberOfRows];
      NSInteger cols = [_EO numberOfColumns];
      NSSize cellSize = [_EO cellSize];
      
      height = width = 0;
      if (cols > 1)
	width = ( frame.size.width - cellSize.width * cols) / (cols - 1);
      if (rows > 1)
	height = ( frame.size.height - cellSize.height * rows ) / (rows - 1);
      
      width *= (cols - 1);
      width += cellSize.width * cols;
      height *= (rows - 1);
      height += cellSize.height * rows;
    }
  else
    {
      NSInteger rows = [_EO numberOfRows];
      NSInteger cols = [_EO numberOfColumns];
      NSSize interSize = [_EO intercellSpacing];
      
      width = ( frame.size.width - interSize.width * (cols - 1) ) /  cols;
      width *= cols;
      width += (interSize.width * (cols - 1));
      
      height = ( frame.size.height - interSize.height * (rows - 1) ) /  rows;
      height *= rows;
      height += (interSize.height * (rows - 1));
    }
  
  switch (knob)
    {
    case IBBottomLeftKnobPosition:
    case IBMiddleLeftKnobPosition:
    case IBTopLeftKnobPosition:
      frame.origin.x = NSMaxX(frame) - width;
      frame.size.width = width;
      break;
    case IBTopRightKnobPosition:
    case IBMiddleRightKnobPosition:
    case IBBottomRightKnobPosition:
      frame.size.width = width;
      break;
    case IBTopMiddleKnobPosition:
    case IBBottomMiddleKnobPosition:
    case IBNoneKnobPosition:
      break;
    }
  
  
  switch (knob)
    {
    case IBBottomLeftKnobPosition:
    case IBBottomRightKnobPosition:
    case IBBottomMiddleKnobPosition:
      frame.origin.y = NSMaxY(frame) - height;
      frame.size.height = height;
      break;
    case IBTopMiddleKnobPosition:
    case IBTopRightKnobPosition:
    case IBTopLeftKnobPosition:
      frame.size.height = height;
      break;
    case IBMiddleLeftKnobPosition:
    case IBMiddleRightKnobPosition:
    case IBNoneKnobPosition:
      break;
    }
  
  return frame;
}


- (void) updateResizingWithFrame: (NSRect) frame
			andEvent: (NSEvent *)theEvent
		andPlacementInfo: (GormPlacementInfo*) gpi
{
  gpi->lastFrame = [self _constrainedFrame: frame
		    withEvent: theEvent
		    andKnob: gpi->knob];

  [self _displayFrame: gpi->lastFrame
	withPlacementInfo: gpi];
}



- (void) validateFrame: (NSRect) frame
	     withEvent: (NSEvent *) theEvent
      andPlacementInfo: (GormPlacementInfo*)gpi
{
  frame = gpi->lastFrame;

  if ([theEvent modifierFlags] & (NSControlKeyMask | NSShiftKeyMask))
    {
      NSInteger rows = [_EO numberOfRows];
      NSInteger cols = [_EO numberOfColumns];
      NSSize interSize = [_EO intercellSpacing];
      
      NSInteger colWidth = ([_EO frame].size.width - 
		      (cols - 1) * interSize.width) / cols;
      NSInteger rowHeight = ([_EO frame].size.height - 
		       (rows - 1) * interSize.height) / rows;
	
      NSInteger widthIncrement = colWidth + interSize.width;
      NSInteger heightIncrement = rowHeight + interSize.height;

      NSInteger newCols = (frame.size.width - [_EO frame].size.width) /
	widthIncrement;
      NSInteger newRows = (frame.size.height - [_EO frame].size.height) /
	heightIncrement;
      
      NSInteger i, j;

      if (newCols > 0)
	{
	  for (j = cols; j < cols + newCols; j++)
	    {
	      [_EO addColumn];
	      for (i = 0; i < rows; i++)
		{
		  [document attachObject: [_EO cellAtRow: i column: j]
				toParent: _EO];
		}
	    }
	}
      else if (newCols < 0)
	{
	  for (j = cols - 1; j >= cols - newCols; j--)
	    {
	      for (i = 0; i < rows; i++)
		{
		  [document detachObject: [_EO cellAtRow: i column: j]];
		}
	      [_EO removeColumn: j];
	    }
	}

      if (newRows > 0)
	{
	  for (i = rows; i < rows + newRows; i++)
	    {
	      [_EO addRow];
	      for (j = 0; j < cols + newCols; j++)
		{
		  [document attachObject: [_EO cellAtRow: i column: j]
				toParent: _EO];
		}
	    }
	}
      else if (newRows < 0)
	{
	  for (i = rows - 1; i >= rows + newRows; i--)
	    {
	      for (j = 0; j < cols + newCols; j++)
		{
		  [document detachObject: [_EO cellAtRow: i column: j]];
		}
	      [_EO removeRow: i];
	    }
	}
      [_EO setFrame: frame];
    }
  else if ([theEvent modifierFlags] & NSControlKeyMask)
    {
      NSInteger width;
      NSInteger height;
      NSInteger rows = [_EO numberOfRows];
      NSInteger cols = [_EO numberOfColumns];
      NSSize cellSize = [_EO cellSize];
      
      
      [self setFrame: frame];
      
      
      height = width = 0;
      if (cols > 1)
	width = ( frame.size.width - cellSize.width * cols) / (cols - 1);
      if (rows > 1)
	height = ( frame.size.height - cellSize.height * rows ) / (rows - 1);
      
      [_EO setIntercellSpacing: NSMakeSize(width, height)];
    }
  else
    {
      NSInteger width;
      NSInteger height;
      NSInteger rows = [_EO numberOfRows];
      NSInteger cols = [_EO numberOfColumns];
      NSSize interSize = [_EO intercellSpacing];
      
      
      [self setFrame: frame];
      
      
      width = ( frame.size.width - interSize.width * (cols - 1) ) /  cols;
      height = ( frame.size.height - interSize.height * (rows - 1) ) /  rows;
      
      [_EO setCellSize: NSMakeSize(width, height)];
    }
}

- (void) changeFont: (id)sender
{
  NSEnumerator *enumerator = [[self selection] objectEnumerator];
  id anObject;
  NSFont *newFont;

  NSDebugLog(@"In %@ changing font for %@",[self className],[self selection]);
  while ((anObject = [enumerator nextObject]))
    {
      if([anObject respondsToSelector: @selector(setTitleFont:)] &&
	 [anObject respondsToSelector: @selector(setTextFont:)])
	{
	  newFont = [sender convertFont: [anObject font]];
	  newFont = [[GormFontViewController sharedGormFontViewController] 
		      convertFont: newFont];
	  [anObject setTitleFont: newFont];
	  [anObject setTextFont: newFont];
	}
      else if ([anObject respondsToSelector: @selector(font)] &&
	       [anObject respondsToSelector: @selector(setFont:)])
	{
	  newFont = [sender convertFont: [anObject font]];
	  newFont = [[GormFontViewController sharedGormFontViewController] 
		      convertFont: newFont];
	  [anObject setFont: newFont];
	}
    }

  return;
}

- (id) connectTargetAtPoint: (NSPoint)mouseLoc
{
  NSInteger row, col;

  if ([_EO getRow: &row column: &col forPoint: mouseLoc] == YES)
    {
      /* If a matrix has small intercell spacing (less than 1 pixel), it
	 becomes impossible to make connections to the whole matrix, since
	 -getRow:column:forPoint: returns YES for every location within the
	 matrix's bounds. Therefore, we accept connection to matrix cells
	 only if the mouse is strictly inside the cell. */
      NSRect cellFrame = [_EO cellFrameAtRow: row column: col];

      if (mouseLoc.x != NSMinX(cellFrame) &&
	  mouseLoc.x != NSMaxX(cellFrame) &&
	  mouseLoc.y != NSMinY(cellFrame) &&
	  mouseLoc.y != NSMaxY(cellFrame))
	{
	  return [_EO cellAtRow: row column: col];
	}
    }

  return _EO;
}

- (NSDragOperation) draggingEntered: (id<NSDraggingInfo>)sender
{
  NSPasteboard *dragPb;
  NSArray      *types;
  id             delegate = [NSApp delegate];

  dragPb = [sender draggingPasteboard];
  types = [dragPb types];
  if ([types containsObject: GormLinkPboardType] == YES)
    {
      NSPoint loc = [sender draggingLocation];
      NSPoint mouseDownPoint = [_EO convertPoint: loc fromView: nil];

      [delegate displayConnectionBetween: [delegate connectSource]
				     and: [self connectTargetAtPoint: mouseDownPoint]];
      return NSDragOperationLink;
    }
  return [super draggingEntered: sender];
}

- (BOOL) performDragOperation: (id<NSDraggingInfo>)sender
{
  NSPasteboard	*dragPb;
  NSArray	*types;
  NSPoint       dropPoint = [sender draggedImageLocation];
  NSPoint       mouseDownPoint = [_EO convertPoint: dropPoint fromView: nil];
  id             delegate = [NSApp delegate];

  dragPb = [sender draggingPasteboard];
  types = [dragPb types];

  if ([types containsObject: GormLinkPboardType])
    {
      [delegate displayConnectionBetween: [delegate connectSource] 
				     and: [self connectTargetAtPoint: mouseDownPoint]];
      [delegate startConnecting];
    }
  else if ([types containsObject: GormImagePboardType] == YES ||
	   [types containsObject: GormSoundPboardType] == YES)
    {
      NSInteger row, col;
      if ([_EO getRow: &row column: &col forPoint: mouseDownPoint] == YES)
	{
	  id object = [_EO cellAtRow: row column: col];
	  if ([types containsObject: GormImagePboardType] == YES)
	    {
	      NSString *name = [dragPb stringForType: GormImagePboardType];
	      NSImage *image = [NSImage imageNamed: name];
	      [image setArchiveByName: NO];
	      if ([object respondsToSelector: @selector(setSound:)])
		{
		  [object setImage: image];
		}
	      else
		{
		  return NO;
		}

	      return YES;
	    }
	  else if ([types containsObject: GormSoundPboardType] == YES)
	    {
	      NSString *name;
	      name = [dragPb stringForType: GormSoundPboardType];
	      if ([object respondsToSelector: @selector(setSound:)])
		{
		  [object setSound: [NSSound soundNamed: name]];
		}
	      else
		{
		  return NO;
		}

	      return YES;
	    }
	}
    }
  
  return NO;
}

@end



