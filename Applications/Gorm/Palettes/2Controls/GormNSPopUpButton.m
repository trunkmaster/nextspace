/** 
   main.m

   Copyright (C) 2024 Free Software Foundation, Inc.

   Author:  Gregory John Casamento <greg_casamento@yahoo.com>
   Date: 2024
   
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

#include <GormCore/GormCore.h>
#include "GormNSPopUpButton.h"

Class _gormnspopupbuttonCellClass = 0;

@implementation GormNSPopUpButton
/*
 * Class methods
 */
+ (void) initialize
{
  if (self == [GormNSPopUpButton class])
    {
      // Initial version
      [self setVersion: 1];
      [self setCellClass: [GormNSPopUpButtonCell class]];
    } 
}

+ (Class) cellClass
{
  return _gormnspopupbuttonCellClass;
}

+ (void) setCellClass: (Class)classId
{
  _gormnspopupbuttonCellClass = classId;
}

- (NSString*) editorClassName
{
  return @"GormPopUpButtonEditor";
}

- (NSString *) className
{
  return @"NSPopUpButton";
}
@end

@implementation NSPopUpButtonCell (DirtyHack)
- (id) _gormInitTextCell: (NSString *) string
{
  return [super initTextCell: string];
}
@end

@implementation GormNSPopUpButtonCell 

/* Overriden helper method */
- (void) _initMenu
{
  NSMenu *menu = [[NSMenu allocSubstitute] initWithTitle: @""];
  [self setMenu: menu];
  RELEASE(menu);
}

- (NSString *) className
{
  return @"NSPopUpButtonCell";
}

/**
 * Override this here, since themes may override it.
 * Always want to show the menu view since it's editable. 
 */
/*
- (void) attachPopUpWithFrame: (NSRect)cellFrame
                       inView: (NSView *)controlView
{
  NSRectEdge            preferredEdge = _pbcFlags.preferredEdge;
  NSNotificationCenter  *nc = [NSNotificationCenter defaultCenter];
  NSWindow              *cvWin = [controlView window];
  NSMenuView            *mr = [[self menu] menuRepresentation];
  int                   selectedItem;

  [nc postNotificationName: NSPopUpButtonCellWillPopUpNotification
                    object: self];

  [nc postNotificationName: NSPopUpButtonWillPopUpNotification
                    object: controlView];

  // Convert to Screen Coordinates
  cellFrame = [controlView convertRect: cellFrame toView: nil];
  cellFrame.origin = [cvWin convertBaseToScreen: cellFrame.origin];

  if (_pbcFlags.pullsDown)
    selectedItem = -1;
  else
    {
      selectedItem = [self indexOfSelectedItem];
      if (selectedItem == -1) // Test
	selectedItem = 0;
    }

  if (selectedItem > 0)
    {
      [mr setHighlightedItemIndex: selectedItem];
    }

  if ([controlView isFlipped])
    {
      if (preferredEdge == NSMinYEdge)
	{
	  preferredEdge = NSMaxYEdge;
	}
      else if (preferredEdge == NSMaxYEdge)
	{
	  preferredEdge = NSMinYEdge;
	}
    }

  // Ask the MenuView to attach the menu to this rect
  [mr setWindowFrameForAttachingToRect: cellFrame
      onScreen: [cvWin screen]
      preferredEdge: preferredEdge
      popUpSelectedItem: selectedItem];

  // Set to be above the main window
  [cvWin addChildWindow: [mr window] ordered: NSWindowAbove];

  // Last, display the window
  [[mr window] orderFrontRegardless];

  [nc addObserver: self
      selector: @selector(_handleNotification:)
      name: NSMenuDidSendActionNotification
      object: _menu];
}
*/

@end
