/*
   GormComboBoxAttributesInspector.m

   Copyright (C) 2001-2005 Free Software Foundation, Inc.

   Author:  Laurent Julliard <laurent@julliard-online.org>
   Date: Nov 2001
   
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

#include <AppKit/AppKit.h>

#include <GormCore/GormCore.h>

#include "GormNSComboBoxAttributesInspector.h"


/*
  IBObjectAdditions category 
*/
@implementation	NSComboBox (IBObjectAdditions)
- (NSString*) inspectorClassName
{
  return @"GormNSComboBoxAttributesInspector";
}
@end


@implementation GormNSComboBoxAttributesInspector

- (id) init
{
  if ([super init] == nil)
    return nil;
  
  if ([NSBundle loadNibNamed: @"GormNSComboBoxInspector" owner: self] == NO)
    {
       NSLog(@"Could not gorm GormNSComboBoxInspector");
       return nil;
     }
  
  return self;
}

/* Commit changes that the user makes in the Attributes Inspector */
- (void) ok:(id) sender
{
  if (sender == backgroundColorWell)
    {
      [object setBackgroundColor: [sender color]];
    }
  else if (sender == textColorWell)
    {
      [object setTextColor: [sender color]];
    }
  else if (sender == alignmentMatrix)
    {
      [object setAlignment: (NSTextAlignment)[[sender selectedCell] tag]];
    }
  if (sender == editable)
    {
      BOOL flag = ([sender state] == NSOnState) ? YES :NO;
      [[object cell] setEditable: flag];
    }
  if (sender == selectable)
    {
      BOOL flag = ([sender state] == NSOnState) ? YES :NO;
      [[object cell] setSelectable: flag];
    }
  if (sender == usesDataSource)
    {
      BOOL flag = ([sender state] == NSOnState) ? YES :NO;
      [[object cell] setUsesDataSource: flag];
    }
  else if (sender == visibleItemsForm)
    {
      [object setNumberOfVisibleItems: [[sender cellAtIndex: 0] intValue]];
    }
  else if (sender == itemField )
    {
      // #warning To be done
    }
  else if (sender == addButton) 
    {
      if ( ! [[itemTxt stringValue] isEqualToString:@""] )
	{
	  [object addItemWithObjectValue:[itemTxt stringValue]];
	  [itemTableView reloadData];
	}
    }
  else if (sender == removeButton) 
    {
      int selected = [itemTableView selectedRow];
      if ( selected != -1 ) 
	{
	  [itemTxt setStringValue:@""];
	  [object removeItemAtIndex:selected];
	  [itemTableView reloadData];
	}
    }

  // some changes might affect other settings...
  [self revert: sender];

  // call the superclass.
  [super ok: sender];
}

/* Sync from object ( NSComboBox ) changes to the inspector   */
-(void) revert:(id) sender
{
  if ( object == nil )
    return;

  [backgroundColorWell setColorWithoutAction: [object backgroundColor]];
  [textColorWell setColorWithoutAction: [object textColor]];

  [alignmentMatrix selectCellWithTag: [object alignment]];

  // clear buttons.
  [editable setState: NSOffState];
  [selectable setState: NSOffState];
  [usesDataSource setState: NSOffState];

  // set buttons.
  if ([[object cell] isEditable])
    [editable setState: NSOnState];

  if ([[object cell] isSelectable])
    [selectable setState: NSOnState];

  if ([[object cell] usesDataSource])
    [usesDataSource setState: NSOnState];

  [itemTableView reloadData];
  [itemTxt setStringValue:@""];
  
  [super revert:sender];
}

/* TableView dataSource methods */
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
  if (aTableView == itemTableView )
    return [[object objectValues]  count];
  
  return 0;
}

- (id)tableView:(NSTableView *)aTableView 
objectValueForTableColumn:(NSTableColumn *)aTableColumn
	    row:(NSInteger)rowIndex
{
  if (aTableView == itemTableView )
    return  [object itemObjectValueAtIndex:rowIndex];
  
  return nil;
}

/* TableView delegate methods */
- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex
{
  if ( aTableView == itemTableView ) 
    {
      [itemTxt setStringValue:[object itemObjectValueAtIndex:rowIndex]];
      return YES;
    }
   return NO;
}
@end
