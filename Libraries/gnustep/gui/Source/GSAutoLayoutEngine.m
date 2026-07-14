/* Copyright (C) 2023 Free Software Foundation, Inc.

   By: Benjamin Johnson
   Date: 28-2-2023
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

#import "GSAutoLayoutEngine.h"
#import "AppKit/NSLayoutConstraint.h"
#import "GSCSConstraint.h"
#import "GSFastEnumeration.h"
#import "NSViewPrivate.h"

enum
{
  GSLayoutAttributeNotAnAttribute = 0,
  GSLayoutAttributeLeft = 1,
  GSLayoutAttributeRight,
  GSLayoutAttributeTop,
  GSLayoutAttributeBottom,
  GSLayoutAttributeLeading,
  GSLayoutAttributeTrailing,
  GSLayoutAttributeWidth,
  GSLayoutAttributeHeight,
  GSLayoutAttributeCenterX,
  GSLayoutAttributeCenterY,
  GSLayoutAttributeLastBaseline,
  GSLayoutAttributeBaseline = GSLayoutAttributeLastBaseline,
  GSLayoutAttributeFirstBaseline,
  GSLayoutAttributeMinX = 32,
  GSLayoutAttributeMinY = 33,
  GSLayoutAttributeMaxX = 36,
  GSLayoutAttributeMaxY = 37
};
typedef NSInteger GSLayoutAttribute;

enum
{
  GSLayoutViewAttributeBaselineOffsetFromBottom = 1,
  GSLayoutViewAttributeFirstBaselineOffsetFromTop,
  GSLayoutViewAttributeIntrinsicWidth,
  GSLayoutViewAttributeIntrinsicHeight,
} GSLayoutViewAttribue;
typedef NSInteger GSLayoutViewAttribute;

@interface GSAutoLayoutEngine (PrivateMethods)

- (GSCSConstraint *) solverConstraintForConstraint:
    (NSLayoutConstraint *)constraint;

- (void) mapLayoutConstraint: (NSLayoutConstraint *)layoutConstraint
          toSolverConstraint: (GSCSConstraint *)solverConstraint;

- (void) updateAlignmentRectsForTrackedViews;

- (void) updateAlignmentRectsForTrackedViewsForSolution:
    (GSCSSolution *)solution;

- (BOOL) hasConstraintsForView: (NSView *)view;

- (GSCSConstraint *) getExistingConstraintForAutolayoutConstraint:
    (NSLayoutConstraint *)constraint;

- (void) addConstraintAgainstViewConstraintsArray:
    (NSLayoutConstraint *)constraint;

- (void) removeConstraintAgainstViewConstraintsArray:
    (NSLayoutConstraint *)constraint;

- (void) addSupportingInternalConstraintsToView: (NSView *)view
                                   forAttribute: (NSLayoutAttribute)attribute
                                     constraint: (GSCSConstraint *)constraint;

- (void) removeInternalConstraintsForView: (NSView *)view;

- (void) addSolverConstraint: (GSCSConstraint *)constraint;

- (void) removeSolverConstraint: (GSCSConstraint *)constraint;

- (NSArray *) constraintsForView: (NSView *)view;

- (NSNumber *) indexForView: (NSView *)view;

- (void) notifyViewsOfAlignmentRectChange: (NSArray *)viewsWithChanges;

- (BOOL) solverCanSolveAlignmentRectForView: (NSView *)view
                                   solution: (GSCSSolution *)solution;

- (void) recordAlignmentRect: (NSRect)alignmentRect
                forViewIndex: (NSNumber *)viewIndex;

- (NSRect) solverAlignmentRectForView: (NSView *)view
                             solution: (GSCSSolution *)solution;

- (NSRect) currentAlignmentRectForViewAtIndex: (NSNumber *)viewIndex;

- (BOOL) updateViewAligmentRect: (GSCSSolution *)solution view: (NSView *)view;

- (BOOL) hasAddedWidthAndHeightConstraintsToView: (NSView *)view;

- (GSCSVariable *) variableForView: (NSView *)view
                      andAttribute: (GSLayoutAttribute)attribute;

- (GSCSVariable *) variableForView: (NSView *)view
                  andViewAttribute: (GSLayoutViewAttribute)attribute;

- (void) resolveVariableForView: (NSView *)view
                      attribute: (GSLayoutViewAttribute)attribute;

- (GSCSVariable *) createVariableWithName: (NSString *)name;

- (GSCSVariable *) getExistingVariableForView: (NSView *)view
                                withAttribute: (GSLayoutAttribute)attribute;

- (GSCSVariable *) getExistingVariableForView: (NSView *)view
                            withViewAttribute:
                              (GSLayoutViewAttribute)attribute;

- (GSCSVariable *) variableWithName: (NSString *)variableName;

- (NSString *) getVariableIdentifierForView: (NSView *)view
                              withAttribute: (GSLayoutAttribute)attribute;

- (NSString *) getAttributeName: (GSLayoutAttribute)attribute;

- (NSString *) getLayoutViewAttributeName: (GSLayoutViewAttribute)attribute;

- (NSString *) getDynamicVariableIdentifierForView: (NSView *)view
                                 withViewAttribute:
                                   (GSLayoutViewAttribute)attribute;

- (NSString *) getIdentifierForView: (NSView *)view;

- (NSInteger) registerView: (NSView *)view;

- (void) addInternalWidthConstraintForView: (NSView *)view;

- (void) addInternalHeightConstraintForView: (NSView *)view;

- (void) addInternalLeadingConstraintForView: (NSView *)view
                                  constraint: (GSCSConstraint *)constraint;

- (void) addInternalTrailingConstraintForView: (NSView *)view
                                   constraint: (GSCSConstraint *)constraint;

- (void) addInternalLeftConstraintForView: (NSView *)view
                               constraint: (GSCSConstraint *)constraint;

- (void) addInternalRightConstraintForView: (NSView *)view
                                constraint: (GSCSConstraint *)constraint;

- (void) addInternalBottomConstraintForView: (NSView *)view
                                 constraint: (GSCSConstraint *)constraint;

- (void) addInternalTopConstraintForView: (NSView *)view
                              constraint: (GSCSConstraint *)constraint;

- (void) addInternalCenterXConstraintsForView: (NSView *)view
                                   constraint: (GSCSConstraint *)constraint;

- (void) addInternalCenterYConstraintsForView: (NSView *)view
                                   constraint: (GSCSConstraint *)constraint;

- (void) addInternalFirstBaselineConstraintsForView: (NSView *)view
                                         constraint:
                                           (GSCSConstraint *)constraint;

- (void) addInternalBaselineConstraintsForView: (NSView *)view
                                    constraint: (GSCSConstraint *)constraint;

- (void) addInternalSolverConstraint: (GSCSConstraint *)constraint
                             forView: (NSView *)view;

- (void) addIntrinsicContentSizeConstraintsToView: (NSView *)view;

- (void) addSupportingIntrinsicSizeConstraintsToView: (NSView *)view
                                        orientation:
                                          (NSLayoutConstraintOrientation)
                                            orientation
                             intrinsicSizeAttribute:
                               (GSLayoutViewAttribute)intrinsicSizeAttribute
                                 dimensionAttribute:
                                   (GSLayoutAttribute)dimensionAttribute;

- (void) addSupportingConstraintForLayoutViewAttribute:
           (GSLayoutViewAttribute)attribute
                                                  view: (NSView *)view
                                            constraint:
                                              (GSCSConstraint *)constraint;

- (GSCSConstraint *) solverConstraintForRelationalConstraint:
  (NSLayoutConstraint *)constraint;

- (GSCSConstraint *) solverConstraintForNonRelationalConstraint:
  (NSLayoutConstraint *)constraint;

- (void) addObserverToConstraint: (NSLayoutConstraint *)constranit;

- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context;

- (void) updateConstraint: (NSLayoutConstraint *)constraint;

- (void) addSupportingSolverConstraint: (GSCSConstraint *)supportingConstraint
                   forSolverConstraint: (GSCSConstraint *)constraint;

- (CGFloat) valueForView: (NSView *)view
               attribute: (GSLayoutViewAttribute)attribute;

- (int) getConstantMultiplierForLayoutAttribute: (NSLayoutAttribute)attribute;

@end

@implementation GSAutoLayoutEngine

- (instancetype) initWithSolver: (GSCassowarySolver *)cassowarySolver;
{
  self = [super init];
  if (self != nil)
    {
      ASSIGN(_solver, cassowarySolver);

      ASSIGN(_variablesByKey, [NSMapTable strongToStrongObjectsMapTable]);

      ASSIGN(_constraintsByAutoLayoutConstaintHash, [NSMapTable strongToStrongObjectsMapTable]);

      ASSIGN(_layoutConstraintsBySolverConstraint, [NSMapTable strongToStrongObjectsMapTable]);

      ASSIGN(_solverConstraints, [NSMutableArray array]);

      ASSIGN(_trackedViews, [NSMutableArray array]);

      ASSIGN(_supportingConstraintsByConstraint, [NSMapTable strongToStrongObjectsMapTable]);

      ASSIGN(_viewAlignmentRectByViewIndex, [NSMutableDictionary dictionary]);

      ASSIGN(_viewIndexByViewHash, [NSMutableDictionary dictionary]);

      ASSIGN(_constraintsByViewIndex, [NSMutableDictionary dictionary]);

      ASSIGN(_internalConstraintsByViewIndex, [NSMapTable strongToStrongObjectsMapTable]);
    }
  return self;
}

- (instancetype) init
{
  GSCassowarySolver *solver = [[GSCassowarySolver alloc] init];
  self = [self initWithSolver: solver];
  RELEASE(solver);
  return self;
}

- (void) addConstraints: (NSArray *)constraints
{
  FOR_IN(NSLayoutConstraint *, constraint, constraints)
    [self addConstraint: constraint];
  END_FOR_IN(constraints);
}

- (void) addConstraint: (NSLayoutConstraint *)constraint
{
  GSCSConstraint *solverConstraint =
      [self solverConstraintForConstraint: constraint];

  [self mapLayoutConstraint: constraint toSolverConstraint: solverConstraint];

  [self addSupportingInternalConstraintsToView: [constraint firstItem]
                                  forAttribute: [constraint firstAttribute]
                                    constraint: solverConstraint];

  if ([constraint secondItem])
    {
      [self
          addSupportingInternalConstraintsToView: [constraint secondItem]
                                    forAttribute: [constraint secondAttribute]
                                      constraint: solverConstraint];
    }

  [self addSolverConstraint: solverConstraint];
  [self updateAlignmentRectsForTrackedViews];

  [self addConstraintAgainstViewConstraintsArray: constraint];
}

- (void) removeConstraint: (NSLayoutConstraint *)constraint
{
  GSCSConstraint *solverConstraint =
      [self getExistingConstraintForAutolayoutConstraint: constraint];
  if (solverConstraint == nil)
    {
      return;
    }

  [self removeSolverConstraint: solverConstraint];

  NSArray *internalConstraints =
      [_supportingConstraintsByConstraint objectForKey: solverConstraint];
  if (internalConstraints)
    {
      FOR_IN(GSCSConstraint *, internalConstraint, internalConstraints)
        [self removeSolverConstraint: internalConstraint];
      END_FOR_IN(internalConstraints);
    }

  [_supportingConstraintsByConstraint setObject: nil forKey: solverConstraint];

  [self updateAlignmentRectsForTrackedViews];
  [self removeConstraintAgainstViewConstraintsArray: constraint];

  if ([self hasConstraintsForView: [constraint firstItem]])
    {
      [self removeInternalConstraintsForView: [constraint firstItem]];
    }
  if ([constraint secondItem] != nil &&
      [self hasConstraintsForView: [constraint secondItem]])
    {
      [self removeInternalConstraintsForView: [constraint secondItem]];
    }
}

- (void) removeConstraints: (NSArray *)constraints
{
  FOR_IN(NSLayoutConstraint *, constraint, constraints)
    [self removeConstraint: constraint];
  END_FOR_IN(constraints);
}

- (GSCSConstraint *) solverConstraintForConstraint:
    (NSLayoutConstraint *)constraint
{
  if ([constraint secondItem] == nil)
    {
      return [self solverConstraintForNonRelationalConstraint: constraint];
    }
  else
    {
      return [self solverConstraintForRelationalConstraint: constraint];
    }
}

- (GSCSConstraint *) solverConstraintForNonRelationalConstraint:
    (NSLayoutConstraint *)constraint
{
  GSCSVariable *firstItemConstraintVariable =
    [self variableForView: [constraint firstItem]
             andAttribute: (GSLayoutAttribute)[constraint firstAttribute]];
  GSCSConstraint *newConstraint;
  switch ([constraint relation])
    {
    case NSLayoutRelationLessThanOrEqual:
      newConstraint = [GSCSConstraint constraintWithLeftVariable: firstItemConstraintVariable operator: GSCSConstraintOperatorLessThanOrEqual rightConstant: [constraint constant]];
      break;
    case NSLayoutRelationEqual:
    default:
      newConstraint =  [GSCSConstraint constraintWithLeftVariable: firstItemConstraintVariable operator: GSCSConstraintOperatorEqual rightConstant: [constraint constant]];
      break;
    case NSLayoutRelationGreaterThanOrEqual:
      newConstraint = [GSCSConstraint constraintWithLeftVariable: firstItemConstraintVariable operator: GSCSConstraintOperationGreaterThanOrEqual rightConstant: [constraint constant]];
      break;
    }
  GSCSStrength *strength =
    [[GSCSStrength alloc] initWithName: nil strength: [constraint priority]];
  [newConstraint setStrength: strength];
  RELEASE(strength);

  return newConstraint;
}

- (GSCSConstraint *) solverConstraintForRelationalConstraint:
  (NSLayoutConstraint *)constraint
{
  GSCSVariable *firstItemConstraintVariable =
    [self variableForView: [constraint firstItem]
             andAttribute: (GSLayoutAttribute)[constraint firstAttribute]];
  GSCSVariable *secondItemConstraintVariable =
    [self variableForView: [constraint secondItem]
             andAttribute: (GSLayoutAttribute)[constraint secondAttribute]];

  CGFloat multiplier = [constraint multiplier];

  GSCSConstraintOperator op = GSCSConstraintOperatorEqual;
  switch ([constraint relation])
    {
    case NSLayoutRelationEqual:
      op = GSCSConstraintOperatorEqual;
      break;
    case NSLayoutRelationLessThanOrEqual:
      op = GSCSConstraintOperatorLessThanOrEqual;
      break;
    case NSLayoutRelationGreaterThanOrEqual:
      op = GSCSConstraintOperationGreaterThanOrEqual;
      break;
    }
  double constant =
    [self getConstantMultiplierForLayoutAttribute: [constraint secondAttribute]] * [constraint constant];

  GSCSLinearExpression *rightExpression = [[GSCSLinearExpression alloc]
    initWithVariable: secondItemConstraintVariable
         coefficient: multiplier
            constant: constant];
  GSCSConstraint *newConstraint = [GSCSConstraint constraintWithLeftVariable: firstItemConstraintVariable operator: op rightExpression: rightExpression];
  RELEASE(rightExpression);

  GSCSStrength *strength =
    [[GSCSStrength alloc] initWithName: nil strength: [constraint priority]];
  [newConstraint setStrength: strength];
  RELEASE(strength);

  return newConstraint;
}

- (int) getConstantMultiplierForLayoutAttribute: (NSLayoutAttribute)attribute
{
  switch (attribute)
    {
    case NSLayoutAttributeTop:
      return -1;
    case NSLayoutAttributeBottom:
      return 1;
    case NSLayoutAttributeLeading:
      return 1;
    case NSLayoutAttributeTrailing:
      return -1;
    case NSLayoutAttributeLeft:
      return 1;
    case NSLayoutAttributeRight:
      return -1;
    default:
      return 1;
    }
}

- (GSCSVariable *) variableForView: (NSView *)view
                  andViewAttribute: (GSLayoutViewAttribute)attribute
{
  NSString *variableName = [self getDynamicVariableIdentifierForView: view
                                                   withViewAttribute: attribute];
  
  GSCSVariable *existingVariable = [self variableWithName: variableName];
  if (existingVariable != nil)
    {
      return existingVariable;
    }
  else
    {
      return [self createVariableWithName: variableName];
    }
}

- (GSCSVariable *) variableForView: (NSView *)view
                      andAttribute: (GSLayoutAttribute)attribute
{
  NSString *variableName =
    [self getVariableIdentifierForView: view withAttribute: attribute];
  GSCSVariable *existingVariable = [self variableWithName: variableName];
  if (existingVariable != nil)
    {
      return existingVariable;
    }
  else
    {
      return [self createVariableWithName: variableName];
    }
}

- (GSCSVariable *) getExistingVariableForView: (NSView *)view
                                withAttribute: (GSLayoutAttribute)attribute
{
  NSString *variableIdentifier =
    [self getVariableIdentifierForView: view
                          withAttribute: (GSLayoutAttribute)attribute];
  return [self variableWithName: variableIdentifier];
}

- (GSCSVariable *) createVariableWithName: (NSString *)name
{
  GSCSVariable *variable = [GSCSVariable variableWithValue: 0 name: name];
  [_variablesByKey setObject: variable forKey: name];

  return variable;
}

- (GSCSVariable *) getExistingVariableForView: (NSView *)view
                            withViewAttribute: (GSLayoutViewAttribute)attribute
{
  NSString *variableIdentifier =
    [self getDynamicVariableIdentifierForView: view
                            withViewAttribute: attribute];
  return [self variableWithName: variableIdentifier];
}

- (GSCSVariable *) variableWithName: (NSString *)variableName
{
  return [_variablesByKey objectForKey: variableName];
}

- (NSString *) getVariableIdentifierForView: (NSView *)view
                              withAttribute: (GSLayoutAttribute)attribute
{
  NSString *viewIdentifier = [self getIdentifierForView: view];
  return [NSString stringWithFormat: @"%@.%@", viewIdentifier,
                                    [self getAttributeName: attribute]];
}

- (NSString *) getAttributeName: (GSLayoutAttribute)attribute
{
  switch (attribute)
    {
    case GSLayoutAttributeTop:
          return @"top";
    case GSLayoutAttributeBottom:
          return @"bottom";
    case GSLayoutAttributeLeading:
          return @"leading";
    case GSLayoutAttributeLeft:
          return @"left";
    case GSLayoutAttributeRight:
          return @"right";
    case GSLayoutAttributeTrailing:
          return @"trailing";
    case GSLayoutAttributeHeight:
          return @"height";
    case GSLayoutAttributeWidth:
          return @"width";
    case GSLayoutAttributeCenterX:
          return @"centerX";
    case GSLayoutAttributeCenterY:
          return @"centerY";
    case GSLayoutAttributeBaseline:
          return @"baseline";
    case GSLayoutAttributeFirstBaseline:
          return @"firstBaseline";
    case GSLayoutAttributeMinX:
          return @"minX";
    case GSLayoutAttributeMinY:
          return @"minY";
    case GSLayoutAttributeMaxX:
          return @"maxX";
    case GSLayoutAttributeMaxY:
          return @"maxY";
    default:
          [[NSException exceptionWithName: @"Not handled"
                                   reason: @"GSLayoutAttribute not handled"
                                 userInfo: nil] raise];
          return nil;
    }
}

- (NSString *) getLayoutViewAttributeName: (GSLayoutViewAttribute)attribute
{
  switch (attribute)
  {
  case GSLayoutViewAttributeBaselineOffsetFromBottom:
    return @"baselineOffsetFromBottom";
  case GSLayoutViewAttributeFirstBaselineOffsetFromTop:
    return @"firstBaselineOffsetFromTop";
  case GSLayoutViewAttributeIntrinsicWidth:
    return @"intrinsicContentSize.width";
  case GSLayoutViewAttributeIntrinsicHeight:
    return @"intrinsicContentSize.height";
  default:
    [[NSException
      exceptionWithName: @"GSLayoutViewAttribute Not handled"
                  reason: @"The provided GSLayoutViewAttribute does "
                        @"not have a name"
                userInfo: nil] raise];
    return nil;
  }
}

- (NSString *) getDynamicVariableIdentifierForView: (NSView *)view
                                 withViewAttribute:
                                   (GSLayoutViewAttribute)attribute
{
  NSString *viewIdentifier = [self getIdentifierForView: view];
  return
    [NSString stringWithFormat: @"%@.%@", viewIdentifier,
                                [self getLayoutViewAttributeName: attribute]];
}

- (NSString *) getIdentifierForView: (NSView *)view
{
  NSUInteger viewIndex;
  NSNumber *existingViewIndex = [self indexForView: view];
  if (existingViewIndex)
    {
      viewIndex = [existingViewIndex unsignedIntegerValue];
    }
  else
    {
      viewIndex = [self registerView: view];
    }

  return [NSString stringWithFormat: @"view%ld", (long)viewIndex];
}

- (NSInteger) registerView: (NSView *)view
{
  NSUInteger viewIndex = [_trackedViews count];
  [_trackedViews addObject: view];
  [_viewIndexByViewHash
    setObject: [NSNumber numberWithUnsignedInteger: viewIndex]
        forKey: [NSNumber numberWithUnsignedInteger: [view hash]]];

  return viewIndex;
}

- (void) mapLayoutConstraint: (NSLayoutConstraint *)layoutConstraint
          toSolverConstraint: (GSCSConstraint *)solverConstraint
{
  [_constraintsByAutoLayoutConstaintHash setObject: solverConstraint
                                            forKey: layoutConstraint];
  [_layoutConstraintsBySolverConstraint setObject: layoutConstraint
                                            forKey: solverConstraint];
}

- (void) addSupportingInternalConstraintsToView: (NSView *)view
                                   forAttribute: (NSLayoutAttribute)attribute
                                     constraint: (GSCSConstraint *)constraint
{
  if (![self hasAddedWidthAndHeightConstraintsToView: view])
    {
      [self addInternalWidthConstraintForView: view];
      [self addInternalHeightConstraintForView: view];
      [self addIntrinsicContentSizeConstraintsToView: view];
    }

  switch (attribute)
    {
    case NSLayoutAttributeTrailing:
      [self addInternalTrailingConstraintForView: view
                                      constraint: constraint];
      break;
    case NSLayoutAttributeLeading:
      [self addInternalLeadingConstraintForView: view
                                      constraint: constraint];
      break;
    case NSLayoutAttributeLeft:
      [self addInternalLeftConstraintForView: view
                                  constraint: constraint];
      break;
    case NSLayoutAttributeRight:
      [self addInternalRightConstraintForView: view
                                    constraint: constraint];
      break;
    case NSLayoutAttributeTop:
      [self addInternalTopConstraintForView: view
                                  constraint: constraint];
      break;
    case NSLayoutAttributeBottom:
      [self addInternalBottomConstraintForView: view
                                    constraint: constraint];
      break;
    case NSLayoutAttributeCenterX:
      [self addInternalCenterXConstraintsForView: view
                                      constraint: constraint];
      break;
    case NSLayoutAttributeCenterY:
      [self addInternalCenterYConstraintsForView: view
                                      constraint: constraint];
      break;
    case NSLayoutAttributeBaseline:
      [self addInternalBaselineConstraintsForView: view
                                        constraint: constraint];
      break;
    case NSLayoutAttributeFirstBaseline:
      [self addInternalFirstBaselineConstraintsForView: view
                                            constraint: constraint];
    default:
            break;
      }
}

- (BOOL) hasAddedWidthAndHeightConstraintsToView: (NSView *)view
{
  NSArray *added = [_internalConstraintsByViewIndex objectForKey: view];
  return added != nil;
}

- (void) addInternalWidthConstraintForView: (NSView *)view
{
  GSCSVariable *widthConstraintVariable =
    [self variableForView: view andAttribute: GSLayoutAttributeWidth];
  GSCSVariable *minX = [self variableForView: view
                                andAttribute: GSLayoutAttributeMinX];
  GSCSVariable *maxX = [self variableForView: view
                                andAttribute: GSLayoutAttributeMaxX];

  GSCSLinearExpression *maxXMinusMinX =
    [[GSCSLinearExpression alloc] initWithVariable: maxX];
  [maxXMinusMinX addVariable: minX coefficient: -1];
  GSCSConstraint *widthRelationshipToMaxXAndMinXConstraint = [GSCSConstraint constraintWithLeftVariable: widthConstraintVariable operator: GSCSConstraintOperatorEqual rightExpression: maxXMinusMinX];

  [self addInternalSolverConstraint: widthRelationshipToMaxXAndMinXConstraint
                            forView: view];
  RELEASE(maxXMinusMinX);
}

- (void) addInternalHeightConstraintForView: (NSView *)view
{
  GSCSVariable *heightConstraintVariable =
    [self variableForView: view andAttribute: GSLayoutAttributeHeight];
  GSCSVariable *minY = [self variableForView: view
                                andAttribute: GSLayoutAttributeMinY];
  GSCSVariable *maxY = [self variableForView: view
                                andAttribute: GSLayoutAttributeMaxY];

  GSCSLinearExpression *maxYMinusMinY =
    [[GSCSLinearExpression alloc] initWithVariable: maxY];
  [maxYMinusMinY addVariable: minY coefficient: -1];
  GSCSConstraint *heightConstraint = [GSCSConstraint constraintWithLeftVariable: heightConstraintVariable operator: GSCSConstraintOperatorEqual rightExpression: maxYMinusMinY];
  [self addInternalSolverConstraint: heightConstraint forView: view];

  RELEASE(maxYMinusMinY);
}

- (void) addInternalLeadingConstraintForView: (NSView *)view
                                  constraint: (GSCSConstraint *)constraint
{
  GSCSVariable *minX = [self variableForView: view
                                andAttribute: GSLayoutAttributeMinX];
  GSCSVariable *leadingVariable =
    [self variableForView: view andAttribute: GSLayoutAttributeLeading];
  GSCSConstraint *minXLeadingRelationshipConstraint = [GSCSConstraint constraintWithLeftVariable: minX operator: GSCSConstraintOperatorEqual rightVariable: leadingVariable];
  [self addSupportingSolverConstraint: minXLeadingRelationshipConstraint
                  forSolverConstraint: constraint];
}

- (void) addInternalTrailingConstraintForView: (NSView *)view
                                   constraint: (GSCSConstraint *)constraint
{
  GSCSVariable *trailingVariable =
    [self variableForView: view andAttribute: GSLayoutAttributeTrailing];
  GSCSVariable *maxX = [self variableForView: view
                                andAttribute: GSLayoutAttributeMaxX];
  GSCSConstraint *maxXTrailingRelationshipConstraint = [GSCSConstraint constraintWithLeftVariable: maxX operator: GSCSConstraintOperatorEqual rightVariable: trailingVariable];
  [self addSupportingSolverConstraint: maxXTrailingRelationshipConstraint
                  forSolverConstraint: constraint];
}

- (void) addInternalLeftConstraintForView: (NSView *)view
                               constraint: (GSCSConstraint *)constraint
{
  GSCSVariable *minX = [self variableForView: view
                                andAttribute: GSLayoutAttributeMinX];
  GSCSVariable *leftVariable = [self variableForView: view
                                        andAttribute: GSLayoutAttributeLeft];
  GSCSConstraint *minXLeadingRelationshipConstraint = [GSCSConstraint constraintWithLeftVariable: minX operator: GSCSConstraintOperatorEqual rightVariable: leftVariable];
  [self addSupportingSolverConstraint: minXLeadingRelationshipConstraint
                  forSolverConstraint: constraint];
}

- (void) addInternalRightConstraintForView: (NSView *)view
                                constraint: (GSCSConstraint *)constraint
{
  GSCSVariable *maxX = [self variableForView: view
                                andAttribute: GSLayoutAttributeMaxX];
  GSCSVariable *rightVariable =
    [self variableForView: view andAttribute: GSLayoutAttributeRight];
  GSCSConstraint *maxXRightRelationshipConstraint = [GSCSConstraint constraintWithLeftVariable: maxX operator: GSCSConstraintOperatorEqual rightVariable: rightVariable];
  [self addSupportingSolverConstraint: maxXRightRelationshipConstraint
                  forSolverConstraint: constraint];
}

- (void) addInternalBottomConstraintForView: (NSView *)view
                                 constraint: (GSCSConstraint *)constraint
{
  GSCSVariable *minY = [self variableForView: view
                                andAttribute: GSLayoutAttributeMinY];
  GSCSVariable *bottomVariable =
    [self variableForView: view andAttribute: GSLayoutAttributeBottom];
  GSCSConstraint *minYBottomRelationshipConstraint = [GSCSConstraint constraintWithLeftVariable: minY operator: GSCSConstraintOperatorEqual rightVariable: bottomVariable];
  [self addSupportingSolverConstraint: minYBottomRelationshipConstraint
                  forSolverConstraint: constraint];
}

- (void) addInternalTopConstraintForView: (NSView *)view
                              constraint: (GSCSConstraint *)constraint
{
    GSCSVariable *maxY = [self variableForView: view
                                  andAttribute: GSLayoutAttributeMaxY];
    GSCSVariable *topVariable = [self variableForView: view
                                         andAttribute: GSLayoutAttributeTop];
    GSCSConstraint *maxYTopRelationshipConstraint = [GSCSConstraint constraintWithLeftVariable: maxY operator: GSCSConstraintOperatorEqual rightVariable: topVariable];
    [self addSupportingSolverConstraint: maxYTopRelationshipConstraint
                    forSolverConstraint: constraint];
}

- (void) addInternalCenterXConstraintsForView: (NSView *)view
                                   constraint: (GSCSConstraint *)constraint
{
    GSCSVariable *centerXVariable =
      [self variableForView: view andAttribute: GSLayoutAttributeCenterX];
    GSCSVariable *width = [self variableForView: view
                                   andAttribute: GSLayoutAttributeWidth];
    GSCSVariable *minX = [self variableForView: view
                                  andAttribute: GSLayoutAttributeMinX];

    GSCSLinearExpression *exp =
      [[GSCSLinearExpression alloc] initWithVariable: minX];
    [exp addVariable: width coefficient: 0.5];
    GSCSConstraint *centerXConstraint = [GSCSConstraint constraintWithLeftVariable: centerXVariable operator: GSCSConstraintOperatorEqual rightExpression: exp];

    [self addSupportingSolverConstraint: centerXConstraint
                    forSolverConstraint: constraint];

    RELEASE(exp);
}

- (void) addInternalCenterYConstraintsForView: (NSView *)view
                                   constraint: (GSCSConstraint *)constraint
{
    GSCSVariable *centerYVariable =
      [self variableForView: view andAttribute: GSLayoutAttributeCenterY];
    GSCSVariable *height = [self variableForView: view
                                    andAttribute: GSLayoutAttributeHeight];
    GSCSVariable *minY = [self variableForView: view
                                  andAttribute: GSLayoutAttributeMinY];

    GSCSLinearExpression *exp =
      [[GSCSLinearExpression alloc] initWithVariable: minY];
    [exp addVariable: height coefficient: 0.5];
    GSCSConstraint *centerYConstraint = [GSCSConstraint constraintWithLeftVariable: centerYVariable operator: GSCSConstraintOperatorEqual rightExpression: exp];
    RELEASE(exp);

    [self addSupportingSolverConstraint: centerYConstraint
                    forSolverConstraint: constraint];
}

- (void) addInternalFirstBaselineConstraintsForView: (NSView *)view
                                         constraint:
                                           (GSCSConstraint *)constraint
{
    GSCSVariable *firstBaselineVariable =
      [self variableForView: view
               andAttribute: GSLayoutAttributeFirstBaseline];
    GSCSVariable *maxY = [self variableForView: view
                                  andAttribute: GSLayoutAttributeMaxY];
    GSCSVariable *firstBaselineOffsetVariable =
      [self variableForView: view
           andViewAttribute: GSLayoutViewAttributeFirstBaselineOffsetFromTop];

    GSCSLinearExpression *exp =
      [[GSCSLinearExpression alloc] initWithVariable: maxY];
    [exp addVariable: firstBaselineOffsetVariable coefficient: -1];
    GSCSConstraint *firstBaselineConstraint = [GSCSConstraint constraintWithLeftVariable: firstBaselineVariable operator: GSCSConstraintOperatorEqual rightExpression: exp];
    RELEASE(exp);

    [self addSupportingConstraintForLayoutViewAttribute:
            GSLayoutViewAttributeFirstBaselineOffsetFromTop
                                                   view: view
                                             constraint: constraint];
    [self addSupportingSolverConstraint: firstBaselineConstraint
                    forSolverConstraint: constraint];
}

- (void) addInternalBaselineConstraintsForView: (NSView *)view
                                    constraint: (GSCSConstraint *)constraint
{
    GSCSVariable *baselineVariable =
      [self variableForView: view andAttribute: GSLayoutAttributeBaseline];
    GSCSVariable *minY = [self variableForView: view
                                  andAttribute: GSLayoutAttributeMinY];
    GSCSVariable *baselineOffsetVariable =
      [self variableForView: view
           andViewAttribute: GSLayoutViewAttributeBaselineOffsetFromBottom];

    [self addSupportingConstraintForLayoutViewAttribute:
            GSLayoutViewAttributeBaselineOffsetFromBottom
                                                   view: view
                                             constraint: constraint];
    GSCSLinearExpression *exp =
      [[GSCSLinearExpression alloc] initWithVariable: minY];
    [exp addVariable: baselineOffsetVariable];
    GSCSConstraint *baselineConstraint = [GSCSConstraint constraintWithLeftVariable: baselineVariable operator: GSCSConstraintOperatorEqual rightExpression: exp];
    RELEASE(exp);

    [self addSupportingSolverConstraint: baselineConstraint
                    forSolverConstraint: constraint];
}

- (void) addInternalSolverConstraint: (GSCSConstraint *)constraint
                             forView: (NSView *)view
{
  [self addSolverConstraint: constraint];

  NSArray *internalViewConstraints =
    [_internalConstraintsByViewIndex objectForKey: view];
  if (internalViewConstraints == nil)
    {
      [_internalConstraintsByViewIndex setObject: [NSMutableArray array]
                                          forKey: view];
    }
  [[_internalConstraintsByViewIndex objectForKey: view]
    addObject: constraint];
}

- (void) addIntrinsicContentSizeConstraintsToView: (NSView *)view
{
    NSSize intrinsicContentSize = [view intrinsicContentSize];
    if (intrinsicContentSize.width != NSViewNoIntrinsicMetric)
      {
            [self
              addSupportingIntrinsicSizeConstraintsToView: view
                                             orientation: NSLayoutConstraintOrientationHorizontal
                                  intrinsicSizeAttribute: GSLayoutViewAttributeIntrinsicWidth
                                      dimensionAttribute: GSLayoutAttributeWidth];
      }
    if (intrinsicContentSize.height != NSViewNoIntrinsicMetric)
      {
            [self
              addSupportingIntrinsicSizeConstraintsToView: view
                                             orientation: NSLayoutConstraintOrientationVertical
                                  intrinsicSizeAttribute: GSLayoutViewAttributeIntrinsicHeight
                                      dimensionAttribute: GSLayoutAttributeHeight];
      }
}

- (void) addSupportingIntrinsicSizeConstraintsToView: (NSView *)view
                                        orientation: (NSLayoutConstraintOrientation)orientation
                             intrinsicSizeAttribute: (GSLayoutViewAttribute)intrinsicSizeAttribute
                                 dimensionAttribute: (GSLayoutAttribute)dimensionAttribute
{
    GSCSVariable *intrinsicContentDimension =
      [self variableForView: view andViewAttribute: intrinsicSizeAttribute];
    GSCSVariable *dimensionVariable =
      [self variableForView: view andAttribute: dimensionAttribute];

    GSCSVariable *intrinsicSizeVariable =
      [self getExistingVariableForView: view
                     withViewAttribute: intrinsicSizeAttribute];
    GSCSConstraint *intrinsicSizeConstraint =
      [GSCSConstraint editConstraintWithVariable: intrinsicSizeVariable];
    [self addInternalSolverConstraint: intrinsicSizeConstraint forView: view];
    [self resolveVariableForView: view attribute: intrinsicSizeAttribute];

    double huggingPriority =
      [view contentHuggingPriorityForOrientation: orientation];
    GSCSConstraint *huggingConstraint = [GSCSConstraint constraintWithLeftVariable: dimensionVariable operator: GSCSConstraintOperatorLessThanOrEqual rightVariable: intrinsicContentDimension];
    GSCSStrength *huggingConstraintStrength =
      [[GSCSStrength alloc] initWithName: nil strength: huggingPriority];
    [huggingConstraint setStrength: huggingConstraintStrength];
    RELEASE(huggingConstraintStrength);

    [self addInternalSolverConstraint: huggingConstraint forView: view];

    double compressionPriority =
      [view contentCompressionResistancePriorityForOrientation: orientation];
    GSCSConstraint *compressionConstraint = [GSCSConstraint constraintWithLeftVariable: dimensionVariable operator: GSCSConstraintOperationGreaterThanOrEqual rightVariable: intrinsicContentDimension];
    GSCSStrength *compressionConstraintStrength =
      [[GSCSStrength alloc] initWithName: nil strength: compressionPriority];
    [compressionConstraint setStrength: compressionConstraintStrength];
    RELEASE(compressionConstraintStrength);

    [self addInternalSolverConstraint: compressionConstraint forView: view];
}

- (void) addSupportingConstraintForLayoutViewAttribute:
           (GSLayoutViewAttribute)attribute
                                                  view: (NSView *)view
                                            constraint:
                                              (GSCSConstraint *)constraint
{
  GSCSVariable *variable = [self getExistingVariableForView: view
                                          withViewAttribute: attribute];
  GSCSConstraint *editConstraint =
    [GSCSConstraint editConstraintWithVariable: variable];
  [self addSupportingSolverConstraint: editConstraint
                  forSolverConstraint: constraint];
  [self resolveVariableForView: view attribute: attribute];
}

- (void) addObserverToConstraint: (NSLayoutConstraint *)constranit
{
  [constranit addObserver: self
                forKeyPath: @"constant"
                  options: NSKeyValueObservingOptionNew
                  context: nil];
}

- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context
{
  if ([object isKindOfClass: [NSLayoutConstraint class]])
    {
      NSLayoutConstraint *constraint = (NSLayoutConstraint *)object;
      [self updateConstraint: constraint];
    }
}

- (void) updateConstraint: (NSLayoutConstraint *)constraint
{
  GSCSConstraint *kConstraint =
    [self getExistingConstraintForAutolayoutConstraint: constraint];
  [self removeSolverConstraint: kConstraint];

  GSCSConstraint *newKConstraint =
    [self solverConstraintForConstraint: constraint];
  [self mapLayoutConstraint: constraint toSolverConstraint: newKConstraint];
  [self addSolverConstraint: newKConstraint];

  [self updateAlignmentRectsForTrackedViews];
}

- (void) removeInternalConstraintsForView: (NSView *)view
{
  NSArray *internalViewConstraints =
      [_internalConstraintsByViewIndex objectForKey: view];
  FOR_IN(GSCSConstraint *, constraint, internalViewConstraints)
    [self removeSolverConstraint: constraint];
  END_FOR_IN(internalViewConstraints);

  [_internalConstraintsByViewIndex setObject: nil forKey: view];
}

- (BOOL) hasConstraintsForView: (NSView *)view
{
  NSNumber *viewIndex = [self indexForView: view];
  return [[_constraintsByViewIndex objectForKey: viewIndex] count] > 0;
}

- (GSCSConstraint *) getExistingConstraintForAutolayoutConstraint:
    (NSLayoutConstraint *)constraint
{
  return [_constraintsByAutoLayoutConstaintHash objectForKey: constraint];
}

- (void) addConstraintAgainstViewConstraintsArray:
    (NSLayoutConstraint *)constraint
{
  NSNumber *firstItemViewIndex = [self indexForView: [constraint firstItem]];
  NSMutableArray *constraintsForView =
      [_constraintsByViewIndex objectForKey: firstItemViewIndex];
  if (!constraintsForView)
    {
      constraintsForView = [NSMutableArray array];
      [_constraintsByViewIndex setObject: constraintsForView
                                  forKey: firstItemViewIndex];
    }
  [constraintsForView addObject: constraint];

  if ([constraint secondItem] != nil)
    {
      NSNumber *secondItemViewIndex =
        [self indexForView: [constraint secondItem]];
      if ([_constraintsByViewIndex objectForKey: secondItemViewIndex])
        {
          [_constraintsByViewIndex setObject: [NSMutableArray array]
                                      forKey: secondItemViewIndex];
        }
      [[_constraintsByViewIndex objectForKey: secondItemViewIndex]
          addObject: constraint];
    }
}

- (void) removeConstraintAgainstViewConstraintsArray:
    (NSLayoutConstraint *)constraint
{
  NSNumber *firstItemViewIndex = [self indexForView: [constraint firstItem]];
  NSMutableArray *constraintsForFirstItem =
      [_constraintsByViewIndex objectForKey: firstItemViewIndex];

  NSUInteger indexOfConstraintInFirstItem =
      [constraintsForFirstItem indexOfObject: constraint];
  [constraintsForFirstItem removeObjectAtIndex: indexOfConstraintInFirstItem];

  if ([constraint secondItem] != nil)
    {
      NSNumber *secondItemViewIndexIndex =
          [self indexForView: [constraint secondItem]];
      NSMutableArray *constraintsForSecondItem =
          [_constraintsByViewIndex objectForKey: secondItemViewIndexIndex];

      NSUInteger indexOfConstraintInSecondItem =
          [constraintsForSecondItem indexOfObject: constraint];
      [constraintsForSecondItem
          removeObjectAtIndex: indexOfConstraintInSecondItem];
    }
}

- (void) updateAlignmentRectsForTrackedViews
{
  GSCSSolution *solution = [_solver solve];
  [self updateAlignmentRectsForTrackedViewsForSolution: solution];
}

- (void) updateAlignmentRectsForTrackedViewsForSolution:
    (GSCSSolution *)solution
{
  NSMutableArray *viewsWithChanges = [NSMutableArray array];
  FOR_IN(NSView *, view, _trackedViews)
    BOOL viewAlignmentRectUpdated = [self updateViewAligmentRect: solution
                                                            view: view];
    if (viewAlignmentRectUpdated)
      {
        [viewsWithChanges addObject: view];
      }
  END_FOR_IN(_trackedViews);

  [self notifyViewsOfAlignmentRectChange: viewsWithChanges];
}

- (BOOL) updateViewAligmentRect: (GSCSSolution *)solution view: (NSView *)view
{
  NSNumber *viewIndex = [self indexForView: view];
  if ([self solverCanSolveAlignmentRectForView: view solution: solution])
    {
      NSRect existingAlignmentRect =
          [self currentAlignmentRectForViewAtIndex: viewIndex];
      BOOL isExistingAlignmentRect = NSIsEmptyRect(existingAlignmentRect);
      NSRect solverAlignmentRect = [self solverAlignmentRectForView: view
                                                           solution: solution];
      [self recordAlignmentRect: solverAlignmentRect forViewIndex: viewIndex];

      if (isExistingAlignmentRect == NO
          || !NSEqualRects(solverAlignmentRect, existingAlignmentRect))
        {
          return YES;
        }
    }

  return NO;
}

- (BOOL) solverCanSolveAlignmentRectForView: (NSView *)view
                                   solution: (GSCSSolution *)solution
{
  // FIXME
  return NO;
}

- (void) recordAlignmentRect: (NSRect)alignmentRect
                forViewIndex: (NSNumber *)viewIndex
{
  NSValue *newRectValue = [NSValue valueWithRect: alignmentRect];
  [_viewAlignmentRectByViewIndex setObject: newRectValue forKey: viewIndex];
}

- (NSRect) currentAlignmentRectForViewAtIndex: (NSNumber *)viewIndex
{
  NSValue *existingRectValue =
  [_viewAlignmentRectByViewIndex objectForKey: viewIndex];
  if (existingRectValue == nil)
    {
      return NSZeroRect;
    }
  NSRect existingAlignmentRect;
  [existingRectValue getValue: &existingAlignmentRect];
  return existingAlignmentRect;
}

- (NSRect) solverAlignmentRectForView: (NSView *)view
                             solution: (GSCSSolution *)solution
{
  // FIXME Get view solution from solver
  return NSZeroRect;
}

- (void) notifyViewsOfAlignmentRectChange: (NSArray *)viewsWithChanges
{
  FOR_IN(NSView *, view, viewsWithChanges)
    [view _layoutEngineDidChangeAlignmentRect];
  END_FOR_IN(viewsWithChanges);
}

- (NSRect) alignmentRectForView: (NSView *)view
{
  // FIXME Get alignment rect for view from solver
  return NSZeroRect;
}

- (void) addSupportingSolverConstraint: (GSCSConstraint *)supportingConstraint
                   forSolverConstraint: (GSCSConstraint *)constraint
{
  [self addSolverConstraint: supportingConstraint];

  if ([_supportingConstraintsByConstraint objectForKey: constraint] == nil)
    {
          [_supportingConstraintsByConstraint
            setObject: [NSMutableArray array]
                forKey: constraint];
    }
  [[_supportingConstraintsByConstraint objectForKey: constraint]
    addObject: supportingConstraint];
}

- (void) addSolverConstraint: (GSCSConstraint *)constraint
{
  [_solverConstraints addObject: constraint];
  [_solver addConstraint: constraint];
}

- (void) removeSolverConstraint: (GSCSConstraint *)constraint
{
  [_solver removeConstraint: constraint];
  [_solverConstraints removeObject: constraint];
}

- (NSNumber *) indexForView: (NSView *)view
{
  return [_viewIndexByViewHash
      objectForKey: [NSNumber numberWithUnsignedInteger: [view hash]]];
}

- (NSArray *) constraintsForView: (NSView *)view
{
  NSNumber *viewIndex = [self indexForView: view];
  if (!viewIndex)
    {
      return [NSArray array];
    }

  NSMutableArray *constraintsForView = [NSMutableArray array];
  NSArray *viewConstraints = [_constraintsByViewIndex objectForKey: viewIndex];
  FOR_IN(NSLayoutConstraint *, constraint, viewConstraints)
    if ([constraint firstItem] == view)
      {
        [constraintsForView addObject: constraint];
      }
  END_FOR_IN(viewConstraints);

  return constraintsForView;
}

- (void) resolveVariableForView: (NSView *)view
                      attribute: (GSLayoutViewAttribute)attribute
{
    GSCSVariable *editVariable = [self getExistingVariableForView: view
                                                withViewAttribute: attribute];
    CGFloat value = [self valueForView: view attribute: attribute];

    [_solver suggestEditVariable: editVariable equals: value];
    [self updateAlignmentRectsForTrackedViews];
}

- (CGFloat) valueForView: (NSView *)view
               attribute: (GSLayoutViewAttribute)attribute
{
  switch (attribute)
    {
    case GSLayoutViewAttributeBaselineOffsetFromBottom:
      return [view baselineOffsetFromBottom];
    case GSLayoutViewAttributeFirstBaselineOffsetFromTop:
      return [view firstBaselineOffsetFromTop];
    case GSLayoutViewAttributeIntrinsicWidth:
      return [view intrinsicContentSize].width;
    case GSLayoutViewAttributeIntrinsicHeight:
      return [view intrinsicContentSize].height;
    default:
      [[NSException exceptionWithName: @"Not handled"
                               reason: @"GSLayoutAttribute not handled"
                              userInfo: nil] raise];
      return 0;
    }
}

- (void) dealloc
{
    RELEASE(_trackedViews);
    RELEASE(_viewAlignmentRectByViewIndex);
    RELEASE(_viewIndexByViewHash);
    RELEASE(_constraintsByViewIndex);
    RELEASE(_constraintsByViewIndex);
    RELEASE(_supportingConstraintsByConstraint);
    RELEASE(_constraintsByAutoLayoutConstaintHash);
    RELEASE(_internalConstraintsByViewIndex);
    RELEASE(_solverConstraints);
    RELEASE(_variablesByKey);
    RELEASE(_solver);

    [super dealloc];
}

@end
