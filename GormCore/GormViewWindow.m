/* GormViewWindow.m
 *
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	2004
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

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#include <InterfaceBuilder/InterfaceBuilder.h>

#include "GormViewWindow.h"
#include "GormFunctions.h"

@interface GormViewWindowDelegate : NSObject
{
  NSView *_view;
}

- (id) initWithView: (NSView *)view;
- (void) initialResize;
@end

@implementation GormViewWindowDelegate

- (id) initWithView: (NSView *)view;
{
  if((self = [super init]) != nil)
    {
      _view = view;
      [self initialResize];
    }
  return self;
}

- (void) initialResize
{
  NSWindow *window = [_view window];
  NSRect windowFrame = [window frame];
  
  // if the view is uninitialized, 
  // it's new... give it size.
  if(NSIsEmptyRect([_view frame]))
    {    
      NSArray *subs = [_view subviews];
      NSRect newFrame;

      if([subs count] > 0)
	{
	  newFrame = minimalContainerFrame(subs);
	  newFrame.size.height += 70;
	  newFrame.size.width += 40;
	  [window setFrame: newFrame display: YES];
	  [_view setPostsFrameChangedNotifications: YES];
	}
      else
	{
	  newFrame = windowFrame;
	  
	  newFrame.origin.x = 10;
	  newFrame.origin.y = 20;
	  newFrame.size.height -= 70;
	  newFrame.size.width -= 20;
	}

      [_view setPostsFrameChangedNotifications: NO];
      [_view setFrame: newFrame];
      [_view setPostsFrameChangedNotifications: YES];
    }
  else // otherwise take size from it.
    {
      NSRect newFrame = [_view frame];

      newFrame.origin.x = windowFrame.origin.x+10;
      newFrame.origin.y = windowFrame.origin.y+20;
      newFrame.size.height += 100;
      newFrame.size.width += 20;

      [_view setPostsFrameChangedNotifications: NO];
      [_view setFrame: newFrame];
      [_view setPostsFrameChangedNotifications: YES];
      [window setFrame: newFrame display: YES];
    }

  [window center];
}

- (void) windowDidResize: (NSNotification *)notification
{
  NSWindow *window = [_view window];
  NSRect windowFrame = [window frame];
  NSRect newFrame = windowFrame;
  NSRect viewFrame = [_view frame];

  newFrame.origin.x = 10;
  newFrame.origin.y = 20;
  newFrame.size.height -= 70;
  newFrame.size.width -= 20;

  if(NSIsEmptyRect(viewFrame))
    {
      [_view setPostsFrameChangedNotifications: NO];
      [_view setFrame: newFrame];
      [_view setPostsFrameChangedNotifications: YES];
    }
  else
    {
      [_view setFrame: newFrame];
      [_view setNeedsDisplay: YES];
    }
}

@end


@implementation GormViewWindow

- (id) initWithView: (NSView *)view
{
  if((self = [super init]) != nil)
    { 
      NSString *className = NSStringFromClass([view class]);
      NSString *objectName = [[(id<IB>)[NSApp delegate] activeDocument] nameForObject: view];
      NSString *title = [NSString stringWithFormat: @"Standalone View Window: (%@, %@)",
				  className, objectName];
      NSColor *color = [NSColor lightGrayColor];

      [self setTitle: title];
      [self setFrame: NSMakeRect(0,0,400,300) display: YES];
      [self setBackgroundColor: color];
      [self setReleasedWhenClosed: NO];
      [self setView: view];
    }
  return self;
}

- (void) setView: (NSView *)view
{
  if(_view != nil)
    {
      [_view removeFromSuperviewWithoutNeedingDisplay];
    }

  _view = view;

  [[self contentView] addSubview: _view];
  RELEASE([self delegate]);
  [self setDelegate: [[GormViewWindowDelegate alloc] initWithView: _view]];
}

- (NSView *) view
{
  return _view;
}

- (void) activateEditorForView
{
  id editor = [[(id<IB>)[NSApp delegate] activeDocument] editorForObject: _view create: YES];
  // NSArray *subviews = [_view subviews];
  // NSEnumerator *en = [subviews objectEnumerator];
  // id sub = nil;

  // activate the parent and all subview editors...
  [(id<IBEditors>)editor activate];
  /*
  while((sub = [en nextObject]) != nil)
    {
      editor = [[(id<IB>)[NSApp delegate] activeDocument] editorForObject: sub create: YES];
      [editor activate];
    }
  */
}

- (void) encodeWithCoder: (NSCoder *)coder
{
  [NSException raise: NSInternalInconsistencyException
	       format: @"Cannot encode a GormViewWindow"];
}

- (void) orderFront: (id)sender
{
  [super orderFront: sender];
  [self activateEditorForView];
}

- (void) dealloc
{
  RELEASE([self delegate]);
  [self setDelegate: nil];
  [super dealloc];
}

@end

