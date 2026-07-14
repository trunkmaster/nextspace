/*
  GormTableColumnAttributesInspector.m

   Copyright (C) 2001-2005 Free Software Foundation, Inc.

   Author:  Adam Fedor <fedor@gnu.org>
            Laurent Julliard <laurent@julliard-online.org>
   Date: Aug 2001
   Author:  Gregory Casamento <greg_casamento@yahoo.com>
            Added custom class handling for table column.
   Date: 2004
   
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


#import <AppKit/AppKit.h>

#import <GormCore/GormCore.h>

#import "GormTableColumnAttributesInspector.h"

/*
  IBObjectAdditions category
*/

@implementation GormTableColumnAttributesInspector

- (id) init
{
  if ([super init] == nil)
    {
      return nil;
    }

  if ([NSBundle loadNibNamed: @"GormNSTableColumnInspector" owner: self] == NO)
    {
      NSLog(@"Could not gorm GormTableColumnInspector");
      return nil;
    }

  return self;
}

- (void) awakeFromNib
{
  [cellTable setDoubleAction: @selector(ok:)];
}

- (NSString *)_getCellClassName
{
  id cell = [[self object] dataCell];
  NSString *customClassName = [[(id<GormAppDelegate>)[NSApp delegate] classManager] customClassForObject: cell];
  NSString *result = nil;

  if(customClassName == nil)
    {
      result = NSStringFromClass([cell class]);
    }
  else
    {
      result = customClassName;
    }
  
  return result;
}

/* Commit changes that the user makes in the Attributes Inspector */
- (void) ok: (id) sender
{
  /* title Alignment */
  if (sender == titleAlignmentMatrix)
    {
       if ([[sender cellAtRow: 0 column: 0] state] == NSOnState)
 	{
 	  [[object headerCell] setAlignment: NSLeftTextAlignment];
 	}
       else if ([[sender cellAtRow: 0 column: 1] state] == NSOnState)
 	{
 	  [[object headerCell] setAlignment: NSCenterTextAlignment];
 	}
       else if ([[sender cellAtRow: 0 column: 2] state] == NSOnState)
 	{
 	  [[object headerCell] setAlignment: NSRightTextAlignment];
 	}

       // [[object headerCell] setAlignment: [[titleAlignmentMatrix selectedRow] tag]];

      if ([[object tableView] headerView] != nil)
	{
	  [[[object tableView] headerView] setNeedsDisplay: YES];
	}
    }
  /* contents Alignment */
  else if (sender == contentsAlignmentMatrix)
    {
      if ([[sender cellAtRow: 0 column: 0] state] == NSOnState)
	{
	  [[object dataCell] setAlignment: NSLeftTextAlignment];
	}
      else if ([[sender cellAtRow: 0 column: 1] state] == NSOnState)
	{
	  [[object dataCell] setAlignment: NSCenterTextAlignment];
	}
      else if ([[sender cellAtRow: 0 column: 2] state] == NSOnState)
	{
	  [[object dataCell] setAlignment: NSRightTextAlignment];
	}
      [[object tableView] setNeedsDisplay: YES];
    }

  /* Identifier */
  else if (sender == identifierTextField)
    {
      [object setIdentifier:
		[identifierTextField stringValue]];
    }
  /* Options */
  else if (sender == editableSwitch)
    {
      [object setEditable:
		([editableSwitch state] == NSOnState)];
    }
  else if (sender == resizableSwitch)
    {
      [object setResizable:
		([resizableSwitch state] == NSOnState)];
    }
  /* set Button */
  else if (sender == setButton || sender == cellTable)
    {
      id classManager = [(id<GormAppDelegate>)[NSApp delegate] classManager];
      id<IBDocuments> doc = [(id<IB>)[NSApp delegate] activeDocument];
      id cell = nil;
      int i = [cellTable selectedRow];
      NSArray *list = [classManager allSubclassesOf: @"NSCell"];
      NSString *className = [list objectAtIndex: i];
      BOOL isCustom = [classManager isCustomClass: className];
      Class cls = nil;

      if(isCustom)
	{
	  NSString *superClass = [classManager nonCustomSuperClassOf: className];
	  cls = NSClassFromString(superClass);
	  NSLog(@"Setting custom cell..");
	}
      else
	{
	  cls = NSClassFromString(className);
	}

      // initialize
      cell = [[cls alloc] init];
      [cell setEditable: [object isEditable]];
      [object setDataCell: cell];
      [[object tableView] setNeedsDisplay: YES];

      // add it to the document, since it needs a custom class...
      if(isCustom)
	{
	  NSString *name = nil;

	  // An object needs to be a "named object" to have a custom class
	  // assigned to it.   Add it to the document and get the name.
	  [doc attachObject: cell toParent: object];
	  if((name = [doc nameForObject: cell]) != nil)
	    {
	      [classManager setCustomClass: className forName: name];
	    } 
	}

      RELEASE(cell);
    }
  /* default button */
  else if (sender == defaultButton)
    {
      [object setDataCell: [[NSTextFieldCell alloc] init]];
      [[object tableView] setNeedsDisplay: YES];
      [self setObject: [self object]]; // reset...
    }
  else if (sender == columnTitle)
    {
      [[object headerCell] setStringValue:
			     [columnTitle stringValue]];
      [[[object tableView] headerView] setNeedsDisplay: YES];
    }
  // sort descriptor...
  else if( sender == sortKey || sender == sortSelector || sender == sortOrder )
    {
      NSString *selectorString = [sortSelector stringValue];
      NSString *key = [sortKey stringValue];
      SEL selector = (([selectorString isEqual: @""]) ? NULL:NSSelectorFromString(selectorString));
      BOOL isAscending = ([sortOrder indexOfSelectedItem] == 0);
      NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:key
								     ascending:isAscending
								      selector:selector];
      [object setSortDescriptorPrototype: sortDescriptor];
      [sortDescriptor release];
    }
  [super ok:sender];
}

/* Sync from object ( NSTableColumn ) changes to the inspector   */
- (void) revert:(id) sender
{
  NSArray *list;
  NSString *cellClassName;
  NSUInteger index;

  if ( object == nil ) 
    return;

  list = [[(id<GormAppDelegate>)[NSApp delegate] classManager] allSubclassesOf: @"NSCell"];
  cellClassName = [self _getCellClassName];
  index =  [list indexOfObject: cellClassName];

  if(index != NSNotFound)
    {
      [cellTable selectRow: index byExtendingSelection: NO];
      [cellTable scrollRowToVisible: index];
    }
  /* title Alignment */
  switch ([[object headerCell] alignment])
    {
    case NSLeftTextAlignment:
      [titleAlignmentMatrix selectCellAtRow: 0 column: 0];
      break;
    case NSCenterTextAlignment:
      [titleAlignmentMatrix selectCellAtRow: 0 column: 1];
      break;
    case NSRightTextAlignment:
      [titleAlignmentMatrix selectCellAtRow: 0 column: 2];
      break;
    default:
      NSLog(@"Unhandled alignment value...");
      break;
    }
  /* contents Alignment */
  switch ([[object dataCell] alignment])
    {
    case NSLeftTextAlignment:
      [contentsAlignmentMatrix selectCellAtRow: 0 column: 0];
      break;
    case NSCenterTextAlignment:
      [contentsAlignmentMatrix selectCellAtRow: 0 column: 1];
      break;
    case NSRightTextAlignment:
      [contentsAlignmentMatrix selectCellAtRow: 0 column: 2];
      break;
    default:
      NSLog(@"Unhandled alignment value...");
      break;
    }

  [identifierTextField setStringValue: [(NSTableColumn *)object identifier]];
  [columnTitle setStringValue: [[(NSTableColumn *)object headerCell] stringValue]];

  /* options */
  if ([object isResizable])
    [resizableSwitch setState: NSOnState];
  else
    [resizableSwitch setState: NSOffState];

  if ([object isEditable])
    [editableSwitch setState: NSOnState];
  else
    [editableSwitch setState: NSOffState];

  /* sort */
  NSSortDescriptor *sortDescriptor = [(NSTableColumn *)object sortDescriptorPrototype];
  if(sortDescriptor != nil)
    {
      SEL sel = [sortDescriptor selector];
      NSString *selectorString = ((sel == NULL) ? @"" : NSStringFromSelector(sel));
      [sortKey setStringValue: [sortDescriptor key]];
      [sortSelector setStringValue: selectorString];
      [sortOrder selectItemAtIndex: ([sortDescriptor ascending]?0:1)];
    }
  else
    {
      [sortKey setStringValue: @""];
      [sortSelector setStringValue: @""];
      [sortOrder selectItemAtIndex: 0];
    }
  [super revert:sender];
}

// Data Source 
// replace by an NSBrowser ? 
- (NSInteger) numberOfRowsInTableView: (NSTableView *)tv
{
  NSArray *list = [[(id<GormAppDelegate>)[NSApp delegate] classManager] allSubclassesOf: @"NSCell"];
  return [list count];
}

- (id) tableView: (NSTableView *)tv
objectValueForTableColumn: (NSTableColumn *)tc
	              row: (NSInteger)rowIndex
{
  NSArray *list = [[(id<GormAppDelegate>)[NSApp delegate] classManager] allSubclassesOf: @"NSCell"];
  id value = nil;
  if([list count] > 0)
    {
      value = [list objectAtIndex: rowIndex];
    }
  return value;
}

// delegate
- (BOOL)    tableView: (NSTableView *)tableView
shouldEditTableColumn: (NSTableColumn *)aTableColumn
		  row: (NSInteger)rowIndex
{
  return NO;
}

- (BOOL) tableView: (NSTableView *)tv
   shouldSelectRow: (NSInteger)rowIndex
{
  return YES;
}


/* delegate method for identifier */
-(void) controlTextDidChange:(NSNotification *)aNotification
{
  [self ok:[aNotification object]];
}

@end
