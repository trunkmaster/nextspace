/* GormDocumentWindow.m
 *
 * Copyright (C) 2006 Free Software Foundation, Inc.
 *
 * Author:      Matt Rice <ratmice@gmail.com>
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

#include "GormDocumentWindow.h"
#include "GormPrivate.h"

@implementation GormDocumentWindow
/*
- (BOOL) canBecomeMainWindow
{
  return NO;
}
*/

- (void) setDocument:(id)document
{
  _document = document;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
{
  NSPasteboard *pb = [sender draggingPasteboard];
  NSUInteger mask = [sender draggingSourceOperationMask];
  NSUInteger oper = NSDragOperationNone;
  dragMgr = [_document resourceManagerForPasteboard:pb];
  
  if (dragMgr)
    {
      if (mask & NSDragOperationCopy)
        {
	  oper = NSDragOperationCopy;
	}
      else if (mask & NSDragOperationLink)
        {
 	  oper = NSDragOperationLink;
	}
      else if (mask & NSDragOperationMove)
        {
  	  oper = NSDragOperationMove;
	}
      else if (mask & NSDragOperationGeneric)
        {
          oper = NSDragOperationGeneric;
	}
      else if (mask & NSDragOperationPrivate)
        {
          oper = NSDragOperationPrivate;
	}
    }

  return oper;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender;
{
  dragMgr = nil;
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;
{
  return !(dragMgr == nil);	
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;
{
  [dragMgr addResourcesFromPasteboard:[sender draggingPasteboard]];
  return !(dragMgr == nil);	
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender;
{
  dragMgr = nil;
}

- (void)draggingEnded: (id <NSDraggingInfo>)sender;
{
  dragMgr = nil;
}

- (void) awakeFromNib
{
  [self setAcceptsMouseMovedEvents: YES];
}

@end

