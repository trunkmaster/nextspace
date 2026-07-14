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

#import "GSCSLinearExpression.h"
#import "GSCSVariable.h"
#import <Foundation/Foundation.h>

#ifndef _GS_CS_TABLEAU_H
#define _GS_CS_TABLEAU_H

@interface GSCSTableau : NSObject
{
  NSMutableSet *_externalParametricVariables;

  NSMapTable *_rows;

  NSMapTable *_columns;

  NSMapTable *_externalRows;

  NSMutableArray *_infeasibleRows;

  GSCSVariable *_objective;
}

#if GS_HAS_DECLARED_PROPERTIES
@property (nonatomic, assign) GSCSVariable *objective;
#else
- (GSCSVariable *) objective;
- (void) setObjective: (GSCSVariable *)objective;
#endif

#if GS_HAS_DECLARED_PROPERTIES
@property (nonatomic, assign) NSMapTable *externalRows;
#else
- (NSMapTable *) externalRows;
- (void) setExternalRows: (NSMapTable *)externalRows;
#endif

#if GS_HAS_DECLARED_PROPERTIES
@property (nonatomic, assign) NSMutableArray *infeasibleRows;
#else
- (NSMutableArray *) infeasibleRows;
- (void) setInfeasibleRows: (NSMutableArray *)infeasibleRows;
#endif

- (void) addRowForVariable: (GSCSVariable *)variable
          equalsExpression: (GSCSLinearExpression *)expression;

- (void) removeRowForVariable: (GSCSVariable *)variable;

- (BOOL) hasRowForVariable: (GSCSVariable *)variable;

- (void) substituteOutVariable: (GSCSVariable *)variable
                 forExpression: (GSCSLinearExpression *)expression;

- (void) substituteOutTerm: (GSCSVariable *)term
            withExpression: (GSCSLinearExpression *)newExpression
              inExpression: (GSCSLinearExpression *)expression
                   subject: (GSCSVariable *)subject;

- (BOOL) isBasicVariable: (GSCSVariable *)variable;

- (void) addVariable: (GSCSVariable *)variable
        toExpression: (GSCSLinearExpression *)expression;

- (void) addVariable: (GSCSVariable *)variable
        toExpression: (GSCSLinearExpression *)expression
     withCoefficient: (CGFloat)coefficient;

- (void) addVariable: (GSCSVariable *)variable
        toExpression: (GSCSLinearExpression *)expression
     withCoefficient: (CGFloat)coefficient
             subject: (GSCSVariable *)subject;

- (void) setVariable: (GSCSVariable *)variable
        onExpression: (GSCSLinearExpression *)expression
     withCoefficient: (CGFloat)coefficient;

- (void) addNewExpression: (GSCSLinearExpression *)newExpression
             toExpression: (GSCSLinearExpression *)existingExpression
                        n: (CGFloat)n
                  subject: (GSCSVariable *)subject;

- (void) addNewExpression: (GSCSLinearExpression *)newExpression
             toExpression: (GSCSLinearExpression *)existingExpression;

- (void) addMappingFromExpressionVariable: (GSCSVariable *)columnVariable
                            toRowVariable: (GSCSVariable *)rowVariable;

- (void) removeColumn: (GSCSVariable *)variable;

- (BOOL) hasColumnForVariable: (GSCSVariable *)variable;

- (NSSet *) columnForVariable: (GSCSVariable *)variable;

- (GSCSLinearExpression *) rowExpressionForVariable: (GSCSVariable *)variable;

- (void) changeSubjectOnExpression: (GSCSLinearExpression *)expression
                   existingSubject: (GSCSVariable *)existingSubject
                        newSubject: (GSCSVariable *)newSubject;

- (void) pivotWithEntryVariable: (GSCSVariable *)entryVariable
                   exitVariable: (GSCSVariable *)exitVariable;

- (BOOL) hasInfeasibleRows;

- (BOOL) containsExternalParametricVariableForEveryExternalTerm;

- (BOOL) containsExternalRowForEachExternalRowVariable;

- (NSArray *) substitedOutNonBasicPivotableVariables:
  (GSCSVariable *)objective;

- (GSCSVariable *) findPivotableExitVariable: (GSCSVariable *)entryVariable;

- (GSCSVariable *)
  findExitVariableForEquationWhichMinimizesRatioOfRestrictedVariables:
    (GSCSVariable *)constraintMarkerVariable;

- (GSCSVariable *) findNonBasicVariables;

- (GSCSVariable *) findPivotableExitVariableWithoutCheck:
  (GSCSVariable *)entryVariable;

@end

#endif