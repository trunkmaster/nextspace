/* GormBoxEditor.m
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

#include "GormPrivate.h"
#include "GormBoxEditor.h"
#include "GormInternalViewEditor.h"
#include "GormViewKnobs.h"

#define _EO ((NSBox *)_editedObject)

@class GormWindowEditor;

@implementation NSBox (IBObjectAdditions)
- (NSString*) editorClassName
{
  return @"GormBoxEditor";
}

- (NSFont *) font
{
  return [self titleFont];
}

- (void) setFont: (NSFont *)aFont
{
  [self setTitleFont: aFont];
}
@end

@implementation GormBoxEditor
- (void) setOpened: (BOOL) flag
{
  [super setOpened: flag];
  if (flag == YES)
    {  
      [document setSelectionFromEditor: contentViewEditor];
    }
}

- (void) dealloc
{
  RELEASE(selection);
  [super dealloc];
}

- (BOOL) activate
{
  if ([super activate])
    {
      NSView *contentView = [_EO contentView];

      contentViewEditor = (GormInternalViewEditor *)[document editorForObject: contentView
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

- (void) makeSelectionVisible: (BOOL) value
{
  // not implemented here.
}

- (void) deleteSelection
{
  NSInteger i = 0;
  NSInteger count = [selection count];
  id temp = nil;
  
  for (i = count - 1; i >= 0; i--)
    {
      temp = [[selection objectAtIndex: i] editedObject];

      [[selection objectAtIndex: i] detachSubviews];
      [document detachObject: temp];
      [[selection objectAtIndex: i] close];

      [temp removeFromSuperview];
      [selection removeObjectAtIndex: i];
    }
  
  [self selectObjects: [NSArray array]];
  
}

- (void) mouseDown: (NSEvent *) theEvent
{
  BOOL onKnob = NO;

  // if we are on one of our own knob, then this event should be processed
  // by our parent (cause this is a resizing event)
  if ([parent respondsToSelector: @selector(selection)] &&
      [[parent selection] containsObject: _EO])
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

  if (opened == NO)
    {
      [super mouseDown: theEvent];
      return;
    }

  if ([[_EO hitTest: [theEvent locationInWindow]]
	isDescendantOf: contentViewEditor])
    {
      if ([contentViewEditor isOpened] == NO)
	{
	  [contentViewEditor setOpened: YES];
	}
      [contentViewEditor mouseDown: theEvent];
    }
  else
    {      
      if ([contentViewEditor isOpened] == YES)
	{
	  [contentViewEditor setOpened: NO];
	}

      if ((NSMouseInRect([_EO convertPoint: [theEvent locationInWindow]
			      fromView: nil], 
			 [_EO titleRect], NO) == YES)
	  && ([theEvent clickCount] == 2))
	{
	  NSTextField *tf = 
	    [[NSTextField alloc] initWithFrame: 
				   [self convertRect: [_EO titleRect]
					 fromView: _EO]];
	  NSRect frame = [tf frame];
	  frame.origin.x = [self bounds].origin.x + 3;
	  frame.size.width = [self bounds].size.width - 6;
	  frame.origin.y -= 3;
	  frame.size.height += 4;
	  [tf setBordered: YES];
	  [tf setEditable: YES];
	  [tf setBezeled: NO];
	  [tf setAlignment: NSCenterTextAlignment];
	  [tf setFrame: frame];
	  [self addSubview: tf];
	  [tf setStringValue: [_EO title]];
	  [self editTextField: tf
		withEvent: theEvent];
	  [_EO setTitle: [tf stringValue]];
	  [tf removeFromSuperview];
	  RELEASE(tf);
	  [[NSNotificationCenter defaultCenter] 
	    postNotificationName: IBSelectionChangedNotification
	    object: self];
	}
    }  
}

- (NSArray *)destroyAndListSubviews
{
  if (contentViewEditor)
    {
      if([contentViewEditor respondsToSelector: @selector(destroyAndListSubviews)])
	{
	  return [contentViewEditor destroyAndListSubviews];
	}
      else
	{
	  return nil;
	}
    }
  else
    {
      return nil;
    }
}
@end
