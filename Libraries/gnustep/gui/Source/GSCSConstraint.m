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

#import "GSCSConstraint.h"
#import "GSCSFloatComparator.h"
#import "GSCSVariable.h"

@implementation GSCSConstraint

- (instancetype) init
{
  return [self initWithType: GSCSConstraintTypeLinear
                   strength: nil
                 expression: nil
                   variable: nil];
}

- (instancetype) initWithType: (GSCSConstraintType)type
                     strength: (GSCSStrength *)strength
                   expression: (GSCSLinearExpression *)expression
                     variable: (GSCSVariable *)variable
{
  self = [super init];
  if (self)
    {
      ASSIGN(_strength, strength != nil ? [strength copy]
                                        : [GSCSStrength strengthRequired]);
      ASSIGN(_expression, expression);
      ASSIGN(_variable, variable);
      _type = type;
    }
  return self;
}

- (instancetype) initLinearConstraintWithExpression:
                     (GSCSLinearExpression *)expression
                                           strength: (GSCSStrength *)strength
                                           variable: (GSCSVariable *)variable
{
  return [self initWithType: GSCSConstraintTypeLinear
                   strength: strength
                 expression: expression
                   variable: variable];
}

- (instancetype) initLinearConstraintWithExpression:
    (GSCSLinearExpression *)expression
{
  return
      [self initLinearConstraintWithExpression: expression
                                      strength: [GSCSStrength strengthRequired]
                                      variable: nil];
}

- (instancetype) initLinearInequityConstraintWithExpression:
    (GSCSLinearExpression *)expression
{
  return
      [self initWithType: GSCSConstraintTypeLinearInequity
                strength: [GSCSStrength strengthRequired]
              expression: expression
                variable: nil];
}

- (instancetype) initEditConstraintWithVariable: (GSCSVariable *)variable
                                        strength: (GSCSStrength *)strength
{
  GSCSLinearExpression *expression =
      [[GSCSLinearExpression alloc] initWithVariable: variable
                                         coefficient: -1
                                            constant: [variable value]];
  GSCSConstraint *constraint = [self initWithType: GSCSConstraintTypeEdit
                   strength: strength
                 expression: expression
                   variable: variable];
  RELEASE(expression);
  return constraint;
}

- (instancetype) initStayConstraintWithVariable: (GSCSVariable *)variable
                                       strength: (GSCSStrength *)strength
{
  GSCSLinearExpression *expression =
      [[GSCSLinearExpression alloc] initWithVariable: variable
                                         coefficient: -1
                                            constant: [variable value]];
  GSCSConstraint *constraint = [[GSCSConstraint alloc] initWithType: GSCSConstraintTypeStay
                                     strength: strength
                                   expression: expression
                                     variable: variable];
  RELEASE(expression);
  return constraint;
}

- (instancetype) initWithLhsVariable: (GSCSVariable *)lhs
                   equalsRhsVariable: (GSCSVariable *)rhs
{
  GSCSLinearExpression *expression =
      [[GSCSLinearExpression alloc] initWithVariable: lhs];
  [expression addVariable: rhs coefficient: -1];
  GSCSConstraint *constraint = [self initLinearConstraintWithExpression: expression];
  RELEASE(expression);

  return constraint;
}

- (instancetype) initWithLhsVariable: (GSCSVariable *)lhs
                      equalsConstant: (CGFloat)rhs
{
  GSCSLinearExpression *expression =
      [[GSCSLinearExpression alloc] initWithVariable: lhs
                                         coefficient: 1
                                            constant: -rhs];
  GSCSConstraint *constraint = [self initLinearConstraintWithExpression: expression];
  RELEASE(expression);
  return constraint;
}

+ (GSCSConstraint *) constraintWithLeftVariable: (GSCSVariable *)lhs
operator: (GSCSConstraintOperator) operator
                                  rightVariable: (GSCSVariable *)rhs
{
  if (operator == GSCSConstraintOperatorEqual)
    {
      return AUTORELEASE([[GSCSConstraint alloc]
          initWithLhsVariable: lhs equalsRhsVariable: rhs]);
    }
  else
    {
      GSCSLinearExpression *rhsExpression =
          [[GSCSLinearExpression alloc] initWithVariable: rhs];
      if (operator == GSCSConstraintOperationGreaterThanOrEqual)
        {
          [rhsExpression multiplyConstantAndTermsBy: -1];
          [rhsExpression addVariable: lhs];
        }
      else if (operator == GSCSConstraintOperatorLessThanOrEqual)
        {
          [rhsExpression addVariable: lhs coefficient: -1];
        }
      
      RELEASE(rhsExpression);

      return AUTORELEASE([[GSCSConstraint alloc]
          initLinearInequityConstraintWithExpression: rhsExpression]);
    }
}

+ (GSCSConstraint *) constraintWithLeftVariable: (GSCSVariable *)lhs
operator: (GSCSConstraintOperator) operator
                                  rightConstant: (CGFloat)rhs
{
  GSCSLinearExpression *expression;
  GSCSConstraint *constraint;
  if (operator == GSCSConstraintOperatorEqual)
    {
      expression = [[GSCSLinearExpression alloc] init];
      [expression addVariable: lhs coefficient: 1];
      [expression setConstant: -rhs];

      constraint = [[GSCSConstraint alloc]
          initLinearConstraintWithExpression: expression
                                    strength: [GSCSStrength strengthRequired]
                                    variable: nil];
    }
  else
    {
      expression =
          [[GSCSLinearExpression alloc] initWithConstant: rhs];
      if (operator == GSCSConstraintOperationGreaterThanOrEqual)
        {
          [expression multiplyConstantAndTermsBy: -1];
          [expression addVariable: lhs coefficient: 1.0];
        }
      else if (operator == GSCSConstraintOperatorLessThanOrEqual)
        {
          [expression addVariable: lhs coefficient: -1.0];
        }

      constraint = [[GSCSConstraint alloc]
          initLinearInequityConstraintWithExpression: expression];
    }

  RELEASE(expression);
  return AUTORELEASE(constraint);
}

+ (GSCSConstraint *) constraintWithLeftVariable: (GSCSVariable *)lhs
operator: (GSCSConstraintOperator) operator
                                rightExpression: (GSCSLinearExpression *)rhs
{
  GSCSLinearExpression *lhsExpression =
      [[GSCSLinearExpression alloc] initWithVariable: lhs];
  GSCSConstraint *constraint = [self constraintWithLeftExpression: lhsExpression operator: operator rightExpression: rhs];
  RELEASE(lhsExpression);
  return constraint;
}

+ (GSCSConstraint *) constraintWithLeftConstant: (CGFloat)lhs
operator: (GSCSConstraintOperator) operator
                                  rightVariable: (GSCSVariable *)rhs
{
    GSCSLinearExpression *valueExpression =
        [[GSCSLinearExpression alloc] initWithConstant: lhs];

    GSCSConstraint *constraint = nil;
    if (operator == GSCSConstraintOperatorEqual)
      {
        [valueExpression addVariable: rhs coefficient: -1.0];
        constraint = [[GSCSConstraint alloc]
            initLinearConstraintWithExpression: valueExpression];
      }
    else
      {
        if (operator == GSCSConstraintOperationGreaterThanOrEqual)
          {
            [valueExpression addVariable: rhs coefficient: -1.0];
          }
        else if (operator == GSCSConstraintOperatorLessThanOrEqual)
          {
            [valueExpression multiplyConstantAndTermsBy: -1];
            [valueExpression addVariable: rhs coefficient: 1.0];
          }

        constraint = [[GSCSConstraint alloc]
            initLinearInequityConstraintWithExpression: valueExpression];
      }
    
    RELEASE(valueExpression);
    return constraint;
}

+ (GSCSConstraint *) constraintWithLeftExpression: (GSCSLinearExpression *)lhs
operator: (GSCSConstraintOperator) operator
                                    rightVariable: (GSCSVariable *)rhs
{
    GSCSLinearExpression *rhsExpression =
        [[GSCSLinearExpression alloc] initWithVariable: rhs];
    GSCSConstraint *constraint = [self constraintWithLeftExpression: lhs operator: operator rightExpression: rhsExpression];
    RELEASE(rhsExpression);
    return constraint;
}

+ (GSCSConstraint *) constraintWithLeftExpression: (GSCSLinearExpression *)lhs
operator: (GSCSConstraintOperator) operator
                                  rightExpression: (GSCSLinearExpression *)rhs
{
    GSCSLinearExpression *expression = [rhs copy];
    GSCSConstraint *constraint;
    if (operator == GSCSConstraintOperatorEqual)
      {
        [expression addExpression: lhs multiplier: -1];
        constraint = [[GSCSConstraint alloc]
            initLinearConstraintWithExpression: expression];
      }
    else
      {
        if (operator == GSCSConstraintOperationGreaterThanOrEqual)
          {
            [expression multiplyConstantAndTermsBy: -1];
            [expression addExpression: lhs];
          }
        else if (operator == GSCSConstraintOperatorLessThanOrEqual)
          {
            [expression addExpression: lhs multiplier: -1];
          }

        constraint = [[GSCSConstraint alloc]
            initLinearInequityConstraintWithExpression: expression];
      }
    
    RELEASE(expression);
    return AUTORELEASE(constraint);
}

+ (GSCSConstraint *) constraintWithLeftExpression: (GSCSLinearExpression *)lhs
operator: (GSCSConstraintOperator) operator
                                    rightConstant: (CGFloat)rhs
{
    GSCSLinearExpression *rhsExpression =
        [[GSCSLinearExpression alloc] initWithConstant: rhs];
    GSCSConstraint *constraint = [self constraintWithLeftExpression: lhs operator: operator rightExpression: rhsExpression];
    RELEASE(rhsExpression);
    return constraint;
}

+ (instancetype) editConstraintWithVariable: (GSCSVariable *)variable
{
  return AUTORELEASE([[self alloc]
       initEditConstraintWithVariable: variable
                              strength: [GSCSStrength strengthStrong]]);
}

- (void) setStrength: (GSCSStrength *)strength
{
  ASSIGN(_strength, strength);
}

- (BOOL) isRequired
{
   return [_strength isRequired];
}

- (BOOL) isEditConstraint
{
   return _type == GSCSConstraintTypeEdit;
}

- (BOOL) isStayConstraint
{
   return _type == GSCSConstraintTypeStay;
}

- (BOOL) isInequality
{
   return _type == GSCSConstraintTypeLinearInequity;
}

- (GSCSLinearExpression *) expression
{
   return _expression;
}

- (GSCSVariable *) variable
{
   return _variable;
}

- (GSCSStrength *) strength
{
   return _strength;
}

- (GSCSConstraintType) type
{
   return _type;
}

- (void) dealloc
{
   RELEASE(_strength);
   RELEASE(_expression);
   RELEASE(_variable);

   [super dealloc];
}

@end