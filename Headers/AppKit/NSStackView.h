/* Definition of class NSStackView
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

#ifndef _NSStackView_h_GNUSTEP_GUI_INCLUDE
#define _NSStackView_h_GNUSTEP_GUI_INCLUDE

#import <AppKit/NSView.h>
#import <AppKit/NSLayoutConstraint.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_9, GS_API_LATEST)

#if	defined(__cplusplus)
extern "C" {
#endif

// Gravity
enum {
    NSStackViewGravityTop = 1,
    NSStackViewGravityLeading = 1,
    NSStackViewGravityCenter = 2,
    NSStackViewGravityBottom = 3,
    NSStackViewGravityTrailing = 3
};
typedef NSInteger NSStackViewGravity;

// Distribution
enum {
    NSStackViewDistributionGravityAreas = -1,
    NSStackViewDistributionFill = 0,
    NSStackViewDistributionFillEqually,
    NSStackViewDistributionFillProportionally,
    NSStackViewDistributionEqualSpacing,
    NSStackViewDistributionEqualCentering
};
typedef NSInteger NSStackViewDistribution;

typedef float NSStackViewVisibilityPriority;
static const NSStackViewVisibilityPriority NSStackViewVisibilityPriorityMustHold = 1000.0; 
static const NSStackViewVisibilityPriority NSStackViewVisibilityPriorityDetachOnlyIfNecessary = 900.0;
static const NSStackViewVisibilityPriority NSStackViewVisibilityPriorityNotVisible = 0.0;

static const CGFloat NSStackViewSpacingUseDefault = FLT_MAX;

@protocol NSStackViewDelegate;
  
APPKIT_EXPORT_CLASS
@interface NSStackView : NSView
{
  id<NSStackViewDelegate> _delegate;
  NSUserInterfaceLayoutOrientation _orientation;
  NSLayoutPriority _horizontalHuggingPriority;
  NSLayoutPriority _verticalHuggingPriority;
  NSLayoutPriority _horizontalClippingResistancePriority;
  NSLayoutPriority _verticalClippingResistancePriority;
  NSLayoutAttribute _alignment;
  NSLayoutAttribute _secondaryAlignment;
  NSEdgeInsets _edgeInsets;
  NSStackViewDistribution _distribution;
  CGFloat _spacing;
  BOOL _detachesHiddenViews;
  BOOL _hasFlagViewHierarchy;
  BOOL _hasEqualSpacing;
  NSMutableArray *_arrangedSubviews;
  NSMutableArray *_detachedViews;
  NSMutableArray *_views;

  // Containers
  id _beginningContainer;
  id _middleContainer;
  id _endContainer;

  NSMapTable *_customSpacingMap;
  NSMapTable *_visiblePriorityMap;
}

// Properties
- (void) setDelegate: (id<NSStackViewDelegate>)delegate;
- (id<NSStackViewDelegate>) delegate;

- (void) setOrientation: (NSUserInterfaceLayoutOrientation)o;
- (NSUserInterfaceLayoutOrientation) orientation;

- (void) setAlignment: (NSLayoutAttribute)alignment;
- (NSLayoutAttribute) alignment;

- (void) setEdgeInsets: (NSEdgeInsets)insets;
- (NSEdgeInsets) edgeInsets;

- (void) setDistribution: (NSStackViewDistribution)d;
- (NSStackViewDistribution) distribution;

- (void) setSpacing: (CGFloat)f;
- (CGFloat) spacing;

- (void) setDetachesHiddenViews: (BOOL)f;
- (BOOL) detachesHiddenViews;

- (void) setArrangedSubviews: (NSArray *)arrangedSubviews;
- (NSArray *) arrangedSubviews;

- (void) setDetachedViews: (NSArray *)detachedViews;
- (NSArray *) detachedViews;

// Instance methods
// Manage views...
+ (instancetype) stackViewWithViews: (NSArray *)views;

- (void) setCustomSpacing: (CGFloat)spacing afterView: (NSView *)v;
- (CGFloat) customSpacingAfterView: (NSView *)v;

- (void) addArrangedSubview: (NSView *)v;
- (void) insertArrangedSubview: (NSView *)v atIndex: (NSInteger)idx;
- (void) removeArrangedSubview: (NSView *)v;

// Custom priorities
- (void)setVisibilityPriority: (NSStackViewVisibilityPriority)priority
                      forView: (NSView *)v;
- (NSStackViewVisibilityPriority) visibilityPriorityForView: (NSView *)v;
 
- (NSLayoutPriority)clippingResistancePriorityForOrientation:(NSLayoutConstraintOrientation)orientation;
- (void) setClippingResistancePriority: (NSLayoutPriority)clippingResistancePriorityn
                        forOrientation: (NSLayoutConstraintOrientation)orientation;

- (NSLayoutPriority) huggingPriorityForOrientation: (NSLayoutConstraintOrientation)o;
- (void) setHuggingPriority: (NSLayoutPriority)huggingPriority
             forOrientation: (NSLayoutConstraintOrientation)o;

- (void) setHasEqualSpacing: (BOOL)f; // deprecated
- (BOOL) hasEqualSpacing; // deprecated

- (void)addView: (NSView *)view inGravity: (NSStackViewGravity)gravity;
- (void)insertView: (NSView *)view atIndex: (NSUInteger)index inGravity: (NSStackViewGravity)gravity;
- (void)removeView: (NSView *)view;
- (NSArray *) viewsInGravity: (NSStackViewGravity)gravity;
- (void)setViews: (NSArray *)views inGravity: (NSStackViewGravity)gravity;

@end

// Protocol
@protocol NSStackViewDelegate <NSObject>

- (void) stackView: (NSStackView *)stackView willDetachViews: (NSArray *)views;
- (void) stackView: (NSStackView *)stackView didReattachViews: (NSArray *)views;

@end

#if	defined(__cplusplus)
}
#endif

#endif	/* GS_API_MACOSX */

#endif	/* _NSStackView_h_GNUSTEP_GUI_INCLUDE */

