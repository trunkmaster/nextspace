/** <title>GormCustomClassInspector</title>

   <abstract>allow user to select custom classes</abstract>

   Copyright (C) 2002 Free Software Foundation, Inc.
   Author:  Gregory John Casamento <greg_casamento@yahoo.com>
   Date: September 2002

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

#include "GormCustomClassInspector.h"
#include "GormPrivate.h"
#include "GormClassManager.h"
#include "GormDocument.h"
#include "GormPrivate.h"
#include "GormViewEditor.h"

@implementation GormCustomClassInspector
+ (void) initialize
{
  if (self == [GormCustomClassInspector class])
    {
    }
}

- (id) init
{
  self = [super init];
  if (self != nil)
    {
      NSBundle *bundle = [NSBundle bundleForClass: [self class]];

      // initialize all member variables...
      _classManager = nil;
      _currentSelectionClassName = nil;
      _rowToSelect = 0;
      
      // load the gui...
      if (![bundle loadNibNamed: @"GormCustomClassInspector"
			  owner: self
		topLevelObjects: NULL])
	{
	  NSLog(@"Could not open gorm GormCustomClassInspector");
	  return nil;
	}
    }
  return self;
}

- (void) _setCurrentSelectionClassName: (id)anobject
{
  NSString	 *className;

  className = [_classManager customClassForObject: anobject];
  if ([className isEqualToString: @""]
    || className == nil)
    {
      className = [anobject className];
    }

  ASSIGN(_currentSelectionClassName, className);
  ASSIGN(_parentClassName, [anobject className]);
}

- (NSMutableArray *) _generateClassList
{
  NSMutableArray *classes = [NSMutableArray arrayWithObject: _parentClassName];
  NSArray *subclasses = [_classManager allSubclassesOf: _parentClassName];
  NSEnumerator *en = [subclasses objectEnumerator];
  NSString *className = nil;
  Class parentClass = NSClassFromString(_parentClassName);

  while((className = [en nextObject]) != nil)
    {
      if([_classManager isCustomClass: className] == YES)
	{
	  NSString *superClass = [_classManager nonCustomSuperClassOf: className];
	  Class cls = NSClassFromString(superClass);
	  if(cls != nil)
	    {
	      if([cls respondsToSelector: @selector(canSubstituteForClass:)])
		{
		  if([cls canSubstituteForClass: parentClass])
		    {
		      [classes addObject: className];
		    }
		}
	    }
	}
      else if(parentClass != nil)
	{
	  Class cls = NSClassFromString(className);
	  if(cls != nil)
	    {
	      if([cls respondsToSelector: @selector(canSubstituteForClass:)])
		{
		  if([cls canSubstituteForClass: parentClass])
		    {
		      [classes addObject: className];
		    }
		}
	    }
	}
    }
  
  return classes;
}

- (void) setObject: (id)anObject
{
  if(anObject != nil)
    {
      NSMutableArray *classes = nil; 
      
      [super setObject: anObject];
      _document = [(id<IB>)[NSApp delegate] activeDocument];
      _classManager = [(id<GormAppDelegate>)[NSApp delegate] classManager];
      
      // get the information...
      NSDebugLog(@"Current selection %@", [self object]);
      [self _setCurrentSelectionClassName: [self object]];
      
      // load the array...
      [browser loadColumnZero];  
      
      // get a list of all of the classes allowed and the class to be shown
      // and select the appropriate row in the inspector...
      classes = [self _generateClassList];
      // [NSMutableArray arrayWithObject: _parentClassName];
      // [classes addObjectsFromArray: [_classManager allCustomSubclassesOf: _parentClassName]];
      
      _rowToSelect = [classes indexOfObject: _currentSelectionClassName];
      _rowToSelect = (_rowToSelect != NSNotFound)?_rowToSelect:0;
      
      if(_rowToSelect != NSNotFound)
	{
	  [browser selectRow: _rowToSelect inColumn: 0];
	}
    }
}

- (void) awakeFromNib
{
  [browser setTarget: self];
  [browser setAction: @selector(select:)];
  [browser setMaxVisibleColumns: 1];
}

- (void) _replaceWithCellClassForClassName: (NSString *)name
{
  NSString *className = name;
  if([[object class] respondsToSelector: @selector(cellClass)])
    {
      if([_classManager customClassForObject: object])
	{
	  if([_classManager isCustomClass: className])
	    {
	      className = [_classManager nonCustomSuperClassOf: name];
	    }
	}
      
      if(className != nil)
	{
	  Class cls = NSClassFromString(className);
	  if(cls != nil)
	    {
	      Class cellClass = [cls cellClass];
	      
	      if(cellClass != [[object cell] class])
		{
		  id newCell = [[cellClass alloc] init];
		  id cell = RETAIN([object cell]); // retain the old cell for now...
		  BOOL   drawsBackground = NO;
		  
		  if([object respondsToSelector: @selector(drawsBackground)])
		    {
		      drawsBackground = [object drawsBackground];
		    }
		  
		  // TODO: Need to find a more generic way to handle this.  Perhaps using
		  // encoding, kv-copying or @defs(...).
		  // set the new cell..
		  [object setCell: newCell];
		  
		  // general state...
		  if([newCell respondsToSelector: @selector(setFont:)] &&
		     [cell respondsToSelector: @selector(font)])
		    {
		      [newCell setFont: [cell font]];
		    }
		  if([newCell respondsToSelector: @selector(setEnabled:)] &&
		     [cell respondsToSelector: @selector(isEnabled)])
		    {
		      [newCell setEnabled: [cell isEnabled]];
		    }
		  if([newCell respondsToSelector: @selector(setEditable:)] &&
		     [cell respondsToSelector: @selector(isEditable)])
		    {
		      [newCell setEditable: [cell isEditable]];
		    }
		  if([newCell respondsToSelector: @selector(setImportsGraphics:)] &&
		     [cell respondsToSelector: @selector(importsGraphics)])
		    {
		      [newCell setImportsGraphics: [cell importsGraphics]];
		    }
		  if([newCell respondsToSelector: @selector(setShowsFirstResponder:)] &&
		     [cell respondsToSelector: @selector(showsFirstResponder)])
		    {
		      [newCell setShowsFirstResponder: [cell showsFirstResponder]];
		    }
		  if([newCell respondsToSelector: @selector(setRefusesFirstResponder:)] &&
		     [cell respondsToSelector: @selector(refusesFirstResponder)])
		    {
		      [newCell setRefusesFirstResponder: [cell refusesFirstResponder]];
		    }
		  if([newCell respondsToSelector: @selector(setBordered:)] &&
		     [cell respondsToSelector: @selector(isBordered)])
		    {
		      [newCell setBordered: [cell isBordered]];
		    }
		  if([newCell respondsToSelector: @selector(setBezeled:)] &&
		     [cell respondsToSelector: @selector(isBezeled)])
		    {
		      [newCell setBezeled: [cell isBezeled]];
		    }
		  if([newCell respondsToSelector: @selector(setScrollable:)] &&
		     [cell respondsToSelector: @selector(isScrollable)])
		    {
		      [newCell setScrollable: [cell isScrollable]];
		    }
		  if([newCell respondsToSelector: @selector(setSelectable:)] &&
		     [cell respondsToSelector: @selector(isSelectable)])
		    { 
		      [newCell setSelectable: [cell isSelectable]];
		    }
		  if([newCell respondsToSelector: @selector(setState:)] &&
		     [cell respondsToSelector: @selector(state)])
		    {
		      [newCell setState: [cell state]];
		    }

		  if([(NSCell *)cell type] == NSTextCellType)
		    {
		      // title...
		      if([newCell respondsToSelector: @selector(setStringValue:)] &&
			 [cell respondsToSelector: @selector(stringValue)])
			{
			  [newCell setStringValue: [cell stringValue]];
			}
		      if([newCell respondsToSelector: @selector(setTitle:)] &&
			 [cell respondsToSelector: @selector(title)])
			{
			  [newCell setTitle: [cell title]];
			}
		      if([newCell respondsToSelector: @selector(setAlternateTitle:)] &&
			 [cell respondsToSelector: @selector(alternateTitle)])
			{
			  [newCell setAlternateTitle: [cell alternateTitle]];
			}
		    }
		  else if([(NSCell *)cell type] == NSImageCellType)
		    {
		      // images...
		      if([newCell respondsToSelector: @selector(setAlternateImage:)] &&
			 [cell respondsToSelector: @selector(alternateImage)])
			{
			  [newCell setAlternateImage: [cell alternateImage]];
			}
		      if([newCell respondsToSelector: @selector(setImage:)] &&
			 [cell respondsToSelector: @selector(image)])
			{
			  [newCell setImage: [cell image]];
			}
		      if([newCell respondsToSelector: @selector(setImagePosition:)] &&
			 [cell respondsToSelector: @selector(imagePosition)])
			{
			  [newCell setImagePosition: [cell imagePosition]];
			}
		    }
		  // set attributes of textfield.
		  if([object respondsToSelector: @selector(setDrawsBackground:)])
		    {
		      [object setDrawsBackground: drawsBackground];
		    }
		  [object setNeedsDisplay: YES];
		  RELEASE(cell);
		}
	    }
	}
    }
}

- (void) select: (id)sender
{
  NSCell *cell = [browser selectedCellInColumn: 0];
  NSString *stringValue = [NSString stringWithString: [cell stringValue]];
  NSString *nameForObject = [_document nameForObject: [self object]];
  NSString *classForObject = [[self object] className]; 
  GormViewEditor *gve = (GormViewEditor *)[_document editorForObject: [self object]
						     create: NO];

  NSDebugLog(@"selected = %@, class = %@",stringValue,nameForObject);

  /* add or remove the mapping as necessary. */
  if(nameForObject != nil)
    {
      [super ok: sender];
      
      if (![stringValue isEqualToString: classForObject])
	{
	  [_classManager setCustomClass: stringValue
			 forName: nameForObject];
	}
      else
	{
	  [_classManager removeCustomClassForName: nameForObject];
	}

      [gve setToolTip: [NSString stringWithFormat: @"%@,%@",
				 nameForObject, 
				 stringValue]];
      
      [self _replaceWithCellClassForClassName: stringValue];
    }
  else
    {
      NSLog(@"name for object %@ returned as nil",[self object]);
    }
}

// Browser delegate
- (void)    browser: (NSBrowser *)sender 
createRowsForColumn: (NSInteger)column
	   inMatrix: (NSMatrix *)matrix
{
  if (_parentClassName != nil)
    {
      NSMutableArray	*classes;
      NSEnumerator	*e = nil;
      NSString		*class = nil;
      NSBrowserCell	*cell = nil;
      NSInteger		i = 0;
      
      classes = [self _generateClassList]; 
      
      // enumerate through the classes...
      e = [classes objectEnumerator];
      while ((class = [e nextObject]) != nil)
	{
	  if ([class isEqualToString: _currentSelectionClassName])
	    {
	      _rowToSelect = i;
	    }
	  [matrix insertRow: i withCells: nil];
	  cell = [matrix cellAtRow: i column: 0];
	  [cell setLeaf: YES];
	  i++;
	  [cell setStringValue: class];
	}
    }
}

- (NSString*) browser: (NSBrowser*)sender 
	titleOfColumn: (NSInteger)column
{
  NSDebugLog(@"Delegate called");
  return @"Class";
}

- (void) browser: (NSBrowser *)sender 
 willDisplayCell: (id)cell 
	   atRow: (NSInteger)row 
	  column: (NSInteger)column
{
}

- (BOOL) browser: (NSBrowser *)sender 
   isColumnValid: (NSInteger)column
{
  return YES;
}
@end
