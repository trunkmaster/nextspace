/* GormNSOutlineView.m

   Copyright (C) 2002 Free Software Foundation, Inc.

   Author: Gregory John Casamento <greg_casamento@yahoo.com>
   Date: 2002
   
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

#include <AppKit/AppKit.h>

#include "GormNSOutlineView.h"

/* --------------------------------------------------------------- 
 * NSTableView dataSource
*/
@interface NSOutlineViewDataSource: NSObject
{
}
- (id)outlineView: (NSOutlineView *)outlineView
	    child: (NSInteger)index
	   ofItem: (id)item;

- (BOOL)outlineView: (NSOutlineView *)outlineView
   isItemExpandable: (id)item;

- (NSInteger)        outlineView: (NSOutlineView *)outlineView 
    numberOfChildrenOfItem: (id)item;

- (id)         outlineView: (NSOutlineView *)outlineView 
 objectValueForTableColumn: (NSTableColumn *)tableColumn 
		    byItem: (id)item;
@end


@implementation NSOutlineViewDataSource
// required methods for data source
- (id)outlineView: (NSOutlineView *)outlineView
	    child: (NSInteger)index
	   ofItem: (id)item
{
  if([item isEqual: @"NSObject"])
    {
      switch(index)
	{
	case 0:
	  return @"NSApplication";
	  break;
	case 1:
	  return @"NSTableColumn";
	  break;
	case 2:
	  return @"NSStatusBar";
	  break;
	case 3:
	  return @"NSResponder";
	  break;
	default:
	  break;
	}
    }
  if([item isEqual: @"NSResponder"])
    {
      switch(index)
	{
	case 0:
	  return @"NSWindow";
	  break;
	case 1:
	  return @"NSView";
	  break;
	default:
	  break;
	}
    }
  else
    if(item == nil)
      {
	if(index == 0)
	  return @"NSObject";
      }

  return nil;
}

- (BOOL)outlineView: (NSOutlineView *)outlineView
   isItemExpandable: (id)item
{
  if([item isEqual: @"NSObject"])
    return YES;
  if([item isEqual: @"NSResponder"])
    return YES;

  return NO;
}

- (NSInteger)        outlineView: (NSOutlineView *)outlineView 
    numberOfChildrenOfItem: (id)item
{
  if(item == nil)
    return 1;
  else
    if([item isEqual: @"NSObject"])
      return 4;
  else
    if([item isEqual: @"NSResponder"])
      return 2;

  return 0;
}

- (id)         outlineView: (NSOutlineView *)outlineView 
 objectValueForTableColumn: (NSTableColumn *)tableColumn 
		    byItem: (id)item
{
  NSString *value = nil;
  if([item isEqual: @"NSObject"])
    {
      if([[tableColumn identifier] isEqual: @"classes"])
	{
	  value = @"NSObject";
	}
      else
      if([[tableColumn identifier] isEqual: @"outlets"])
	{
	  value = @"0";
	}
      else
      if([[tableColumn identifier] isEqual: @"actions"])
	{
	  value = @"0";
	}
    }
  else
    {
      if([[tableColumn identifier] isEqual: @"classes"])
	{
	  value = @"NSApplication";
	}
      else
      if([[tableColumn identifier] isEqual: @"outlets"])
	{
	  value = @"2";
	}
      else
      if([[tableColumn identifier] isEqual: @"actions"])
	{
	  value = @"3";
	}
    }

  return value;
}

@end

static id _sharedDataSource = nil;

@implementation NSOutlineView (GormPrivate)
+ (id) allocSubstitute
{
  return [GormNSOutlineView alloc];
}
@end

@implementation GormNSOutlineView
+ (id) sharedDataSource
{
  if (_sharedDataSource == nil)
    {
      _sharedDataSource = [[NSOutlineViewDataSource alloc] init];
    }
  return _sharedDataSource;
}

- (id) initWithFrame: (NSRect) aRect
{
  self = [super initWithFrame: aRect];
  [super setDataSource: [GormNSOutlineView sharedDataSource]];
  _gormDataSource = nil;
  return self;
}

- (void)setDataSource: (id)anObject
{
  _gormDataSource = anObject;
}

- (id)dataSource
{
  return _gormDataSource;
}

- (void)setDelegate: (id)anObject
{
  _gormDelegate = anObject;
}

- (id)delegate
{
  return _gormDelegate;
}

- (void)setGormDelegate: (id)anObject
{
  [super setDelegate: anObject];
}

- (void)encodeWithCoder: (NSCoder*) aCoder
{
  id oldDelegate;
  int oldNumberOfRows;

  // set real values...
  _allowsColumnReordering = _gormAllowsColumnReordering;
  _allowsColumnResizing = _gormAllowsColumnResizing;
  _allowsColumnSelection = _gormAllowsColumnSelection;
  _allowsMultipleSelection = _gormAllowsMultipleSelection;
  _allowsEmptySelection = _gormAllowsEmptySelection;
  _dataSource = _gormDataSource;
  oldDelegate = _delegate;
  _delegate = _gormDelegate;
  oldNumberOfRows = _numberOfRows;
  _numberOfRows = 0;

  [super encodeWithCoder: aCoder];

  // set fake values back...
  _numberOfRows = oldNumberOfRows;
  _allowsColumnReordering = YES;
  _allowsColumnResizing = YES;
  _allowsColumnSelection = YES;
  _allowsMultipleSelection = NO;
  _allowsEmptySelection = YES;

  _delegate = oldDelegate;
  _dataSource = _sharedDataSource;
}

- (id) initWithCoder: (NSCoder*) aCoder
{
  self = [super initWithCoder: aCoder];

  [super setDataSource: [GormNSOutlineView sharedDataSource]];
  _gormAllowsColumnReordering = _allowsColumnReordering;
  _gormAllowsColumnResizing = _allowsColumnResizing;
  _gormAllowsColumnSelection = _allowsColumnSelection;
  _gormAllowsMultipleSelection = _allowsMultipleSelection;
  _gormAllowsEmptySelection = _allowsEmptySelection;
  _gormDelegate = _delegate;
  _delegate = nil;

  return self;
}

- (void) setGormAllowsColumnReordering: (BOOL)flag
{
  _gormAllowsColumnReordering = flag;
}

- (BOOL) gormAllowsColumnReordering
{
  return _gormAllowsColumnReordering;
}

- (void) setGormAllowsColumnResizing: (BOOL)flag
{
  _gormAllowsColumnResizing = flag;
}

- (BOOL) gormAllowsColumnResizing
{
  return _gormAllowsColumnResizing;
}

- (void) setGormAllowsMultipleSelection: (BOOL)flag
{
  _gormAllowsMultipleSelection = flag;
}

- (BOOL) gormAllowsMultipleSelection
{
  return _gormAllowsMultipleSelection;
}

- (void) setGormAllowsEmptySelection: (BOOL)flag
{
  _gormAllowsEmptySelection = flag;
}

- (BOOL) gormAllowsEmptySelection
{
  return _gormAllowsEmptySelection;
}

- (void) setGormAllowsColumnSelection: (BOOL)flag
{
  _gormAllowsColumnSelection = flag;
}

- (BOOL) gormAllowsColumnSelection
{
  return _gormAllowsColumnSelection;
}

- (NSString *) className
{
  return @"NSOutlineView";
}
@end
