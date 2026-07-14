/* GormTableViewEditor.m - Editor for matrices.
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

#include <InterfaceBuilder/InterfaceBuilder.h>
#include <GormCore/GormCore.h>

#include "GormTableViewEditor.h"
#include "GormNSTableView.h"

NSString *IBTableColumnPboardType = @"IBTableColumnPboardType";

static NSCell *_editedCell;
static NSCell *_currentHeaderCell;
static NSText *_textObject;

@interface GormTableViewEditor (Private)
- (void) editHeader: (NSTableHeaderView*) th
	  withEvent: (NSEvent *) theEvent;
@end

@implementation GormTableViewEditor
- (void) setFrame: (NSRect)frame
{
  if(tableView != nil)
    {
      [tableView deselectAll: self];
    }
  [super setFrame: frame];
}

/**
 * Decide whether an editor can accept data from the pasteboard.
 */
- (BOOL) acceptsTypeFromArray: (NSArray*)types
{
  return NO;
}

/**
 * Activate an editor - inserts it into the view hierarchy or whatever is
 * needed for the editor to be able to provide its functionality.
 * This method should be called by the document when an editor is created
 * or opened.  It should be safe to call repeatedly.
 */
- (BOOL) activate
{
  if ([super activate])
    {
      if ([_editedObject isKindOfClass: [NSScrollView class]])
	tableView = [(NSScrollView *)_editedObject documentView];
      else
	tableView = (GormNSTableView *)_editedObject;

      RETAIN(tableView); // FIXME: Temporary fix.
      [tableView setAllowsColumnResizing: YES];
      [tableView setAllowsColumnSelection: YES];
      [tableView setAllowsMultipleSelection: NO];
      [tableView setAllowsEmptySelection: YES];
      [tableView setAllowsColumnReordering: YES];
      [tableView setGormDelegate: self];
      return YES;
    }
  

  return NO;
}

- (void) scrollToPoint: (NSPoint)point
{
  if ([_super_view respondsToSelector:@selector(scrollToPoint:)])
    {
      [(NSClipView *)_super_view scrollToPoint: point]; 
    }
}

- (NSRect) documentVisibleRect
{
  NSRect visRect = _bounds;
  if ([_super_view respondsToSelector:@selector(documentVisibleRect)])
    {
      visRect = [(NSClipView *)_super_view documentVisibleRect]; 
    }
  return visRect; 
}

/**
 * Deactivate an editor - removes it from the view hierarchy so that objects
 * can be archived without including the editor.
 * This method should be called automatically by the 'close' method.
 * It should be safe to call repeatedly.
 */
- (void) deactivate
{
  if (activated == YES)
    {
      // [tableView unselect]; 
      if ([tableView selectedColumn] != -1)
	{
	  [tableView deselectColumn: [tableView selectedColumn]];
	}
      [tableView setAllowsColumnResizing:
		  [tableView gormAllowsColumnResizing]];
      [tableView setAllowsColumnSelection:
		  [tableView gormAllowsColumnSelection]];
      [tableView setAllowsMultipleSelection:
		  [tableView gormAllowsMultipleSelection]];
      [tableView setAllowsEmptySelection:
		  [tableView gormAllowsEmptySelection]];
      [tableView setAllowsColumnReordering:
		  [tableView gormAllowsColumnReordering]];
      [tableView setGormDelegate: nil];
      [tableView setNeedsDisplay: YES];
      [super deactivate];
    }
}

/*
 * This method deletes all the objects in the current selection in the editor.
 */
- (void) deleteSelection
{
  NSDebugLog(@"deleteSelection");
  if ([selection count] == 0)
    {
      NSDebugLog(@"no column to delete");
    }
  else if([[selection objectAtIndex: 0] isKindOfClass: [NSTableColumn class]])
    {
      [tableView removeTableColumn: [selection objectAtIndex: 0]];
      [tableView deselectAll: self];
      [self selectObjects: [NSArray array]];
    }
}

/*
 * This method places the current selection from the editor on the pasteboard.
 */
- (void) copySelection
{
  NSDebugLog(@"copySelection");
  if ([[[self selection] objectAtIndex: 0] 
	isKindOfClass: [NSTableColumn class]])
    {
      [document copyObjects: [self selection]
		       type: IBTableColumnPboardType
	       toPasteboard: [NSPasteboard generalPasteboard]];
    }
  else
    {
      NSDebugLog(@"no paste");
    }
}

/*
 * This method is used to add the contents of the pasteboard to the current
 * selection of objects within the editor.
 */
- (void) pasteInSelection
{
  NSArray *objects;
  NSDebugLog(@"pasteInSelection");
  

  objects = [document pasteType: IBTableColumnPboardType
                 fromPasteboard: [NSPasteboard generalPasteboard]
	                 parent: _editedObject];

  if (objects == nil)
    return;

  if ([objects count] == 0)
    return;

  if ([objects count] > 1)
    {
      NSDebugLog(@"warning strange behaviour : GormTableViewEditor pasteInSelection");
    }
  else if ([[objects objectAtIndex: 0] isKindOfClass: [NSTableColumn class]]
	   == NO)
    {
      NSDebugLog(@"invalid data in IBTableColumnPboardType");
      return;
    }
	    
  [tableView addTableColumn: [objects objectAtIndex: 0]];

}


- (void) mouseDown:(NSEvent*)theEvent
{
  BOOL onKnob = NO;
  id hitView;
  
  {
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
  }
  
  if (opened == NO)
    {
      NSDebugLog(@"not opened");
      [super mouseDown: theEvent];
      return;
    }


  hitView = 
    [[tableView enclosingScrollView] 
      hitTest: 
	[[[tableView enclosingScrollView] superview]
	  convertPoint: [theEvent locationInWindow]
	  fromView: nil]];

  if (hitView == [tableView headerView])
    {
      if ([theEvent clickCount] == 2)
	{
  	  [self editHeader: hitView
  		withEvent: theEvent];
	  
	}
      else
	{
	  [hitView mouseDown: theEvent];
	}
    }
  else if ([hitView isKindOfClass: [NSScroller class]])
    {
      [hitView mouseDown: theEvent];
    }
  else if (hitView == tableView)
    {
      if ([theEvent modifierFlags] & NSControlKeyMask)
        {
	  [super mouseDown: theEvent];
	}
      else if ([tableView selectedColumn] != -1)
	{
	  [tableView deselectColumn: [tableView selectedColumn]];
	}
    }
  else if (hitView == self && [theEvent modifierFlags] & NSControlKeyMask)
    {
      /*
       * see if we're making a connection from the selected column.
       * not useful in vanilla gorm as they have no outlets or actions,
       * but palettes might find it useful.
       */
      int selectedColumn = [tableView selectedColumn];

      if (selectedColumn != -1)
        {
          NSPoint pt = [theEvent locationInWindow];
          NSRect r = [tableView rectOfColumn: selectedColumn];
      
          pt = [tableView convertPoint:pt fromView:nil];
      
          if (NSMouseInRect(pt, r, [tableView isFlipped]))
            {
              /* mouse was inside the selected column */
	      NSPasteboard *pb;
	      NSPoint	dragPoint = [theEvent locationInWindow];
	      NSTableColumn *col = [[tableView tableColumns] 
		  			objectAtIndex: selectedColumn];
	      NSString	*name = [document nameForObject: col];
	      
	      pb = [NSPasteboard pasteboardWithName: NSDragPboard];
	      [pb declareTypes:
		[NSArray arrayWithObject: GormLinkPboardType]
			 owner: self];
	      [pb setString: name forType: GormLinkPboardType];
	      [[NSApp delegate] displayConnectionBetween: col and: nil];
	      [[NSApp delegate] startConnecting];

	      [self dragImage: [[NSApp delegate] linkImage]
			   at: dragPoint
		       offset: NSZeroSize
			event: theEvent
		   pasteboard: pb
		       source: self
		    slideBack: YES];
	    }
	}
    }
}

- (void) tableViewSelectionDidChange: (id) tv
{
  if ([tableView selectedColumn] != -1)
    {
      [self selectObjects: 
	      [NSArray arrayWithObject: 
			 [[tableView tableColumns]
			   objectAtIndex: [tableView selectedColumn]]]];
    }
  else
    {
      [self selectObjects:
	      [NSArray arrayWithObject: tableView]];
    }
}


- (void) outlineViewSelectionDidChange: (id) tv
{
  if ([tableView selectedColumn] != -1)
    {
      [self selectObjects: 
	      [NSArray arrayWithObject: 
			 [[tableView tableColumns]
			   objectAtIndex: [tableView selectedColumn]]]];
    }
  else
    {
      [self selectObjects:
	      [NSArray arrayWithObject: tableView]];
    }
}

- (void) editHeader: (NSTableHeaderView*) th
	  withEvent: (NSEvent *) theEvent 
{
  NSText *t;
  NSTableColumn *tc;
  NSRect drawingRect;

  NSUInteger columnIndex = [th columnAtPoint: 
			  [th convertPoint:[theEvent locationInWindow]
			      fromView: nil]];
  
  if (columnIndex == NSNotFound)
    return; 

  _textObject = nil;

  [[th tableView] scrollColumnToVisible: columnIndex];

  

  t = [[th window] fieldEditor: YES  forObject: self];

  if ([t superview] != nil)
    {
      if ([t resignFirstResponder] == NO)
	{
	  return;
	}
    }
  

  // Prepare the cell
  tc = [[tableView tableColumns] objectAtIndex: columnIndex];
  // NB: need to be released when no longer used
  _editedCell = [[tc headerCell] copy];
  _currentHeaderCell = [tc headerCell];
  [_editedCell setStringValue: [[tc headerCell] stringValue]];
  [_editedCell setEditable: YES];
  _textObject = [_editedCell setUpFieldEditorAttributes: t];

  drawingRect = [th headerRectOfColumn: columnIndex];
  [_editedCell editWithFrame: drawingRect
	       inView: th
	       editor: _textObject
	       delegate: self
	       event: theEvent];
  return;    
}

- (void) textDidEndEditing: (NSNotification *)aNotification
{
  [_editedCell endEditing: _textObject];
  [_currentHeaderCell setStringValue: [[_textObject text] copy]];

  RELEASE(_editedCell);
}

- (NSDragOperation) draggingEntered: (id<NSDraggingInfo>)sender
{
  return [self draggingUpdated: sender];
}

- (NSDragOperation) draggingUpdated: (id<NSDraggingInfo>)sender
{
  NSPasteboard	*dragPb;
  NSArray	*types;
  
  dragPb = [sender draggingPasteboard];
  types = [dragPb types];
  if ([types containsObject: GormLinkPboardType] == YES)
    {
      id destination = nil;

      /*
      NSView *hitView = 
	[[tableView enclosingScrollView] 
	  hitTest: 
	    [[[tableView enclosingScrollView] superview]
	      convertPoint: [sender draggingLocation]
	      fromView: nil]];
      
      if (hitView == [tableView headerView])
	{
	  NSPoint p = [hitView convertPoint: [sender draggingLocation]
			       fromView: nil];
	  int columnNumber = 
	    [(NSTableHeaderView*) hitView columnAtPoint: p];
	  
	  if (columnNumber != -1)
	    destination = [[tableView tableColumns] 
			    objectAtIndex: columnNumber];
	}

      if (hitView == tableView)
	destination = tableView;
      */

      if (destination == nil)
	{
	  int col = 0;
	  destination = _editedObject;	  
	  if((col = [_editedObject selectedColumn]) != -1)
	    {
	      destination = [[_editedObject tableColumns] objectAtIndex: col];
	    }
	}

      [[NSApp delegate] displayConnectionBetween: [[NSApp delegate] connectSource] 
	     and: destination];
      return NSDragOperationLink;
    }
  else
    {
      return NSDragOperationNone;
    }
}

- (BOOL) performDragOperation: (id<NSDraggingInfo>)sender
{
  return ([self draggingUpdated: sender] == NSDragOperationLink);
}

- (NSWindow *)windowAndRect: (NSRect *)prect
		  forObject: (id) object
{
  if (object == tableView)
    {
      *prect = [tableView convertRect: [tableView visibleRect]
			  toView :nil];
      return _window;
    }
  else
    {
      return [super windowAndRect: prect forObject: object];
    }
}
@end
