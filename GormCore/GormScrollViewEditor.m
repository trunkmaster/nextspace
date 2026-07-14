/* GormScrollViewEditor.m
 *
 * Copyright (C) 2002 Free Software Foundation, Inc.
 *
 * Author:	Pierre-Yves Rivaille <pyrivail@ens-lyon.fr>
 * Author:      Gregory John Casamento <greg_casamento@yahoo.com>
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

#include "GormPrivate.h"
#include "GormBoxEditor.h"
#include "GormViewKnobs.h"

@implementation NSScrollView (IBObjectAdditions)
- (NSString *) inspectorClassName
{
  return @"GormScrollViewAttributesInspector";
}

- (NSString*) editorClassName
{
  return @"GormScrollViewEditor";
}
@end

#define _EO ((NSScrollView *)_editedObject)

@interface GormScrollViewEditor : GormViewWithSubviewsEditor
{
  GormInternalViewEditor *documentViewEditor;
}
@end

@implementation GormScrollViewEditor

- (void) setOpened: (BOOL) flag
{
  [super setOpened: flag];
  if (flag == YES)
    {  
      [document setSelectionFromEditor: documentViewEditor];
    }
}

- (BOOL) activate
{
  if ([super activate])
    {
      NSView *documentView = [_EO documentView];
      
      NSDebugLog(@"documentView %@", documentView);
      documentViewEditor = (GormInternalViewEditor *)[document 
						       editorForObject: documentView
						       inEditor: self 
						       create: YES];
      return YES;
    }

  return NO;
}

- (void) deactivate
{
  if (activated == YES)
    {
      [self deactivateSubeditors];
      
      [super deactivate];
    }
}

- (void) close
{
  [self setOpened: NO];
  [super close];
}

- (void) mouseDown: (NSEvent *) theEvent
{
  BOOL onKnob = NO;

  if ([parent respondsToSelector: @selector(selection)] &&
      [[parent selection] containsObject: _EO])
    {
      IBKnobPosition knob = IBNoneKnobPosition;
      NSPoint mouseDownPoint = 
	[self convertPoint: [theEvent locationInWindow]
	      fromView: nil];
      knob = GormKnobHitInRect([self bounds], 
			       mouseDownPoint);
      if (knob != IBNoneKnobPosition)
	{
	  onKnob = YES;
	}
    }

  if (onKnob == YES)
    {
      if (parent)
	{
	  return [parent mouseDown: theEvent];
	}
      else
	{
	  return [self noResponderFor: @selector(mouseDown:)];
	}
    }

  // Open the scrollview, if it's not opened...
  if (opened == NO)
    {
      [super mouseDown: theEvent];
      // return;
    }

  if ([[_EO hitTest: [theEvent locationInWindow]]
	isDescendantOf: documentViewEditor])
    {
      if (([self isOpened] == YES) && ([documentViewEditor isOpened] == NO))
	{
	  [documentViewEditor setOpened: YES];
	}
      if ([documentViewEditor isOpened])
	{
	  [documentViewEditor mouseDown: theEvent];
	}
    }
  else
    {
      NSView *v = [_EO hitTest: [theEvent locationInWindow]];
      id r = [v nextResponder];
      
      if([v respondsToSelector: @selector(setNextResponder:)])
	{
	  // this is done to prevent a responder loop.
	  [v setNextResponder: nil];
	  [v mouseDown: theEvent];	  
	  [v setNextResponder: r];
	}
      else
	{
	  [v mouseDown: theEvent];	  
	}
    }

  opened = NO;
}

- (void) dealloc
{
  RELEASE(selection);
  [super dealloc];
}

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
  [self registerForDraggedTypes: [NSArray arrayWithObjects: IBViewPboardType, 
					  GormLinkPboardType, 
					  IBFormatterPboardType, 
					  nil]];

  return self;
}

- (NSArray *)destroyAndListSubviews
{
  id documentView = [_EO documentView];
  NSArray *subviews = [documentView subviews];
  NSMutableArray *newSelection = [NSMutableArray array];

  if([documentView conformsToProtocol: @protocol(IBEditors)] == YES)
    {
      id internalView = [subviews objectAtIndex: 0];
      NSEnumerator *enumerator = [[internalView subviews] objectEnumerator];
      GormViewEditor *subview;

      if([[documentView editedObject] isKindOfClass: [NSTextView class]])
        return newSelection;

      [parent makeSubeditorResign];
      while ((subview = [enumerator nextObject]) != nil)
	{
	  id v;
	  NSRect frame;

	  v = [subview editedObject];
	  frame = [v frame];
	  frame = [parent convertRect: frame fromView: _EO];
	  [subview deactivate];      
	  [v setFrame: frame];
	  [newSelection addObject: v];
	}
    }
  else
    {
      NSRect frame = [documentView frame];

      if([documentView isKindOfClass: [NSTextView class]])
        return newSelection;

      // In this case the view editor is the documentView and
      // we need to add the internal view back into the superview
      frame = [parent convertRect: frame fromView: _EO];
      [documentView setFrame: frame];
      [newSelection addObject: documentView];
      [_EO setDocumentView: nil];
    }

  [self close];
  return newSelection;
}
@end
