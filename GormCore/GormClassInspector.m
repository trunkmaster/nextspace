/** <title>GormClassInspector</title>

   <abstract>allow user to select custom classes</abstract>

   Copyright (C) 2003 Free Software Foundation, Inc.
   Author:  Gregory John Casamento <greg_casamento@yahoo.com>
   Date: March 2003

   This file is part of GNUstep.
 
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
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/

/* All rights reserved */

#include <AppKit/AppKit.h>

#include <InterfaceBuilder/InterfaceBuilder.h>

#include "GormClassInspector.h"
#include "GormClassManager.h"
#include "GormDocument.h"
#include "GormFunctions.h"
#include "GormPrivate.h"
#include "GormProtocol.h"

NSNotificationCenter *nc = nil;

// interfaces
@interface GormDocument (GormClassInspectorAdditions)
- (void) collapseClass: (NSString *)className;
- (void) reloadClasses;
@end

// the data source classes for each of the tables...
@interface GormOutletDataSource : NSObject
{
  id inspector;
}
- (void) setInspector: (id)ins;
@end

@interface GormActionDataSource : NSObject
{
  id inspector;
}
- (void) setInspector: (id)ins;
@end

@interface GormClassesDataSource : NSObject
{
  id inspector;
}
- (void) setInspector: (id)ins;
@end

// implementation
@implementation GormDocument (GormClassInspectorAdditions)
- (void) collapseClass: (NSString *)className
{
  NSDebugLog(@"%@",className);
  [classesView resetObject: className];
}

- (void) reloadClasses
{
  [classesView reloadData];
}
@end

@implementation GormOutletDataSource 
- (NSInteger) numberOfRowsInTableView: (NSTableView *)tv
{
  NSArray *list = [[(id<GormAppDelegate>)[NSApp delegate] classManager] allOutletsForClassNamed: [inspector _currentClass]];
  return [list count];
}

- (id)          tableView: (NSTableView *)tv
objectValueForTableColumn: (NSTableColumn *)tc
	              row: (NSInteger)rowIndex
{
  NSArray *list = [[(id<GormAppDelegate>)[NSApp delegate] classManager] allOutletsForClassNamed: [inspector _currentClass]];
  id value = nil;

  list = [list sortedArrayUsingSelector: @selector(compare:)];
  
  if([list count] > 0)
    {
      value = [list objectAtIndex: rowIndex];
    }
  return value;
}

- (void) tableView: (NSTableView *)tv
    setObjectValue: (id)anObject
    forTableColumn: (NSTableColumn *)tc
	       row: (NSInteger)rowIndex
{
  id classManager = [(id<GormAppDelegate>)[NSApp delegate] classManager];
  NSString *currentClass = [inspector _currentClass];
  NSArray *list = [classManager allOutletsForClassNamed: currentClass];
  list = [list sortedArrayUsingSelector: @selector(compare:)];  

  NSString *name = [list objectAtIndex: rowIndex];
  NSString *formattedOutlet = formatOutlet( (NSString *)anObject );
  GormDocument *document = (GormDocument *)[(id <IB>)[NSApp delegate] activeDocument];

  if(![name isEqual: formattedOutlet])
    {
      BOOL removed = [document 
		       removeConnectionsWithLabel: name 
		       forClassNamed: currentClass
		       isAction: NO];
      if(removed)
	{
	  [classManager replaceOutlet: name
			withOutlet: formattedOutlet
			forClassNamed: currentClass];
	  
	  // collapse the class in question if it's being edited and make
	  // certain that names in the list are kept in sync.
	  [document collapseClass: currentClass];
	  [document reloadClasses];
	  [document selectClass: currentClass editClass: NO];
	}
    }
}

// set methods
- (void) setInspector: (id)ins
{
  ASSIGN(inspector, ins);
}
@end

@implementation GormActionDataSource
- (NSInteger) numberOfRowsInTableView: (NSTableView *)tv
{
  NSArray *list = [[(id<GormAppDelegate>)[NSApp delegate] classManager] allActionsForClassNamed: [inspector _currentClass]];
  return [list count];
}

- (id)          tableView: (NSTableView *)tv
objectValueForTableColumn: (NSTableColumn *)tc
	              row: (NSInteger)rowIndex
{
  NSArray *list = [[(id<GormAppDelegate>)[NSApp delegate] classManager] allActionsForClassNamed: [inspector _currentClass]];
  list = [list sortedArrayUsingSelector: @selector(compare:)];
  return [list objectAtIndex: rowIndex];
}

- (void) tableView: (NSTableView *)tv
    setObjectValue: (id)anObject
    forTableColumn: (NSTableColumn *)tc
	       row: (NSInteger)rowIndex
{
  id classManager = [(id<GormAppDelegate>)[NSApp delegate] classManager];
  NSString *currentClass = [inspector _currentClass];
  NSArray *list = [classManager allActionsForClassNamed: currentClass];
  list = [list sortedArrayUsingSelector: @selector(compare:)];

  NSString *name = [list objectAtIndex: rowIndex];
  NSString *formattedAction = formatAction( (NSString *)anObject );
  GormDocument *document = (GormDocument *)[(id <IB>)[NSApp delegate] activeDocument];

  if(![name isEqual: formattedAction])
    {
      BOOL removed = [document 
		       removeConnectionsWithLabel: name 
		       forClassNamed: currentClass
		       isAction: YES];
      if(removed)
	{
	  [classManager replaceAction: name
			withAction: formattedAction
			forClassNamed: currentClass];
	  
	  // collapse the class in question if it's being edited and make
	  // certain that names in the list are kept in sync.
	  [document collapseClass: currentClass];
	  [document reloadClasses];
	  [document selectClass: currentClass editClass: NO];
	}
    }
}

// set method
- (void) setInspector: (id)ins
{
  ASSIGN(inspector, ins);
}
@end

@implementation GormClassesDataSource 
- (NSInteger) numberOfRowsInTableView: (NSTableView *)tv
{
  NSArray *list = [[(id<GormAppDelegate>)[NSApp delegate] classManager] allClassNames];
  return [list count];
}

- (id)          tableView: (NSTableView *)tv
objectValueForTableColumn: (NSTableColumn *)tc
	              row: (NSInteger)rowIndex
{
  NSArray *list = [[(id<GormAppDelegate>)[NSApp delegate] classManager] allClassNames];
  id value = nil;

  list = [list sortedArrayUsingSelector: @selector(compare:)];
  if([list count] > 0)
    {
      value = [list objectAtIndex: rowIndex];
    }
  return value;
}

- (void) tableView: (NSTableView *)tv
    setObjectValue: (id)anObject
    forTableColumn: (NSTableColumn *)tc
	       row: (NSInteger)rowIndex
{
  // cannot replace any values for this data source...
}

// set methods
- (void) setInspector: (id)ins
{
  ASSIGN(inspector, ins);
}
@end

@implementation GormClassInspector
+ (void) initialize
{
  if (self == [GormClassInspector class])
    {
      nc = [NSNotificationCenter defaultCenter];
    }
}

- (id) init
{
  self = [super init];
  if (self != nil)
    {
      NSBundle *bundle = [NSBundle bundleForClass: [self class]];
      
      // initialize all member variables...
      _actionTable = nil;
      _addAction = nil;
      _addOutlet = nil;
      _classField = nil;
      _outletTable = nil;
      _removeAction = nil;
      _removeOutlet = nil;
      _tabView = nil;
      _currentClass = nil;
      _actionData = nil;
      _outletData = nil;
      _parentClassData = nil;

      // load the gui...
      if (![bundle loadNibNamed: @"GormClassInspector"
			  owner: self
		topLevelObjects: NULL])
	{
	  NSLog(@"Could not open gorm GormClassInspector");
	  return nil;
	}

      [nc addObserver: self
	     selector: @selector(handleNotification:)
		 name: GormDidModifyClassNotification
	       object: nil];

    }
  return self;
}

- (void) dealloc
{
  RELEASE(_actionData);
  RELEASE(_outletData);
  RELEASE(_parentClassData);

  [super dealloc];
}

- (void) awakeFromNib
{
  // instantiate..
  _actionData = [[GormActionDataSource alloc] init];
  _outletData = [[GormOutletDataSource alloc] init];
  _parentClassData = [[GormClassesDataSource alloc] init];

  // initialize..
  [_actionData setInspector: self];
  [_outletData setInspector: self];
  [_parentClassData setInspector: self];

  // use..
  [_actionTable setDataSource: _actionData];
  [_outletTable setDataSource: _outletData];
  [_parentClass setDataSource: _parentClassData];
  [_parentClass setDoubleAction: @selector(selectClass:)];
  [_parentClass setTarget: self];

  // delegate...
  [_actionTable setDelegate: self];
  [_outletTable setDelegate: self];
  [_parentClass setDelegate: self];
}

- (void) _refreshView
{
  id addActionCell = [_addAction cell];
  id removeActionCell = [_removeAction cell];
  id addOutletCell = [_addOutlet cell];
  id removeOutletCell = [_removeOutlet cell];
  id selectClassCell = [_selectClass cell];
  id searchCell = [_search cell];
  BOOL isEditable = [_classManager isCustomClass: [self _currentClass]]; 
  BOOL isFirstResponder = [[self _currentClass] isEqualToString: @"FirstResponder"];

  NSArray *list = [_classManager allClassNames];
  NSString *superClass = [_classManager parentOfClass: [self _currentClass]];
  NSUInteger index = [list indexOfObject: superClass];

  [_classField setStringValue: [self _currentClass]];
  [_outletTable reloadData];
  [_actionTable reloadData];
  [_parentClass reloadData];
  // [_outletTable deselectAll: self];
  // [_actionTable deselectAll: self];

  // activate for actions...
  [addActionCell setEnabled: YES]; 
  [removeActionCell setEnabled: NO]; // YES]; 

  // activate for outlet...
  [addOutletCell setEnabled: (isEditable && !isFirstResponder)];
  [removeOutletCell setEnabled: NO]; // (isEditable && !isFirstResponder)];

  // activate select class...
  [selectClassCell setEnabled: (isEditable && !isFirstResponder)];
  [_parentClass setEnabled: (isEditable && !isFirstResponder)];
  [searchCell setEnabled: (isEditable && !isFirstResponder)];
  [_classField setEditable: (isEditable && !isFirstResponder)];
  [_classField setBackgroundColor: ((isEditable && !isFirstResponder)?[NSColor textBackgroundColor]:[NSColor selectedTextBackgroundColor])];

  // select the parent class
  if(index != NSNotFound && list != nil)
    {
      [_parentClass selectRow: index byExtendingSelection: NO];
      [_parentClass scrollRowToVisible: index];
    }
}

- (void) addAction: (id)sender
{
  NS_DURING
    {
      GormDocument *document = (GormDocument *)[(id <IB>)[NSApp delegate] activeDocument];
      if(document != nil)
	{
	  NSString *className = [self _currentClass];
	  NSString *newAction = [_classManager addNewActionToClassNamed: className];  
	  NSArray *list = [_classManager allActionsForClassNamed: className];
	  NSInteger row = [list indexOfObject: newAction];
	  
	  [document collapseClass: className];
	  [document reloadClasses];
	  [nc postNotificationName: IBInspectorDidModifyObjectNotification
	      object: _classManager];
	  [_actionTable reloadData];
	  [_actionTable scrollRowToVisible: row];
	  [_actionTable selectRow: row byExtendingSelection: NO];
	  [document selectClass: className];
	  [super ok: sender];
	}
    }
  NS_HANDLER
    {
      NSLog(@"%@",[localException reason]);
    }
  NS_ENDHANDLER;
}

- (void) addOutlet: (id)sender
{
  NS_DURING
    {
      GormDocument *document = (GormDocument *)[(id <IB>)[NSApp delegate] activeDocument];
      if(document != nil)
	{
	  NSString *className = [self _currentClass];
	  NSString *newOutlet = [_classManager addNewOutletToClassNamed: className];  
	  NSArray *list = [_classManager allOutletsForClassNamed: className];
	  NSInteger row = [list indexOfObject: newOutlet];
	  
	  [document collapseClass: className];
	  [document reloadClasses];
	  [nc postNotificationName: IBInspectorDidModifyObjectNotification
	      object: _classManager];
	  [_outletTable reloadData];
	  [_outletTable scrollRowToVisible: row];
	  [_outletTable selectRow: row byExtendingSelection: NO];
	  [document selectClass: className];
	  [super ok: sender];
	}
    }
  NS_HANDLER
    {
      NSLog(@"%@",[localException reason]);
    }
  NS_ENDHANDLER;
}

- (void) removeAction: (id)sender
{
  NS_DURING
    {
      NSInteger i = [_actionTable selectedRow];
      NSString *className = [self _currentClass];
      NSArray *list = [_classManager allActionsForClassNamed: className];
      BOOL removed = NO;
      BOOL isCustom = [_classManager isCustomClass: className]; 
      NSString *name = nil;
      GormDocument *document = (GormDocument *)[(id <IB>)[NSApp delegate] activeDocument];
      
      if(document != nil)
	{
	  // check the count...
	  if(isCustom || [_classManager isCategoryForClass: className])
	    {
	      if([list count] > 0 && i >= 0 && i < [list count])
		{
		  [_actionTable deselectAll: self];
		  name = [list objectAtIndex: i];
		  if(isCustom || [_classManager isAction: name onCategoryForClassNamed: className])
		    {
		      removed = [document 
				  removeConnectionsWithLabel: name 
				  forClassNamed: _currentClass
				  isAction: YES];
		    }
		}
	      
	      if(removed)
		{
		  [super ok: sender];
		  [document collapseClass: className];
		  [document reloadClasses];
		  [_classManager removeAction: name fromClassNamed: className];
		  [nc postNotificationName: IBInspectorDidModifyObjectNotification
		      object: _classManager];
		  [_actionTable reloadData];
		  [document selectClass: className];
		}
	    }
	}
    }
  NS_HANDLER
    {
      NSLog(@"%@",[localException reason]);
    }
  NS_ENDHANDLER;
}

- (void) removeOutlet: (id)sender
{
  NS_DURING
    {
      NSInteger i = [_outletTable selectedRow];
      NSString *className = [self _currentClass];
      NSArray *list = [_classManager allOutletsForClassNamed: className];
      BOOL removed = NO;
      NSString *name = nil;
      GormDocument *document = (GormDocument *)[(id <IB>)[NSApp delegate] activeDocument];
      
      if(document != nil)
	{ 
	  // check the count...
	  if([list count] > 0 && i >= 0 && i < [list count])
	    {
	      [_outletTable deselectAll: self];
	      name = [list objectAtIndex: i];
	      removed = [document 
			  removeConnectionsWithLabel: name 
			  forClassNamed: _currentClass
			  isAction: NO];
	    }
	  
	  if(removed)
	    {
	      [super ok: sender];
	      [document collapseClass: className];
	      [document reloadClasses];
	      [_classManager removeOutlet: name fromClassNamed: className];
	      [nc postNotificationName: IBInspectorDidModifyObjectNotification
		  object: _classManager];
	      [_outletTable reloadData];
	      [document selectClass: className];
	    }
	}
    }
  NS_HANDLER
    {
      NSLog(@"%@",[localException reason]);
    }
  NS_ENDHANDLER;
}

- (void) select: (id)sender
{
  NSLog(@"select...");
}

- (void) searchForClass: (id)sender
{
  NSArray *list = [_classManager allClassNames];
  NSString *stringValue = [_searchText stringValue];
  NSInteger index = [list indexOfObject: stringValue];

  NSLog(@"Search... %@",[_searchText stringValue]);
  if(index != NSNotFound && list != nil && 
     [stringValue isEqualToString: @"FirstResponder"] == NO)
    {
      // select the parent class
      [_parentClass selectRow: index byExtendingSelection: NO];
      [_parentClass scrollRowToVisible: index];
    }
}

- (void) selectClass: (id)sender
{
  NSArray *list = [_classManager allClassNames];
  NSInteger row = [_parentClass selectedRow];

  NS_DURING
    {
      if(row >= 0)
	{
	  NSString *newParent = [list objectAtIndex: row];
	  NSString *name = [self _currentClass];
	  GormDocument *document = (GormDocument *)[(id <IB>)[NSApp delegate] activeDocument];
	  
	  // if it's a custom class, let it go, if not do nothing.
	  if(document != nil)
	    {
	      if([_classManager isCustomClass: name])
		{
		  NSString *title = _(@"Modifying/Reparenting Class");
		  NSString *msg = [NSString stringWithFormat: _(@"This action may break existing connections "
								@"to instances of class '%@'"
								@"and it's subclasses.  Continue?"), name];
		  NSInteger retval = -1;
		  BOOL removed = NO;

		  [super ok: sender];
		  
		  // ask the user if he/she wants to continue...
		  retval = NSRunAlertPanel(title, msg,_(@"OK"),_(@"Cancel"), nil, nil);
		  if (retval == NSAlertDefaultReturn)
		    {
		      removed = YES;
		    }
		  else
		    {
		      removed = NO;
		    }

		  // if removed, move the class and notify... 
		  if(removed)
		    {
		      NSString *oldSuper = [_classManager superClassNameForClassNamed: name];
		      
		      [_classManager setSuperClassNamed: newParent forClassNamed: name];
		      [document refreshConnectionsForClassNamed: name];
		      [nc postNotificationName: IBInspectorDidModifyObjectNotification
			  object: _classManager];
		      [document collapseClass: oldSuper];
		      [document collapseClass: name];
		      [document reloadClasses];
		      [document selectClass: name];
		    }
		}
	    }
	}
    }
  NS_HANDLER
    {
      NSLog(@"%@",[localException reason]);
    }
  NS_ENDHANDLER;
}

- (void) changeClassName: (id)sender
{
  NSString *name = [self _currentClass];
  NSString *newName = [sender stringValue];
  GormDocument *document = (GormDocument *)[(id <IB>)[NSApp delegate] activeDocument];
  BOOL flag = NO;

  // check to see if the user wants to do this and rename the connections.
  flag = [document renameConnectionsForClassNamed: name
		   toName: newName]; 

  if(flag)
    {
      [document collapseClass: name];
      [_classManager renameClassNamed: name
		    newName: newName];
      [nc postNotificationName: IBInspectorDidModifyObjectNotification
	  object: _classManager];
      [document reloadClasses];
      [document selectClass: newName];
      [super ok: sender];
    }
}

- (void) selectAction: (id)sender
{
  NSInteger row = [sender selectedRow];
  NSArray *actions = [_classManager allActionsForClassNamed: _currentClass];
  if(row <= [actions count])
    {
      BOOL isCustom = [_classManager isCustomClass: _currentClass]; 
      id cell = [_removeAction cell];
      NSString *action = [actions objectAtIndex: row];
      BOOL isAction = [_classManager isAction: action ofClass: _currentClass];
      BOOL isActionOnCategory = [_classManager isAction: action onCategoryForClassNamed: _currentClass];
      [cell setEnabled: ((isCustom && isAction) || isActionOnCategory)];
    }
}

- (void) selectOutlet: (id)sender
{
  NSInteger row = [sender selectedRow];
  NSArray *outlets = [_classManager allOutletsForClassNamed: _currentClass];
  if(row <= [outlets count])
    {
      BOOL isCustom = [_classManager isCustomClass: _currentClass]; 
      BOOL isFirstResponder = [_currentClass isEqualToString: @"FirstResponder"];
      id cell = [_removeOutlet cell];
      NSString *outlet = [outlets objectAtIndex: row];
      BOOL isOutlet = [_classManager isOutlet: outlet ofClass: _currentClass];
      [cell setEnabled: (isOutlet && isCustom && !isFirstResponder)];
    }
}

- (void) clickOnClass: (id)sender
{
  NSLog(@"Click on class %@",sender);
}

- (void) setObject: (id)anObject
{
  NSInteger outletsCount = 0;
  NSInteger actionsCount = 0;
  NSTabViewItem *item = nil;

  if([anObject isKindOfClass: [GormClassProxy class]])
    {
      [super setObject: anObject];
      ASSIGN(_classManager, [(id<GormAppDelegate>)[NSApp delegate] classManager]);
      ASSIGN(_currentClass, [object className]);
      
      outletsCount = [[_classManager allOutletsForClassNamed: _currentClass] count];
      actionsCount = [[_classManager allActionsForClassNamed: _currentClass] count];
      
      item = [_tabView tabViewItemAtIndex: 1]; // actions;
      [item setLabel: [NSString stringWithFormat: @"Actions (%ld)",(long)actionsCount]];
      item = [_tabView tabViewItemAtIndex: 0]; // outlets;
      [item setLabel: [NSString stringWithFormat: @"Outlets (%ld)",(long)outletsCount]];
      [_tabView setNeedsDisplay: YES];
      
      [self _refreshView];
    }
  else
    {
      NSLog(@"Got %@ set to class edit inspector",anObject);
    }
}

- (NSString *) _currentClass
{
  return AUTORELEASE([[object className] copy]);
}

- (void) handleNotification: (NSNotification *)notification
{
  if([notification object] == _classManager &&
     (id<IB>)[[NSApp delegate] activeDocument] != nil)
    {
      [self _refreshView];
    }
}

// table delegate/data source methods...
- (BOOL)    tableView: (NSTableView *)tableView
shouldEditTableColumn: (NSTableColumn *)aTableColumn
		  row: (NSInteger)rowIndex
{
  BOOL result = NO;

  if(tableView != _parentClass)
    {
      NSArray *list = nil;
      NSString *name = nil;
      NSString *className = [self _currentClass];
      
      if(tableView == _actionTable)
	{
	  list = [_classManager allActionsForClassNamed: className];
	  name = [list objectAtIndex: rowIndex];
	}
      else if(tableView == _outletTable)
	{
	  list = [_classManager allOutletsForClassNamed: className];
	  name = [list objectAtIndex: rowIndex];
	}
      
      if([_classManager isCustomClass: className])
	{
	  if(tableView == _actionTable)
	    {
	      result = [_classManager isAction: name
				     ofClass: className];
	    }
	  else if(tableView == _outletTable)
	    {
	      result = [_classManager isOutlet: name
				     ofClass: className];
	    }	       
	}
      else 
	{
	  result = [_classManager isAction: name onCategoryForClassNamed: className];
	}
    }

  return result;
}

- (void) tableView: (NSTableView *)tableView
   willDisplayCell: (id)aCell
    forTableColumn: (NSTableColumn *)aTableColumn
	       row: (NSInteger)rowIndex
{
  NSString *name = [aCell stringValue];
  NSString *className = [self _currentClass];

  if (tableView == _parentClass)
    {
      [aCell setTextColor: [NSColor textColor]];
    }
  else if (tableView == _actionTable)
    {
      if(([_classManager isCustomClass: className] &&
	  [_classManager isAction: name ofClass: className]) ||
	 [_classManager isAction: name onCategoryForClassNamed: className])
	{
	  [aCell setTextColor: [NSColor textColor]];
	}
      else
	{
	  [aCell setTextColor: [NSColor selectedTextColor]];
	}
    }
  else if( tableView == _outletTable)
    {
      if([_classManager isCustomClass: className] &&
	 [_classManager isOutlet: name ofClass: className])
	{
	  [aCell setTextColor: [NSColor textColor]];
	}
      else
	{
	  [aCell setTextColor: [NSColor selectedTextColor]];
	}
    }
  
  [(NSTextFieldCell *)aCell setScrollable: YES];
}

- (BOOL) tableView: (NSTableView *)tv
   shouldSelectRow: (NSInteger)rowIndex
{
  BOOL result = YES;
  if(tv == _parentClass)
    {
      NSArray *list = [_classManager allClassNames];
      NSString *className = [list objectAtIndex: rowIndex];
      NSString *name = [self _currentClass];
      BOOL isFirstResponder = [className isEqualToString: @"FirstResponder"];
      BOOL isCurrentClass = [className isEqualToString: name];
      BOOL isSubClass = [_classManager isSuperclass: name linkedToClass: className];
      if(isFirstResponder || isCurrentClass || isSubClass)
	{
	  NSBeep();
	  result = NO;
	}
    }
  return result;
}

@end
