/*
  GormMatrixdAttributesInspector.m

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

#include <GormCore/GormCore.h>

#include "GormMatrixAttributesInspector.h"


#include <InterfaceBuilder/IBApplicationAdditions.h>
#include <GormCore/GormViewKnobs.h>

@implementation	NSMatrix (IBObjectAdditions)
- (NSString*) inspectorClassName
{
  return @"GormMatrixAttributesInspector";
}
@end

@implementation GormMatrixAttributesInspector

NSUInteger rowsStepperValue;
NSUInteger colsStepperValue;

- (void) _displayObject: (id)obj resize: (BOOL)resize
{
  id     document = [(id<IB>)[NSApp delegate] documentForObject: obj];
  id     editor = [document editorForObject: obj create: NO];
  NSRect eoFrame = [editor frame];

  if (resize == NO)
    {
      NSRect rect = [obj frame];
      NSSize cell = [obj cellSize];
      NSSize inter = [obj intercellSpacing];
      cell.width = (rect.size.width + inter.width) / colsStepperValue - inter.width;
      cell.height = (rect.size.height + inter.height) / rowsStepperValue - inter.height;
      [object setCellSize: cell];
    }
  else
    {
      [obj sizeToCells];
    }
  [obj setNeedsDisplay: YES];
  [[editor superview] setNeedsDisplayInRect: GormExtBoundsForRect(eoFrame)];
}

- (id) init
{
  if ([super init] == nil)
    {
      return nil;
    }
  if ([NSBundle loadNibNamed: @"GormNSMatrixInspector" owner: self] == NO)
    {
      NSLog(@"Could not gorm GormMatrixInspector");
      return nil;
    }
  /* It shouldn't break functionality of rows/columns number 
     changing if someone will decide in the future to change 
     the values of the corresponding steppers in the gorm file. 
     So we stores those values from the gorm file in the auxillary 
     variables to use its later in -[ok:]. 
     (It allows us to avoid the values being hardcoded).
   */
  rowsStepperValue = [rowsStepper intValue];
  colsStepperValue = [colsStepper intValue];

  return self;
}

- (void) _refreshCellsComparingWithOldCells: (NSArray *)oldCells
{
  id<IBDocuments> document = [(id<IB>)[NSApp delegate] activeDocument];
  NSArray *newCells = [[self object] cells];
  NSUInteger newCount = [newCells count];
  NSUInteger oldCount = [oldCells count];
  NSMutableArray *cellsAdded = [NSMutableArray arrayWithCapacity: newCount];
  NSMutableArray *cellsRemoved = [NSMutableArray arrayWithCapacity: newCount];
  NSEnumerator *en = nil;
  NSCell *c = nil;

  if (newCount > oldCount)
    {
      en = [newCells objectEnumerator];
      while ((c = [en nextObject]) != nil)
        {
          if ([oldCells containsObject: c] == NO)
            {
              [cellsAdded addObject: c]; // object is new
            }
        }
      [document attachObjects: cellsAdded toParent: [self object]];
    }
  else if (oldCount > newCount)
    {
      en = [oldCells objectEnumerator];
      while ((c = [en nextObject]) != nil)
        {
          if ([newCells containsObject: c] == NO)
            {
              [cellsRemoved addObject: c]; // object is new
            }
        }
      [document detachObjects: cellsRemoved closeEditors: NO];
    }
  else
    {
      NSLog(@"No change");
    }
}

/* Commit changes that the user makes in the Attributes Inspector */
- (void) ok: (id) sender
{
  if (sender == autosizeSwitch)
    {
      [object setAutosizesCells: ([sender state] == NSOnState)];
    }
  else if (sender == autotagSwitch)
    {
      NSInteger	rows;
      NSInteger	cols;
      int	i;

      [object getNumberOfRows: &rows columns: &cols];

      if ((rows == 1) && (cols > 1))
        {
          for (i = 0; i < cols; i++)
	    {
	      [[object cellAtRow:0 column:i] setTag: i];
	    }
        }
      else if ((rows > 1) && (cols ==1))
        {
          for (i = 0; i < rows; i++)
	    {
	      [[object cellAtRow:i column:0] setTag: i];
	    }
        }
    }
  else if (sender == backgroundColorWell)
    {
      [object setBackgroundColor: [sender color]];
    }
  else if (sender == drawsBackgroundSwitch)
    {
      [object setDrawsBackground: ([sender state] == NSOnState)];
    }
  else if (sender == modeMatrix)
    {
      [(NSMatrix *)object setMode: [[sender selectedCell] tag]];
    }
  else if (sender == propagateSwitch)
    {
      NSButtonCell *cell;
      NSInteger    tag;
      NSString     *title;
      int          c;

      if ([object prototype] == nil)
        {
          NSLog(@"prototype is nil, using first cell in matrix");
          if ([object cells] > 0)
            {
              NSCell *acell = [[object cells] objectAtIndex: 0];
              [object setPrototype: acell];
              NSLog(@"prototype set %@", acell);
            }
        }
      
      if ([object prototype] != nil)
        {
          for (c = 0; c < [object numberOfColumns]; c++)
            {
              int r;
              for (r = 0; r < [object numberOfRows]; r++)
                {
                  cell = [object cellAtRow: r column: c];
                  tag = [cell tag];
                  title = [cell title];
                  cell = [[object prototype] copy];
                  [cell setTag: tag];
                  [cell setTitle: title];
                  [object putCell:cell atRow:r column:c];
                  [cell release];
                }
            }
        }
      [object deselectAllCells];
      [object selectCellAtRow: 0 column: 0];
    }
  else if (sender == selRectSwitch)
    {
      [object setSelectionByRect: ([sender state] == NSOnState)];
    }
  else if (sender == tagForm)
    {
      [object setTag: [[sender cellAtIndex: 0] intValue]];
    }
  else if (sender == rowsForm || sender == colsForm)
    {
      int rows = [[rowsForm cellAtIndex: 0] intValue];
      int cols = [[colsForm cellAtIndex: 0] intValue];
      int num = 0;
      NSArray *oldCells = [NSArray arrayWithArray: [[self object] cells]];

      while((num = [object numberOfRows]) != rows)
	{
	  if(num > rows)
	    {
	      [object removeRow: num - 1]; // remove last row
	    }
	  else
	    {
	      [object addRow];
	    }
	}
      
      while((num = [object numberOfColumns]) != cols)
	{
	  if(num > cols)
	    {
	      [object removeColumn: num - 1]; // remove last column
	    }
	  else
	    {
	      [object addColumn];
	    }
	}
      [self _displayObject: object resize: YES];
      [self _refreshCellsComparingWithOldCells: oldCells];
    }
  else if(sender == rowsStepper)
    {
      int delta = [sender intValue] - rowsStepperValue;
      int num = [object numberOfRows];
      NSArray *oldCells = [NSArray arrayWithArray: [[self object] cells]];

      while(delta > 0)
	{
	  [object addRow];
	  delta--;
	  num++;
	}
      while((delta < 0) && (num > 1))
	{
	  [object removeRow: num - 1];
	  num--;
	  delta++;
	}
      [[rowsForm cellAtIndex: 0] setIntValue: num];
      [sender setIntValue: num];
      rowsStepperValue = num;
      [self _displayObject: object resize: YES];
      [self _refreshCellsComparingWithOldCells: oldCells];
    }
  else if(sender == colsStepper)
    {
      int delta = [sender intValue] - colsStepperValue;
      int num = [object numberOfColumns];
      NSArray *oldCells = [NSArray arrayWithArray: [[self object] cells]];

      while(delta > 0)
	{
	  [object addColumn];
	  delta--;
	  num++;
	}
      while((delta < 0) && (num > 1))
	{
	  [object removeColumn: num - 1];
	  num--;
	  delta++;
	}
      [[colsForm cellAtIndex: 0] setIntValue: num];
      [sender setIntValue: num];
      colsStepperValue = num;
      [self _displayObject: object resize: YES];
      [self _refreshCellsComparingWithOldCells: oldCells];
    }

  /*
   * prototypeMatrix
   * If prototype cell is set show it else show a matrix cell
   */
  if ([object prototype] == nil)
    {
      [prototypeMatrix putCell: [object cellAtRow:0 column:0] atRow:0 column:0];
    }
   else
    {
      [prototypeMatrix putCell: [object prototype] atRow:0 column:0];
    }

   [super ok:sender];
}


/* Sync from object ( NSMatrix ) changes to the inspector   */
- (void) revert:(id)sender
{
  if (object == nil)
      return;

  [autosizeSwitch setState: 
    ([object autosizesCells]) ? NSOnState : NSOffState];

  {
    NSInteger	rows;
    NSInteger cols;

    [object getNumberOfRows: &rows columns: &cols];
 
    if ((rows == 1 && cols > 1) || (cols == 1 && rows > 1))
      [autotagSwitch setEnabled: YES];
    else
      [autotagSwitch setEnabled: NO];
  }

  [backgroundColorWell setColorWithoutAction: [object backgroundColor]];
  [drawsBackgroundSwitch setState: 
                           ([object drawsBackground]) ? NSOnState : NSOffState];

  [modeMatrix selectCellWithTag: [(NSMatrix *)object mode]];
  
  if ([object prototype] == nil)
    [prototypeMatrix putCell: [object cellAtRow:0 column:0] atRow:0 column:0];
  else
    [prototypeMatrix putCell: [object prototype] atRow:0 column:0];
  
  [selRectSwitch setState: 
    ([object isSelectionByRect]) ? NSOnState : NSOffState];
  [[tagForm cellAtIndex: 0] setIntValue: [object tag]];
  rowsStepperValue = [object numberOfRows];
  [[rowsForm cellAtIndex: 0] setIntValue: rowsStepperValue];
  [rowsStepper setIntValue: rowsStepperValue];
  colsStepperValue = [object numberOfColumns];
  [[colsForm cellAtIndex: 0] setIntValue: colsStepperValue];
  [colsStepper setIntValue: colsStepperValue];

  [super revert:sender];
}


/* delegate method for tag Form */
- (void) controlTextDidEndEditing: (NSNotification*)aNotification
{
  [self ok:[aNotification object]];
}

@end
