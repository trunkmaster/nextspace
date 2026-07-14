/* inspectors - Various inspectors for data elements

   Copyright (C) 2001 Free Software Foundation, Inc.

   Author:  Laurent Julliard <laurent@julliard-online.org>
   Date: Nov 2001   
   Author:  Gregory Casamento <greg_casamento@yahoo.com>
   Date: Nov 2003,2004,2005
   
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
#include <GormCore/GormCore.h>

#include "GormTextViewEditor.h"

@implementation GormTextViewEditor

- (id) initWithObject: (id)anObject 
	   inDocument: (id<IBDocuments>)aDocument
{
  if((self = [super initWithObject: anObject inDocument: aDocument]) != nil)
    {
      id sv = [anObject enclosingScrollView];
      [self registerForDraggedTypes: [NSArray arrayWithObjects: IBViewPboardType, 
					      GormLinkPboardType, 
					      IBFormatterPboardType, 
					      nil]];

      // subscribe to frame changes of the superview...
      [[NSNotificationCenter defaultCenter] addObserver: self
					    selector: @selector(handleNotification:)
					    name: NSViewFrameDidChangeNotification
					    object: sv];

      // make the view post frame changes...
      [[textView enclosingScrollView] setPostsFrameChangedNotifications: YES];
    }
  return self;
}

- (void) dealloc
{
  [[textView enclosingScrollView] setPostsFrameChangedNotifications: NO];
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  [super dealloc];
}

- (BOOL) activate
{
  if ([super activate])
    {
      if ([_editedObject isKindOfClass: [NSScrollView class]])
	{
	  textView = [(NSScrollView *)_editedObject documentView];
	}
      else
	{
	  textView = (NSTextView *)_editedObject;
	}

      return YES;
    }
  return NO;
}

- (void) deactivate
{
  [super deactivate];
  [[textView enclosingScrollView] setPostsFrameChangedNotifications: NO];
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
      NSView *hitView = 
	[[textView enclosingScrollView] 
	  hitTest: 
	    [[[textView enclosingScrollView] superview]
	      convertPoint: [sender draggingLocation]
	      fromView: nil]];

      if ((hitView == textView) || (hitView == [textView superview]))
	destination = textView;

      if (destination == nil)
	destination = _editedObject;

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

- (void) handleNotification: (id) notification
{
  id view = [notification object];
  NSRect frame = [view frame];
  NSSize size;
  
  if([view hasVerticalScroller])
    {
      NSSize s = [[view verticalScroller] frame].size;
      frame.size.width -= (s.width + 5);
    }

  if([view hasHorizontalScroller])
    {
      NSSize s = [[view horizontalScroller] frame].size;
      frame.size.height -= (s.height + 5);
    }

  size = frame.size;

  [textView setMinSize: size];
  [textView setFrame: frame]; 
}


@end
