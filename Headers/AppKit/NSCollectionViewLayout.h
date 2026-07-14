/* Interface of class NSCollectionViewLayout
   Copyright (C) 2021 Free Software Foundation, Inc.
   
   By: Gregory John Casamento
   Date: 30-05-2021

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

#ifndef _NSCollectionViewLayout_h_GNUSTEP_GUI_INCLUDE
#define _NSCollectionViewLayout_h_GNUSTEP_GUI_INCLUDE

#import <Foundation/NSObject.h>
#import <Foundation/NSGeometry.h>

#import <AppKit/NSCollectionView.h>
#import <AppKit/AppKitDefines.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_11, GS_API_LATEST)

#if	defined(__cplusplus)
extern "C" {
#endif

enum
{
 NSCollectionElementCategoryItem,
 NSCollectionElementCategorySupplementaryView,
 NSCollectionElementCategoryDecorationView,
 NSCollectionElementCategoryInterItemGap
}; 
typedef NSInteger NSCollectionElementCategory;
  

typedef NSString *NSCollectionViewDecorationElementKind;
APPKIT_EXPORT NSCollectionViewSupplementaryElementKind NSCollectionElementKindInterItemGapIndicator;

@class NSCollectionViewLayoutAttributes;
@class NSCollectionView;
@class NSDictionary;
@class NSIndexPath;
@class NSMutableDictionary;
@class NSNib;
@class NSSet;

APPKIT_EXPORT_CLASS
@interface NSCollectionViewLayoutAttributes : NSObject <NSCopying>
{
  NSRect _frame;
  CGFloat _alpha;
  NSInteger _zIndex;
  BOOL _hidden; 
  NSIndexPath *_indexPath;
  NSCollectionElementCategory _representedElementCategory;
  NSString *_representedElementKind;
}

// Initializers
+ (instancetype) layoutAttributesForItemWithIndexPath: (NSIndexPath *)indexPath;
+ (instancetype) layoutAttributesForInterItemGapBeforeIndexPath: (NSIndexPath *)indexPath;
+ (instancetype) layoutAttributesForSupplementaryViewOfKind: (NSCollectionViewSupplementaryElementKind)elementKind
                                              withIndexPath: (NSIndexPath *)indexPath;
+ (instancetype)layoutAttributesForDecorationViewOfKind:(NSCollectionViewDecorationElementKind)decorationViewKind
                                              withIndexPath: (NSIndexPath*)indexPath;

// Properties
- (NSRect) frame;
- (void) setFrame: (NSRect)frame;

- (NSSize) size;
- (void) setSize: (NSSize)size;

- (CGFloat) alpha;
- (void) setAlpha: (CGFloat)alpha;

- (BOOL) isHidden;
- (void) setHidden: (BOOL)hidden;

- (NSIndexPath *) indexPath;
- (void) setIndexPath: (NSIndexPath *)indexPath;

- (NSCollectionElementCategory) representedElementCategory;
- (NSString *) representedElementKind;

- (NSInteger) zIndex;
- (void) setZIndex: (NSInteger)zIndex;
  
@end

enum
{
 NSCollectionUpdateActionInsert,
 NSCollectionUpdateActionDelete,
 NSCollectionUpdateActionReload,
 NSCollectionUpdateActionMove,
 NSCollectionUpdateActionNone
};
typedef NSInteger NSCollectionUpdateAction;

APPKIT_EXPORT_CLASS  
@interface NSCollectionViewUpdateItem : NSObject
{
  NSIndexPath *_indexPathBeforeUpdate;
  NSIndexPath *_indexPathAfterUpdate;
  NSCollectionUpdateAction _updateAction;
}

- (NSIndexPath *) indexPathBeforeUpdate;
- (NSIndexPath *) indexPathAfterUpdate;
- (NSCollectionUpdateAction) updateAction;

@end

APPKIT_EXPORT_CLASS
@interface NSCollectionViewLayoutInvalidationContext : NSObject
{
  NSPoint _contentOffsetAdjustment;
  NSSize _contentSizeAdjustment;
  NSSet *_invalidatedItemIndexPaths;
  NSDictionary *_invalidatedSupplementaryIndexPaths;
  NSDictionary *_invalidatedDecorationIndexPaths;
}

// Initializers
- (void)invalidateItemsAtIndexPaths: (NSSet *)indexPaths;
- (void)invalidateSupplementaryElementsOfKind: (NSCollectionViewSupplementaryElementKind)elementKind
                                 atIndexPaths: (NSSet *)indexPaths;
- (void)invalidateDecorationElementsOfKind: (NSCollectionViewDecorationElementKind)elementKind
                              atIndexPaths: (NSSet *)indexPaths;

// Properties
- (BOOL) invalidateEverything;
- (BOOL) invalidateDataSourceCounts;

- (NSSet *) invalidatedItemIndexPaths;

- (NSPoint) contentOffsetAdjustment;
- (void) setContentOffsetAdjustment: (NSPoint)point;

- (NSSize) contentSizeAdjustment;
- (void) setContentSizeAdjustment: (NSSize)size;

- (NSDictionary *) invalidatedSupplementaryIndexPaths;
- (NSDictionary *) invalidatedDecorationIndexPaths;

@end

APPKIT_EXPORT_CLASS
@interface NSCollectionViewLayout : NSObject <NSCoding>
{
  NSCollectionView *_collectionView; // weak
  BOOL _valid;

  Class _layoutAttributesClass;
  Class _invalidationContextClass;
  NSSize _collectionViewContentSize;
}

// Initializers
- (void)invalidateLayout;
- (void)invalidateLayoutWithContext: (NSCollectionViewLayoutInvalidationContext *)context;

- (void)registerClass: (Class)viewClass
        forDecorationViewOfKind: (NSCollectionViewDecorationElementKind)elementKind;
- (void)registerNib: (NSNib *)nib
        forDecorationViewOfKind: (NSCollectionViewDecorationElementKind)elementKind;

// Properties
- (NSCollectionView *) collectionView;
- (void) setCollectionView: (NSCollectionView *)cv;
  
@end

APPKIT_EXPORT_CLASS
@interface NSCollectionViewLayout (NSSubclassingHooks)
  
// Methods to override for specific layouts...
- (void) prepareLayout;
- (NSArray *) layoutAttributesForElementsInRect: (NSRect)rect;
- (NSCollectionViewLayoutAttributes *) layoutAttributesForItemAtIndexPath: (NSIndexPath *)indexPath;
- (NSCollectionViewLayoutAttributes *)
  layoutAttributesForSupplementaryViewOfKind: (NSCollectionViewSupplementaryElementKind)elementKind
  atIndexPath: (NSIndexPath *)indexPath;

- (NSCollectionViewLayoutAttributes *)
  layoutAttributesForDecorationViewOfKind: (NSCollectionViewDecorationElementKind)elementKind
                              atIndexPath: (NSIndexPath *)indexPath;

- (NSCollectionViewLayoutAttributes *) layoutAttributesForDropTargetAtPoint: (NSPoint)pointInCollectionView;
- (NSCollectionViewLayoutAttributes *) layoutAttributesForInterItemGapBeforeIndexPath: (NSIndexPath *)indexPath;

- (BOOL) shouldInvalidateLayoutForBoundsChange: (NSRect)newBounds;
- (NSCollectionViewLayoutInvalidationContext *) invalidationContextForBoundsChange: (NSRect)newBounds;

- (BOOL) shouldInvalidateLayoutForPreferredLayoutAttributes: (NSCollectionViewLayoutAttributes *)preferredAttributes
                                     withOriginalAttributes: (NSCollectionViewLayoutAttributes *)originalAttributes;

- (NSCollectionViewLayoutInvalidationContext *)
  invalidationContextForPreferredLayoutAttributes: (NSCollectionViewLayoutAttributes *)preferredAttributes
                           withOriginalAttributes: (NSCollectionViewLayoutAttributes *)originalAttributes;

- (NSPoint) targetContentOffsetForProposedContentOffset: (NSPoint)proposedContentOffset
                                  withScrollingVelocity: (NSPoint)velocity; 
- (NSPoint) targetContentOffsetForProposedContentOffset: (NSPoint)proposedContentOffset;

- (NSSize) collectionViewContentSize;

@end

APPKIT_EXPORT_CLASS
@interface NSCollectionViewLayout (NSUpdateSupportHooks)

// Update support
- (void) prepareForCollectionViewUpdates: (NSArray *)updateItems;
- (void) finalizeCollectionViewUpdates;
- (void) prepareForAnimatedBoundsChange: (NSRect)oldBounds;
- (void) finalizeAnimatedBoundsChange;

- (void) prepareForTransitionToLayout: (NSCollectionViewLayout *)newLayout;
- (void) prepareForTransitionFromLayout: (NSCollectionViewLayout *)oldLayout;
- (void) finalizeLayoutTransition;

- (NSCollectionViewLayoutAttributes *) initialLayoutAttributesForAppearingItemAtIndexPath: (NSIndexPath *)itemIndexPath;
- (NSCollectionViewLayoutAttributes *) finalLayoutAttributesForDisappearingItemAtIndexPath: (NSIndexPath *)itemIndexPath;
- (NSCollectionViewLayoutAttributes *)
  initialLayoutAttributesForAppearingSupplementaryElementOfKind: (NSCollectionViewSupplementaryElementKind)elementKind
                                                    atIndexPath: (NSIndexPath *)elementIndexPath;
- (NSCollectionViewLayoutAttributes *)
  finalLayoutAttributesForDisappearingSupplementaryElementOfKind: (NSCollectionViewSupplementaryElementKind)elementKind
                                                     atIndexPath: (NSIndexPath *)elementIndexPath;
- (NSCollectionViewLayoutAttributes *)
  initialLayoutAttributesForAppearingDecorationElementOfKind: (NSCollectionViewDecorationElementKind)elementKind
                                                 atIndexPath: (NSIndexPath *)decorationIndexPath;
- (NSCollectionViewLayoutAttributes *)
  finalLayoutAttributesForDisappearingDecorationElementOfKind: (NSCollectionViewDecorationElementKind)elementKind
                                                   atIndexPath: (NSIndexPath *)decorationIndexPath;

- (NSSet *) indexPathsToDeleteForSupplementaryViewOfKind: (NSCollectionViewSupplementaryElementKind)elementKind;
- (NSSet *) indexPathsToDeleteForDecorationViewOfKind: (NSCollectionViewDecorationElementKind)elementKind;
- (NSSet *) indexPathsToInsertForSupplementaryViewOfKind: (NSCollectionViewSupplementaryElementKind)elementKind;
- (NSSet *) indexPathsToInsertForDecorationViewOfKind: (NSCollectionViewDecorationElementKind)elementKind;

@end

#if	defined(__cplusplus)
}
#endif

#endif	/* GS_API_MACOSX */

#endif	/* _NSCollectionViewLayout_h_GNUSTEP_GUI_INCLUDE */

