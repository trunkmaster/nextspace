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

#import "GSCSEditInfo.h"
#import <Foundation/Foundation.h>

#ifndef _GS_CS_EDIT_VARIABLE_MANAGER_H
#define _GS_CS_EDIT_VARIABLE_MANAGER_H

@interface GSCSEditVariableManager : NSObject
{
  NSMutableArray *_editVariablesList;
  NSMutableArray *_editVariablesStack;
  NSMapTable *_editVariablesMap;
}

- (NSArray *) editInfos;

- (BOOL) isEmpty;

- (void) addEditInfo: (GSCSEditInfo *)editInfo;

- (void) removeEditInfo: (GSCSEditInfo *)editInfo;

- (GSCSEditInfo *) editInfoForConstraint: (GSCSConstraint *)constraint;

- (NSArray *) editInfosForVariable: (GSCSVariable *)editVariable;

- (void) removeEditInfoForConstraint: (GSCSConstraint *)constraint;

- (void) pushEditVariableCount;

- (NSInteger) topEditVariableStack;

- (NSInteger) editVariableStackCount;

- (NSArray *) getNextSet;

@end

#endif
