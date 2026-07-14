/* GormClassPanelController.m
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

/* All rights reserved */

#include <AppKit/AppKit.h>

#include "GormClassPanelController.h"
#include "GormPrivate.h"

@implementation GormClassPanelController

- (id) initWithTitle: (NSString *)title classList: (NSArray *)classes
{
  self = [super init];
  if(self != nil)
    {
      NSBundle *bundle = [NSBundle bundleForClass: [self class]];
      
      if ( ![bundle loadNibNamed:@"GormClassPanel" owner:self topLevelObjects: NULL] )
	{
	  NSLog(@"Can not load bundle GormClassPanel");
	  return nil;
	}
    }

  ASSIGN(allClasses, [classes mutableCopy]);
  [allClasses removeObject: @"FirstResponder"];
  [panel setTitle: title];
  [classBrowser loadColumnZero];

  return self;
}

- (NSString *)runModal
{
  [NSApp runModalForWindow: panel];
  [panel orderOut: self];
  return className;
}

- (void) dealloc
{
  RELEASE(allClasses);
  RELEASE(className);
  RELEASE(panel);
  [super dealloc];
}

- (void) okButton: (id)sender
{
  ASSIGN(className, [[classNameForm cellAtIndex: 0] stringValue]);
  [NSApp stopModal];
}

- (void) browserAction: (id)sender
{
  [[classNameForm cellAtIndex: 0] setStringValue: [[classBrowser selectedCell] stringValue]];
}

- (NSInteger) browser: (NSBrowser*)sender numberOfRowsInColumn: (NSInteger)column
{
  return [allClasses count];
}

- (NSString*) browser: (NSBrowser*)sender titleOfColumn: (NSInteger)column
{
  return @"Class";
}

- (void) browser: (NSBrowser*)sender
 willDisplayCell: (id)aCell
	   atRow: (NSInteger)row
	  column: (NSInteger)col
{
  if (row >= 0 && row < [allClasses count])
    {
      [aCell setStringValue: [allClasses objectAtIndex: row]];
      [aCell setEnabled: YES];
    }
  else
    {
      [aCell setStringValue: @""];
      [aCell setEnabled: NO];
    }
  [aCell setLeaf: YES];
}
@end
