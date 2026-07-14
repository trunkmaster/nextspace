/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2005 Free Software Foundation

   Authors: Serg Stoyan

   This file is part of GNUstep.

   This application is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#import <AppKit/AppKit.h>

#import <ProjectCenter/PCDefines.h>
#import <ProjectCenter/PCFileNameIcon.h>
#import <ProjectCenter/PCProjectBrowser.h>

@implementation PCFileNameIcon

- (void)awakeFromNib
{
  filePath = nil;
  [self setRefusesFirstResponder:YES];
//  [self setEditable:NO]; // prevents dragging
//  [self setImage:[NSImage imageNamed:@"ProjectCenter"]];
  [self 
    registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
}

- (id)initWithFrame:(NSRect)frameRect
{
  self = [super initWithFrame:frameRect];

  filePath = nil;
  [self setRefusesFirstResponder:YES];
//  [self setEditable:NO]; // prevents dragging
//  [self setImage:[NSImage imageNamed:@"ProjectCenter"]];

  return self;
}

- (void)dealloc
{
#ifdef DEBUG
  NSLog (@"PCFileNameIcon: dealloc");
#endif

  [[NSNotificationCenter defaultCenter] removeObserver:self];

  RELEASE(fileNameField);
  RELEASE(delegate);
  RELEASE(filePath);

  [super dealloc];
}

- (void)setFileNameField:(NSTextField *)field
{
  fileNameField = RETAIN(field);
}

- (void)setDelegate:(id)object
{
  ASSIGN(delegate, object);
}

- (void)updateIcon
{
  if (delegate)
    {
      if ([delegate respondsToSelector:@selector(fileNameIconImage)])
	{
	  [self setImage:[delegate fileNameIconImage]];
	}
      if ((fileNameField != nil) &&
	  [delegate respondsToSelector:@selector(fileNameIconTitle)])
	{
	  [fileNameField setStringValue:[delegate fileNameIconTitle]];
	}
      if ([delegate respondsToSelector:@selector(fileNameIconPath)])
	{
	  ASSIGN(filePath, [delegate fileNameIconPath]);
	}
    }
}

// --- Drag and drop

- (void)mouseDown:(NSEvent *)theEvent
{
  NSArray      *fileList = [NSArray arrayWithObjects:filePath, nil];
  NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
  NSPoint      dragPosition;

  [pboard declareTypes:[NSArray arrayWithObject:NSFilenamesPboardType]
		 owner:nil];
  [pboard setPropertyList:fileList forType:NSFilenamesPboardType];

  // Start the drag operation
  dragPosition = [self convertPoint:[theEvent locationInWindow]
			   fromView:nil];
  dragPosition.x -= 16;
  dragPosition.y -= 16;

  [self dragImage:[self image]
	       at:dragPosition
	   offset:NSZeroSize
	    event:theEvent
       pasteboard:pboard
	   source:self
	slideBack:YES];
}

// --- NSDraggingDestination protocol methods
// -- Before the image is released
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
  NSPasteboard *pb = [sender draggingPasteboard];
  NSArray      *paths = [pb propertyListForType:NSFilenamesPboardType];
  NSDragOperation draggingOp = NSDragOperationNone;

//  NSLog(@"Dragging entered: %@", paths);

  if (![paths isKindOfClass:[NSArray class]] || [paths count] == 0)
    {
      return draggingOp;
    }

  if (delegate && 
      [delegate respondsToSelector:@selector(canPerformDraggingOf:)] &&
      [delegate canPerformDraggingOf:paths] == YES)
    {
      draggingOp = NSDragOperationCopy;
    }

  if (draggingOp == NSDragOperationCopy)
    { // TODO: Change icon to icon that shows open state of destination
    }

  return draggingOp;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
  NSLog(@"Dragging exited");
}

// -- After the image is released
- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
  NSPasteboard *pb = [sender draggingPasteboard];
  NSArray      *paths = [pb propertyListForType:NSFilenamesPboardType];

  NSLog(@"Prepare for drag operation");

  if (delegate && 
      [delegate respondsToSelector:@selector(prepareForDraggingOf:)])
    {
      return [delegate prepareForDraggingOf:paths];
    }
  return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
  NSPasteboard *pb = [sender draggingPasteboard];
  NSArray      *paths = [pb propertyListForType:NSFilenamesPboardType];

  NSLog(@"performDragOperation: %@", paths);

  if (delegate && 
      [delegate respondsToSelector:@selector(performDraggingOf:)])
    {
      return [delegate performDraggingOf:paths];
    }

  return YES;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
  NSPasteboard *pb = [sender draggingPasteboard];
  NSArray      *paths = [pb propertyListForType:NSFilenamesPboardType];

  NSLog(@"Conclude drag operation");

  if (delegate && 
      [delegate respondsToSelector:@selector(concludeDraggingOf:)])
    {
      [delegate concludeDraggingOf:paths];
    }
}

// --- NSDraggingSource protocol methods

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
  return NSDragOperationCopy;
}

@end

