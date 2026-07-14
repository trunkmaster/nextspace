/*
  GormBrowserAttributesInspector.m

   Copyright (C) 2001-2015 Free Software Foundation, Inc.

   Author:  Adam Fedor <fedor@gnu.org>
            Laurent Julliard <laurent@julliard-online.org>
            Gregory John Casamento <greg_casamento@yahoo.com>
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

#include "GormBrowserAttributesInspector.h"

@implementation GormBrowserAttributesInspector

- (id) init
{
  if ([super init] == nil)
    {
      return nil;
    }

  if ([NSBundle loadNibNamed: @"GormNSBrowserInspector" owner: self] == NO)
    {
      NSLog(@"Could not gorm GormBrowserInspector");
      return nil;
    }

  return self;
}

/* Commit changes that the user makes in the Attributes Inspector */
- (void) ok: (id)sender
{
  /* options */
  if ( sender == multipleSelectionSwitch ) 
    {
      [object setAllowsMultipleSelection: [multipleSelectionSwitch state]];
    }
  else if ( sender == emptySelectionSwitch ) 
    {
      [object setAllowsEmptySelection: [emptySelectionSwitch state]];
    }
  else if ( sender == branchSelectionSwitch ) 
    {
      [object setAllowsBranchSelection: [branchSelectionSwitch state]];
    }
  else if ( sender == separateColumnsSwitch ) 
    {
      [object setSeparatesColumns: [separateColumnsSwitch state]];
    }
  else if ( sender == horizontalScrollerSwitch ) 
    {
      [object setHasHorizontalScroller: [horizontalScrollerSwitch state]];
    }
  else if ( sender == displayTitlesSwitch )
    {
      [object setTitled: [displayTitlesSwitch state]];
    }
  else if ( sender == minColumnWidthField )   /* minimum column width */
    {
      // TODO: Use stepper..
      [object setMinColumnWidth: [minColumnWidthField intValue]];
      [minColumnWidthField setStringValue:
               [NSString stringWithFormat:@"%.2f",
                         [object minColumnWidth]]];
    }
  else if ( sender == maxVisibleColumnsField ) 
    {
      [object setMaxVisibleColumns: [maxVisibleColumnsField intValue]];
    }
  else if(sender == tagForm)   /* tag */
    {
      [object setTag:[[tagForm cellAtIndex:0] intValue]];
    }

  [super ok:sender];
}

/* Sync from object ( NSBrowser ) changes to the inspector */
- (void) revert: (id) sender
{
  if (object == nil)
    return;
  
  [multipleSelectionSwitch setState: [object allowsMultipleSelection]];
  [emptySelectionSwitch setState: [object allowsEmptySelection]];
  [branchSelectionSwitch setState:[object allowsBranchSelection]];
  [separateColumnsSwitch setState:[object separatesColumns]];
  [displayTitlesSwitch setState:[object isTitled]];
  [horizontalScrollerSwitch setState:[object hasHorizontalScroller]];

  [[tagForm cellAtIndex:0] setIntValue: [object tag]];

  [minColumnWidthField setStringValue:
			 [NSString stringWithFormat:@"%.2f",
				   [object minColumnWidth]]];
  [maxVisibleColumnsField setStringValue:
			    [NSString stringWithFormat:@"%ld",
				      (long int)[object maxVisibleColumns]]];

  [super revert:sender];
}

/* delegate method for tagForm and minColumnWidthField */
-(void) controlTextDidChange:(NSNotification *)aNotification
{
  [self ok:[aNotification object]];
}


@end
