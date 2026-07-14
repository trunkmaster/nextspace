/* Copyright (C) 2022 Free Software Foundation, Inc.
   
   By: Benjamin Johnson
   Date: 11-11-2022
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

#import "GSAutoLayoutVFLParser.h"
#import "GSFastEnumeration.h"

struct GSObjectOfPredicate
{
  NSNumber *priority;
  NSView *view;
  NSLayoutRelation relation;
  CGFloat constant;
};
typedef struct GSObjectOfPredicate GSObjectOfPredicate;

NSInteger const GS_DEFAULT_VIEW_SPACING = 8;
NSInteger const GS_DEFAULT_SUPERVIEW_SPACING = 20;

@interface GSAutoLayoutVFLParser (PrivateMethods)

- (void) parseOrientation;

- (NSArray *) parseView;

- (NSView *) parseViewName;

- (void) addFormattingConstraints:(NSView *)lastView;

- (BOOL) isVerticalEdgeFormatLayoutOption:(NSLayoutFormatOptions)options;

- (void) assertHasValidFormatLayoutOptions;

- (void) addLeadingSuperviewConstraint:(NSNumber *)spacing;

- (void) addViewSpacingConstraint:(NSNumber *)spacing
                     previousView:(NSView *)previousView;

- (void) addLeadingSuperviewConstraint:(NSNumber *)spacing;

- (void) addTrailingToSuperviewConstraint:(NSNumber *)spacing;

- (NSNumber *) parseLeadingSuperViewConnection;

- (NSNumber *) parseConnection;

- (NSNumber *) parseSimplePredicate;

- (NSArray *) parsePredicateList;

- (NSLayoutConstraint *) createConstraintFromParsedPredicate:
    (GSObjectOfPredicate *)predicate;

- (void) parseObjectOfPredicate: (GSObjectOfPredicate *)predicate;

- (NSLayoutRelation) parseRelation;

- (NSNumber *) parsePriority;

- (NSNumber *) resolveMetricWithIdentifier:(NSString *)identifier;

- (NSView *) resolveViewWithIdentifier:(NSString *)identifier;

- (NSNumber *) parseConstant;

- (NSString *) parseIdentifier;

- (void) parseViewOpen;

- (void) parseViewClose;

- (BOOL) isValidIdentifier:(NSString *)identifer;

- (NSArray *) layoutAttributesForLayoutFormatOptions:
    (NSLayoutFormatOptions)options;

- (void) failParseWithMessage:(NSString *)parseErrorMessage;

@end

@implementation GSAutoLayoutVFLParser

- (instancetype) initWithFormat:(NSString *)format
                       options:(NSLayoutFormatOptions)options
                       metrics:(NSDictionary *)metrics
                         views:(NSDictionary *)views
{
  self = [super init];
  if (self != nil)
    {
      _views = views;
      _metrics = metrics;
      _options = options;

      _scanner = [NSScanner scannerWithString: format];
      _constraints = [NSMutableArray array];
      _layoutFormatConstraints = [NSMutableArray array];
    }

  return self;
}

- (NSArray *) parse
{
  if ([[_scanner string] length] == 0)
    {
      [self failParseWithMessage: @"Cannot parse an empty string"];
    }

  [self parseOrientation];
  NSNumber *spacingConstant = [self parseLeadingSuperViewConnection];
  NSView *previousView = nil;

  while (![_scanner isAtEnd])
    {
      NSArray *viewConstraints = [self parseView];
      if (_createLeadingConstraintToSuperview)
        {
          [self addLeadingSuperviewConstraint: spacingConstant];
          _createLeadingConstraintToSuperview = NO;
        }

      if (previousView != nil)
        {
          [self addViewSpacingConstraint: spacingConstant
                            previousView: previousView];
          [self addFormattingConstraints: previousView];
        }
      [_constraints addObjectsFromArray: viewConstraints];

      spacingConstant = [self parseConnection];
      if ([_scanner scanString: @"|" intoString: NULL])
        {
          [self addTrailingToSuperviewConstraint: spacingConstant];
        }
      previousView = _view;
    }

  [_constraints addObjectsFromArray: _layoutFormatConstraints];

  return _constraints;
}

- (void) addFormattingConstraints:(NSView *)lastView
{
  BOOL hasFormatOptions = (_options & NSLayoutFormatAlignmentMask) > 0;
  if (!hasFormatOptions)
    {
      return;
    }
  [self assertHasValidFormatLayoutOptions];

  NSArray *attributes = [self layoutAttributesForLayoutFormatOptions:_options];
  FOR_IN(NSNumber*, layoutAttribute, attributes)
    NSLayoutConstraint *formatConstraint =
      [NSLayoutConstraint constraintWithItem: lastView
                                    attribute: [layoutAttribute integerValue]
                                    relatedBy: NSLayoutRelationEqual
                                      toItem: _view
                                    attribute: [layoutAttribute integerValue]
                                  multiplier: 1.0
                                    constant: 0];
    [_layoutFormatConstraints addObject: formatConstraint];
  END_FOR_IN(attributes);
}

- (void) assertHasValidFormatLayoutOptions
{
  if (_isVerticalOrientation &&
      [self isVerticalEdgeFormatLayoutOption: _options])
    {
      [self failParseWithMessage: @"A vertical alignment format option cannot "
                                 @"be used with a vertical layout"];
    }
  else if (!_isVerticalOrientation
           && ![self isVerticalEdgeFormatLayoutOption: _options])
    {
      [self failParseWithMessage: @"A horizontal alignment format option "
                                 @"cannot be used with a horizontal layout"];
    }
}

- (void) parseOrientation
{
  if ([_scanner scanString: @"V:" intoString: NULL])
    {
      _isVerticalOrientation = true;
    }
  else
    {
      [_scanner scanString: @"H:" intoString: NULL];
    }
}

- (NSArray *) parseView
{
  [self parseViewOpen];

  _view = [self parseViewName];
  NSArray *viewConstraints = [self parsePredicateList];
  [self parseViewClose];

  return viewConstraints;
}

- (NSView *) parseViewName
{
  NSString *viewName = nil;
  NSCharacterSet *viewTerminators =
      [NSCharacterSet characterSetWithCharactersInString: @"]("];
  [_scanner scanUpToCharactersFromSet: viewTerminators intoString: &viewName];

  if (viewName == nil)
    {
      [self failParseWithMessage: @"Failed to parse view name"];
    }

  if (![self isValidIdentifier: viewName])
    {
      [self failParseWithMessage:
                @"Invalid view name. A view name must be a valid C identifier "
                @"and may only contain letters, numbers and underscores"];
    }

  return [self resolveViewWithIdentifier: viewName];
}

- (BOOL) isVerticalEdgeFormatLayoutOption:(NSLayoutFormatOptions)options
{
  if (options & NSLayoutFormatAlignAllTop)
    {
      return YES;
    }
  if (options & NSLayoutFormatAlignAllBaseline)
    {
      return YES;
    }
  if (options & NSLayoutFormatAlignAllFirstBaseline)
    {
      return YES;
    }
  if (options & NSLayoutFormatAlignAllBottom)
    {
      return YES;
    }
  if (options & NSLayoutFormatAlignAllCenterY)
    {
      return YES;
    }

  return NO;
}

- (void) addViewSpacingConstraint:(NSNumber *)spacing
                     previousView:(NSView *)previousView
{
  CGFloat viewSpacingConstant
      = spacing ? [spacing doubleValue] : GS_DEFAULT_VIEW_SPACING;
  NSLayoutAttribute firstAttribute;
  NSLayoutAttribute secondAttribute;
  NSView *firstItem;
  NSView *secondItem;

  NSLayoutFormatOptions directionOptions
      = _options & NSLayoutFormatDirectionMask;
  if (_isVerticalOrientation)
    {
      firstAttribute = NSLayoutAttributeTop;
      secondAttribute = NSLayoutAttributeBottom;
      firstItem = _view;
      secondItem = previousView;
    }
  else if (directionOptions & NSLayoutFormatDirectionRightToLeft)
    {
      firstAttribute = NSLayoutAttributeLeft;
      secondAttribute = NSLayoutAttributeRight;
      firstItem = previousView;
      secondItem = _view;
    }
  else if (directionOptions & NSLayoutFormatDirectionLeftToRight)
    {
      firstAttribute = NSLayoutAttributeLeft;
      secondAttribute = NSLayoutAttributeRight;
      firstItem = _view;
      secondItem = previousView;
    }
  else
    {
      firstAttribute = NSLayoutAttributeLeading;
      secondAttribute = NSLayoutAttributeTrailing;
      firstItem = _view;
      secondItem = previousView;
    }

  NSLayoutConstraint *viewSeparatorConstraint =
      [NSLayoutConstraint constraintWithItem: firstItem
                                   attribute: firstAttribute
                                   relatedBy: NSLayoutRelationEqual
                                      toItem: secondItem
                                   attribute: secondAttribute
                                  multiplier: 1.0
                                    constant: viewSpacingConstant];

  [_constraints addObject: viewSeparatorConstraint];
}

- (void) addLeadingSuperviewConstraint:(NSNumber *)spacing
{
  NSLayoutAttribute firstAttribute;
  NSView *firstItem;
  NSView *secondItem;

  NSLayoutFormatOptions directionOptions
      = _options & NSLayoutFormatDirectionMask;
  if (_isVerticalOrientation)
    {
      firstAttribute = NSLayoutAttributeTop;
      firstItem = _view;
      secondItem = _view.superview;
    }
  else if (directionOptions & NSLayoutFormatDirectionRightToLeft)
    {
      firstAttribute = NSLayoutAttributeRight;
      firstItem = _view.superview;
      secondItem = _view;
    }
  else if (directionOptions & NSLayoutFormatDirectionLeftToRight)
    {
      firstAttribute = NSLayoutAttributeLeft;
      firstItem = _view;
      secondItem = _view.superview;
    }
  else
    {
      firstAttribute = _isVerticalOrientation ? NSLayoutAttributeTop
                                              : NSLayoutAttributeLeading;
      firstItem = _view;
      secondItem = _view.superview;
    }

  CGFloat viewSpacingConstant
      = spacing ? [spacing doubleValue] : GS_DEFAULT_SUPERVIEW_SPACING;

  NSLayoutConstraint *leadingConstraintToSuperview =
      [NSLayoutConstraint constraintWithItem: firstItem
                                   attribute: firstAttribute
                                   relatedBy: NSLayoutRelationEqual
                                      toItem: secondItem
                                   attribute: firstAttribute
                                  multiplier: 1.0
                                    constant: viewSpacingConstant];
  [_constraints addObject: leadingConstraintToSuperview];
}

- (void) addTrailingToSuperviewConstraint:(NSNumber *)spacing
{
  CGFloat viewSpacingConstant
      = spacing ? [spacing doubleValue] : GS_DEFAULT_SUPERVIEW_SPACING;

  NSLayoutFormatOptions directionOptions
      = _options & NSLayoutFormatDirectionMask;
  NSLayoutAttribute attribute;
  NSView *firstItem;
  NSView *secondItem;

  if (_isVerticalOrientation)
    {
      attribute = NSLayoutAttributeBottom;
      firstItem = _view.superview;
      secondItem = _view;
    }
  else if (directionOptions & NSLayoutFormatDirectionRightToLeft)
    {
      attribute = NSLayoutAttributeLeft;
      firstItem = _view;
      secondItem = _view.superview;
    }
  else if (directionOptions & NSLayoutFormatDirectionLeftToRight)
    {
      attribute = NSLayoutAttributeRight;
      firstItem = _view.superview;
      secondItem = _view;
    }
  else
    {
      attribute = NSLayoutAttributeTrailing;
      firstItem = _view.superview;
      secondItem = _view;
    }

  NSLayoutConstraint *trailingConstraintToSuperview =
      [NSLayoutConstraint constraintWithItem: firstItem
                                   attribute: attribute
                                   relatedBy: NSLayoutRelationEqual
                                      toItem: secondItem
                                   attribute: attribute
                                  multiplier: 1.0
                                    constant: viewSpacingConstant];
  [_constraints addObject: trailingConstraintToSuperview];
}

- (NSNumber *) parseLeadingSuperViewConnection
{
  BOOL foundSuperview = [_scanner scanString: @"|" intoString: NULL];
  if (!foundSuperview)
    {
      return nil;
    }
  _createLeadingConstraintToSuperview = YES;
  return [self parseConnection];
}

- (NSNumber *) parseConnection
{
  BOOL foundConnection = [_scanner scanString: @"-" intoString: NULL];
  if (!foundConnection)
    {
      return [NSNumber numberWithDouble: 0];
    }

  NSNumber *simplePredicateValue = [self parseSimplePredicate];
  BOOL endConnectionFound = [_scanner scanString: @"-" intoString: NULL];

  if (simplePredicateValue != nil && !endConnectionFound)
    {
      [self failParseWithMessage: @"A connection must end with a '-'"];
    }
  else if (simplePredicateValue == nil && endConnectionFound)
    {
      [self failParseWithMessage: @"Found invalid connection"];
    }

  return simplePredicateValue;
}

- (NSNumber *) parseSimplePredicate
{
  float constant;
  BOOL scanConstantResult = [_scanner scanFloat: &constant];
  if (scanConstantResult)
    {
      return [NSNumber numberWithDouble: constant];
    }
  else
    {
      NSString *metricName = nil;
      NSCharacterSet *simplePredicateTerminatorsCharacterSet =
          [NSCharacterSet characterSetWithCharactersInString: @"-[|"];
      BOOL didParseMetricName = [_scanner
          scanUpToCharactersFromSet: simplePredicateTerminatorsCharacterSet
                         intoString: &metricName];
      if (!didParseMetricName)
        {
          return nil;
        }
      if (![self isValidIdentifier: metricName])
        {
          [self failParseWithMessage:
                    @"Invalid metric identifier. Metric identifiers must be a "
                    @"valid C identifier and may only contain letters, "
                    @"numbers and underscores"];
        }

      return [self resolveMetricWithIdentifier: metricName];
    }
}

- (NSArray *) parsePredicateList
{
  BOOL startsWithPredicateList = [_scanner scanString: @"(" intoString: NULL];
  if (!startsWithPredicateList)
    {
      return [NSArray array];
    }

  NSMutableArray *viewPredicateConstraints = [NSMutableArray array];
  BOOL shouldParsePredicate = YES;
  while (shouldParsePredicate)
    {
      GSObjectOfPredicate predicate;
      [self parseObjectOfPredicate: &predicate];
      [viewPredicateConstraints
          addObject: [self createConstraintFromParsedPredicate: &predicate]];

      shouldParsePredicate = [_scanner scanString: @"," intoString: NULL];
    }

  if (![_scanner scanString: @")" intoString: NULL])
    {
      [self failParseWithMessage: @"A predicate on a view must end with ')'"];
    }

  return viewPredicateConstraints;
}

- (NSLayoutConstraint *) createConstraintFromParsedPredicate:
    (GSObjectOfPredicate *)predicate
{
  NSLayoutConstraint *constraint = nil;
  NSLayoutAttribute attribute = _isVerticalOrientation
                                    ? NSLayoutAttributeHeight
                                    : NSLayoutAttributeWidth;
  if (predicate->view != nil)
    {
      constraint = [NSLayoutConstraint constraintWithItem: _view
                                                attribute: attribute
                                                relatedBy: predicate->relation
                                                   toItem: predicate->view
                                                attribute: attribute
                                               multiplier: 1.0
                                                 constant: predicate->constant];
    }
  else
    {
      constraint = [NSLayoutConstraint
          constraintWithItem: _view
                   attribute: attribute
                   relatedBy: predicate->relation
                      toItem: nil
                   attribute: NSLayoutAttributeNotAnAttribute
                  multiplier: 1.0
                    constant: predicate->constant];
    }

  if (predicate->priority)
    {
      [constraint setPriority: [predicate->priority doubleValue]];
    }

  return constraint;
}

- (void) parseObjectOfPredicate: (GSObjectOfPredicate *)predicate
{
  NSLayoutRelation relation = [self parseRelation];

  CGFloat parsedConstant;
  NSView *predicatedView = nil;
  BOOL scanConstantResult = [_scanner scanDouble: &parsedConstant];
  if (!scanConstantResult)
    {
      NSString *identiferName = [self parseIdentifier];
      if (![self isValidIdentifier: identiferName])
        {
          [self failParseWithMessage:
                    @"Invalid metric or view identifier. Metric/View "
                    @"identifiers must be a valid C identifier and may only "
                    @"contain letters, numbers and underscores"];
        }

      NSNumber *metric = [_metrics objectForKey: identiferName];
      if (metric != nil)
        {
          parsedConstant = [metric doubleValue];
        }
      else if ([_views objectForKey: identiferName])
        {
          parsedConstant = 0;
          predicatedView = [_views objectForKey: identiferName];
        }
      else
        {
          NSString *message = [NSString
              stringWithFormat:
                  @"Failed to find constant or metric for identifier '%@'",
                  identiferName];
          [self failParseWithMessage: message];
        }
    }

  NSNumber *priorityValue = [self parsePriority];

  predicate->priority = priorityValue;
  predicate->relation = relation;
  predicate->constant = parsedConstant;
  predicate->view = predicatedView;
}

- (NSLayoutRelation) parseRelation
{
  if ([_scanner scanString: @"==" intoString: NULL])
    {
      return NSLayoutRelationEqual;
    }
  else if ([_scanner scanString: @">=" intoString: NULL])
    {
      return NSLayoutRelationGreaterThanOrEqual;
    }
  else if ([_scanner scanString: @"<=" intoString: NULL])
    {
      return NSLayoutRelationLessThanOrEqual;
    }
  else
    {
      return NSLayoutRelationEqual;
    }
}

- (NSNumber *) parsePriority
{
  NSCharacterSet *priorityMarkerCharacterSet =
      [NSCharacterSet characterSetWithCharactersInString: @"@"];
  BOOL foundPriorityMarker =
      [_scanner scanCharactersFromSet: priorityMarkerCharacterSet
                           intoString: NULL];
  if (!foundPriorityMarker)
    {
      return nil;
    }

  return [self parseConstant];
}

- (NSNumber *) resolveMetricWithIdentifier:(NSString *)identifier
{
  NSNumber *metric = [_metrics objectForKey: identifier];
  if (metric == nil)
    {
      [self failParseWithMessage: @"Found metric not inside metric dictionary"];
    }
  return metric;
}

- (NSView *) resolveViewWithIdentifier:(NSString *)identifier
{
  NSView *view = [_views objectForKey: identifier];
  if (view == nil)
    {
      [self failParseWithMessage: @"Found view not inside view dictionary"];
    }
  return view;
}

- (NSNumber *) parseConstant
{
  CGFloat constant;
  BOOL scanConstantResult = [_scanner scanDouble: &constant];
  if (scanConstantResult)
    {
      return [NSNumber numberWithFloat: constant];
    }

  NSString *metricName = [self parseIdentifier];
  if (![self isValidIdentifier: metricName])
    {
      [self failParseWithMessage:
                @"Invalid metric identifier. Metric identifiers must be a "
                @"valid C identifier and may only contain letters, numbers "
                @"and underscores"];
    }

  return [self resolveMetricWithIdentifier: metricName];
}

- (NSString *) parseIdentifier
{
  NSString *identifierName = nil;
  NSCharacterSet *identifierTerminators =
      [NSCharacterSet characterSetWithCharactersInString: @"),"];
  BOOL scannedIdentifier =
      [_scanner scanUpToCharactersFromSet: identifierTerminators
                               intoString: &identifierName];
  if (!scannedIdentifier)
    {
      [self failParseWithMessage: @"Failed to find constant or metric"];
    }

  return identifierName;
}

- (void) parseViewOpen
{
  NSCharacterSet *openViewIdentifier =
      [NSCharacterSet characterSetWithCharactersInString: @"["];
  BOOL scannedOpenBracket = [_scanner scanCharactersFromSet: openViewIdentifier
                                                 intoString: NULL];
  if (!scannedOpenBracket)
    {
      [[NSException exceptionWithName: NSInternalInconsistencyException
                               reason: @"A view must start with a '['"
                             userInfo: nil] raise];
    }
}

- (void) parseViewClose
{
  NSCharacterSet *closeViewIdentifier =
      [NSCharacterSet characterSetWithCharactersInString: @"]"];
  BOOL scannedCloseBracket =
      [_scanner scanCharactersFromSet: closeViewIdentifier intoString: NULL];
  if (!scannedCloseBracket)
    {
      [[NSException exceptionWithName: NSInternalInconsistencyException
                               reason: @"A view must end with a ']'"
                             userInfo: nil] raise];
    }
}

- (BOOL) isValidIdentifier:(NSString *)identifer
{
  NSRegularExpression *cIdentifierRegex = [NSRegularExpression
      regularExpressionWithPattern: @"^[a-zA-Z_][a-zA-Z0-9_]*$"
                           options: 0
                             error: NULL];
  NSArray *matches =
      [cIdentifierRegex matchesInString: identifer
                                options: 0
                                  range: NSMakeRange (0, identifer.length)];

  return [matches count] > 0;
}

- (NSArray *) layoutAttributesForLayoutFormatOptions:
    (NSLayoutFormatOptions)options
{
  NSMutableArray *attributes = [NSMutableArray array];

  if (options & NSLayoutFormatAlignAllLeft)
    {
      [attributes
          addObject: [NSNumber numberWithInteger: NSLayoutAttributeLeft]];
    }
  if (options & NSLayoutFormatAlignAllRight)
    {
      [attributes
          addObject: [NSNumber numberWithInteger: NSLayoutAttributeRight]];
    }
  if (options & NSLayoutFormatAlignAllTop)
    {
      [attributes addObject: [NSNumber numberWithInteger: NSLayoutAttributeTop]];
    }
  if (options & NSLayoutFormatAlignAllBottom)
    {
      [attributes
          addObject: [NSNumber numberWithInteger: NSLayoutAttributeBottom]];
    }
  if (options & NSLayoutFormatAlignAllLeading)
    {
      [attributes
          addObject: [NSNumber numberWithInteger: NSLayoutAttributeLeading]];
    }
  if (options & NSLayoutFormatAlignAllTrailing)
    {
      [attributes
          addObject: [NSNumber numberWithInteger: NSLayoutAttributeTrailing]];
    }
  if (options & NSLayoutFormatAlignAllCenterX)
    {
      [attributes
          addObject: [NSNumber numberWithInteger: NSLayoutAttributeCenterX]];
    }
  if (options & NSLayoutFormatAlignAllCenterY)
    {
      [attributes
          addObject: [NSNumber numberWithInteger: NSLayoutAttributeCenterY]];
    }
  if (options & NSLayoutFormatAlignAllBaseline)
    {
      [attributes
          addObject: [NSNumber numberWithInteger: NSLayoutAttributeBaseline]];
    }
  if (options & NSLayoutFormatAlignAllFirstBaseline)
    {
      [attributes
          addObject: [NSNumber
                        numberWithInteger: NSLayoutAttributeFirstBaseline]];
    }

  if ([attributes count] == 0)
    {
      [self failParseWithMessage:@"Unrecognized layout formatting option"];
    }

  return attributes;
}

- (void) failParseWithMessage:(NSString *)parseErrorMessage
{
  NSException *parseException = [NSException
      exceptionWithName:NSInvalidArgumentException
                 reason:[NSString stringWithFormat:
                                      @"Unable to parse constraint format: %@",
                                      parseErrorMessage]
               userInfo: nil];
  [parseException raise];
}

@end
