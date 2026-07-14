/* GormNSBrowser.m

   Copyright (C) 2001 Free Software Foundation, Inc.

   Author: Pierre-Yves Rivaille <pyrivail@ens-lyon.fr>
   Date: 2001
   
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

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#include "GormNSBrowser.h"

/* --------------------------------------------------------------- 
 * NSBrowser Delegate
*/
@interface NSBrowserDelegate: NSObject
{
}

- (NSInteger) browser: (NSBrowser *)sender numberOfRowsInColumn: (NSInteger)column;
- (NSString *) browser: (NSBrowser *)sender titleOfColumn: (NSInteger)column;
- (void) browser: (NSBrowser *)sender willDisplayCell: (id)cell
           atRow: (NSInteger)row column: (NSInteger)column;

@end


@implementation NSBrowserDelegate

- (NSInteger) browser: (NSBrowser *)sender numberOfRowsInColumn: (NSInteger)column
{
  return 0;
}

- (NSString *) browser: (NSBrowser *)sender titleOfColumn: (NSInteger)column
{
  return (column==0) ? @"Browser" : @"";
}

- (void) browser: (NSBrowser *)sender
 willDisplayCell: (id)cell
           atRow: (NSInteger)row
          column: (NSInteger)column
{
  // NSDebugLog(@"%@: browser %@ will display %@ %@ at %d,%d",self,sender,[cell class],cell,row,column);
  // This code should never be called because there is no row
  // in our browser. But just in case...
  [cell setLeaf:YES];
  [cell setStringValue: @""];
}

@end

static id _sharedDelegate = nil;

@implementation GormNSBrowser
+ (id) sharedDelegate
{
  if (_sharedDelegate == nil)
    {
      _sharedDelegate = [[NSBrowserDelegate alloc] init];
    }
  return _sharedDelegate;
}

- (id) initWithFrame: (NSRect) aRect
{
  self = [super initWithFrame: aRect];
  [super setDelegate: [GormNSBrowser sharedDelegate]];
  _gormDelegate = nil;
  return self;
}

- (void)setDelegate: (id)anObject
{
  _gormDelegate = anObject;
}

- (id)delegate
{
  return _gormDelegate;
}

- (void)encodeWithCoder: (NSCoder*) aCoder
{
  _browserDelegate = _gormDelegate;
  [super encodeWithCoder: aCoder];
  _browserDelegate = _sharedDelegate;
}

- (id) initWithCoder: (NSCoder*) aCoder
{
  [super setDelegate: [GormNSBrowser sharedDelegate]];
  self = [super initWithCoder: aCoder];
  return self;
}

- (NSString *) className
{
  return @"NSBrowser";
}
@end
