/** <title>GormNSMenuView</title>

   Copyright (C) 2007 Free Software Foundation, Inc.

   Author: Gregory Casamento <greg.casamento@gmail.com>
   Date: 2007
   
   This file is part of the GNUstep GUI Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
*/

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#include "GormNSMenuView.h"

@implementation GormNSMenuView
- (BOOL) _executeItemAtIndex: (int)indexOfActionToExecute
	       removeSubmenu: (BOOL)subMenusNeedRemoving
{
  if (indexOfActionToExecute == -1)
    {
      return YES;
    }
  
  if (indexOfActionToExecute >= 0
      && [[self menu] attachedMenu] != nil && [[self menu] attachedMenu] ==
      [[[[self menu] itemArray] objectAtIndex: indexOfActionToExecute] submenu])
    {
      if (subMenusNeedRemoving)
        {
          [self detachSubmenu];
        }
      return NO;
    }

  return YES;
}

- (NSPoint) locationForSubmenu: (NSMenu *)aSubmenu
{
  NSRect frame = [_window frame];
  NSRect submenuFrame;

  if (_needsSizing)
    [self sizeToFit];

  if (aSubmenu)
    submenuFrame = [[[aSubmenu menuRepresentation] window] frame];
  else
    submenuFrame = NSZeroRect;

  return NSMakePoint(NSMaxX(frame),
		     NSMaxY(frame) - NSHeight(submenuFrame));

}
@end

