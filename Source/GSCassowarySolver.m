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

#import "GSCassowarySolver.h"

@implementation GSCassowarySolver

- (void) addConstraint: (GSCSConstraint*)constraint
{
  // FIXME Add constraint to solver
}

- (void) addConstraints: (NSArray*)constraints
{
  // FIXME Add constraints to solver
}

- (void) removeConstraint: (GSCSConstraint*)constraint
{
  // FIXME Remove constraint from solver
}

- (void) removeConstraints: (NSArray*)constraints
{
    // FIXME Remove constraints from solver
}

- (GSCSSolution*) solve
{
    // FIXME Return correct solution
    return [[GSCSSolution alloc] init];
}

- (void) suggestEditVariable: (GSCSVariable*)variable equals: (CGFloat)value
{
    // FIXME Suggest edit variable
}

@end