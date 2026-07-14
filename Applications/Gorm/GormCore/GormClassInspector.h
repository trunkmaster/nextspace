/** <title>GormClassInspector</title>

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

/* All Rights reserved */

#include <AppKit/AppKit.h>

#include <InterfaceBuilder/InterfaceBuilder.h>

@class GormClassManager;

@interface GormClassInspector : IBInspector
{
  // outlets
  id _actionTable; 
  id _addAction;
  id _addOutlet;
  id _classField;
  id _outletTable;
  id _parentClass;
  id _removeAction;
  id _removeOutlet;
  id _selectClass;
  id _search;
  id _searchText;
  id _tabView;

  // internal vars
  NSString *_currentClass;
  id _theobject;
  id _actionData;
  id _outletData;
  id _parentClassData;

  // class manager..
  GormClassManager *_classManager;
}
- (void) addAction: (id)sender;
- (void) removeAction: (id)sender;
- (void) addOutlet: (id)sender;
- (void) removeOutlet: (id)sender;
- (void) select: (id)sender;
- (void) searchForClass: (id)sender;
- (void) selectClass: (id)sender;
- (NSString *) _currentClass;
- (void) _refreshView;
- (void) handleNotification: (NSNotification *)notification;
- (void) changeClassName: (id)sender;
- (void) selectAction: (id)sender;
- (void) selectOutlet: (id)sender;
@end
