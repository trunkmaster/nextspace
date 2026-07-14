/* GormNSTableView.h

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
#ifndef	INCLUDED_GormNSTableView_h
#define	INCLUDED_GormNSTableView_h

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

@interface GormNSTableView : NSTableView
{
  id _gormDataSource;
  id _gormDelegate;
  BOOL _gormAllowsColumnReordering;
  BOOL _gormAllowsColumnResizing;
  BOOL _gormAllowsColumnSelection;
  BOOL _gormAllowsMultipleSelection;
  BOOL _gormAllowsEmptySelection;
}

- (void) setGormDelegate: (id)anObject;
- (void) setGormAllowsColumnReordering: (BOOL)flag;
- (BOOL) gormAllowsColumnReordering;
- (void) setGormAllowsColumnResizing: (BOOL)flag;
- (BOOL) gormAllowsColumnResizing;
- (void) setGormAllowsMultipleSelection: (BOOL)flag;
- (BOOL) gormAllowsMultipleSelection;
- (void) setGormAllowsEmptySelection: (BOOL)flag;
- (BOOL) gormAllowsEmptySelection;
- (void) setGormAllowsColumnSelection: (BOOL)flag;
- (BOOL) gormAllowsColumnSelection;
@end

#endif
