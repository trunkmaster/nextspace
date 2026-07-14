/* Copyright (C) 2023 Free Software Foundation, Inc.

   By: Benjamin Johnson
   Date: 19-3-2023
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

#import <Foundation/Foundation.h>

#ifndef _GS_CS_VARIABLE_H
#define _GS_CS_VARIABLE_H

enum GSCSVariableType
{
  GSCSVariableTypeDummy,
  GSCSVariableTypeSlack,
  GSCSVaraibleTypeVariable,
  GSCSVariableTypeObjective,
  GSCSVariableTypeExternal
};
typedef enum GSCSVariableType GSCSVariableType;

@interface GSCSVariable : NSObject
{
  GSCSVariableType _type;
  NSUInteger _id;
  CGFloat _value;
  NSString *_name;
}

- (GSCSVariableType) type;

- (NSUInteger) id;

- (CGFloat) value;

- (void) setValue: (CGFloat)value;

- (NSString *) name;

- (BOOL) isExternal;

- (BOOL) isDummy;

- (BOOL) isPivotable;

- (BOOL) isRestricted;

- (instancetype) initWithName: (NSString *)name;

+ (instancetype) variable;

+ (instancetype) variableWithValue: (CGFloat)value;

+ (instancetype) variableWithValue: (CGFloat)value name: (NSString *)name;

+ (instancetype) dummyVariableWithName: (NSString*)name;

+ (instancetype) slackVariableWithName: (NSString*)name;

+ (instancetype) objectiveVariableWithName: (NSString*)name;

@end

#endif
