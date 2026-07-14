/* GormButtonEditor.m
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

#include "GormButtonEditor.h"

#define _EO ((NSButton *)_editedObject)

@interface NSButtonCell (GormObjectAdditions)
- (NSRect) gormTitleRectForFrame: (NSRect) cellFrame
			  inView: (NSView *)controlView;
@end

@implementation NSButtonCell (GormObjectAdditions)
- (NSRect) gormTitleRectForFrame: (NSRect) cellFrame
			  inView: (NSView *)controlView
{
  unsigned	mask;
  NSImage	*imageToDisplay;
  NSRect	imageRect;
  NSString	*titleToDisplay;
  NSRect	titleRect = {{0,0},{0,0}};
  NSSize	imageSize = {0, 0};
  NSSize        titleSize = {0, 0};
  NSColor	*backgroundColor = nil;
  BOOL		flippedView = [controlView isFlipped];
  NSCellImagePosition ipos = _cell.image_position;

  cellFrame = [self drawingRectForBounds: cellFrame];

  if (_cell.is_highlighted)
    {
      mask = _highlightsByMask;

      if (_cell.state)
	mask &= ~_showAltStateMask;
    }
  else if (_cell.state)
    mask = _showAltStateMask;
  else
    mask = NSNoCellMask;

  /* Pushed in buttons contents are displaced to the bottom right 1px.  */
  if (_cell.is_bordered && (mask & NSPushInCellMask))
    {
      cellFrame = NSOffsetRect(cellFrame, 1., flippedView ? 1. : -1.);
    }

  /* Determine the background color. */
  if (mask & (NSChangeGrayCellMask | NSChangeBackgroundCellMask))
    {
      backgroundColor = [NSColor selectedControlColor];
    }

  if (backgroundColor == nil)
    backgroundColor = [NSColor controlBackgroundColor];

  /*
   * Determine the image and the title that will be
   * displayed. If the NSContentsCellMask is set the
   * image and title are swapped only if state is 1 or
   * if highlighting is set (when a button is pushed it's
   * content is changed to the face of reversed state).
   */
  if (mask & NSContentsCellMask)
    {
      imageToDisplay = _altImage;
      if (!imageToDisplay)
	imageToDisplay = _cell_image;
      titleToDisplay = _altContents;
      if (titleToDisplay == nil || [titleToDisplay isEqual: @""])
        titleToDisplay = _contents;
    }
  else
    {
      imageToDisplay = _cell_image;
      titleToDisplay = _contents;
    }

  if (imageToDisplay)
    {
      imageSize = [imageToDisplay size];
    }

  titleSize = [self _sizeText: titleToDisplay];

  if (flippedView == YES)
    {
      if (ipos == NSImageAbove)
	{
	  ipos = NSImageBelow;
	}
      else if (ipos == NSImageBelow)
	{
	  ipos = NSImageAbove;
	}
    }
  
  switch (ipos)
    {
      case NSNoImage: 
	imageToDisplay = nil;
	titleRect = cellFrame;
	{
	  int heightDiff = titleRect.size.height - titleSize.height;
	  titleRect.origin.y += heightDiff - heightDiff / 2;
	  titleRect.size.height -= heightDiff;
	}
	break;

      case NSImageOnly: 
	titleToDisplay = nil;
	imageRect = cellFrame;
	break;

      case NSImageLeft: 
	imageRect.origin = cellFrame.origin;
	imageRect.size.width = imageSize.width;
	imageRect.size.height = cellFrame.size.height;
	if (_cell.is_bordered || _cell.is_bezeled) 
	  {
	    imageRect.origin.x += 3;
	    imageRect.size.height -= 2;
	    imageRect.origin.y += 1;
	  }
	titleRect = imageRect;
	titleRect.origin.x += imageSize.width + GSCellTextImageXDist;
	titleRect.size.width = cellFrame.size.width - imageSize.width - GSCellTextImageXDist;
	if (_cell.is_bordered || _cell.is_bezeled) 
	  {
	    titleRect.size.width -= 3;
	  }
	{
	  int heightDiff = titleRect.size.height - titleSize.height;
	  titleRect.origin.y += heightDiff - heightDiff / 2;
	  titleRect.size.height -= heightDiff;
	}
	break;

      case NSImageRight: 
	imageRect.origin.x = NSMaxX(cellFrame) - imageSize.width;
	imageRect.origin.y = cellFrame.origin.y;
	imageRect.size.width = imageSize.width;
	imageRect.size.height = cellFrame.size.height;
	if (_cell.is_bordered || _cell.is_bezeled) 
	  {
	    imageRect.origin.x -= 3;
	    imageRect.size.height -= 2;
	    imageRect.origin.y += 1;
	  }
	titleRect.origin = cellFrame.origin;
	titleRect.size.width = cellFrame.size.width - imageSize.width - GSCellTextImageXDist;
	titleRect.size.height = cellFrame.size.height;
	if (_cell.is_bordered || _cell.is_bezeled) 
	  {
	    titleRect.origin.x += 3;
	    titleRect.size.width -= 3;
	  }
	{
	  int heightDiff = titleRect.size.height - titleSize.height;
	  titleRect.origin.y += heightDiff - heightDiff / 2;
	  titleRect.size.height -= heightDiff;
	}
	break;

      case NSImageAbove: 
	/*
         * In this case, imageRect is all the space we can allocate
	 * above the text. 
	 * The drawing code below will then center the image in imageRect.
	 */
	titleRect.origin.x = cellFrame.origin.x;
	titleRect.origin.y = cellFrame.origin.y;
	titleRect.size.width = cellFrame.size.width;
	titleRect.size.height = titleSize.height;

	imageRect.origin.x = cellFrame.origin.x;
	imageRect.origin.y = cellFrame.origin.y;
	imageRect.origin.y += titleRect.size.height + GSCellTextImageYDist;
	imageRect.size.width = cellFrame.size.width;
	imageRect.size.height = cellFrame.size.height;
	imageRect.size.height -= titleSize.height + GSCellTextImageYDist;

	if (_cell.is_bordered || _cell.is_bezeled) 
	  {
	    imageRect.size.width -= 6;
	    imageRect.origin.x   += 3;
	    titleRect.size.width -= 6;
	    titleRect.origin.x   += 3;
	    imageRect.size.height -= 1;
	    titleRect.size.height -= 1;
	  }
	break;

      case NSImageBelow: 
	/*
	 * In this case, imageRect is all the space we can allocate
	 * below the text. 
	 * The drawing code below will then center the image in imageRect.
	 */
	titleRect.origin.x = cellFrame.origin.x;
	titleRect.origin.y = cellFrame.origin.y + cellFrame.size.height;
	titleRect.origin.y -= titleSize.height;
	titleRect.size.width = cellFrame.size.width;
	titleRect.size.height = titleSize.height;

	imageRect.origin.x = cellFrame.origin.x;
	imageRect.origin.y = cellFrame.origin.y;
	imageRect.size.width = cellFrame.size.width;
	imageRect.size.height = cellFrame.size.height;
	imageRect.size.height -= titleSize.height + GSCellTextImageYDist;

	if (_cell.is_bordered || _cell.is_bezeled) 
	  {
	    imageRect.size.width -= 6;
	    imageRect.origin.x   += 3;
	    titleRect.size.width -= 6;
	    titleRect.origin.x   += 3;
	    imageRect.size.height -= 1;
	    imageRect.origin.y    += 1;
	  }
	break;

      case NSImageOverlaps: 
	titleRect = cellFrame;
	imageRect = cellFrame;
	{
	  int heightDiff = titleRect.size.height - titleSize.height;
	  titleRect.origin.y += heightDiff - heightDiff / 2;
	  titleRect.size.height -= heightDiff;
	}
	break;
    }
  
  return titleRect;
}

@end

static BOOL done_editing;
static NSRect oldFrame;

@implementation GormButtonEditor

- (void) handleNotification: (NSNotification*)aNotification
{
  NSString	*name = [aNotification name];
  if ([name isEqual: NSControlTextDidEndEditingNotification] == YES)
    {
      done_editing = YES;
    }
  else if([name isEqual: IBWillSaveDocumentNotification] == YES)
    {
      done_editing = YES;

      [[NSNotificationCenter defaultCenter] 
	removeObserver: self
	name: IBWillSaveDocumentNotification
	object: nil];
      
      [tempTextView resignFirstResponder];
      [tempTextView removeFromSuperview];
      [tempTextView setDelegate: nil];

      tempTextView = nil;
    }
}

- (void) textDidChange: (NSNotification *)aNotification
{
  [_EO setTitle: [[aNotification object] string]];
  [_EO setNeedsDisplay: NO];
  [[(id<GormAppDelegate>)[NSApp delegate] inspectorsManager] updateSelection];
}

- (void) textDidEndEditing: (NSNotification *)aNotification
{
  [[aNotification object] setDelegate: nil];

  [_EO setTitle: [[aNotification object] string]];

  [[aNotification object] removeFromSuperview];
  {
    NSSize suggestedSize;
    NSRect newFrame = [_EO frame];
    suggestedSize = [[_EO cell] cellSize];
    if (suggestedSize.width > newFrame.size.width)
      {
	newFrame.origin.x = newFrame.origin.x
	  - (int)((suggestedSize.width - newFrame.size.width) / 2);
	newFrame.size.width = suggestedSize.width;
	[_EO setFrame: newFrame];
	[[self window] disableFlushWindow];
	[[self window] display];
	[[self window] enableFlushWindow];
	[[self window] flushWindow];
      }
  }
}


/* Edit a textfield. If it's not already editable, make it so, then
   edit it */
- (NSEvent *) editTextField: view withEvent: (NSEvent *)theEvent
{
  unsigned eventMask;
  BOOL wasEditable;
  BOOL didDrawBackground;
  NSTextField *editField;
  NSRect                 frame;
  NSNotificationCenter  *nc = [NSNotificationCenter defaultCenter];
  NSDate		*future = [NSDate distantFuture];
  NSEvent *e;
      
  editField = view;
  frame = [editField frame];
  wasEditable = [editField isEditable];
  [editField setEditable: YES];
  didDrawBackground = [editField drawsBackground];
  [editField setDrawsBackground: YES];

  [nc addObserver: self
      selector: @selector(handleNotification:)
      name: NSControlTextDidEndEditingNotification
      object: nil];

  /* Do some modal editing */
  [editField selectText: self];
  eventMask = NSLeftMouseDownMask | NSLeftMouseUpMask |
    NSKeyDownMask | NSKeyUpMask | NSFlagsChangedMask;


  done_editing = NO;
  while (!done_editing)
    {
      NSEventType eType;
      e = [[NSApp delegate] nextEventMatchingMask: eventMask
		 untilDate: future
		 inMode: NSEventTrackingRunLoopMode
		 dequeue: YES];
      eType = [e type];
      switch (eType)
	{
	case NSLeftMouseDown:
	  {
	    NSPoint dp =  [self convertPoint: [e locationInWindow]
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

  [editField setEditable: wasEditable];
  [editField setDrawsBackground: didDrawBackground];

  [nc removeObserver: self
                name: NSControlTextDidEndEditingNotification
              object: nil];

  [[editField currentEditor] resignFirstResponder];
  [self setNeedsDisplay: YES];

  tempTextView = nil;

  return e;
}

- (NSTextView *) startEditingInFrame: (NSRect) frame
{
  NSTextView *textView = [[NSTextView alloc] initWithFrame: frame];
  NSTextContainer *textContainer = [textView textContainer];

  tempTextView = textView;

  [textContainer setContainerSize: NSMakeSize(3000, NSHeight([textView frame]))];
  [textContainer setWidthTracksTextView: NO];
  [textContainer setHeightTracksTextView: NO];

  [textView setHorizontallyResizable: NO];
  [textView setVerticallyResizable: NO];

  [textView setMinSize: frame.size];
  [textView setMaxSize: frame.size];
  [textView setAutoresizingMask: NSViewMinXMargin | NSViewMaxXMargin];
  [textView setSelectable: YES];
  [textView setEditable: YES];
  [textView setRichText: NO];
  [textView setImportsGraphics: NO];
  [textView setFieldEditor: YES];
  [textView setHorizontallyResizable: YES];
  [textView setDelegate: self];
  [textView setPostsFrameChangedNotifications:YES];

  [[NSNotificationCenter defaultCenter] 
    addObserver: self
    selector: @selector(textViewFrameChanged:)
    name: NSViewFrameDidChangeNotification
    object: textView];

  [[NSNotificationCenter defaultCenter] 
    addObserver: self
    selector: @selector(handleNotification:)
    name: IBWillSaveDocumentNotification
    object: nil];

  oldFrame = frame;
  return textView;
}

- (void) textViewFrameChanged: (NSNotification *)aNot
{
  static BOOL inside = NO;
  NSRect newFrame;

  if (inside)
    return;
  inside = YES;

  [[[self window] contentView] setNeedsDisplayInRect: oldFrame];

  newFrame = [[aNot object] frame];

  if ([[aNot object] alignment] == NSCenterTextAlignment)
    {
      NSRect frame = [[_EO cell] 
		       gormTitleRectForFrame: [_EO frame]
  		       inView: _EO];
      int difference = newFrame.size.width - frame.size.width;
      newFrame.origin.x = frame.origin.x - (int) (difference / 2);
      [[aNot object] setFrame: newFrame];
      oldFrame = newFrame;
    }


  [[self superview] setNeedsDisplayInRect: oldFrame];
  inside = NO;
}

- (void) mouseDown:  (NSEvent*)theEvent
{
    // double-clicked -> let's edit
  if (([theEvent clickCount] == 2) && [parent isOpened])
    {
      NSRect frame = [[_EO cell] 
		       gormTitleRectForFrame: [_EO frame]
  		       inView: _EO];
      NSTextView *tv = [self startEditingInFrame: frame];
      [[self superview] addSubview: tv];
      [tv setText: [_EO title]];
      [tv setAlignment: [_EO alignment]];
      [tv setFont: [_EO font]];
      [[self window] display];
      [[self window] makeFirstResponder: tv];

      [tv mouseDown: theEvent];
    }
  else
    {
      [super mouseDown: theEvent];
    }
}
@end
