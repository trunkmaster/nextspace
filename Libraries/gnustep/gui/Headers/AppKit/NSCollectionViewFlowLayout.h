/* Definition of class NSCollectionViewFlowLayout
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

#ifndef _NSCollectionViewFlowLayout_h_GNUSTEP_GUI_INCLUDE
#define _NSCollectionViewFlowLayout_h_GNUSTEP_GUI_INCLUDE

#import <AppKit/NSCollectionViewLayout.h>
#import <AppKit/AppKitDefines.h>

@class NSCollectionViewLayout, NSMutableIndexSet;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_11, GS_API_LATEST)

#if	defined(__cplusplus)
extern "C" {
#endif

enum
{
 NSCollectionViewScrollDirectionVertical,
 NSCollectionViewScrollDirectionHorizontal
};
typedef NSInteger NSCollectionViewScrollDirection;
  
APPKIT_EXPORT NSCollectionViewSupplementaryElementKind NSCollectionElementKindSectionHeader;
APPKIT_EXPORT NSCollectionViewSupplementaryElementKind NSCollectionElementKindSectionFooter;

APPKIT_EXPORT_CLASS  
@interface NSCollectionViewFlowLayoutInvalidationContext : NSCollectionViewLayoutInvalidationContext
{
  BOOL _invalidateFlowLayoutDelegateMetrics; 
  BOOL _invalidateFlowLayoutAttributes; 
}

- (void) setInvalidateFlowLayoutDelegateMetrics: (BOOL)flag;
- (BOOL) invalidateFlowLayoutDelegateMetrics;

- (void) setInvalidateFlowLayoutAttributes: (BOOL)flag;
- (BOOL) invalidateFlowLayoutAttributes;
@end

@protocol NSCollectionViewDelegateFlowLayout <NSCollectionViewDelegate>

- (NSSize) collectionView: (NSCollectionView *)collectionView
                   layout: (NSCollectionViewLayout*)collectionViewLayout
   sizeForItemAtIndexPath:(NSIndexPath *)indexPath;

- (NSEdgeInsets)collectionView: (NSCollectionView *)collectionView
                        layout: (NSCollectionViewLayout *)collectionViewLayout
        insetForSectionAtIndex: (NSInteger)section;
  
- (CGFloat) collectionView: (NSCollectionView *)collectionView
                    layout: (NSCollectionViewLayout *)collectionViewLayout
                    minimumLineSpacingForSectionAtIndex: (NSInteger)section;
  
- (CGFloat) collectionView: (NSCollectionView *)collectionView
                    layout: (NSCollectionViewLayout *)collectionViewLayout
                    minimumInteritemSpacingForSectionAtIndex: (NSInteger)section;
  
- (NSSize) collectionView: (NSCollectionView *)collectionView
                   layout: (NSCollectionViewLayout *)collectionViewLayout
                   referenceSizeForHeaderInSection: (NSInteger)section;
  
- (NSSize) collectionView: (NSCollectionView *)collectionView
                   layout: (NSCollectionViewLayout *)collectionViewLayout
                   referenceSizeForFooterInSection: (NSInteger)section;

@end

APPKIT_EXPORT_CLASS
@interface NSCollectionViewFlowLayout : NSCollectionViewLayout
{
  CGFloat _minimumLineSpacing;
  CGFloat _minimumInteritemSpacing;
  NSSize _itemSize;
  NSSize _estimatedItemSize; 
  NSCollectionViewScrollDirection _scrollDirection;
  NSSize _headerReferenceSize;
  NSSize _footerReferenceSize;
  NSEdgeInsets _sectionInset;
  BOOL _sectionHeadersPinToVisibleBounds;
  BOOL _sectionFootersPinToVisibleBounds;
  NSMutableIndexSet *_collapsedSections;

  NSInteger _ds; // deltas for when overflow happens...
  NSInteger _dr;

}

- (CGFloat) minimumLineSpacing;
- (void) setMinimumLineSpacing: (CGFloat)spacing;

- (CGFloat) minimumInteritemSpacing;
- (void) setMinimumInteritemSpacing: (CGFloat)spacing;
  
- (NSSize) itemSize;
- (void) setItemSize: (NSSize)itemSize;
  
- (NSSize) estimatedItemSize;
- (void) setEstimatedItemSize: (NSSize)size;
  
- (NSCollectionViewScrollDirection) scrollDirection;
- (void) setScrollDirection: (NSCollectionViewScrollDirection)direction;
  
- (NSSize) headerReferenceSize;
- (void) setHeaderReferenceSize: (NSSize)size;
  
- (NSSize) footerReferenceSize;
- (void) setFooterReferenceSize: (NSSize)size;
  
- (NSEdgeInsets) sectionInset;
- (void) setSectionInset: (NSEdgeInsets)inset;
  
- (BOOL) sectionHeadersPinToVisibleBounds;
- (void) setSectionHeadersPinToVisibleBounds: (BOOL)f;

- (BOOL) sectionFootersPinToVisibleBounds;
- (void) setSectionFootersPinToVisibleBounds: (BOOL)f;

- (BOOL) sectionAtIndexIsCollapsed: (NSUInteger)sectionIndex;

- (void) collapseSectionAtIndex: (NSUInteger)sectionIndex;

- (void) expandSectionAtIndex: (NSUInteger)sectionIndex;

@end

#if	defined(__cplusplus)
}
#endif

#endif	/* GS_API_MACOSX */

#endif	/* _NSCollectionViewFlowLayout_h_GNUSTEP_GUI_INCLUDE */

