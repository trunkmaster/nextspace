#/* GormPluginsPref.m
 *
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	2004
 * 
 * This file is part of GNUstep.
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#include <GormCore/GormCore.h>

#include "GormPluginsPref.h"

@class NSTableView;

// data source...
@interface PluginDataSource : NSObject
@end

@implementation PluginDataSource
- (NSInteger) numberOfRowsInTableView: (NSTableView *)tv
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSArray *list = [defaults objectForKey: @"UserPlugins"];
  return [list count];
}

- (id)          tableView: (NSTableView *)tv
objectValueForTableColumn: (NSTableColumn *)tc
	              row: (NSInteger)rowIndex
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSArray *list = [defaults objectForKey: @"UserPlugins"];
  id value = nil;
  if([list count] > 0)
    {
      value = [[list objectAtIndex: rowIndex] lastPathComponent];
    }
  return value;
}
@end


@implementation GormPluginsPref
- (id) init
{
  _view = nil;

  self = [super init];
  
  if ( ! [NSBundle loadNibNamed:@"GormPrefPlugins" owner:self] )
    {
      NSLog(@"Can not load bundle GormPrefPlugins");
      return nil;
    }
  
  _view =  [[(NSWindow *)window contentView] retain];
  return self;
}

- (void) dealloc
{
  TEST_RELEASE(_view);
  [super dealloc];
}


-(NSView *) view
{
  return _view;
}

- (void) addAction: (id)sender
{
  [[(id<GormAppDelegate>)[NSApp delegate] pluginManager] openPlugin: self];
  [table reloadData];
}


- (void) removeAction: (id)sender
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSMutableArray *list = [defaults objectForKey: @"UserPlugins"];
  int row = [table selectedRow];

  if(row >= 0)
    {
      NSString *stringValue = [list objectAtIndex: row];
      
      if(stringValue != nil)
	{
	  [list removeObject: stringValue];
	  [defaults setObject: list forKey: @"UserPlugins"];
	  [table reloadData];
	}
    }
}

- (BOOL)    tableView: (NSTableView *)tableView
shouldEditTableColumn: (NSTableColumn *)aTableColumn
		  row: (NSInteger)rowIndex
{
  BOOL result = NO;
  return result;
}

- (BOOL) tableView: (NSTableView *)tv
   shouldSelectRow: (NSInteger)rowIndex
{
  BOOL result = YES;
  return result;
}

@end
