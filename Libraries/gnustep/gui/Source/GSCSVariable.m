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

#import "GSCSVariable.h"

@implementation GSCSVariable

- (instancetype) initWithName: (NSString *)name
{
  self = [super init];
  if (self != nil)
    {
      ASSIGN(_name, name);
      _type = GSCSVaraibleTypeVariable;
    }

  return self;
}

- (instancetype) initWithName: (NSString *)name type: (GSCSVariableType)type
{
  self = [super init];
  if (self != nil)
    {
      ASSIGN(_name, name);
      _type = type;
    }

  return self;
}

- (instancetype) init
{
  return [self initWithName: nil type: GSCSVaraibleTypeVariable];
}

+ (instancetype) dummyVariableWithName: (NSString *)name
{
  return AUTORELEASE([[GSCSVariable alloc] initWithName: name type: GSCSVariableTypeDummy]);
}

+ (instancetype) slackVariableWithName: (NSString *)name
{
  return AUTORELEASE([[GSCSVariable alloc] initWithName: name type: GSCSVariableTypeSlack]);
}

+ (instancetype) objectiveVariableWithName: (NSString *)name
{
  return AUTORELEASE([[GSCSVariable alloc] initWithName: name
                                       type: GSCSVariableTypeObjective]);
}

+ (instancetype) variableWithValue: (CGFloat)value
{
  return [self variableWithValue: value name: nil];
}

+ (instancetype) variable
{
  return [self variableWithValue: 0 name: nil];
}

+ (instancetype) variableWithValue: (CGFloat)value name: (NSString *)name
{
  GSCSVariable *variable =
      [[GSCSVariable alloc] initWithName: name type: GSCSVariableTypeExternal];
  [variable setValue: value];
  return AUTORELEASE(variable);
}

- (BOOL) isDummy
{
  return _type == GSCSVariableTypeDummy;
}

- (BOOL) isExternal
{
  return _type == GSCSVariableTypeExternal;
}

- (BOOL) isPivotable
{
  return _type == GSCSVariableTypeSlack;
}

- (BOOL) isRestricted
{
  return _type == GSCSVariableTypeExternal || _type == GSCSVariableTypeSlack;
}

- (NSString *) description
{
  if (_type == GSCSVariableTypeDummy)
    {
      return [NSString stringWithFormat: @"[%@:dummy]", _name];
    }
  else if (_type == GSCSVariableTypeSlack)
    {
      return [NSString stringWithFormat: @"[%@:slack]", _name];
    }
  else if (_type == GSCSVariableTypeExternal)
    {
      return [NSString stringWithFormat: @"[%@:%.02f]", _name, _value];
    }
  else if (_type == GSCSVariableTypeObjective)
    {
      return [NSString stringWithFormat: @"[%@:objective]", _name];
    }

  return [NSString stringWithFormat: @"[%@]", _name];
}

- (GSCSVariableType) type
{
  return _type;
}

- (NSUInteger) id
{
  return _id;
}

- (CGFloat) value
{
  return _value;
}

- (void) setValue: (CGFloat)value
{
  _value = value;
}

- (NSString *) name
{
  return _name;
}

- (void) dealloc
{
  TEST_RELEASE(_name);
  [super dealloc];
}

@end