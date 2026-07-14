/* Implementation of class NSCollectionViewLayout
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

#import "AppKit/NSCollectionViewLayout.h"
#import "AppKit/NSCollectionViewItem.h"

#import "GSFastEnumeration.h"

@interface NSCollectionView (__NSCollectionViewLayout__)
- (NSMapTable *) itemsToAttributes;
@end

@implementation NSCollectionView (__NSCollectionViewLayout__)  
- (NSMapTable *) itemsToAttributes
{
  return _itemsToAttributes;
}
@end

@implementation NSCollectionViewLayoutAttributes

// Initializers
+ (instancetype) layoutAttributesForItemWithIndexPath: (NSIndexPath *)indexPath
{
  return nil;
}

+ (instancetype) layoutAttributesForInterItemGapBeforeIndexPath: (NSIndexPath *)indexPath
{
  return nil;
}

+ (instancetype) layoutAttributesForSupplementaryViewOfKind: (NSCollectionViewSupplementaryElementKind)elementKind
                                              withIndexPath: (NSIndexPath *)indexPath
{
  return nil;
}

+ (instancetype)layoutAttributesForDecorationViewOfKind: (NSCollectionViewDecorationElementKind)decorationViewKind
                                          withIndexPath: (NSIndexPath*)indexPath
{
  return nil;
}

// Properties
- (NSRect) frame
{
  return _frame;
}

- (void) setFrame: (NSRect)frame
{
  _frame = frame;
}

- (NSSize) size
{
  return _frame.size;
}

- (void) setSize: (NSSize)size
{
  _frame.size = size;
}

- (CGFloat) alpha
{
  return _alpha;
}

- (void) setAlpha: (CGFloat)alpha
{
  _alpha = alpha;
}

- (BOOL) isHidden
{
  return _hidden;
}

- (void) setHidden: (BOOL)hidden
{
  _hidden = hidden;
}

- (NSIndexPath *) indexPath
{
  return _indexPath;
}

- (void) setIndexPath: (NSIndexPath *)indexPath
{
  _indexPath = indexPath;
}

- (NSInteger) zIndex
{
  return _zIndex;
}

- (void) setZIndex: (NSInteger)zIndex
{
  _zIndex = zIndex;
}

- (NSCollectionElementCategory) representedElementCategory
{
  return _representedElementCategory;
}

- (NSString *) representedElementKind
{
  return _representedElementKind;
}

// Copying
- (id) copyWithZone: (NSZone *)z
{
  NSCollectionViewLayoutAttributes *a = [[NSCollectionViewLayoutAttributes allocWithZone: z] init];

  [a setFrame: [self frame]];
  [a setSize: [self size]];
  [a setAlpha: [self alpha]];
  [a setHidden: [self isHidden]];
  [a setIndexPath: [self indexPath]];
  [a setZIndex: [self zIndex]];
  
  return self;
}

- (NSString *) description
{
  return [NSString stringWithFormat: @"%@ - f = %@, alpha = %f, z = %ld",
                   [super description], NSStringFromRect(_frame),
                   _alpha, _zIndex];
}

@end


@implementation NSCollectionViewUpdateItem

- (NSIndexPath *) indexPathBeforeUpdate
{
  return _indexPathBeforeUpdate;
}

- (NSIndexPath *) indexPathAfterUpdate
{
  return _indexPathAfterUpdate;
}

- (NSCollectionUpdateAction) updateAction
{
  return _updateAction;
}

@end


@implementation NSCollectionViewLayoutInvalidationContext

// Initializers
- (void)invalidateItemsAtIndexPaths: (NSSet *)indexPaths
{
}

- (void)invalidateSupplementaryElementsOfKind: (NSCollectionViewSupplementaryElementKind)elementKind
                                 atIndexPaths: (NSSet *)indexPaths
{
}

- (void)invalidateDecorationElementsOfKind: (NSCollectionViewDecorationElementKind)elementKind
                              atIndexPaths: (NSSet *)indexPaths
{
}

// Properties
- (BOOL) invalidateEverything
{
  return YES;
}

- (BOOL) invalidateDataSourceCounts
{
  return YES;
}

- (NSSet *) invalidatedItemIndexPaths
{
  return _invalidatedItemIndexPaths;
}

- (NSPoint) contentOffsetAdjustment
{
  return _contentOffsetAdjustment;
}

- (void) setContentOffsetAdjustment: (NSPoint)point
{
  _contentOffsetAdjustment = point;
}

- (NSSize) contentSizeAdjustment
{
  return _contentSizeAdjustment;
}

- (void) setContentSizeAdjustment: (NSSize)size
{
  _contentSizeAdjustment = size;
}

- (NSDictionary *) invalidatedSupplementaryIndexPaths
{
  return _invalidatedSupplementaryIndexPaths;
}

- (NSDictionary *) invalidatedDecorationIndexPaths
{
  return _invalidatedDecorationIndexPaths;
}

@end

@implementation NSCollectionViewLayout

// Initializers
- (void) _initDefaults
{
  // _itemsToAttributes = [[NSMutableDictionary alloc] init];
}

- (void)invalidateLayout
{
  _valid = NO;
  [_collectionView reloadData];
}

- (void)invalidateLayoutWithContext:(NSCollectionViewLayoutInvalidationContext *)context
{
}

- (void)registerClass: (Class)viewClass
        forDecorationViewOfKind: (NSCollectionViewDecorationElementKind)elementKind
{
}

- (void)registerNib: (NSNib *)nib
        forDecorationViewOfKind: (NSCollectionViewDecorationElementKind)elementKind
{
}

// Properties
- (NSCollectionView *) collectionView
{
  return _collectionView;
}

- (void) setCollectionView: (NSCollectionView *)cv
{
  _collectionView = cv;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
}

- (instancetype) initWithCoder: (NSCoder *)coder
{
  self = [super init];
  if (self != nil)
    {
      [self _initDefaults];
    }
  return self;
}

@end

@implementation NSCollectionViewLayout (NSSubclassingHooks)

// Methods to override for specific layouts...
- (void) prepareLayout
{
  _valid = YES;
}

- (NSArray *) layoutAttributesForElementsInRect: (NSRect)rect
{
  NSMutableArray *result = [NSMutableArray array];
  NSArray *items = [_collectionView visibleItems];
  NSMapTable *itemsToAttributes = [_collectionView itemsToAttributes];
  
  FOR_IN(NSCollectionViewItem*, i, items)
    {
      NSView *v = [i view];
      NSRect f = [v frame];
      BOOL intersects = NSIntersectsRect(f, rect);
    
      if (intersects)
        {
          NSCollectionViewLayoutAttributes *a = [itemsToAttributes objectForKey: i];
          [result addObject: a]; // add item since it intersects
        }
    }
  END_FOR_IN(items);

  return result;
}

- (NSCollectionViewLayoutAttributes *) layoutAttributesForItemAtIndexPath: (NSIndexPath *)indexPath
{
  return nil;
}

- (NSCollectionViewLayoutAttributes *)
  layoutAttributesForSupplementaryViewOfKind: (NSCollectionViewSupplementaryElementKind)elementKind
  atIndexPath: (NSIndexPath *)indexPath
{
  return nil;
}

- (NSCollectionViewLayoutAttributes *)
  layoutAttributesForDecorationViewOfKind: (NSCollectionViewDecorationElementKind)elementKind
                              atIndexPath: (NSIndexPath *)indexPath
{
  return nil;
}

- (NSCollectionViewLayoutAttributes *)layoutAttributesForDropTargetAtPoint: (NSPoint)pointInCollectionView
{
  return nil;
}

- (NSCollectionViewLayoutAttributes *)layoutAttributesForInterItemGapBeforeIndexPath: (NSIndexPath *)indexPath
{
  return nil;
}

- (BOOL) shouldInvalidateLayoutForBoundsChange: (NSRect)newBounds
{
  return NO;
}

- (NSCollectionViewLayoutInvalidationContext *)invalidationContextForBoundsChange: (NSRect)newBounds
{
  return nil;
}

- (BOOL)shouldInvalidateLayoutForPreferredLayoutAttributes: (NSCollectionViewLayoutAttributes *)preferredAttributes
                                    withOriginalAttributes: (NSCollectionViewLayoutAttributes *)originalAttributes
{
  return NO;
}

- (NSCollectionViewLayoutInvalidationContext *)
  invalidationContextForPreferredLayoutAttributes: (NSCollectionViewLayoutAttributes *)preferredAttributes
                           withOriginalAttributes: (NSCollectionViewLayoutAttributes *)originalAttributes
{
  return nil;
}

- (NSPoint) targetContentOffsetForProposedContentOffset: (NSPoint)proposedContentOffset
                                  withScrollingVelocity: (NSPoint)velocity
{
  return NSZeroPoint;
}

- (NSPoint) targetContentOffsetForProposedContentOffset: (NSPoint)proposedContentOffset
{
  return NSZeroPoint;  
}

- (NSSize) collectionViewContentSize
{
  return [_collectionView frame].size;
}

@end

@implementation NSCollectionViewLayout (NSUpdateSupportHooks)

// Update support
- (void) prepareForCollectionViewUpdates: (NSArray *)updateItems
{
}

- (void) finalizeCollectionViewUpdates
{
}

- (void) prepareForAnimatedBoundsChange: (NSRect)oldBounds
{
}

- (void) finalizeAnimatedBoundsChange
{
}

- (void) prepareForTransitionToLayout: (NSCollectionViewLayout *)newLayout
{
}

- (void) prepareForTransitionFromLayout: (NSCollectionViewLayout *)oldLayout
{
}

- (void) finalizeLayoutTransition
{
}

- (NSCollectionViewLayoutAttributes *) initialLayoutAttributesForAppearingItemAtIndexPath: (NSIndexPath *)itemIndexPath
{
  return nil;
}

- (NSCollectionViewLayoutAttributes *) finalLayoutAttributesForDisappearingItemAtIndexPath: (NSIndexPath *)itemIndexPath
{
  return nil;
}

- (NSCollectionViewLayoutAttributes *)
  initialLayoutAttributesForAppearingSupplementaryElementOfKind: (NSCollectionViewSupplementaryElementKind)elementKind
                                                    atIndexPath: (NSIndexPath *)elementIndexPath
{
  return nil;
}

- (NSCollectionViewLayoutAttributes *)
  finalLayoutAttributesForDisappearingSupplementaryElementOfKind: (NSCollectionViewSupplementaryElementKind)elementKind
                                                     atIndexPath: (NSIndexPath *)elementIndexPath
{
  return nil;
}

- (NSCollectionViewLayoutAttributes *)
  initialLayoutAttributesForAppearingDecorationElementOfKind: (NSCollectionViewDecorationElementKind)elementKind
                                                 atIndexPath: (NSIndexPath *)decorationIndexPath
{
  return nil;
}

- (NSCollectionViewLayoutAttributes *)
  finalLayoutAttributesForDisappearingDecorationElementOfKind: (NSCollectionViewDecorationElementKind)elementKind
                                                  atIndexPath: (NSIndexPath *)decorationIndexPath
{
  return nil;
}

- (NSSet *)indexPathsToDeleteForSupplementaryViewOfKind: (NSCollectionViewSupplementaryElementKind)elementKind
{
  return nil;
}

- (NSSet *)indexPathsToDeleteForDecorationViewOfKind: (NSCollectionViewDecorationElementKind)elementKind
{
  return nil;
}

- (NSSet *)indexPathsToInsertForSupplementaryViewOfKind: (NSCollectionViewSupplementaryElementKind)elementKind
{
  return nil;
}

- (NSSet *)indexPathsToInsertForDecorationViewOfKind: (NSCollectionViewDecorationElementKind)elementKind
{
  return nil;
}

@end
