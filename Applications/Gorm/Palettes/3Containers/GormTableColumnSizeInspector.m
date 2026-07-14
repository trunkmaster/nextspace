/*
   GormTableColumnSizeInspector.m

   Copyright (C) 2001-2005 Free Software Foundation, Inc.

   Author:  Adam Fedor <fedor@gnu.org>
              Laurent Julliard <laurent@julliard-online.org>
   Date: Aug 2001
   
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

/*
  July 2005 : Split inspector classes into separate files.
  Always use ok: revert: methods
  Clean up
  Author : Fabien Vallon <fabien@sonappart.net>
*/

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#include "GormTableColumnSizeInspector.h"

#define MINIMUMINDEX 0
#define CURRENTINDEX 1
#define MAXIMUMINDEX 2

@implementation GormTableColumnSizeInspector

- (id) init
{
  if ([super init] == nil)
    {
      return nil;
    }

  if ([NSBundle loadNibNamed: @"GormNSTableColumnSizeInspector" owner: self] == NO)
    {
      NSLog(@"Could not gorm GormTableColumnSizeInspector");
      return nil;
    }

  return self;
}

/* Commit changes that the user makes in the Attributes Inspector */
- (void) ok: (id)sender
{
  [object setMinWidth:
	    [[widthForm cellAtRow:MINIMUMINDEX column: 0] floatValue]];
  [object setWidth:
	    [[widthForm cellAtRow:CURRENTINDEX column: 0] floatValue]];
  [object setMaxWidth:
	    [[widthForm cellAtRow:MAXIMUMINDEX column: 0] floatValue]];

  [super ok:sender];
}

/* Sync from object ( NSTableColumn size ) changes to the inspector */
- (void) revert: (id) sender
{
  if (object == nil)
    return;
  
  [[widthForm cellAtRow:MINIMUMINDEX column: 0] setFloatValue: 
						  [object minWidth]];
  [[widthForm cellAtRow:CURRENTINDEX column: 0] setFloatValue:
						  [object width]];
  [[widthForm cellAtRow:MAXIMUMINDEX column: 0] setFloatValue:
						  [object maxWidth]];
  
  [super revert:sender];
}

- (void) controlTextDidEndEditing: (NSNotification*)aNotification
{
  [self ok:[aNotification object]];
}

/* delegate method for the form */
-(void) controlTextDidChange:(NSNotification *)aNotification
{
}


@end
