/** <title>GormOutlineView</title>

   <abstract>The NSOutlineView subclass in gorm which handles outlet/action editing</abstract>
   
   Copyright (C) 2001 Free Software Foundation, Inc.

   Author:  Gregory John Casamento <greg_casamento@yahoo.com>
   Date: July 2002
   
   This file is part of the GNUstep GUI Library.

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

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#include "GormOutlineView.h"

static NSNotificationCenter *nc = nil;
static const NSInteger current_version = 1;

// Cache the arrow images...
static NSImage *collapsed = nil;
static NSImage *expanded  = nil;
static NSImage *unexpandable  = nil;
static NSImage *action = nil;
static NSImage *outlet = nil;
static NSImage *actionSelected = nil;
static NSImage *outletSelected = nil;

// some common colors which will be used to indicate state in the outline
// view.
static NSColor *salmonColor = nil;
static NSColor *darkSalmonColor = nil;
static NSColor *lightGreyBlueColor = nil;
static NSColor *darkGreyBlueColor = nil;

@implementation GormOutletActionHolder
- init
{
  [super init];
  _name = nil;
  return self;
}

- initWithName: (NSString *)name
{
  [self init];
  ASSIGN(_name,name);
  return self;
}

- (NSString *)getName
{
  return _name;
}

- (void)setName: (NSString *)name
{
  ASSIGN(_name,name);
}
@end

@implementation GormOutlineView
// Initialize the class when it is loaded
+ (void) initialize
{
  if (self == [GormOutlineView class])
    {
      NSBundle *bundle = [NSBundle bundleForClass: self];
      NSString *path = nil;
      
      // initialize images
      [self setVersion: current_version];
      nc = [NSNotificationCenter defaultCenter];
      collapsed    = [NSImage imageNamed: @"common_outlineCollapsed"];
      expanded     = [NSImage imageNamed: @"common_outlineExpanded"];
      unexpandable = [NSImage imageNamed: @"common_outlineUnexpandable"];
      path = [bundle pathForImageResource: @"GormAction"];
      action       = [[NSImage alloc] initWithContentsOfFile: path];
      path = [bundle pathForImageResource: @"GormOutlet"];
      outlet       = [[NSImage alloc] initWithContentsOfFile: path];
      path = [bundle pathForImageResource: @"GormActionSelected"];
      actionSelected = [[NSImage alloc] initWithContentsOfFile: path];
      path = [bundle pathForImageResource: @"GormOutletSelected"];
      outletSelected = [[NSImage alloc] initWithContentsOfFile: path];

      // initialize colors
      salmonColor = 
	RETAIN([NSColor colorWithCalibratedRed: 0.850980 
			green: 0.737255
			blue: 0.576471
			alpha: 1.0 ]);
      darkSalmonColor = 
	RETAIN([NSColor colorWithCalibratedRed: 0.568627 
			green: 0.494118
			blue: 0.384314
			alpha: 1.0 ]);
      lightGreyBlueColor = 
	RETAIN([NSColor colorWithCalibratedRed: 0.450980 
			green: 0.450980
			blue: 0.521569
			alpha: 1.0 ]);
      darkGreyBlueColor = 
	RETAIN([NSColor colorWithCalibratedRed: 0.333333 
			green: 0.333333
			blue: 0.384314
			alpha: 1.0 ]);
    }
}

- (void) _handleDoubleClick: (id)sender
{
  NSDebugLog(@"Double clicked");
}

- init
{
  if((self = [super init]) != nil)
    {
      _actionColumn = nil;
      _outletColumn = nil;
      _isEditing = NO;
      _attributeOffset = 0.0;
      _edittype = None;
      _menuItem = nil;
      [self setDoubleAction: @selector(_handleDoubleClick:)];
      [self setTarget: self];
    }

  return self;
}

- (void) collapseItem: (id)item collapseChildren: (BOOL)collapseChildren;
{
  if (!_isEditing)
    {
      // [self deselectAll: self];
      [super collapseItem: item
	 collapseChildren: collapseChildren];
    }
}

- (void) expandItem: (id)item expandChildren: (BOOL)expandChildren
{
  if (!_isEditing)
    {
      // [self deselectAll: self];
      [super expandItem: item
	 expandChildren: expandChildren];
    } 
}

- (BOOL) _isOutletOrActionOfItemBeingEdited: (NSString *)name
{
  NSArray *array = nil;
  array = [_dataSource outlineView: self
		       actionsForItem: _itemBeingEdited];
  if ([array containsObject: name])
    return YES;
  array = [_dataSource outlineView: self outletsForItem: _itemBeingEdited];
  if ([array containsObject: name])
    return YES;
  return NO;
}

- (void) _addNewActionToObject: (id)item
{
  NSUInteger insertionPoint = 0;
  NSString *name = nil;

  GormOutletActionHolder *holder = [[GormOutletActionHolder alloc] init];
  name = [_dataSource outlineView: self addNewActionForClass: _itemBeingEdited];
  if (name != nil)
    {
      _numberOfRows += 1;
      [holder setName: name];
      insertionPoint = [_items indexOfObject: item];
      [_items insertObject: holder atIndex: insertionPoint + 1];
      [self setNeedsDisplay: YES];
      [self noteNumberOfRowsChanged];
    }
}

- (void) _addNewOutletToObject: (id)item
{
  NSUInteger insertionPoint = 0;
  GormOutletActionHolder *holder = [[GormOutletActionHolder alloc] init];
  NSString *name = nil;

  _numberOfRows += 1;
  name = [_dataSource outlineView: self addNewOutletForClass: _itemBeingEdited];
  if (name != nil)
    {
      [holder setName: name];
      insertionPoint = [_items indexOfObject: item];
      [_items insertObject: holder atIndex: insertionPoint + 1];
      [self setNeedsDisplay: YES];
      [self noteNumberOfRowsChanged];
    }
}

- (void) removeItemAtRow: (int)row
{
  [_items removeObjectAtIndex: row];
  _numberOfRows -= 1;
  [self setNeedsDisplay: YES];
  [self noteNumberOfRowsChanged];
}

- (void)_openActions: (id)item
{
  NSInteger numchildren = 0;
  NSInteger i = 0;
  NSUInteger insertionPoint = 0;
  id object = nil;
  id sitem = (item == nil)?((id)[NSNull null]):((id)item);

  object = [_dataSource outlineView: self
		     actionsForItem: sitem];
  numchildren = [object count];
  
  _numberOfRows += numchildren;
  // open the item...
  if (item != nil)
    {
      [self setItemBeingEdited: item];
      [self setIsEditing: YES];
    }

  insertionPoint = [_items indexOfObject: item];
  if (insertionPoint == NSNotFound)
    {
      insertionPoint = 0;
    }
  else
    {
      insertionPoint++;
    }
  
  [self setNeedsDisplay: YES];  
  for (i = numchildren - 1; i >= 0; i--)
    {
      id child = [object objectAtIndex: i];       // Add all of the children...
      GormOutletActionHolder *holder;

      holder = [[GormOutletActionHolder alloc] initWithName: child];
      [_items insertObject: holder atIndex: insertionPoint];
    }
  [self noteNumberOfRowsChanged];
}

- (void) _openOutlets: (id)item
{
  NSInteger numchildren = 0;
  NSInteger i = 0;
  NSInteger insertionPoint = 0;
  id object = nil;
  id sitem = (item == nil)?((id)[NSNull null]):((id)item);

  object = [_dataSource outlineView: self
		     outletsForItem: sitem];
  numchildren = [object count];
  
  _numberOfRows += numchildren;
  // open the item...
  if (item != nil)
    {
      [self setItemBeingEdited: item];
      [self setIsEditing: YES];
    }

  insertionPoint = [_items indexOfObject: item];
  if (insertionPoint == NSNotFound)
    {
      insertionPoint = 0;
    }
  else
    {
      insertionPoint++;
    }
  
  [self setNeedsDisplay: YES];  
  for (i = numchildren - 1; i >= 0; i--)
    {
      id child = [object objectAtIndex: i];       // Add all of the children...
      GormOutletActionHolder *holder;

      holder = [[GormOutletActionHolder alloc] initWithName: child];
      [_items insertObject: holder atIndex: insertionPoint];
    }
  [self noteNumberOfRowsChanged];
}

- (void) drawRow: (NSInteger)rowIndex clipRect: (NSRect)aRect
{
  NSInteger startingColumn; 
  NSInteger endingColumn;
  NSTableColumn *tb;
  NSRect drawingRect;
  NSCell *cell;
  NSCell *imageCell = nil;
  NSRect imageRect;
  NSInteger i;
  float x_pos;

  if (_dataSource == nil)
    {
      return;
    }

  /* Using columnAtPoint: here would make it called twice per row per drawn 
     rect - so we avoid it and do it natively */
  
  if (rowIndex >= _numberOfRows)
    {
      return;
    }

  /* Determine starting column as fast as possible */
  x_pos = NSMinX (aRect);
  i = 0;
  while ((x_pos > _columnOrigins[i]) && (i < _numberOfColumns))
    {
      i++;
    }
  startingColumn = (i - 1);

  if (startingColumn == -1)
    startingColumn = 0;

  /* Determine ending column as fast as possible */
  x_pos = NSMaxX (aRect);
  // Nota Bene: we do *not* reset i
  while ((x_pos > _columnOrigins[i]) && (i < _numberOfColumns))
    {
      i++;
    }
  endingColumn = (i - 1);

  if (endingColumn == -1)
    endingColumn = _numberOfColumns - 1;

  /* Draw the row between startingColumn and endingColumn */
  for (i = startingColumn; i <= endingColumn; i++)
    {
      if (i != _editedColumn || rowIndex != _editedRow)
	{
	  id item = [self itemAtRow: rowIndex];
	  id value = nil, valueforcell = nil;
	  BOOL isOutletAction = NO;

	  tb = [_tableColumns objectAtIndex: i];
	  cell = [tb dataCellForRow: rowIndex];
	  value = [_dataSource outlineView: self
			       objectValueForTableColumn: tb
			       byItem: item];

	  if ([value isKindOfClass: [GormOutletActionHolder class]])
	    {
	      valueforcell = [value getName];
	      isOutletAction = YES;
 	    }
	  else
	    {
	      valueforcell = value;
	      isOutletAction = NO;
	    }

	  if ([_delegate respondsToSelector: @selector(outlineView:willDisplayCell:forTableColumn:item:)])
	    {
	      [_delegate outlineView: self   
			 willDisplayCell: cell 
			 forTableColumn: tb   
			 item: item];
	    }
	  
	  [cell setObjectValue: valueforcell]; 
	  drawingRect = [self frameOfCellAtColumn: i
			      row: rowIndex];	      
	  

	  if (isOutletAction)
	    {
	      drawingRect.origin.x += _attributeOffset;
	      drawingRect.size.width -= _attributeOffset;
	    }	  

	  if (tb == _outlineTableColumn && !isOutletAction)
	    {
	      NSImage *image = nil;
	      NSInteger level = 0;
	      float indentationFactor = 0.0;

	      // display the correct arrow...
	      if ([self isItemExpanded: item])
		{
		  image = expanded;
		}
	      else
		{
		  image = collapsed;
		}
	      
	      if (![self isExpandable: item])
		{
		  image = unexpandable;
		}
	      
	      level = [self levelForItem: item];
	      indentationFactor = _indentationPerLevel * level;
	      imageCell = [[NSCell alloc] initImageCell: image];
	      
	      if (_indentationMarkerFollowsCell)
		{
		  imageRect.origin.x = drawingRect.origin.x + indentationFactor;
		  imageRect.origin.y = drawingRect.origin.y;
		}
	      else
		{
		  imageRect.origin.x = drawingRect.origin.x;
		  imageRect.origin.y = drawingRect.origin.y;
		}
	      
	      imageRect.size.width = [image size].width;
	      imageRect.size.height = [image size].height;
	      
	      [imageCell drawWithFrame: imageRect inView: self];
	      
	      drawingRect.origin.x
	     	+= indentationFactor + [image size].width + 5;
	      drawingRect.size.width
	        -= indentationFactor + [image size].width + 5;
	      // [cell drawWithFrame: drawingRect inView: self];
	    }
	  else if ((tb == _actionColumn || tb == _outletColumn)
		   && isOutletAction == NO)
	    {
	      NSImage *image = nil;

	      if (item == _itemBeingEdited && tb == _actionColumn
		&& _edittype == Actions)
		image = actionSelected;
	      else if (item == _itemBeingEdited && tb == _outletColumn
		&& _edittype == Outlets)
		image = outletSelected;
	      else
		image = (tb == _actionColumn)?action:outlet;
	      
	      // Prepare image cell...
	      imageCell = [[NSCell alloc] initImageCell: image];
	      imageRect.origin.x = drawingRect.origin.x;
	      imageRect.origin.y = drawingRect.origin.y;
	      imageRect.size.width = [image size].width;
	      imageRect.size.height = [image size].height;
	      [imageCell drawWithFrame: imageRect inView: self];
	      
	      // Adjust drawing rect of cell being displayed...
	      drawingRect.origin.x += [image size].width + 5;
	      drawingRect.size.width -= [image size].width + 5;
	      // [cell drawWithFrame: drawingRect inView: self];
	    }
	  
	  if (((tb != _outletColumn || tb != _actionColumn) && !isOutletAction) || (tb == _outlineTableColumn))
	    {
	      [cell drawWithFrame: drawingRect inView: self];
	    }
	}
    }
}

- (void) reset
{
  [self setItemBeingEdited: nil];
  [self setIsEditing: NO];
  [self setBackgroundColor: salmonColor];
  [self reloadData];
}

- (void) mouseDown: (NSEvent *)theEvent
{
  NSPoint location = [theEvent locationInWindow];
  NSTableColumn *tb;
  NSImage *image = nil;
  id _clickedItem = nil;
  BOOL isActionOrOutlet = NO;

  location = [self convertPoint: location  fromView: nil];
  _clickedRow = [self rowAtPoint: location];
  _clickedColumn = [self columnAtPoint: location];
  _clickedItem = [self itemAtRow: _clickedRow];
  isActionOrOutlet
    = [_clickedItem isKindOfClass: [GormOutletActionHolder class]];

  tb = [_tableColumns objectAtIndex: _clickedColumn];
  if (tb == _actionColumn)
    {
      image = action;
    }
  else if (tb == _outletColumn)
    {
      image = outlet;
    }

  if ((tb == _actionColumn || tb == _outletColumn) && !_isEditing)
    {
      NSInteger position = 0;      
      position += _columnOrigins[_clickedColumn] + 5;

      if (location.x >= position
	&& location.x <= position + [image size].width + 5)
	{
	  [self setItemBeingEdited: _clickedItem];
	  [self setIsEditing: YES];
	  // [self setBackgroundColor: darkSalmonColor]; // for later
	  if (tb == _actionColumn)
	    {
	      _edittype = Actions;
	      [self _openActions: _clickedItem];
	    }
	  else if (tb == _outletColumn)
	    {
	      _edittype = Outlets;
	      [self _openOutlets: _clickedItem];
	    }
	}
      [super mouseDown: theEvent];
    }
  else if (_isEditing && !isActionOrOutlet)
    {
      if (_clickedItem != [self itemBeingEdited] && !isActionOrOutlet)
	{
	  [self reset];
	}
      else if (tb == _actionColumn)
	{
	  if (_edittype != Actions)
	    {
	      [self reset];
	      _edittype = Actions;
	      [self _openActions: _clickedItem];
	    }
	}
      else /* tb == _outletColumn */
	{
	  if (_edittype != Outlets)
	    {
	      [self reset];
	      _edittype = Outlets;
	      [self _openOutlets: _clickedItem];
	    }
	}
    }
  else
    {
      [super mouseDown: theEvent];
    }
}  

// additional methods for subclass
- (void) setAttributeOffset: (float)offset
{
  _attributeOffset = offset;
}

- (float) attributeOffset
{
  return _attributeOffset;
}

- (void) setItemBeingEdited: (id)item
{
  _itemBeingEdited = item;
}

- (id) itemBeingEdited
{
  return _itemBeingEdited;
}

- (void) setIsEditing: (BOOL)flag
{
  _isEditing = flag;
}

- (BOOL) isEditing
{
  return _isEditing;
}

- (void)setActionColumn: (NSTableColumn *)ac
{
  ASSIGN(_actionColumn,ac);
}

- (NSTableColumn *)actionColumn
{
  return _actionColumn;
}

- (void)setOutletColumn: (NSTableColumn *)oc
{
  ASSIGN(_outletColumn,oc);
}

- (NSTableColumn *)outletColumn
{
  return _outletColumn;
}

- (void)setMenuItem: (NSMenuItem *)item
{
  ASSIGN(_menuItem, item);
}

- (NSMenuItem *)menuItem
{
  return _menuItem;
}

- (GSAttributeType)editType
{
  return _edittype;
}

- (void) editColumn: (NSInteger) columnIndex 
		row: (NSInteger) rowIndex 
	  withEvent: (NSEvent *) theEvent 
	     select: (BOOL) flag
{
  NSText *t;
  NSTableColumn *tb;
  NSRect drawingRect, imageRect;
  unsigned length = 0;
  id item = nil;
  NSInteger level = 0;
  float indentationFactor = 0.0;
  NSImage *image = nil;
  NSCell *imageCell = nil;
  id value = nil;
  BOOL isOutletOrAction = NO;

  // We refuse to edit cells if the delegate can not accept results 
  // of editing.
  if (_dataSource_editable == NO)
    {
      return;
    }
  
  [self scrollRowToVisible: rowIndex];
  [self scrollColumnToVisible: columnIndex];

  if (rowIndex < 0 || rowIndex >= _numberOfRows 
    || columnIndex < 0 || columnIndex >= _numberOfColumns)
    {
      [NSException raise: NSInvalidArgumentException
		   format: @"Row/column out of index in edit"];
    }
  
  if (_textObject != nil)
    {
      [self validateEditing];
      [self abortEditing];
    }

  // Now (_textObject == nil)

  t = [_window fieldEditor: YES  forObject: self];

  if ([t superview] != nil)
    {
      if ([t resignFirstResponder] == NO)
	{
	  return;
	}
    }
  
  _editedRow = rowIndex;
  _editedColumn = columnIndex;
  item = [self itemAtRow: _editedRow];

  // Prepare the cell
  tb = [_tableColumns objectAtIndex: columnIndex];
  // NB: need to be released when no longer used
  _editedCell = [[tb dataCellForRow: rowIndex] copy];
  value =  [_dataSource outlineView: self 
			objectValueForTableColumn: tb
			byItem: item];
  if ([value isKindOfClass: [GormOutletActionHolder class]])
    {
      isOutletOrAction = YES;
      value = [value getName];
    }

  [_editedCell setEditable: YES];
  [_editedCell setObjectValue: value];
  // We really want the correct background color!
  if ([_editedCell respondsToSelector: @selector(setBackgroundColor:)])
    {
      [(NSTextFieldCell *)_editedCell setBackgroundColor: _backgroundColor];
    }
  else
    {
      [t setBackgroundColor: _backgroundColor];
    }
  
  // But of course the delegate can mess it up if it wants
  if (_del_responds)
    {
      [_delegate outlineView: self   
		 willDisplayCell: _editedCell 
		 forTableColumn: tb   
		 item: [self itemAtRow: rowIndex]];
    }

  /* Please note the important point - calling stringValue normally
     causes the _editedCell to call the validateEditing method of its
     control view ... which happens to be this object :-)
     but we don't want any spurious validateEditing to be performed
     before the actual editing is started (otherwise you easily end up
     with the table view picking up the string stored in the field
     editor, which is likely to be the string resulting from the last
     edit somewhere else ... getting into the bug that when you TAB
     from one cell to another one, the string is copied!), so we must
     call stringValue when _textObject is still nil.  */
  if (flag)
    {
      length = [[_editedCell stringValue] length];
    }

  _textObject = [_editedCell setUpFieldEditorAttributes: t];

  // determine which image to use...
  if ([self isItemExpanded: item])
    {
      image = expanded;
    }
  else
    {
      image = collapsed;
    }

  if (![self isExpandable: item])
    {
      image = unexpandable;
    }
  // move the drawing rect over like in the drawRow routine...
  level = [self levelForItem: item];
  indentationFactor = _indentationPerLevel * level;
  drawingRect = [self frameOfCellAtColumn: columnIndex  row: rowIndex];
  if (isOutletOrAction)
    {
      drawingRect.origin.x += _attributeOffset;
      drawingRect.size.width -= _attributeOffset;
    }
  else
    {
      drawingRect.origin.x += indentationFactor + 5 + [image size].width;
      drawingRect.size.width -= indentationFactor + 5 + [image size].width;
    }
  
  // create the image cell..
  imageCell = [[NSCell alloc] initImageCell: image];
  if (_indentationMarkerFollowsCell)
    {
      imageRect.origin.x = drawingRect.origin.x + indentationFactor;
      imageRect.origin.y = drawingRect.origin.y;
    }
  else
    {
      imageRect.origin.x = drawingRect.origin.x;
      imageRect.origin.y = drawingRect.origin.y;
    }
  
  // draw...
  imageRect.size.width = [image size].width;
  imageRect.size.height = [image size].height;
  [imageCell drawWithFrame: imageRect inView: self];
  if (flag)
    {
      [_editedCell selectWithFrame: drawingRect
		   inView: self
		   editor: _textObject
		   delegate: self
		   start: 0
		   length: length];
    }
  else
    {
      [_editedCell editWithFrame: drawingRect
		   inView: self
		   editor: _textObject
		   delegate: self
		   event: theEvent];
    }
  return;    
}

- (void) selectRow: (int)rowIndex
{
  [self setNeedsDisplayInRect: [self rectOfRow: rowIndex]];
  [_selectedRows addIndex: rowIndex];
  _selectedRow = rowIndex;
}
@end /* implementation of GormOutlineView */

