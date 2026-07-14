/* Implementation of class NSMenuToolbarItem
   Copyright (C) 2024 Free Software Foundation, Inc.

   By: Gregory John Casamento
   Date: 03-05-2024

   This file is part of the GNUstep Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110 USA.
*/

#import "AppKit/NSMenuToolbarItem.h"
#import "AppKit/NSMenu.h"
#import "AppKit/NSImage.h"

#import "GNUstepGUI/GSTheme.h"

@implementation NSMenuToolbarItem

- (instancetype) initWithItemIdentifier: (NSString *)identifier
{
  self = [super initWithItemIdentifier: identifier];
  if (self != nil)
    {
      [self setImage: [NSImage imageNamed: @"NSMenuToolbarItem"]];
      [self setTarget: self];
      [self setAction: @selector(_showMenu:)];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_menu);
  [super dealloc];
}

- (BOOL) showsIndicator
{
  return _showsIndicator;
}

- (void) setShowsIndicator: (BOOL)flag
{
  _showsIndicator = flag;

  if (_showsIndicator == YES)
    {
      [self setImage: [NSImage imageNamed: @"NSMenuToolbarItem"]];
    }
  else
    {
      [self setImage: nil];
    }
}

- (NSMenu *) menu
{
  return _menu;
}

- (void) setMenu: (NSMenu *)menu
{
  ASSIGN(_menu, menu);
}

- (void) _showMenu: (id)sender
{
  [[GSTheme theme] rightMouseDisplay: _menu
			    forEvent: nil];
}

@end
