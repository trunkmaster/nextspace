/* Implementation of class NSStackView
   Copyright (C) 2020 Free Software Foundation, Inc.
   
   By: Gregory John Casamento <greg.casamento@gmail.com>
   Date: 08-08-2020

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

#import "AppKit/NSStackView.h"
#import "AppKit/NSTextStorage.h"
#import "AppKit/NSTextContainer.h"
#import "AppKit/NSLayoutManager.h"
#import "AppKit/NSButton.h"

#import "GSFastEnumeration.h"

@interface NSString (__StackViewPrivate__)
- (NSRect) _rectOfString;
@end

@interface NSView (__NSViewPrivateMethods__)
- (void) _insertSubview: (NSView *)sv atIndex: (NSUInteger)idx; // implemented in NSView.m
@end

@interface NSView (__StackViewPrivate__)
- (void) _insertView: (NSView *)v atIndex: (NSUInteger)i;
- (void) _removeAllSubviews;
- (void) _addSubviews: (NSArray *)views;
@end

@interface NSStackViewContainer : NSView
{
  NSMutableArray *_nonDroppedViews;
  NSMutableDictionary *_customAfterSpaceMap;
}

- (NSArray *) nonDroppedViews;
- (NSDictionary *) customAfterSpaceMap;
@end

@implementation NSString (__StackViewPrivate__)
- (NSRect) _rectOfString;
{
  NSTextStorage *textStorage = [[NSTextStorage alloc] initWithString: self];
  NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
  NSTextContainer *textContainer = [[NSTextContainer alloc] init];
  
  [layoutManager addTextContainer:textContainer];
  [textContainer release];
  
  [textStorage addLayoutManager:layoutManager];
  [layoutManager release];
  
  //Figure out the bounding rectangle
  NSRect stringRect =
    [layoutManager boundingRectForGlyphRange:NSMakeRange(0, [layoutManager numberOfGlyphs])
                             inTextContainer:textContainer];
  return stringRect;
}
@end

@implementation NSStackViewContainer
- (instancetype) initWithCoder: (NSCoder *)coder
{
  self = [super initWithCoder: coder];
  if (self != nil)
    {
      if ([coder allowsKeyedCoding])
        {
          if ([coder containsValueForKey: @"NSStackViewContainerNonDroppedViews"])
            {
              ASSIGN(_nonDroppedViews,
                     [coder decodeObjectForKey: @"NSStackViewContainerNonDroppedViews"]);
            }

          if ([coder containsValueForKey: @"NSStackViewContainerViewToCustomAfterSpaceMap"])
            {
              ASSIGN(_customAfterSpaceMap,
                     [coder decodeObjectForKey: @"NSStackViewContainerViewToCustomAfterSpaceMap"]);
            }
        }
      else
        {
          ASSIGN(_nonDroppedViews, [coder decodeObject]);
          ASSIGN(_customAfterSpaceMap, [coder decodeObject]);
        }

      [self _addSubviews: _nonDroppedViews];
    }
  return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
  [super encodeWithCoder: coder];

  if ([coder allowsKeyedCoding])
    {
      [coder encodeObject: _nonDroppedViews
                   forKey: @"NSStackViewContainerNonDroppedViews"];
      [coder encodeObject: _customAfterSpaceMap
                   forKey: @"NSStackViewContainerViewToCustomAfterSpaceMap"];
    }
  else
    {
      [coder encodeObject: _nonDroppedViews];
      [coder encodeObject: _customAfterSpaceMap];
    }
}

- (NSArray *) nonDroppedViews
{
  return _nonDroppedViews;
}

- (NSDictionary *) customAfterSpaceMap
{
  return _customAfterSpaceMap;
}
@end

@implementation NSView (__StackViewPrivate__)
- (void) _insertView: (NSView *)v atIndex: (NSUInteger)i
{
  [self _insertSubview: v atIndex: i];
}

- (void) _removeAllSubviews
{
  NSArray *subviews = [self subviews];
  FOR_IN(NSView*, v, subviews)
    {
      [v removeFromSuperview];
    }
  END_FOR_IN(subviews);
}

- (void) _addSubviews: (NSArray *)views
{
  FOR_IN(NSView*, v, views)
    {
      [self addSubview: v];
    }
  END_FOR_IN(views);
}

@end

@implementation NSStackView

- (void) _layoutViewsWithOrientation: (NSUserInterfaceLayoutOrientation)o
{
  NSRect currentFrame = [self frame];
  NSRect newFrame = currentFrame;
  NSArray *sv = [self subviews];
  NSUInteger n = [sv count];
  CGFloat sp = [self spacing];
  CGFloat x = 0.0;
  CGFloat y = 0.0;
  CGFloat newHeight = 0.0;
  NSUInteger i = 0;
  
  // Advance vertically or horizontally depending on orientation...
  if (o == NSUserInterfaceLayoutOrientationVertical)
    {
      if (sp == 0.0)
        {
          if (n >= 0)
            {
              NSView *v = [sv objectAtIndex: 0];
              sp = [v frame].size.height;
            }
        }

      newFrame.size.height += sp; // * 2; // expand height
      newFrame.origin.y -= (sp / 2.0); // move the view down.
      newHeight = newFrame.size.height; // start at top of view...
    }
  else
    {
      if (sp == 0.0)
        {
          if (n >= 0)
            {
              NSView *v = [sv objectAtIndex: 0];
              sp = [v frame].size.width;
            }
        }

      newFrame.size.width += sp;
    }
  
  [self setFrame: newFrame];
  FOR_IN(NSView*,v,sv)
    {
      NSRect f; 
      NSString *str = nil;
      NSRect sr = NSZeroRect;

      if ([v respondsToSelector: @selector(title)])
        {
          str = [(NSButton *)v title];
        }
                           
      f = [v frame];
      if (f.origin.x < 0.0)
        {
          f.origin.x = 0.0;
        }

      if (str != nil)
        {
          sr = [str _rectOfString];
        }

      // Calculate control position...
      if (o == NSUserInterfaceLayoutOrientationVertical)
        {
          y = newHeight - ((CGFloat)i * sp) - f.size.height;              
          f.origin.y = y;
        }
      else
        {
          x = (CGFloat)i * sp;
          f.origin.x = x;
        }

      // expand width if control is too short for title...
      if (f.size.width < sr.size.width)
        {
          f.size.width = sr.size.width + 5.0;  //+5 to accomodate border...
        }
      
      [v setFrame: f];
      i++;
    }
  END_FOR_IN(sv);
  [self setNeedsDisplay: YES];
}

- (void) _refreshView
{
  NSRect currentFrame = [self frame];
  
  if (_beginningContainer != nil)
    {
      NSSize s = currentFrame.size;
      NSUInteger i = 0;
      CGFloat y = 0.0;
      CGFloat x = 0.0;
      CGFloat w = 0.0; 
      CGFloat h = 0.0;
      
      if (_orientation == NSUserInterfaceLayoutOrientationHorizontal)
        {
          w = s.width / 3.0;  // three sections, always.
          h = s.height; // since we are horiz. the height is the height of the view
        }
      else
        {
          h = s.height / 3.0; // 3 sections
          w = s.width;
        }
      
      for (i = 0; i < 3; i++)
        {
          NSRect f;
          NSStackViewContainer *c = nil;
          
          if (_orientation == NSUserInterfaceLayoutOrientationHorizontal)
            {
              x = w * (CGFloat)i;
            }
          else
            {
              y = h * (CGFloat)i;
            }
          
          f = NSMakeRect(x,y,w,h);          
          if (i == 0)
            {
              c = _beginningContainer;
            }
          if (i == 1)
            {
              c = _middleContainer;
            }
          if (i == 2)
            {
              c = _endContainer;
            }
          
          [super addSubview: c];
          [c setFrame: f];
        }
    }
  else
    {
      [self _layoutViewsWithOrientation: _orientation];
    }
  [self setNeedsDisplay: YES];
}

// Overridden methods

- (NSArray *) subviews
{
  if (_beginningContainer != nil)
    {
      NSMutableArray *result = [NSMutableArray array];
      
      [result addObjectsFromArray: [_beginningContainer nonDroppedViews]];
      [result addObjectsFromArray: [_middleContainer nonDroppedViews]];
      [result addObjectsFromArray: [_endContainer nonDroppedViews]];

      return result;
    }

  return [super subviews];
}

// Properties
- (void) setDelegate: (id<NSStackViewDelegate>)delegate
{
  _delegate = delegate;
}

- (id<NSStackViewDelegate>) delegate
{
  return _delegate;
}

- (void) setOrientation: (NSUserInterfaceLayoutOrientation)o
{
  _orientation = o;
  [self _refreshView];
}

- (NSUserInterfaceLayoutOrientation) orientation
{
  return _orientation;
}

- (void) setAlignment: (NSLayoutAttribute)alignment
{
  _alignment = alignment;
  [self _refreshView];
}

- (NSLayoutAttribute) alignment
{
  return _alignment;
}

- (void) setEdgeInsets: (NSEdgeInsets)insets
{
  _edgeInsets = insets;
  [self _refreshView];
}

- (NSEdgeInsets) edgeInsets
{
  return _edgeInsets;
}

- (void) setDistribution: (NSStackViewDistribution)d
{
  _distribution = d;
  [self _refreshView];
}

- (NSStackViewDistribution) distribution
{
  return _distribution;
}

- (void) setSpacing: (CGFloat)f
{
  _spacing = f;
  [self _refreshView];
}

- (CGFloat) spacing
{
  return _spacing;
}

- (void) setDetachesHiddenViews: (BOOL)f
{
  _detachesHiddenViews = f;
}

- (BOOL) detachesHiddenViews
{
  return _detachesHiddenViews;
}

- (void) setArrangedSubviews: (NSArray *)arrangedSubviews
{
  ASSIGN(_arrangedSubviews, arrangedSubviews);
  _distribution = NSStackViewDistributionFill;

  [self _removeAllSubviews];

  _beginningContainer = nil;
  _middleContainer = nil;
  _endContainer = nil;

  [self _addSubviews: arrangedSubviews];
  [self _refreshView];
}

- (NSArray *) arrangedSubviews
{
  return [self subviews];
}

- (void) setDetachedViews: (NSArray *)detachedViews
{
  ASSIGN(_detachedViews, detachedViews);
}

- (NSArray *) detachedViews
{
  return _detachedViews;
}

// Instance methods
// Manage views...
- (instancetype) initWithViews: (NSArray *)views
{
  self = [super init];
  if (self != nil)
    {
      NSUInteger c = [views count];
      
      _arrangedSubviews = [[NSMutableArray alloc] initWithArray: views];
      _detachedViews = [[NSMutableArray alloc] initWithCapacity: c];
      ASSIGNCOPY(_views, views);
      _customSpacingMap = RETAIN([NSMapTable weakToWeakObjectsMapTable]);
      _visiblePriorityMap = RETAIN([NSMapTable weakToWeakObjectsMapTable]);

      // Gravity...  not used by default.
      _beginningContainer = nil;
      _middleContainer = nil;
      _endContainer = nil;

      [self _refreshView];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_arrangedSubviews);
  RELEASE(_detachedViews);
  RELEASE(_views);
  RELEASE(_customSpacingMap);
  RELEASE(_visiblePriorityMap);

  RELEASE(_beginningContainer);
  RELEASE(_middleContainer);
  RELEASE(_endContainer);
  
  _delegate = nil;
  [super dealloc];
}

+ (instancetype) stackViewWithViews: (NSArray *)views
{
  return AUTORELEASE([[self alloc] initWithViews: views]);
}

- (void) setCustomSpacing: (CGFloat)spacing afterView: (NSView *)v
{
  if (_hasEqualSpacing == NO)
    {
      NSNumber *n = [NSNumber numberWithFloat: spacing];
      [_customSpacingMap setObject: n
                            forKey: v];
      [self _refreshView];
    }
}

- (CGFloat) customSpacingAfterView: (NSView *)v
{
  return [[_customSpacingMap objectForKey: v] floatValue];
}

- (void) addArrangedSubview: (NSView *)v
{
  [_arrangedSubviews addObject: v];
  [self _refreshView];
}

- (void) insertArrangedSubview: (NSView *)v atIndex: (NSInteger)idx
{
  [_arrangedSubviews insertObject: v atIndex: idx];
}

- (void) removeArrangedSubview: (NSView *)v
{
  [_arrangedSubviews removeObject: v];
}

// Custom priorities
- (void)setVisibilityPriority: (NSStackViewVisibilityPriority)priority
                      forView: (NSView *)v
{
  NSNumber *n = [NSNumber numberWithInteger: priority];
  [_visiblePriorityMap setObject: n
                          forKey: v];
  [self _refreshView];
}

- (NSStackViewVisibilityPriority) visibilityPriorityForView: (NSView *)v
{
  NSNumber *n = [_visiblePriorityMap objectForKey: v];
  NSStackViewVisibilityPriority p = (NSStackViewVisibilityPriority)[n integerValue];
  return p;
}
 
- (NSLayoutPriority)clippingResistancePriorityForOrientation:(NSLayoutConstraintOrientation)o
{
  NSLayoutPriority p = 0L;
  if (o == NSLayoutConstraintOrientationHorizontal)
    {
      p = _horizontalClippingResistancePriority;
    }
  else if (o == NSLayoutConstraintOrientationVertical)
    {
      p = _verticalClippingResistancePriority;
    }
  return p;
}

- (void) setClippingResistancePriority: (NSLayoutPriority)clippingResistancePriority
                        forOrientation: (NSLayoutConstraintOrientation)o
{
  if (o == NSLayoutConstraintOrientationHorizontal)
    {
      _horizontalClippingResistancePriority = clippingResistancePriority;
    }
  else if (o == NSLayoutConstraintOrientationVertical)
    {
      _verticalClippingResistancePriority = clippingResistancePriority;
    }
  [self _refreshView];
}

- (NSLayoutPriority) huggingPriorityForOrientation: (NSLayoutConstraintOrientation)o
{
  NSLayoutPriority p = 0L;
  if (o == NSLayoutConstraintOrientationHorizontal)
    {
      p = _horizontalHuggingPriority;
    }
  else if (o == NSLayoutConstraintOrientationVertical)
    {
      p = _verticalHuggingPriority;
    }
  return p;
}

- (void) setHuggingPriority: (NSLayoutPriority)huggingPriority
             forOrientation: (NSLayoutConstraintOrientation)o
{
  if (o == NSLayoutConstraintOrientationHorizontal)
    {
      _horizontalHuggingPriority = huggingPriority;
    }
  else if (o == NSLayoutConstraintOrientationVertical)
    {
      _verticalHuggingPriority = huggingPriority;
    }
  [self _refreshView];
}

- (void) setHasEqualSpacing: (BOOL)f
{
  _hasEqualSpacing = f;
}

- (BOOL) hasEqualSpacing
{
  return _hasEqualSpacing;
}

- (void)addView: (NSView *)view inGravity: (NSStackViewGravity)gravity
{
  if (_beginningContainer != nil)
    {
      switch (gravity)
        {
        case NSStackViewGravityTop:  // or leading...
          [_beginningContainer addSubview: view];
          break;
        case NSStackViewGravityCenter:
          [_middleContainer addSubview: view];
          break;
        case NSStackViewGravityBottom:
          [_endContainer addSubview: view]; // or trailing...
          break;
        default:
          [NSException raise: NSInternalInconsistencyException
                      format: @"Attempt to add view %@ to unknown container %ld.", view, gravity];
          break;
        }
    }
  else
    {
      [super addSubview: view];
    }
  
  [self _refreshView];
}

- (void)insertView: (NSView *)view atIndex: (NSUInteger)index inGravity: (NSStackViewGravity)gravity
{
  switch (gravity)
    {
    case NSStackViewGravityTop:  // or leading...
      [_beginningContainer _insertView: view atIndex: index];
      break;
    case NSStackViewGravityCenter:
      [_middleContainer _insertView: view atIndex: index];
      break;
    case NSStackViewGravityBottom:
      [_endContainer _insertView: view atIndex: index]; // or trailing...
      break;
    default:
      [NSException raise: NSInternalInconsistencyException
                  format: @"Attempt insert view %@ at index %ld into unknown container %ld.", view, index, gravity];
      break;
    }
  [self _refreshView];
}

- (void)removeView: (NSView *)view
{
  [view removeFromSuperview];
  [self _refreshView];
}

- (NSArray *) viewsInGravity: (NSStackViewGravity)gravity
{
  NSMutableArray *result = [NSMutableArray array];

  if (_beginningContainer != nil)
    {
      switch (gravity)
        {
        case NSStackViewGravityTop:  // or leading...
          [result addObjectsFromArray: [_beginningContainer subviews]];
          break;
        case NSStackViewGravityCenter:
          [result addObjectsFromArray: [_middleContainer subviews]];
          break;
        case NSStackViewGravityBottom:
          [result addObjectsFromArray: [_endContainer subviews]];
          break;
        default:
          [NSException raise: NSInternalInconsistencyException
                      format: @"Attempt get array of views from unknown gravity %ld.", gravity];
          break;
        }
    }
  
  return result;
}

- (void)setViews: (NSArray *)views inGravity: (NSStackViewGravity)gravity
{
  if (_beginningContainer != nil)
    {
      switch (gravity)
        {
        case NSStackViewGravityTop:  // or leading...
          [_beginningContainer _removeAllSubviews];
          [_beginningContainer _addSubviews: views];
          break;
        case NSStackViewGravityCenter:
          [_middleContainer _removeAllSubviews];
          [_middleContainer _addSubviews: views];
          break;
        case NSStackViewGravityBottom:
          [_endContainer _removeAllSubviews];
          [_endContainer _addSubviews: views];
          break;
        default:
          [NSException raise: NSInternalInconsistencyException
                      format: @"Attempt set array of views %@ into unknown gravity %ld.", views, gravity];
          break;
        }
    }
  else
    {
      [super _addSubviews: views];
    }
  
  [self _refreshView];
}

- (void) setViews: (NSArray *)views
{
  ASSIGN(_arrangedSubviews, views);
  [self _refreshView];
}

- (NSArray *) views
{
  return _arrangedSubviews;
}

// Encoding...
- (void) encodeWithCoder: (NSCoder *)coder
{
  [super encodeWithCoder: coder];
  if ([coder allowsKeyedCoding])
    {
      [coder encodeInteger: _alignment forKey: @"NSStackViewAlignment"];
      [coder encodeObject: _beginningContainer forKey: @"NSStackViewBeginningContainer"];
      [coder encodeObject: _middleContainer forKey: @"NSStackViewMiddleContainer"];
      [coder encodeObject: _endContainer forKey: @"NSStackViewEndContainer"];
      [coder encodeBool: _detachesHiddenViews forKey: @"NSStackViewDetachesHiddenViews"];
      [coder encodeFloat: _edgeInsets.bottom forKey: @"NSStackViewEdgeInsets.bottom"];
      [coder encodeFloat: _edgeInsets.left forKey: @"NSStackViewEdgeInsets.left"];
      [coder encodeFloat: _edgeInsets.right forKey: @"NSStackViewEdgeInsets.right"];
      [coder encodeFloat: _edgeInsets.top forKey: @"NSStackViewEdgeInsets.top"];
      [coder encodeBool: _hasFlagViewHierarchy forKey: @"NSStackViewHasFlagViewHierarchy"];
      [coder encodeFloat: _horizontalClippingResistancePriority forKey: @"NSStackViewHorizontalClippingResistance"];
      [coder encodeFloat: _horizontalHuggingPriority forKey: @"NSStackViewHorizontalHuggingPriority"];
      [coder encodeInteger: _orientation forKey: @"NSStackViewOrientation"];
      [coder encodeInteger: _alignment forKey: @"NSStackViewSecondaryAlignment"];
      [coder encodeFloat: _spacing forKey: @"NSStackViewSpacing"];
      [coder encodeFloat: _verticalClippingResistancePriority forKey: @"NSStackViewVerticalClippingResistance"];
      [coder encodeFloat: _verticalHuggingPriority forKey: @"NSStackViewVerticalHuggingPriority"];
      [coder encodeInteger: _distribution forKey: @"NSStackViewdistribution"];
    }
  else
    {
      [coder encodeValueOfObjCType: @encode(NSUInteger)
                                at: &_alignment];
      [coder encodeObject: _beginningContainer];
      [coder encodeObject: _middleContainer];
      [coder encodeObject: _endContainer];
      [coder encodeValueOfObjCType: @encode(BOOL)
                                at: &_detachesHiddenViews];
      [coder encodeValueOfObjCType: @encode(CGFloat)
                                at: &_edgeInsets.bottom];
      [coder encodeValueOfObjCType: @encode(CGFloat)
                                at: &_edgeInsets.left];
      [coder encodeValueOfObjCType: @encode(CGFloat)
                                at: &_edgeInsets.right];
      [coder encodeValueOfObjCType: @encode(CGFloat)
                                at: &_edgeInsets.top];
      [coder encodeValueOfObjCType: @encode(BOOL)
                                at: &_hasFlagViewHierarchy];
      [coder encodeValueOfObjCType: @encode(CGFloat)
                                at: &_horizontalClippingResistancePriority];
      [coder encodeValueOfObjCType: @encode(CGFloat)
                                at: &_horizontalHuggingPriority];
      [coder encodeValueOfObjCType: @encode(NSInteger)
                                at: &_orientation];
      [coder encodeValueOfObjCType: @encode(CGFloat)
                                at: &_secondaryAlignment];
      [coder encodeValueOfObjCType: @encode(CGFloat)
                                at: &_spacing];
      [coder encodeValueOfObjCType: @encode(CGFloat)
                                at: &_verticalClippingResistancePriority];
      [coder encodeValueOfObjCType: @encode(CGFloat)
                                at: &_verticalHuggingPriority];
      [coder encodeValueOfObjCType: @encode(NSInteger)
                                at: &_distribution];
    }
}

- (instancetype) initWithCoder: (NSCoder *)coder
{
  self = [super initWithCoder: coder];
  if (self != nil)
    {
      if ([coder allowsKeyedCoding])
        {
          if ([coder containsValueForKey: @"NSStackViewAlignment"])
            {
              _alignment = [coder decodeIntForKey: @"NSStackViewAlignment"];
            }
          if ([coder containsValueForKey: @"NSStackViewBeginningContainer"])
            {
              ASSIGN(_beginningContainer, [coder decodeObjectForKey: @"NSStackViewBeginningContainer"]);
            }
          if ([coder containsValueForKey: @"NSStackViewMiddleContainer"])
            {
              ASSIGN(_middleContainer, [coder decodeObjectForKey: @"NSStackViewMiddleContainer"]);
            }
          if ([coder containsValueForKey: @"NSStackViewEndContainer"])
            {
              ASSIGN(_endContainer, [coder decodeObjectForKey: @"NSStackViewEndContainer"]);
            }
          if ([coder containsValueForKey: @"NSStackViewDetachesHiddenViews"])
            {
              _detachesHiddenViews = [coder decodeBoolForKey: @"NSStackViewDetachesHiddenViews"];
            }
          if ([coder containsValueForKey: @"NSStackViewEdgeInsets.bottom"])
            {
              _edgeInsets.bottom = [coder decodeFloatForKey: @"NSStackViewEdgeInsets.bottom"];
            }
          if ([coder containsValueForKey: @"NSStackViewEdgeInsets.left"])
            {
              _edgeInsets.left = [coder decodeFloatForKey: @"NSStackViewEdgeInsets.left"];
            }
          if ([coder containsValueForKey: @"NSStackViewEdgeInsets.right"])
            {
              _edgeInsets.right = [coder decodeFloatForKey: @"NSStackViewEdgeInsets.right"];              
            }
          if ([coder containsValueForKey: @"NSStackViewEdgeInsets.top"])
            {
              _edgeInsets.top = [coder decodeFloatForKey: @"NSStackViewEdgeInsets.top"];              
            }
          if ([coder containsValueForKey: @"NSStackViewHasFlagViewHierarchy"])
            {
              _hasFlagViewHierarchy = [coder decodeBoolForKey: @"NSStackViewHasFlagViewHierarchy"];
            }
          if ([coder containsValueForKey: @"NSStackViewHorizontalClippingResistance"])
            {
              _horizontalClippingResistancePriority = [coder decodeFloatForKey: @"NSStackViewHorizontalClippingResistance"];
            }
          if ([coder containsValueForKey: @"NSStackViewHorizontalHuggingPriority"])
            {
              _horizontalHuggingPriority = [coder decodeFloatForKey: @"NSStackViewHorizontalHuggingPriority"];
            }
          if ([coder containsValueForKey: @"NSStackViewOrientation"])
            {
              _orientation = [coder decodeIntForKey: @"NSStackViewOrientation"];
            }
          if ([coder containsValueForKey: @"NSStackViewSecondaryAlignment"])
            {
              _secondaryAlignment = [coder decodeFloatForKey: @"NSStackViewSecondaryAlignment"];
            }
          if ([coder containsValueForKey: @"NSStackViewSpacing"])
            {
              _spacing = [coder decodeFloatForKey: @"NSStackViewSpacing"];
            }
          if ([coder containsValueForKey: @"NSStackViewVerticalClippingResistance"])
            {
              _verticalClippingResistancePriority = [coder decodeFloatForKey: @"NSStackViewVerticalClippingResistance"];
            }
          if ([coder containsValueForKey: @"NSStackViewVerticalHugging"])
            {
              _verticalHuggingPriority = [coder decodeFloatForKey: @"NSStackViewVerticalHugging"];
            }
          if ([coder containsValueForKey: @"NSStackViewdistribution"])
            {
              _distribution = [coder decodeIntForKey: @"NSStackViewdistribution"];
            }        
        }
      else
        {
          [coder decodeValueOfObjCType: @encode(NSUInteger)
                                    at: &_alignment];
          ASSIGN(_beginningContainer, [coder decodeObject]);
          [coder decodeValueOfObjCType: @encode(BOOL)
                                    at: &_detachesHiddenViews];
          [coder decodeValueOfObjCType: @encode(CGFloat)
                                    at: &_edgeInsets.bottom];
          [coder decodeValueOfObjCType: @encode(CGFloat)
                                    at: &_edgeInsets.left];
          [coder decodeValueOfObjCType: @encode(CGFloat)
                                    at: &_edgeInsets.right];
          [coder decodeValueOfObjCType: @encode(CGFloat)
                                    at: &_edgeInsets.top];
          [coder decodeValueOfObjCType: @encode(BOOL)
                                    at: &_hasFlagViewHierarchy];
          [coder decodeValueOfObjCType: @encode(CGFloat)
                                    at: &_horizontalClippingResistancePriority];
          [coder decodeValueOfObjCType: @encode(CGFloat)
                                    at: &_horizontalHuggingPriority];
          [coder decodeValueOfObjCType: @encode(NSInteger)
                                    at: &_orientation];
          [coder decodeValueOfObjCType: @encode(CGFloat)
                                    at: &_secondaryAlignment];
          [coder decodeValueOfObjCType: @encode(CGFloat)
                                    at: &_spacing];
          [coder decodeValueOfObjCType: @encode(CGFloat)
                                    at: &_verticalClippingResistancePriority];
          [coder decodeValueOfObjCType: @encode(CGFloat)
                                    at: &_verticalHuggingPriority];
          [coder decodeValueOfObjCType: @encode(NSInteger)
                                    at: &_distribution];
        }
      [self _refreshView];
    }
  return self;
}
  
@end

