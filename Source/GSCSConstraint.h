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

#import "GSCSConstraintOperator.h"
#import "GSCSLinearExpression.h"
#import "GSCSStrength.h"
#import "GSCSVariable.h"
#import <Foundation/Foundation.h>

#ifndef _GS_CS_CONSTRAINT_H
#define _GS_CS_CONSTRAINT_H

enum GSCSConstraintType
{
  GSCSConstraintTypeEdit,
  GSCSConstraintTypeStay,
  GSCSConstraintTypeLinear,
  GSCSConstraintTypeLinearInequity
};
typedef enum GSCSConstraintType GSCSConstraintType;

@interface GSCSConstraint : NSObject
{
  GSCSConstraintType _type;
  GSCSStrength *_strength;
  GSCSLinearExpression *_expression;
  GSCSVariable *_variable;
}

#if GS_HAS_DECLARED_PROPERTIES
@property (nonatomic, assign) GSCSStrength *strength;
#else
- (GSCSStrength *) strength;
- (void) setStrength: (GSCSStrength *)strength;
#endif

- (instancetype) initWithType: (GSCSConstraintType)type
                     strength: (GSCSStrength *)strength
                   expression: (GSCSLinearExpression *)expression
                     variable: (GSCSVariable *)variable;

- (instancetype) initLinearConstraintWithExpression:
    (GSCSLinearExpression *)expression;

- (instancetype) initLinearInequityConstraintWithExpression:
    (GSCSLinearExpression *)expression;

- (instancetype) initLinearConstraintWithExpression:
                     (GSCSLinearExpression *)expression
                                           strength: (GSCSStrength *)strength
                                           variable: (GSCSVariable *)variable;

- (instancetype) initEditConstraintWithVariable: (GSCSVariable *)variable
                                        strength: (GSCSStrength *)strength;

- (instancetype) initStayConstraintWithVariable: (GSCSVariable *)variable
                                       strength: (GSCSStrength *)strength;

- (instancetype) initWithLhsVariable: (GSCSVariable *)lhs
                      equalsConstant: (CGFloat)rhs;

- (instancetype) initWithLhsVariable: (GSCSVariable *)lhs
                   equalsRhsVariable: (GSCSVariable *)rhs;

+ (GSCSConstraint *) constraintWithLeftVariable: (GSCSVariable *)lhs
operator: (GSCSConstraintOperator) operator
                                  rightVariable: (GSCSVariable *)rhsVariable;

+ (GSCSConstraint *) constraintWithLeftVariable: (GSCSVariable *)lhs
operator: (GSCSConstraintOperator) operator
                                  rightConstant: (CGFloat)rhs;

+ (GSCSConstraint *) constraintWithLeftVariable: (GSCSVariable *)lhs
operator: (GSCSConstraintOperator) operator
                                rightExpression: (GSCSLinearExpression *)rhs;

+ (GSCSConstraint *) constraintWithLeftConstant: (CGFloat)lhs
operator: (GSCSConstraintOperator) operator
                                  rightVariable: (GSCSVariable *)rhs;

+ (GSCSConstraint *) constraintWithLeftExpression: (GSCSLinearExpression *)lhs
operator: (GSCSConstraintOperator) operator
                                    rightVariable: (GSCSVariable *)rhs;

+ (GSCSConstraint *) constraintWithLeftExpression: (GSCSLinearExpression *)lhs
operator: (GSCSConstraintOperator) operator
                                  rightExpression: (GSCSLinearExpression *)rhs;

+ (GSCSConstraint *) constraintWithLeftExpression: (GSCSLinearExpression *)lhs
operator: (GSCSConstraintOperator) operator
                                    rightConstant: (CGFloat)rhs;

+ (instancetype) editConstraintWithVariable: (GSCSVariable *)variable;

- (BOOL) isRequired;

- (BOOL) isEditConstraint;

- (BOOL) isStayConstraint;

- (BOOL) isInequality;

- (GSCSLinearExpression *) expression;

- (GSCSConstraintType) type;

- (GSCSVariable *) variable;

@end

#endif
