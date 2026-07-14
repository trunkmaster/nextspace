/*
  GormFormAttributesInspector.m

   Copyright (C) 2001-2005 Free Software Foundation, Inc.

   Author:  Adam Fedor <fedor@gnu.org>
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

#include <GormCore/GormCore.h>

#include "GormFormAttributesInspector.h"

/*
  IBObjectAdditions category
*/
@implementation	NSForm (IBObjectAdditions)
- (NSString*) inspectorClassName
{
  return @"GormFormAttributesInspector";
}
@end


@implementation GormFormAttributesInspector

NSUInteger numberStepperValue;

- (id) init
{
  if ([super init] == nil)
    {
      return nil;
    }
  if ([NSBundle loadNibNamed: @"GormNSFormInspector" owner: self] == NO)
    {
      NSLog(@"Could not gorm GormFormInspector");
      return nil;
    }
  /* It shouldn't break functionality of field number changing 
     if someone will decide in the future to change the value
     of the stepper in the gorm file. So we stores those value 
     from the gorm file in the auxillary variable to use it 
     later in -[ok:]. 
     (It allows us to avoid the value being hardcoded).
   */
  numberStepperValue = [numberStepper intValue];

  return self;
}

/* Commit changes that the user makes in the Attributes Inspector */
- (void) ok:(id) sender
{
  NSInteger	rows;
  NSInteger	cols;
  int	i;
      
  [object getNumberOfRows: &rows columns: &cols];
  
  /* background color */

  if (sender == backgroundColorWell)
    {
      [object setBackgroundColor: [sender color]];
    }
  else if (sender == drawsBackgroundSwitch)
    {
      [object setDrawsBackground: ([sender state] == NSOnState)];
    }
  /* options */
  else if (sender == cellPositionSwitch)
    {
      BOOL flag;

      flag = ([cellPositionSwitch state] == NSOnState) ? YES : NO;
      if (flag == YES)
	{
	  for (i = 0; i < rows; i++)
	    {
	      [[object cellAtIndex: i] setTag: i];
	    }
	}

    }
  else if ( sender == editableSwitch ) 
    {
      BOOL flag = ([editableSwitch state] == NSOnState) ? YES : NO;
      for (i = 0; i < rows; i++)
	{
	  [[object cellAtIndex: i] setEditable: flag];
	}
    }
  else if ( sender == selectableSwitch ) 
    {
      BOOL flag = ([selectableSwitch state] == NSOnState) ? YES : NO;
      for (i = 0; i < rows; i++)
	{
	  [[object cellAtIndex: i] setSelectable: flag];
	}
    }
  else if ( sender == scrollableSwitch ) 
    {
      BOOL flag = ([scrollableSwitch state] == NSOnState) ? YES : NO;
      for (i = 0; i < rows; i++)
	{
	  [[object cellAtIndex: i] setScrollable: flag];
	}
    }
  /* text alignment */
  else if (sender == textMatrix)
    {
      [object setTextAlignment: (NSTextAlignment)[[sender selectedCell] tag]];
    }
  /* title alignment */
  else if (sender == titleMatrix)
    {
      [object setTitleAlignment: (NSTextAlignment)[[sender selectedCell] tag]];
    }
  /* tag */
  else if (sender == tagForm)
    {
      [object setTag: [[sender cellAtIndex: 0] intValue]];
    }
  /* autosize */
  else if (sender == autosizeSwitch)
    {
      BOOL flag = ([autosizeSwitch state] == NSOnState) ? YES : NO;
      [object setAutosizesCells: flag];
    }
  /* number of fields */
  else if(sender == dimensionsForm)
    {
      int fields = [[sender cellAtIndex: 0] intValue];
      
      if(fields) // make changes only if the user actions do something meaningful
	{
	  NSRect rect = [object frame];
	  NSSize cell = [object cellSize];
	  NSSize inter = [object intercellSpacing];

	  while(((rows = [object numberOfRows]) != fields))
	    {
	      if(rows > fields)
		{
		  [object removeEntryAtIndex: rows - 1]; // remove last field
		}
	      else
		{
		  [object addEntry: [NSString stringWithFormat: @"Field (%ld)", (long)rows]];
		}
	    }
	  cell.height = (rect.size.height + inter.height) / fields - inter.height;
	  [object setCellSize: cell];
	}
      [object setNeedsDisplay: YES];
      [[object superview] setNeedsDisplay: YES];
    }
  else if(sender == numberStepper)
    {
      int delta = [sender intValue] - numberStepperValue;
      NSRect rect = [object frame];
      NSSize cell = [object cellSize];
      NSSize inter = [object intercellSpacing];

      while(delta > 0)
	{
	  [object addEntry: [NSString stringWithFormat: @"Field (%ld)", (long)rows]];
	  delta--;
	  rows++;
	}
      while((delta < 0) && (rows > 1))
	{
	  [object removeEntryAtIndex: rows - 1];
	  rows--;
	  delta++;
	}
      cell.height = (rect.size.height + inter.height) / rows - inter.height;
      [object setCellSize: cell];
      [[dimensionsForm cellAtIndex: 0] setIntValue: rows];
      [sender setIntValue: numberStepperValue];
      [dimensionsForm setNeedsDisplay: YES];
      [object setNeedsDisplay: YES];
    }

  [super ok:sender];
}


/* Sync from object ( NSForm ) changes to the inspector   */
- (void) revert: (id) sender
{
  if ( object == nil )
    {
      return;
    }

  /* background color */
  [backgroundColorWell setColorWithoutAction: [object backgroundColor]];
  [drawsBackgroundSwitch setState: 
    ([object drawsBackground]) ? NSOnState : NSOffState];
  /* alignments */
  [textMatrix selectCellWithTag: [[object  cellAtIndex: 0] alignment]];
  [titleMatrix selectCellWithTag: [[object cellAtIndex: 0] titleAlignment]];

  /* options */
  [editableSwitch setState:[[object cellAtIndex: 0] isEditable]];
  [selectableSwitch setState:[[object cellAtIndex: 0] isSelectable]];
  [scrollableSwitch setState:[[object cellAtIndex: 0] isScrollable]];
  [autosizeSwitch setState: [object autosizesCells]];

  // Cells tags = position is not directly stored in the Form so guess it.
  {
    NSInteger		rows;
    NSInteger		cols;
    int		i;
    BOOL	flag;
    
    [object getNumberOfRows: &rows columns: &cols];

    i = 0;    
    do
      {
	flag = ([[object cellAtIndex: i] tag] == i);
      }
    while (flag && (++i < rows)); 

    if (flag)
      {
        [cellPositionSwitch setState:NSOnState];
      }
  }
  
  /* number of fields */
  [[dimensionsForm cellAtIndex: 0] setIntValue: [object numberOfRows]];

  /* tag */
  [[tagForm cellAtRow: 0 column: 0] setIntValue: [object tag]];

  [super revert:sender];
}


/* delegate method for tagForm */
-(void) controlTextDidChange:(NSNotification*) aNotification
{
  [self ok:[aNotification object]];
}


/* The button type isn't stored in the button, so reverse-engineer it */
- (NSButtonType) buttonTypeForObject: button
{
  NSButtonCell *cell;
  NSButtonType type;
  int highlight, stateby;

  /* We could be passed the button or the cell */
  cell = ([button isKindOfClass: [NSButton class]]) ? [button cell] : button;

  highlight = [cell highlightsBy];
  stateby = [cell showsStateBy];
  NSDebugLog(@"highlight = %d, stateby = %d",
    (int)[cell highlightsBy],(int)[cell showsStateBy]);
  
  type = NSMomentaryPushButton;
  if (highlight == NSChangeBackgroundCellMask)
    {
      if (stateby == NSNoCellMask)
	type = NSMomentaryLight;
      else 
	type = NSOnOffButton;
    }
  else if (highlight == (NSPushInCellMask | NSChangeGrayCellMask))
    {
      if (stateby == NSNoCellMask)
	type = NSMomentaryPushButton;
      else
	type = NSPushOnPushOffButton;
    }
  else if (highlight == (NSPushInCellMask | NSContentsCellMask))
    {
      type = NSToggleButton;
    }
  else if (highlight == NSContentsCellMask)
    {
      if (stateby == NSNoCellMask)
	type = NSMomentaryChangeButton;
      else
	type = NSToggleButton; /* Really switch or radio. What should it be? */
    }
  else
    {
      NSDebugLog(@"Ack! no button type");
    }
  return type;
}

/* We may need to reset some parameters based on the previous type */
- (void) setButtonType: (NSButtonType)type forObject: (id)button
{
  [object setButtonType: type];
}

@end
