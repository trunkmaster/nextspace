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
#import <Foundation/Foundation.h>

#ifndef _GS_CS_LINEAR_EXPRESSION_H
#define _GS_CS_LINEAR_EXPRESSION_H

@interface GSCSLinearExpression : NSObject <NSCopying>
{
  NSMapTable *_terms;
  CGFloat _constant;
  NSMutableArray *_termVariables;
}

- (instancetype) initWithConstant: (CGFloat)constant;

- (instancetype) initWithVariable: (GSCSVariable *)variable;

- (instancetype) initWithVariable: (GSCSVariable *)variable
                      coefficient: (CGFloat)value
                         constant: (CGFloat)constant;

- (instancetype) initWithVariables: (NSArray *)variables;

- (CGFloat) constant;

- (void) setConstant: (CGFloat)constant;

- (NSMapTable *) terms;

- (NSArray *) termVariables;

- (NSNumber *) multiplierForTerm: (GSCSVariable *)variable;

- (void) removeVariable: (GSCSVariable *)variable;

- (void) multiplyConstantAndTermsBy: (CGFloat)value;

- (void) divideConstantAndTermsBy: (CGFloat)value;

- (CGFloat) coefficientForTerm: (GSCSVariable *)variable;

- (CGFloat) newSubject: (GSCSVariable *)subject;

- (void) addVariable: (GSCSVariable *)variable;

- (void) addVariable: (GSCSVariable *)variable
         coefficient: (CGFloat)coefficient;

- (void) addExpression: (GSCSLinearExpression *)expression;

- (void) addExpression: (GSCSLinearExpression *)expression
            multiplier: (CGFloat)multiplier;

- (NSArray *) findPivotableVariablesWithMostNegativeCoefficient;

- (void) normalize;

- (BOOL) isConstant;

- (BOOL) isTermForVariable: (GSCSVariable *)variable;

- (GSCSVariable *) anyPivotableVariable;

- (NSArray *) externalVariables;

- (BOOL) containsOnlyDummyVariables;

@end

#endif //_GS_CS_LINEAR_EXPRESSION_H