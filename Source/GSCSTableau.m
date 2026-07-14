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

#import "GSCSTableau.h"
#import "GSCSFloatComparator.h"
#import "GSFastEnumeration.h"

@interface GSCSTableau (PrivateMethods)

- (void) recordUpdatedVariable: (GSCSVariable *)variable;

- (void) addTermVariablesForExpression: (GSCSLinearExpression *)expression
                              variable: (GSCSVariable *)variable;

- (void) substituteOutTermInExpression: (GSCSLinearExpression *)expression
                    newExpression:
                      (GSCSLinearExpression *)newExpression
                          subject: (GSCSVariable *)subject
                            term: (GSCSVariable *)term
                      multiplier: (CGFloat)multiplier;

- (CGFloat) calculateNewCoefficent: (CGFloat)coefficentInExistingExpression
         coefficentInNewExpression: (CGFloat)coefficentInNewExpression
                        multiplier: (CGFloat)multiplier;

- (void) removeColumnVariable: (GSCSVariable *)variable
                      subject: (GSCSVariable *)subject;

- (void) recordUpdatedVariable: (GSCSVariable *)variable;

- (void) addNewExpression: (GSCSLinearExpression *)newExpression
             toExpression: (GSCSLinearExpression *)existingExpression
                        n: (CGFloat)n
                  subject: (GSCSVariable *)subject;

- (NSString *) columnsDescription;

- (NSString *) rowsDescription;

@end

@implementation GSCSTableau

- (instancetype) init
{
  self = [super init];
  if (self != nil)
    {
      ASSIGN(_rows,
             [NSMapTable mapTableWithKeyOptions: NSMapTableStrongMemory
                                   valueOptions: NSMapTableStrongMemory]);

      ASSIGN(_columns,
             [NSMapTable mapTableWithKeyOptions: NSMapTableStrongMemory
                                   valueOptions: NSMapTableStrongMemory]);

      ASSIGN(_externalParametricVariables, [NSMutableSet set]);

      ASSIGN(_externalRows,
             [NSMapTable mapTableWithKeyOptions: NSMapTableStrongMemory
                                   valueOptions: NSMapTableStrongMemory]);

      ASSIGN(_infeasibleRows, [NSMutableArray array]);

      ASSIGN(_objective, [GSCSVariable objectiveVariableWithName: @"Z"]);

      GSCSLinearExpression *expression = [[GSCSLinearExpression alloc] init];
      [self addRowForVariable: _objective equalsExpression: expression];
    }
  return self;
}

- (GSCSVariable *) objective
{
  return _objective;
}

- (void) setObjective: (GSCSVariable *)objective
{
  ASSIGN(_objective, objective);
}

- (NSMapTable *) externalRows
{
  return _externalRows;
}

- (void) setExternalRows: (NSMapTable *)externalRows
{
  ASSIGN(_externalRows, externalRows);
}

- (NSMutableArray *) infeasibleRows
{
  return _infeasibleRows;
}

- (void) setInfeasibleRows: (NSMutableArray *)infeasibleRows
{
  ASSIGN(_infeasibleRows, infeasibleRows);
}

- (BOOL) shouldPreferPivotableVariable: (GSCSVariable *)lhs
                 overPivotableVariable: (GSCSVariable *)rhs
{
  return [lhs id] < [rhs id];
}

- (BOOL) hasColumnForVariable: (GSCSVariable *)variable
{
  return [_columns objectForKey: variable] != nil;
}

- (NSSet *) columnForVariable: (GSCSVariable *)variable
{
  return [_columns objectForKey: variable];
}

// Add v=expr to the tableau, update column cross indices
// v becomes a basic variable
- (void) addRowForVariable: (GSCSVariable *)variable
          equalsExpression: (GSCSLinearExpression *)expression
{
  [_rows setObject: expression forKey: variable];
  if ([variable isExternal])
    {
      [_externalRows setObject: expression forKey: variable];
    }
  [self addTermVariablesForExpression: expression variable: variable];
}

- (void) addTermVariablesForExpression: (GSCSLinearExpression *)expression
                              variable: (GSCSVariable *)variable
{
  NSArray *termVariables = [expression termVariables];
  FOR_IN(GSCSVariable *, expressionTermVariable, termVariables)
    [self addMappingFromExpressionVariable: expressionTermVariable
                             toRowVariable: variable];
    if ([expressionTermVariable isExternal])
      {
        [_externalParametricVariables addObject: expressionTermVariable];
      }
  END_FOR_IN(termVariables);
}

- (void) addMappingFromExpressionVariable: (GSCSVariable *)columnVariable
                            toRowVariable: (GSCSVariable *)rowVariable
{
  NSMutableSet *columnSet = [_columns objectForKey: columnVariable];
  if (columnSet == nil)
    {
      columnSet = [NSMutableSet set];
      [_columns setObject: columnSet forKey: columnVariable];
    }
  [columnSet addObject: rowVariable];
}

- (void) removeMappingFromExpressionVariable: (GSCSVariable *)columnVariable
                               toRowVariable: (GSCSVariable *)rowVariable
{
  NSMutableSet *columnSet = [_columns objectForKey: columnVariable];
  if (columnSet == nil)
    {
      return;
    }
  [columnSet removeObject: rowVariable];
}

- (void) removeColumn: (GSCSVariable *)variable
{
  NSSet *crows = [_columns objectForKey: variable];
  if (_rows != nil)
    {
      FOR_IN(GSCSVariable *, clv, crows)
        GSCSLinearExpression *expression = [_rows objectForKey: clv];
        [expression removeVariable: variable];
      END_FOR_IN(crows);
      [_columns removeObjectForKey: variable];
    }

  if ([variable isExternal])
    {
      [_externalRows removeObjectForKey: variable];
    }
}

- (void) removeRowForVariable: (GSCSVariable *)variable
{
  GSCSLinearExpression *expression = [_rows objectForKey: variable];
  if (expression == nil)
    {
      NSException *missingExpressionException = [NSException
        exceptionWithName: NSInvalidArgumentException
                   reason: @"No expression exists for the provided variable"
                 userInfo: nil];
      [missingExpressionException raise];
    }
  [_rows removeObjectForKey: variable];
  if ([variable isExternal])
    {
      [_externalRows removeObjectForKey: variable];
    }
  NSArray *expressionTermVariables = [expression termVariables];
  FOR_IN(GSCSVariable *, expressionTermVariable, expressionTermVariables)
    [self removeMappingFromExpressionVariable: expressionTermVariable
                                toRowVariable: variable];
  END_FOR_IN(expressionTermVariables);
}

- (BOOL) hasRowForVariable: (GSCSVariable *)variable
{
  return [_rows objectForKey: variable] != nil;
}

- (void) substituteOutVariable: (GSCSVariable *)variable
                 forExpression: (GSCSLinearExpression *)expression
{
  NSSet *variableSet = [[_columns objectForKey: variable] copy];
  FOR_IN(GSCSVariable *, columnVariable, variableSet)
    GSCSLinearExpression *row = [_rows objectForKey: columnVariable];
    [self substituteOutTerm: variable
             withExpression: expression
               inExpression: row
                    subject: columnVariable];
    if ([columnVariable isRestricted] && [row constant] < 0.0)
      {
        [_infeasibleRows addObject: columnVariable];
      }
  END_FOR_IN(variableSet);
  RELEASE(variableSet);

  if ([variable isExternal])
    {
      [_externalRows setObject: expression forKey: variable];
      [_externalParametricVariables removeObject: variable];
    }
  [_columns removeObjectForKey: variable];
}

- (void) substituteOutTerm: (GSCSVariable *)term
            withExpression: (GSCSLinearExpression *)newExpression
              inExpression: (GSCSLinearExpression *)expression
                   subject: (GSCSVariable *)subject
{
  CGFloat coefficieint = [expression coefficientForTerm: term];
  [expression removeVariable: term];
  [expression setConstant: (coefficieint * [newExpression constant]) +
                           [expression constant]];
  NSArray *termVariables = [expression termVariables];
  FOR_IN(GSCSVariable *, newExpressionTerm, termVariables)
    [self substituteOutTermInExpression: expression
                          newExpression: newExpression
                                subject: subject
                                   term: newExpressionTerm
                             multiplier: coefficieint];
  END_FOR_IN(termVariables);
}

- (void) substituteOutTermInExpression: (GSCSLinearExpression *)expression
                         newExpression:
                           (GSCSLinearExpression *)newExpression
                               subject: (GSCSVariable *)subject
                                  term: (GSCSVariable *)term
                            multiplier: (CGFloat)multiplier
{
  NSNumber *coefficentInNewExpression =
    [newExpression multiplierForTerm: term];
  NSNumber *coefficentInExistingExpression =
    [expression multiplierForTerm: term];

  if (coefficentInExistingExpression != nil)
    {
      CGFloat newCoefficent = [self
           calculateNewCoefficent: [coefficentInExistingExpression floatValue]
        coefficentInNewExpression: [coefficentInNewExpression floatValue]
                       multiplier: multiplier];

      if ([GSCSFloatComparator isApproxiatelyZero: newCoefficent])
        {
          [expression removeVariable: term];
          [self removeMappingFromExpressionVariable: term
                                      toRowVariable: subject];
        }
      else
        {
          [expression addVariable: term coefficient: newCoefficent];
        }
    }
  else
    {
      CGFloat updatedCoefficent
        = multiplier * [coefficentInNewExpression floatValue];
      [expression addVariable: term coefficient: updatedCoefficent];
      [self addMappingFromExpressionVariable: term toRowVariable: subject];
    }
}

- (CGFloat) calculateNewCoefficent: (CGFloat)coefficentInExistingExpression
         coefficentInNewExpression: (CGFloat)coefficentInNewExpression
                        multiplier: (CGFloat)multiplier
{
  return coefficentInExistingExpression + multiplier * coefficentInNewExpression;
}

- (BOOL) isBasicVariable: (GSCSVariable *)variable
{
  return [_rows objectForKey: variable] != nil;
}

- (void) addVariable: (GSCSVariable *)variable
        toExpression: (GSCSLinearExpression *)expression
{
  [self addVariable: variable
       toExpression: expression
    withCoefficient: 1.0
            subject: nil];
}

- (void) addVariable: (GSCSVariable *)variable
        toExpression: (GSCSLinearExpression *)expression
     withCoefficient: (CGFloat)coefficient;
{
  [self addVariable: variable
       toExpression: expression
    withCoefficient: coefficient
            subject: nil];
}

- (void) addVariable: (GSCSVariable *)variable
        toExpression: (GSCSLinearExpression *)expression
     withCoefficient: (CGFloat)coefficient
             subject: (GSCSVariable *)subject
{
  if ([expression isTermForVariable: variable])
    {
      CGFloat newCoefficient =
        [expression coefficientForTerm: variable] + coefficient;
      if (newCoefficient == 0 ||
          [GSCSFloatComparator isApproxiatelyZero: newCoefficient])
        {
          [expression removeVariable: variable];
          [self removeColumnVariable: variable subject: subject];
        }
      else
        {
          [self setVariable: variable
               onExpression: expression
            withCoefficient: newCoefficient];
        }
    }
  else
    {
      if (![GSCSFloatComparator isApproxiatelyZero: coefficient])
        {
          [self setVariable: variable
               onExpression: expression
            withCoefficient: coefficient];
          if (subject)
            {
              [self addMappingFromExpressionVariable: variable
                                       toRowVariable: subject];
            }
        }
    }
}

- (void) removeColumnVariable: (GSCSVariable *)variable
                      subject: (GSCSVariable *)subject
{
  NSMutableSet *column = [_columns objectForKey: variable];
  if (subject != nil && column != nil)
    {
      [column removeObject: subject];
    }
}

- (void) addNewExpression: (GSCSLinearExpression *)newExpression
             toExpression: (GSCSLinearExpression *)existingExpression
{
  [self addNewExpression: newExpression
            toExpression: existingExpression
                       n: 1
                 subject: nil];
}

- (void) addNewExpression: (GSCSLinearExpression *)newExpression
             toExpression: (GSCSLinearExpression *)existingExpression
                        n: (CGFloat)n
                  subject: (GSCSVariable *)subject
{
  [existingExpression setConstant: [existingExpression constant]
                                   + (n * [newExpression constant])];
  NSArray *newExpressionTermVariables = [newExpression termVariables];
  FOR_IN(GSCSVariable *, term, newExpressionTermVariables)
    CGFloat newCoefficient = [newExpression coefficientForTerm: term] * n;
    [self addVariable: term
         toExpression: existingExpression
      withCoefficient: newCoefficient
              subject: subject];

    [self recordUpdatedVariable: term];
  END_FOR_IN(newExpressionTermVariables);
}

- (void) recordUpdatedVariable: (GSCSVariable *)variable
{
  if ([variable isExternal])
    {
      [_externalParametricVariables addObject: variable];
    }
}

- (void) setVariable: (GSCSVariable *)variable
        onExpression: (GSCSLinearExpression *)expression
     withCoefficient: (CGFloat)coefficient
{
  [expression addVariable: variable coefficient: coefficient];
  [self recordUpdatedVariable: variable];
}

- (void) changeSubjectOnExpression: (GSCSLinearExpression *)expression
                   existingSubject: (GSCSVariable *)existingSubject
                        newSubject: (GSCSVariable *)newSubject
{
  [self setVariable: existingSubject
       onExpression: expression
    withCoefficient: [expression newSubject: newSubject]];
}

- (GSCSLinearExpression *) rowExpressionForVariable: (GSCSVariable *)variable
{
  return [_rows objectForKey: variable];
}

- (void) pivotWithEntryVariable: (GSCSVariable *)entryVariable
                   exitVariable: (GSCSVariable *)exitVariable
{
// The expression represents the exit variable, which is about to be removed from the basis. 
// This means that the old tableau should contain the equation: exitVar = expr.
  GSCSLinearExpression *expression =
    [self rowExpressionForVariable: exitVariable];
  [self removeRowForVariable: exitVariable];

  // Calculate an expression for the entry variable. 
  // As "expression" has been removed from the tableau, 
  // we can make destructive modifications to it in order to construct this expression.
  [self changeSubjectOnExpression: expression
                  existingSubject: exitVariable
                       newSubject: entryVariable];
  [self substituteOutVariable: entryVariable forExpression: expression];

  if ([entryVariable isExternal])
    {
      [_externalParametricVariables removeObject: entryVariable];
    }

  [self addRowForVariable: entryVariable equalsExpression: expression];
}

- (NSString *) description
{
  NSMutableString *description =
    [NSMutableString stringWithString: @"Tableau Information\n"];
  [description appendFormat: @"Rows: %ld (%ld constraints)\n", [_rows count],
                            [_rows count] - 1];
  [description appendFormat: @"Columns: %ld\n", [_columns count]];
  [description appendFormat: @"Infeasible rows: %ld\n", [_infeasibleRows count]];
  [description
    appendFormat: @"External basic variables: %ld\n", [_externalRows count]];
  [description appendFormat: @"External parametric variables: %ld\n\n",
                            [_externalParametricVariables count]];

  [description appendString: @"Columns: \n"];
  [description appendString: [self columnsDescription]];

  [description appendString: @"\nRows:\n"];
  [description appendString: [self rowsDescription]];

  return description;
}

- (NSString *) columnsDescription
{
  NSMutableString *description = [NSMutableString string];
  FOR_IN(GSCSVariable *, columnVariable, _columns)
    [description appendFormat: @"%@ : %@", columnVariable,
                              [_columns objectForKey: columnVariable]];
  END_FOR_IN(_columns);

  return description;
}

- (NSString *) rowsDescription
{
  NSMutableString *description = [NSMutableString string];
  FOR_IN(GSCSVariable *, variable, _rows)
    [description
      appendFormat: @"%@ : %@\n", variable, [_rows objectForKey: variable]];
  END_FOR_IN(_rows);
  return description;
}

- (BOOL) hasInfeasibleRows
{
  return [_infeasibleRows count] > 0;
}

- (BOOL) containsExternalParametricVariableForEveryExternalTerm
{
  FOR_IN(GSCSVariable *, rowVariable, _rows)
    GSCSLinearExpression *expression = [_rows objectForKey: rowVariable];
    NSArray *termVariables = [expression termVariables];
    FOR_IN(GSCSVariable *, variable, termVariables)
      if ([variable isExternal])
        {
          if (![_externalParametricVariables containsObject: variable])
            {
              return NO;
            }
        }
    END_FOR_IN(termVariables);
  END_FOR_IN(_rows);

  return YES;
}

- (BOOL) containsExternalRowForEachExternalRowVariable
{
  FOR_IN(GSCSVariable *, rowVariable, _rows)
    if ([rowVariable isExternal] &&
        [_externalRows objectForKey: rowVariable] == nil)
      {
        return NO;
      }
  END_FOR_IN(_rows);

  return YES;
}

- (NSArray *) substitedOutNonBasicPivotableVariables: (GSCSVariable *)objective
{
  GSCSLinearExpression *objectiveRowExpression =
    [self rowExpressionForVariable: objective];

  NSMutableArray *substitutedOutVariables = [NSMutableArray array];
  FOR_IN(GSCSVariable *, columnVariable, _columns)
    if ([columnVariable isPivotable] && ![self isBasicVariable: columnVariable]
        && ![objectiveRowExpression isTermForVariable: columnVariable])
      {
        [substitutedOutVariables addObject: columnVariable];
      }
  END_FOR_IN(_columns);

  return substitutedOutVariables;
}

- (GSCSVariable *) findPivotableExitVariable: (GSCSVariable *)entryVariable
{
  CGFloat minRatio = DBL_MAX;
  CGFloat r = 0;
  GSCSVariable *exitVariable = nil;
  NSSet *column = [self columnForVariable: entryVariable];
  FOR_IN(GSCSVariable *, variable, column)
    if ([variable isPivotable])
      {
        GSCSLinearExpression *expression =
          [self rowExpressionForVariable: variable];
        CGFloat coefficient = [expression coefficientForTerm: entryVariable];

        if (coefficient < 0)
          {
            r = -[expression constant] / coefficient;

            // Bland's anti-cycling rule:
            // if multiple variables are about the same,
            // always pick the lowest via some total
            // ordering -- in this implementation we preferred the variable
            // created first
            if (r < minRatio
                || ([GSCSFloatComparator isApproxiatelyEqual: r b: minRatio] &&
                    [self shouldPreferPivotableVariable: variable
                                  overPivotableVariable: exitVariable]))
              {
                minRatio = r;
                exitVariable = variable;
              }
          }
      }
  END_FOR_IN(column);

  return exitVariable;
}

- (GSCSVariable *) findPivotableExitVariableWithoutCheck:
  (GSCSVariable *)entryVariable
{
  CGFloat minRatio = DBL_MAX;
  CGFloat r = 0;
  GSCSVariable *exitVariable = nil;
  NSSet *column = [self columnForVariable: entryVariable];
  FOR_IN(GSCSVariable *, variable, column)
    GSCSLinearExpression *expression =
      [self rowExpressionForVariable: variable];
    CGFloat coefficient = [expression coefficientForTerm: entryVariable];

    r = -[expression constant] / coefficient;

    // Bland's anti-cycling rule
    if (r < minRatio
        || ([GSCSFloatComparator isApproxiatelyEqual: r b: minRatio] &&
            [self shouldPreferPivotableVariable: variable
                          overPivotableVariable: exitVariable]))
      {
        minRatio = r;
        exitVariable = variable;
      }
  END_FOR_IN(column);

  return exitVariable;
}

- (GSCSVariable *)
  findExitVariableForEquationWhichMinimizesRatioOfRestrictedVariables:
    (GSCSVariable *)constraintMarkerVariable
{
  GSCSVariable *exitVariable = nil;
  CGFloat minRatio = 0;

  NSSet *column = [self columnForVariable: constraintMarkerVariable];
  FOR_IN(GSCSVariable *, variable, column)
    if ([variable isRestricted])
      {
        GSCSLinearExpression *expression =
          [self rowExpressionForVariable: variable];
        CGFloat coefficient =
          [expression coefficientForTerm: constraintMarkerVariable];
        CGFloat r = [expression constant] / coefficient;

        if (exitVariable == nil || r < minRatio)
          {
            minRatio = r;
            exitVariable = variable;
          }
      }
  END_FOR_IN(column);

  return exitVariable;
}

- (GSCSVariable *) findNonBasicVariables
{
  FOR_IN(GSCSVariable *, variable, _externalParametricVariables)
    if (![self isBasicVariable: variable])
      {
        return variable;
      }
  END_FOR_IN(_externalParametricVariables);

  return nil;
}

- (void) dealloc
{
  RELEASE(_rows);
  RELEASE(_columns);
  RELEASE(_externalParametricVariables);
  RELEASE(_externalRows);
  RELEASE(_infeasibleRows);
  RELEASE(_objective);

  [super dealloc];
}

@end
