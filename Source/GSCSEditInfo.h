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

#import "GSCSConstraint.h"
#import "GSCSVariable.h"
#import <Foundation/Foundation.h>

#ifndef _GS_CS_EDIT_INFO_H
#define _GS_CS_EDIT_INFO_H

@interface GSCSEditInfo : NSObject
{
  GSCSConstraint *_constraint;
  GSCSVariable *_variable;
  GSCSVariable *_plusVariable;
  GSCSVariable *_minusVariable;
  NSInteger _previousConstant;
}

#if GS_HAS_DECLARED_PROPERTIES
@property (nonatomic, readonly) GSCSConstraint *constraint;
#else
- (GSCSConstraint *) constraint;
#endif

#if GS_HAS_DECLARED_PROPERTIES
@property (nonatomic, readonly) GSCSVariable *variable;
#else
- (GSCSVariable *) variable;
#endif

- (instancetype) initWithVariable: (GSCSVariable *)variable
                       constraint: (GSCSConstraint *)constraint
                     plusVariable: (GSCSVariable *)plusVariable
                    minusVariable: (GSCSVariable *)minusVariable
                 previousConstant: (NSInteger)previousConstant;

@end

#endif
