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

@implementation GSCSEditInfo

- (instancetype) initWithVariable: (GSCSVariable *)variable
                       constraint: (GSCSConstraint *)constraint
                     plusVariable: (GSCSVariable *)plusVariable
                    minusVariable: (GSCSVariable *)minusVariable
                 previousConstant: (NSInteger)previousConstant
{
  self = [super init];
  if (self != nil)
    {
      _variable = variable;
      _plusVariable = plusVariable;
      _minusVariable = minusVariable;
      _constraint = constraint;
      _previousConstant = previousConstant;
    }

  return self;
}

- (GSCSConstraint*) constraint
{
  return _constraint;
}

- (GSCSVariable*) variable
{
  return _variable;
}

- (void) dealloc
{
  RELEASE(_variable);
  RELEASE(_plusVariable);
  RELEASE(_minusVariable);
  RELEASE(_constraint);

  [super dealloc];
}

@end
