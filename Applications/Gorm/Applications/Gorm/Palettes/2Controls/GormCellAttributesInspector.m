/*
   GormCellAttributesInspector.m

   Copyright (C) 2001-2005 Free Software Foundation, Inc.

   Author: Adam Fedor <fedor@gnu.org>
           Laurent Julliard <laurent@julliard-online.org>
   Date: Aug 2001
   Author: Gregory John Casamento <greg_casamento@yahoo.com>
   Date: 2003,2004,2005
   
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

#include "GormCellAttributesInspector.h"

/*
  IBObjectAdditions category
 */
@implementation	NSCell (IBObjectAdditions)
- (NSString*) inspectorClassName
{
  return @"GormCellAttributesInspector";
}
@end

@implementation GormCellAttributesInspector

- (id) init
{
  if ([super init] == nil)
    {
      return nil;
    }
  if ([NSBundle loadNibNamed: @"GormNSCellInspector" owner: self] == NO)
    {
      NSLog(@"Could not gorm GormCellInspector");
      return nil;
    }

  return self;
}


/* Commit changes that the user makes in the Attributes Inspector */
- (void) ok:(id) sender
{
  if (sender == disabledSwitch)
    {
      [object setEnabled: [disabledSwitch state]];
    }
  else if (sender == tagForm)
    {
      [object setTag: [[sender cellAtIndex: 0] intValue]];
    }

  [super ok: sender];
}

/* Sync from object ( NSCell ) changes to the inspector   */
- (void) revert:(id) sender
{
  if ( object == nil)
    return;
  
  [disabledSwitch setState: [object isEnabled]];  
  [[tagForm cellAtRow: 0 column: 0] setIntValue: [object tag]];

  [super revert:sender];
}

/* delegate method for tagForm */
- (void)controlTextDidChange:(NSNotification *)aNotification
{
  [self ok:[aNotification object]];
}



@end
