/* Copyright (C) 2023 Free Software Foundation, Inc.

   By: Benjamin Johnson
   Date: 12-6-2023
   This file is part of the GNUstep Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110 USA.
*/

#import "GSCSEditVariableManager.h"
#import "GSFastEnumeration.h"

@implementation GSCSEditVariableManager

- (instancetype) init
{
  self = [super init];
  if (self)
    {
      ASSIGN(_editVariablesList, [NSMutableArray array]);
      ASSIGN(_editVariablesStack, [NSMutableArray array]);
      ASSIGN(_editVariablesMap,
             [NSMapTable mapTableWithKeyOptions: NSMapTableStrongMemory
                                   valueOptions: NSMapTableStrongMemory]);
      [self pushEditVariableCount];
    }
  return self;
}

- (BOOL) isEmpty
{
  return [_editVariablesList count] == 0;
}

- (NSArray *) editInfos
{
  return _editVariablesList;
}

- (NSInteger) editVariableStackCount
{
  return [_editVariablesStack count];
}

- (NSInteger) topEditVariableStack
{
  return [[_editVariablesStack lastObject] integerValue];
}

- (void) pushEditVariableCount
{
  [_editVariablesStack
    addObject: [NSNumber numberWithInteger: [_editVariablesList count]]];
}

- (void) popEditVariableStack
{
  [_editVariablesStack removeLastObject];
}

- (void) addEditInfo: (GSCSEditInfo *)editInfo
{
  [_editVariablesMap setObject: editInfo forKey: [editInfo variable]];
  [_editVariablesList addObject: editInfo];
}

- (void) removeEditInfo: (GSCSEditInfo *)editInfo
{
  [_editVariablesList removeObject: editInfo];
}

- (void) removeEditInfoForConstraint: (GSCSConstraint *)constraint
{
  GSCSEditInfo *editInfo = [self editInfoForConstraint: constraint];
  [self removeEditInfo: editInfo];
}

- (GSCSEditInfo *) editInfoForConstraint: (GSCSConstraint *)constraint
{
  FOR_IN(GSCSEditInfo *, editInfo, _editVariablesList)
    if ([editInfo constraint] == constraint)
      {
        return editInfo;
      }
  END_FOR_IN(_editVariablesList);

  return nil;
}

- (NSArray *) editInfosForVariable: (GSCSVariable *)editVariable
{
  NSMutableArray *editInfos = [NSMutableArray array];
  FOR_IN(GSCSEditInfo *, editInfo, _editVariablesList)
    if ([editInfo variable] == editVariable)
      {
        [editInfos addObject: editInfo];
      }
  END_FOR_IN(_editVariablesList);

  return editInfos;
}

- (NSArray *) getNextSet
{
  [_editVariablesStack removeLastObject];
  NSInteger index = [self topEditVariableStack];
  NSInteger count = [_editVariablesList count];
  NSMutableArray *editableInfosInDescendingOrder = [NSMutableArray array];
  while (count > index)
    {
      GSCSEditInfo *editInfo = [[self editInfos] objectAtIndex: count - 1];
      [editableInfosInDescendingOrder addObject: editInfo];
      count--;
    }

  return editableInfosInDescendingOrder;
}

- (void) dealloc
{
  RELEASE(_editVariablesList);
  RELEASE(_editVariablesStack);
  RELEASE(_editVariablesMap);

  [super dealloc];
}

@end
