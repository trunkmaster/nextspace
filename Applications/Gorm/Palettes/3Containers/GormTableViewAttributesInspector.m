/*
  GormTableViewAttributesInspector.m

   Copyright (C) 2001 Free Software Foundation, Inc.

   Author:  Laurent Julliard <laurent@julliard-online.org>
   Author:  Gregory John Casamento <greg_casamento@yahoo.com>
   Date: Aug 2001. 2003, 2004
   
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

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#import <GormCore/GormCore.h>

#import "GormTableViewAttributesInspector.h"
#import "GormNSTableView.h"


@implementation GormTableViewAttributesInspector

- (id) init
{
  if ([super init] == nil)
    {
      return nil;
    }

  if ([NSBundle loadNibNamed: @"GormNSTableViewInspector" owner: self] == NO)
    {
      NSLog(@"Could not gorm GormTableViewInspector");
      return nil;
    }

  return self;
}

/* Commit changes that the user makes in the Attributes Inspector */
- (void) ok: (id)sender
{
  BOOL flag;
  BOOL isScrollView;
  id scrollView;

  scrollView = [object enclosingScrollView];
  isScrollView = [scrollView isKindOfClass: [NSScrollView class]];
  
  /* Selection */
  if ( sender == multipleSelectionSwitch ) 
    {
      [object setGormAllowsMultipleSelection:[multipleSelectionSwitch state]];
    }
  else if ( sender == emptySelectionSwith ) 
    {
      [object setGormAllowsEmptySelection: [emptySelectionSwith state]];
    }
  else if ( sender == columnSelectionSwitch ) 
    {
      [object setGormAllowsColumnSelection: [columnSelectionSwitch state]];
    }
  /* scrollers */
  else if ( (sender == verticalScrollerSwitch) && isScrollView)
    {
      flag = ([sender state] == NSOnState) ? YES : NO;
      [scrollView setHasVerticalScroller: flag];
    }
   else if ( (sender == horizontalScrollerSwitch) && isScrollView)
    {
      flag = ([sender state] == NSOnState) ? YES : NO;
      [scrollView setHasHorizontalScroller: flag];
    } 
  /* border */
  else if ( (sender == borderMatrix) && isScrollView)
    {
      [scrollView setBorderType: [[sender selectedCell] tag]];
    }
  /* dimension */
  else if (sender == rowsHeightForm)
    {
      int numCols = [(NSTableView*)object numberOfColumns];
      int newNumCols = [[sender cellAtIndex: 1] intValue];
      float rowHeight = [[sender cellAtIndex: 0] floatValue];

      // make sure the minimum height doesn't go below 1.
      if(rowHeight < 1.0)
	{
	  rowHeight = 1.0;
	  [[sender cellAtIndex: 0] setFloatValue: 1.0]; 
	}

      // add/delete columns based on number in #columns field...
      [object setRowHeight: rowHeight];
      if(newNumCols > 0)
	{
	  if(numCols < newNumCols)
	    {
	      int colsToAdd = newNumCols - numCols;
	      int i = 0;
	      // Add columns from the last to the target number...
	      for(i = 0; i < colsToAdd; i++)
		{
		  NSString *identifier = [NSString stringWithFormat: @"column%d",(numCols + i + 1)];
		  NSTableColumn *tc = AUTORELEASE([(NSTableColumn *)[NSTableColumn alloc] initWithIdentifier: (id)identifier]);
		  [tc setWidth: 50];
		  [tc setMinWidth: 20];
		  [tc setResizable: YES];
		  [tc setEditable: YES];
		  [object addTableColumn: tc];
		}
	    }
	  else if(numCols > newNumCols)
	    {
	      int colsToDelete = numCols - newNumCols;
	      int i = 0;
	      NSArray *columns = [object tableColumns];
	      // remove columns...
	      for(i = 0; i < colsToDelete; i++)
		{
		  NSTableColumn *tc = [columns objectAtIndex: (i + newNumCols)];
		  [object removeTableColumn: tc];
		}
	    }
	}

      // recompute column sizes..
      [object sizeToFit];
      [object tile];
    } 
  /* Options */
  else if ( sender == drawgridSwitch ) 
    {
      [object setDrawsGrid:[drawgridSwitch state]];
    }
  else if ( sender == resizingSwitch ) 
    {
      [object setGormAllowsColumnResizing: [resizingSwitch state]];
    }
  else if ( sender == reorderingSwitch ) 
    {
      [object setGormAllowsColumnReordering:[reorderingSwitch state]];
    }
  /* tag */
  else if( sender == tagForm )
    {
      [object setTag:[[tagForm cellAtIndex:0] intValue]];
    }
  /* background color */
  else if( sender == backgroundColor )
    {
      [object setBackgroundColor: [backgroundColor color]];
    }

  // #warning always needed ? 
  [scrollView setNeedsDisplay: YES];

  [super ok:sender];
}

/* Sync from object ( NSTableView and its scollView ) changes to the inspector   */
- (void) revert: (id) sender
{
  BOOL isScrollView;
  id scrollView;

  if ( object == nil ) 
    return;

  scrollView = [object enclosingScrollView];

  isScrollView = [ scrollView isKindOfClass: [NSScrollView class]];

  /* selection */
  [multipleSelectionSwitch setState: [object gormAllowsMultipleSelection]];
  [emptySelectionSwith setState:[object gormAllowsEmptySelection]];
  [columnSelectionSwitch setState:[object gormAllowsColumnSelection]];

  
  if (isScrollView)
    {
      /* scrollers */
      [verticalScrollerSwitch setEnabled: YES];
      [verticalScrollerSwitch setState: 
				([scrollView hasVerticalScroller]) ? NSOnState : NSOffState];

      [horizontalScrollerSwitch setEnabled: YES];   
      [horizontalScrollerSwitch setState: 
				  ([scrollView hasHorizontalScroller]) ? NSOnState : NSOffState];
      
      /* border */
      [borderMatrix setEnabled: YES];
      [borderMatrix selectCellWithTag: [scrollView borderType]];
    }
  else
    {
      [verticalScrollerSwitch setEnabled: NO];
      [horizontalScrollerSwitch setEnabled: NO];   
      [borderMatrix setEnabled: NO];   
    }

  /* dimension */
  [[rowsHeightForm cellAtIndex: 0] setIntValue: [object rowHeight] ];
  [[rowsHeightForm cellAtIndex: 1] setIntValue: [(NSTableView*)object numberOfColumns]];

  /* options */
  [drawgridSwitch setState:[object drawsGrid]];
  [resizingSwitch setState:[object gormAllowsColumnResizing]];
  [reorderingSwitch setState:[object gormAllowsColumnReordering]];

  /* tag */
  [[tagForm cellAtIndex:0] setIntValue:[object tag]];

  /* background color */
  [backgroundColor setColorWithoutAction: [object backgroundColor]];

  [super revert:sender];
}


/* delegate for tag and Forms */
- (void) controlTextDidEndEditing: (NSNotification*)aNotification
{
  [self ok:[aNotification object]];
}
@end
