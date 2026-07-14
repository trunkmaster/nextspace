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

#import "GSCSLinearExpression.h"
#import "GSCSFloatComparator.h"
#import "GSCSVariable.h"
#import "GSFastEnumeration.h"

@implementation GSCSLinearExpression

- (instancetype) init
{
  self = [super init];
  if (self)
    {
      ASSIGN(_terms, [NSMapTable strongToStrongObjectsMapTable]);
      ASSIGN(_termVariables, [NSMutableArray array]);
      _constant = 0;
    }
  return self;
}

- (instancetype) initWithVariable: (GSCSVariable *)variable
{
  self = [self init];
  if (self)
    {
      [self addVariable: variable coefficient: 1.0];
    }

  return self;
}

- (instancetype) initWithVariables: (NSArray *)variables
{
  self = [self init];
  if (self)
    {
      FOR_IN(GSCSVariable *, variable, variables)
        [self addVariable: variable coefficient: 1.0];
      END_FOR_IN(variables)
    }

  return self;
}

- (instancetype) initWithConstant: (CGFloat)constant
{
  self = [self init];
  if (self)
    {
      _constant = constant;
    }

  return self;
}

- (instancetype) initWithVariable: (GSCSVariable *)variable
                      coefficient: (CGFloat)coefficient
                         constant: (CGFloat)constant
{
  self = [self init];
  if (self)
    {
      [self addVariable: variable coefficient: coefficient];
      _constant = constant;
    }
  return self;
}

- (CGFloat) constant
{
  return _constant;
}

- (void) setConstant: (CGFloat)constant
{
  _constant = constant;
}

- (NSMapTable *) terms
{
  return _terms;
}

- (NSArray *) termVariables
{
  return _termVariables;
}

- (void) removeVariable: (GSCSVariable *)variable
{
  [_terms removeObjectForKey: variable];
  [_termVariables removeObject: variable];
}

- (NSNumber *) multiplierForTerm: (GSCSVariable *)variable
{
  return [_terms objectForKey: variable];
}

- (CGFloat) newSubject: (GSCSVariable *)subject
{
  CGFloat reciprocal = 1.0 / [self coefficientForTerm: subject];

  [self multiplyConstantAndTermsBy: -reciprocal];

  [self removeVariable: subject];
  return reciprocal;
}

- (void) multiplyConstantAndTermsBy: (CGFloat)value
{
  _constant = _constant * value;

  NSMutableArray *keys = [NSMutableArray arrayWithCapacity: [_terms count]];
  FOR_IN(GSCSVariable *, term, _terms)
    [keys addObject: term];
  END_FOR_IN(_terms)

  FOR_IN(GSCSVariable *, term, keys)
    NSNumber *termCoefficent = [_terms objectForKey: term];
    CGFloat multipliedTermCoefficent = [termCoefficent doubleValue] * value;
    [_terms setObject: [NSNumber numberWithDouble: multipliedTermCoefficent]
               forKey: term];
  END_FOR_IN(keys)
}

- (void) divideConstantAndTermsBy: (CGFloat)value
{
  [self multiplyConstantAndTermsBy: 1 / value];
}

- (CGFloat) coefficientForTerm: (GSCSVariable *)variable
{
  return [[self multiplierForTerm: variable] floatValue];
}

- (void) normalize
{
  [self multiplyConstantAndTermsBy: -1];
}

- (id) copyWithZone: (NSZone *)zone
{
  GSCSLinearExpression *expression = [[[self class] allocWithZone: zone] init];
  if (expression)
    {
      [expression setConstant: [self constant]];
      FOR_IN(GSCSVariable *, variable, _termVariables)
        [expression addVariable: variable
                    coefficient: [self coefficientForTerm: variable]];
      END_FOR_IN(_termVariables)
    }

  return expression;
}

- (NSArray *) findPivotableVariablesWithMostNegativeCoefficient
{
  CGFloat mostNegativeCoefficient = 0;
  FOR_IN(GSCSVariable *, term, _termVariables)
    CGFloat coefficientForTerm = [self coefficientForTerm: term];
    if ([term isPivotable] && coefficientForTerm < mostNegativeCoefficient)
      {
        mostNegativeCoefficient = coefficientForTerm;
      }
  END_FOR_IN(_termVariables)

  NSMutableArray *candidates = [NSMutableArray array];
  FOR_IN(GSCSVariable *, term, _termVariables)
    CGFloat coefficientForTerm = [self coefficientForTerm: term];
    if ([term isPivotable] &&
        [GSCSFloatComparator isApproxiatelyEqual: coefficientForTerm
                                               b: mostNegativeCoefficient])
      {
        [candidates addObject: term];
      }
  END_FOR_IN(_termVariables)

  return candidates;
}

- (BOOL) isConstant
{
  return [_terms count] == 0;
}

- (BOOL) isTermForVariable: (GSCSVariable *)variable
{
  return [_terms objectForKey: variable] != nil;
}

- (GSCSVariable *) anyPivotableVariable
{
  if ([self isConstant])
    {
      [[NSException exceptionWithName: NSInternalInconsistencyException
                               reason: @"anyPivotableVariable invoked on a "
                                       @"constant expression"
                             userInfo: nil] raise];
    }

  FOR_IN(GSCSVariable *, variable, _termVariables)
    if ([variable isPivotable])
      {
        return variable;
      }
  END_FOR_IN(_termVariables)

  return nil;
}

- (BOOL) containsOnlyDummyVariables
{
  FOR_IN(GSCSVariable *, term, _termVariables)
    if (![term isDummy])
      {
        return NO;
      }
  END_FOR_IN(_termVariables)

  return YES;
}

- (NSArray *) externalVariables
{
  NSMutableArray *externalVariables = [NSMutableArray array];
  FOR_IN(GSCSVariable *, variable, _terms)
    if ([variable isExternal])
      {
        [externalVariables addObject: variable];
      }
  END_FOR_IN(_terms)

  return externalVariables;
}

- (void) addVariable: (GSCSVariable *)variable
{
  [self addVariable: variable coefficient: 1];
}

- (void) addVariable: (GSCSVariable *)variable
         coefficient: (CGFloat)coefficient;
{
  if (![GSCSFloatComparator isApproxiatelyZero: coefficient])
    {
      if ([self isTermForVariable: variable])
        {
          [_termVariables removeObject: variable];
        }
      [_terms setObject: [NSNumber numberWithFloat: coefficient]
                 forKey: variable];
      [_termVariables addObject: variable];
    }
}

- (NSString *) description
{
  NSString *descriptionString = [NSString stringWithFormat:@"%f", _constant];
  FOR_IN(GSCSVariable *, term, _termVariables)
    descriptionString = [descriptionString
        stringByAppendingString:
            [NSString stringWithFormat: @" + %f * %@",
                                       [self coefficientForTerm: term],
                                       [term description]]];
  END_FOR_IN(_termVariables)

  return descriptionString;
}

- (void) addExpression: (GSCSLinearExpression *)expression
{
  [self addExpression: expression multiplier: 1];
}

- (void) addExpression: (GSCSLinearExpression *)expression
            multiplier: (CGFloat)multiplier
{
  [self setConstant: [self constant] + [expression constant] * multiplier];
  NSArray *termVariables = [expression termVariables];
  FOR_IN(GSCSVariable *, term, termVariables)
    CGFloat termCoefficient =
        [expression coefficientForTerm: term] * multiplier;
    [self addVariable: term coefficient: termCoefficient];
  END_FOR_IN(termVariables)
}

- (void) dealloc
{
  RELEASE(_terms);
  RELEASE(_termVariables);

  [super dealloc];
}

@end
