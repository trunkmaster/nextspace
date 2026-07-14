/* GormNSPanel.m

   Copyright (C) 2003 Free Software Foundation, Inc.

   Author: Gregory John Casamento <greg_casamento@yahoo.com>
   Date: 2003
   (Adapted from GormNSWindow.m)
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

#include <AppKit/AppKit.h>

#include <InterfaceBuilder/InterfaceBuilder.h>

#include <GNUstepGUI/GSGormLoading.h>

#include "GormNSPanel.h"


// the default style mask we start with.
static NSUInteger defaultStyleMask = NSTitledWindowMask | NSClosableWindowMask
		  | NSResizableWindowMask | NSMiniaturizableWindowMask;

@implementation GormNSPanel
- (void)encodeWithCoder: (NSCoder*) aCoder
{
  unsigned oldStyleMask;

  // save the old values...
  oldStyleMask = _styleMask;

  // set the values we wish to save.. after save restore.
  _styleMask = _gormStyleMask;
  [self setReleasedWhenClosed: _gormReleasedWhenClosed];
  [super encodeWithCoder: aCoder];
  _styleMask = oldStyleMask;
  [self setReleasedWhenClosed: NO];
}

- (id) initWithCoder: (NSCoder *)coder
{
  self = [super initWithCoder: coder];
  if (self == nil)
    {
      return nil;
    }
  
  // preserve the setting and set the actual window to NO.
  _gormReleasedWhenClosed = [self isReleasedWhenClosed];
  [self setReleasedWhenClosed: NO];
  
  return self;
}

- (id) initWithContentRect: (NSRect)contentRect
		 styleMask: (NSUInteger)aStyle
		   backing: (NSBackingStoreType)bufferingType
		     defer: (BOOL)flag
{
  _gormStyleMask = aStyle;
  self = [super initWithContentRect: contentRect
		styleMask: defaultStyleMask
		backing: bufferingType
		defer: flag];
  if(self != nil)
    {
      // Don't release when the window is closed, a window being edited may
      // be periodically opened and closed.
      [self setReleasedWhenClosed: NO];

      // remove the default icon...
      [self setMiniwindowImage: nil];

      // set the default position mask;
      autoPositionMask = GSWindowMaxXMargin | GSWindowMaxYMargin;
    }

  return self;
}

- (void) _setStyleMask: (unsigned int) newStyleMask
{
  _gormStyleMask = newStyleMask;
}

- (unsigned int) _styleMask
{
  return _gormStyleMask;
}

- (NSString *) className
{
  return @"NSPanel";
}

- (void) _setReleasedWhenClosed: (BOOL) flag
{
  _gormReleasedWhenClosed = flag;
}

- (BOOL) _isReleasedWhenClosed
{
  return _gormReleasedWhenClosed;
}

- (unsigned int) autoPositionMask
{
  return autoPositionMask;
}

- (void) setAutoPositionMask: (unsigned int)mask
{
  autoPositionMask = mask;
}

- (void) orderWindow: (NSWindowOrderingMode)place relativeTo: (NSInteger)otherWin
{
  id<IBDocuments> document = [(id<IB>)[NSApp delegate] documentForObject: self];
  [super orderWindow: place relativeTo: otherWin];
  if([[NSApp delegate] isConnecting] == NO)
    { 
      id editor = [document editorForObject: self create: NO];

      // select myself.
      if([editor respondsToSelector: @selector(selectObjects:)])
	{
	  [editor selectObjects: [NSArray arrayWithObject: self]];
	}

      [document setSelectionFromEditor: editor];
      [editor makeSelectionVisible: YES];
    }
}

- (void) saveFrameUsingName: (NSString*)name
{
  // do nothing... 
}
@end
