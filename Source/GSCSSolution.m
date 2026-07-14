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

#import "GSCSSolution.h"
#import "GSCSFloatComparator.h"
#import "GSFastEnumeration.h"

@implementation GSCSSolution

- (instancetype) init
{
  self = [super init];
  if (self)
    {
      ASSIGN(_resultsByVariable, [NSMapTable strongToStrongObjectsMapTable]);
    }
  return self;
}

- (void) setResult: (CGFloat)result forVariable: (GSCSVariable *)variable
{
  NSNumber *encodedResult = [NSNumber numberWithFloat: result];
  [_resultsByVariable setObject: encodedResult forKey: variable];
}

- (NSNumber *) resultForVariable: (GSCSVariable *)variable;
{
  return [_resultsByVariable objectForKey: variable];
}

- (NSArray *) variables
{
  NSMutableArray *variables = [NSMutableArray array];
  NSEnumerator *resultVariables = [_resultsByVariable keyEnumerator];
  FOR_IN(GSCSVariable *, variable, resultVariables)
    [variables addObject: variable];
  END_FOR_IN(resultVariables)

  return variables;
}

- (BOOL) solution: (GSCSSolution *)solution
    hasEqualResultForVariable: (GSCSVariable *)variable
{
  NSNumber *lhsResult = [self resultForVariable: variable];
  NSNumber *rhsResult = [solution resultForVariable: variable];

  BOOL hasResultForBoth = lhsResult != nil && rhsResult != nil;
  if (!hasResultForBoth)
    {
      return NO;
    }

  return [GSCSFloatComparator isApproxiatelyEqual: [lhsResult floatValue]
                                                b: [rhsResult floatValue]];
}

- (BOOL) isEqualToCassowarySolverSolution: (GSCSSolution *)solution
{
  if ([[self variables] count] != [[solution variables] count])
    {
      return NO;
    }

  NSArray *variables = [self variables];
  FOR_IN(GSCSVariable *, variable, variables)
    if (![self solution: solution hasEqualResultForVariable: variable])
      {
        return NO;
      }
  END_FOR_IN(variables)

  return YES;
}

- (void) dealloc
{
  RELEASE(_resultsByVariable);
  [super dealloc];
}

@end