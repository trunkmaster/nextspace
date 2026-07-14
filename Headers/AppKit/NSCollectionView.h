/* -*-objc-*-
   NSCollectionView.h

   Copyright (C) 2013,2021 Free Software Foundation, Inc.

   Author: Doug Simons (doug.simons@testplant.com)
           Frank LeGrand (frank.legrand@testplant.com)
           Gregory Casamento (greg.casamento@gmail.com)
           (Adding new delegate methods and support for layouts)

   Date: February 2013, December 2021
   
   This file is part of the GNUstep GUI Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/> or write to the 
   Free Software Foundation, 51 Franklin Street, Fifth Floor, 
   Boston, MA 02110-1301, USA.
*/

#ifndef _GNUstep_H_NSCollectionView
#define _GNUstep_H_NSCollectionView
#import <AppKit/AppKitDefines.h>

#import <AppKit/NSDragging.h>
#import <AppKit/NSNibDeclarations.h>
#import <AppKit/NSView.h>
#import <AppKit/NSUserInterfaceItemIdentification.h>

@class NSCollectionViewItem;
@class NSCollectionView;
@class NSCollectionViewLayout;
@class NSCollectionViewLayoutAttributes;
@class NSCollectionViewTransitionLayout;
@class NSPasteboard;
@class NSNib;
@class NSMapTable;
@class NSMutableDictionary;
@class NSMutableSet;

@protocol NSPasteboardWriting;

enum
{  
  NSCollectionViewDropOn = 0,
  NSCollectionViewDropBefore = 1,
};
typedef NSInteger NSCollectionViewDropOperation;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_11, GS_API_LATEST)
enum {
  NSCollectionViewItemHighlightNone = 0,
  NSCollectionViewItemHighlightForSelection = 1,
  NSCollectionViewItemHighlightForDeselection = 2,
  NSCollectionViewItemHighlightAsDropTarget = 3,
};
typedef NSInteger NSCollectionViewItemHighlightState;

enum {
  NSCollectionViewScrollPositionNone                 = 0,
  
  /*
   * Vertical positions are mutually exclusive to each other, but are bitwise or-able with 
   * the horizontal scroll positions.  Combining positions from the same grouping   
   * (horizontal or vertical) will result in an NSInvalidArgumentException.
   */
  NSCollectionViewScrollPositionTop                   = 1 << 0,
  NSCollectionViewScrollPositionCenteredVertically    = 1 << 1,
  NSCollectionViewScrollPositionBottom                = 1 << 2,
  NSCollectionViewScrollPositionNearestHorizontalEdge = 1 << 9, /* Nearer of Top,Bottom */
  
  /*
   * Likewise, the horizontal positions are mutually exclusive to each other.
   */
  NSCollectionViewScrollPositionLeft                 = 1 << 3,
  NSCollectionViewScrollPositionCenteredHorizontally = 1 << 4,
  NSCollectionViewScrollPositionRight                = 1 << 5,
  NSCollectionViewScrollPositionLeadingEdge          = 1 << 6, /* Left if LTR, Right if RTL */
  NSCollectionViewScrollPositionTrailingEdge         = 1 << 7, /* Right if LTR, Left, if RTL */
  NSCollectionViewScrollPositionNearestVerticalEdge  = 1 << 8, /* Nearer of Leading,Trailing */
};
typedef NSUInteger NSCollectionViewScrollPosition;

#endif

typedef NSString *NSCollectionViewSupplementaryElementKind;
typedef NSString *NSUserInterfaceItemIdentifier;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_11, GS_API_LATEST)
@protocol NSCollectionViewElement <NSObject, NSUserInterfaceItemIdentification>
#if GS_PROTOCOLS_HAVE_OPTIONAL
@optional
#endif

- (void) prepareForReuse;

- (void) applyLayoutAttributes: (NSCollectionViewLayoutAttributes *)layoutAttributes;

- (void) willTransitionFromLayout: (NSCollectionViewLayout *)oldLayout toLayout: (NSCollectionViewLayout *)newLayout;

- (void) didTransitionFromLayout: (NSCollectionViewLayout *)oldLayout toLayout: (NSCollectionViewLayout *)newLayout;

- (NSCollectionViewLayoutAttributes *) preferredLayoutAttributesFittingAttributes: (NSCollectionViewLayoutAttributes *)layoutAttributes;
@end
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_11, GS_API_LATEST)
@protocol NSCollectionViewDataSource <NSObject>
#if GS_PROTOCOLS_HAVE_OPTIONAL
@required
#endif
- (NSInteger) collectionView: (NSCollectionView *)collectionView
      numberOfItemsInSection: (NSInteger)section;

- (NSCollectionViewItem *) collectionView: (NSCollectionView *)collectionView
      itemForRepresentedObjectAtIndexPath: (NSIndexPath *)indexPath;
#if GS_PROTOCOLS_HAVE_OPTIONAL
@optional
#endif
- (NSInteger) numberOfSectionsInCollectionView: (NSCollectionView *)collectionView;

- (NSView *) collectionView: (NSCollectionView *)collectionView
             viewForSupplementaryElementOfKind: (NSCollectionViewSupplementaryElementKind)kind
                atIndexPath: (NSIndexPath *)indexPath;
@end
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_11, GS_API_LATEST)
@protocol NSCollectionViewPrefetching <NSObject>
#if GS_PROTOCOLS_HAVE_OPTIONAL
@required
#endif
/**
 * Load the items listed in indexPaths in collectionView before they are displayed
 */
- (void)collectionView: (NSCollectionView *)collectionView prefetchItemsAtIndexPaths: (NSArray *)indexPaths;
#if GS_PROTOCOLS_HAVE_OPTIONAL
@optional
#endif
/**
 * Cancel the prefetch request for the listed indexPaths.
 */ 
- (void)collectionView: (NSCollectionView *)collectionView cancelPrefetchingForItemsAtIndexPaths: (NSArray *)indexPaths;
@end
#endif

@protocol NSCollectionViewDelegate <NSObject>

#if GS_PROTOCOLS_HAVE_OPTIONAL
@optional
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_11, GS_API_LATEST)
/**
 * Return a boolean indicating if the indexPaths on collectionView can be dragged with the passed in event.
 */
- (BOOL) collectionView: (NSCollectionView *)collectionView
         canDragItemsAtIndexPaths: (NSSet *)indexPaths
              withEvent: (NSEvent *)event;
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
/**
 * Return a boolean indicating if the indexes on collectionView can be dragged with the passed in event.
 */
- (BOOL) collectionView: (NSCollectionView *)collectionView
  canDragItemsAtIndexes: (NSIndexSet *)indexes
              withEvent: (NSEvent *)event;
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_11, GS_API_LATEST)
/**
 * Return a boolean if the items at indexPaths can be written to the pasteboard
 */
- (BOOL) collectionView: (NSCollectionView *)collectionView
         writeItemsAtIndexPaths: (NSSet *)indexPaths
           toPasteboard: (NSPasteboard *)pasteboard;
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
/**
 * Return a boolean if the items at indexes can be written to the pasteboard
 */
- (BOOL) collectionView: (NSCollectionView *)collectionView
    writeItemsAtIndexes: (NSIndexSet *)indexes
           toPasteboard: (NSPasteboard *)pasteboard;
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_11, GS_API_LATEST)
/**
 * Returns an array of filenames for files at indexPaths that will be dropped at the destination specified by NSURL.
 */ 
- (NSArray *) collectionView: (NSCollectionView *)collectionView
              namesOfPromisedFilesDroppedAtDestination: (NSURL *)dropURL
 forDraggedItemsAtIndexPaths: (NSSet *)indexPaths;
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
/**
 * Returns an array of filenames for files at indexes that will be dropped at the destination specified by NSURL.
 */ 
- (NSArray *) collectionView: (NSCollectionView *)collectionView
              namesOfPromisedFilesDroppedAtDestination: (NSURL *)dropURL
    forDraggedItemsAtIndexes: (NSIndexSet *)indexes;
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_11, GS_API_LATEST)
/**
 * Returns an NSImage representing the items at indexPaths which are being dragged.
 */ 
- (NSImage *) collectionView: (NSCollectionView *)collectionView
              draggingImageForItemsAtIndexPaths: (NSSet *)indexPaths
                   withEvent: (NSEvent *)event
                      offset: (NSPointPointer)dragImageOffset;
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
/**
 * Returns an NSImage representing the items at indexes which are being dragged.
 */ 
- (NSImage *) collectionView: (NSCollectionView *)collectionView
              draggingImageForItemsAtIndexes: (NSIndexSet *)indexes
                   withEvent: (NSEvent *)event
                      offset: (NSPointPointer)dragImageOffset;
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_11, GS_API_LATEST)
/**
 * Return NSDragOperation when performing drag and drop on collectionView at proposedDropIndexPath.
 */
- (NSDragOperation) collectionView: (NSCollectionView *)collectionView
                      validateDrop: (id < NSDraggingInfo >)draggingInfo
                 proposedIndexPath: (NSIndexPath **)proposedDropIndexPath
                     dropOperation: (NSCollectionViewDropOperation *)proposedDropOperation;
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
/**
 * Return NSDragOperation when performing drag and drop on collectionView at proposedIndex.
 */
- (NSDragOperation) collectionView: (NSCollectionView *)collectionView
                      validateDrop: (id < NSDraggingInfo >)draggingInfo
                     proposedIndex: (NSInteger *)proposedDropIndex
                     dropOperation: (NSCollectionViewDropOperation *)proposedDropOperation;
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_11, GS_API_LATEST)
/**
 * Returns a BOOL to indicate if the drop at indexPath was accepted
 */
- (BOOL) collectionView: (NSCollectionView *)collectionView
             acceptDrop: (id < NSDraggingInfo >)draggingInfo
              indexPath: (NSIndexPath *)indexPath
          dropOperation: (NSCollectionViewDropOperation)dropOperation;
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
/**
 * Returns a BOOL to indicate if the drop at index was accepted
 */
- (BOOL) collectionView: (NSCollectionView *)collectionView
             acceptDrop: (id < NSDraggingInfo >)draggingInfo
                  index: (NSInteger)index
          dropOperation: (NSCollectionViewDropOperation)dropOperation;
#endif

/* Multi-image drag and drop */

#if OS_API_VERSION(MAC_OS_X_VERSION_10_11, GS_API_LATEST)
/**
 * Return NSPasteboardWriting object for collectionView at indexPath
 */
- (id <NSPasteboardWriting>) collectionView: (NSCollectionView *)collectionView
         pasteboardWriterForItemAtIndexPath: (NSIndexPath *)indexPath;
#endif

/**
 * Return NSPasteboardWriting object for collectionView at index
 */
- (id <NSPasteboardWriting>) collectionView: (NSCollectionView *)collectionView
             pasteboardWriterForItemAtIndex: (NSUInteger)index;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_11, GS_API_LATEST)
/**
 * Allows application to specify the screenPoint at which a dragging session will begin
 * for the given indexPaths
 */
- (void) collectionView: (NSCollectionView *)collectionView
        draggingSession: (NSDraggingSession *)session
       willBeginAtPoint: (NSPoint)screenPoint
   forItemsAtIndexPaths: (NSSet *)indexPaths;
#endif

/**
 * Allows application to specify the screenPoint at which a dragging session will begin
 * for the given indexes
 */
- (void) collectionView: (NSCollectionView *)collectionView
        draggingSession: (NSDraggingSession *)session
       willBeginAtPoint: (NSPoint)screenPoint
      forItemsAtIndexes: (NSIndexSet *)indexes;

/**
 * Allows application to specify the screenPoint at which a dragging session did end
 */
- (void) collectionView: (NSCollectionView *)collectionView
        draggingSession: (NSDraggingSession *)session
           endedAtPoint: (NSPoint)screenPoint
          dragOperation: (NSDragOperation)operation;
/**
 * Update items include in the drag operation for collectionView.
 */
- (void) collectionView: (NSCollectionView *)collectionView
         updateDraggingItemsForDrag: (id <NSDraggingInfo>)draggingInfo;

/* Selection and Highlighting */

#if OS_API_VERSION(MAC_OS_X_VERSION_10_11, GS_API_LATEST)
/**
 * Returns the set of indexPaths that should change their selection.  This is sent to inform the delegate of
 * those items that the collectionView would like to change to highlightState.
 */
- (NSSet *) collectionView: (NSCollectionView *)collectionView
            shouldChangeItemsAtIndexPaths: (NSSet *)indexPaths
          toHighlightState: (NSCollectionViewItemHighlightState)highlightState;

/**
 * This is sent to inform the delegate of those items that did change highlightState.
 */
- (void) collectionView: (NSCollectionView *)collectionView
         didChangeItemsAtIndexPaths: (NSSet *)indexPaths
       toHighlightState: (NSCollectionViewItemHighlightState)highlightState;

/**
 * Returns the set of indexPaths that should change.
 */ 
- (NSSet *) collectionView: (NSCollectionView *)collectionView
shouldSelectItemsAtIndexPaths: (NSSet *)indexPaths;

/**
 * Returns the set of NSIndexPath objects that should be deselected given the proposed indexPaths.
 */
- (NSSet *) collectionView: (NSCollectionView *)collectionView shouldDeselectItemsAtIndexPaths: (NSSet *)indexPaths;

/**
 * Called to inform the delegate of those items that were selected.
 */
- (void) collectionView: (NSCollectionView *)collectionView didSelectItemsAtIndexPaths: (NSSet *)indexPaths;

/**
 * Called to inform the delegate of those items that were deselected.
 */
- (void) collectionView: (NSCollectionView *)collectionView didDeselectItemsAtIndexPaths: (NSSet *)indexPaths;

/* Display Notification */

/**
 * Called to inform the delegate that the item representing the object at indexPath will be displayed.
 */
- (void) collectionView: (NSCollectionView *)collectionView
        willDisplayItem: (NSCollectionViewItem *)item
        forRepresentedObjectAtIndexPath: (NSIndexPath *)indexPath;

/**
 * Called to inform the delegate that the supplementary view for the elementKind will be displayed 
 * at indexPath.
 */
- (void) collectionView: (NSCollectionView *)collectionView
         willDisplaySupplementaryView: (NSView *)view
         forElementKind: (NSCollectionViewSupplementaryElementKind)elementKind
            atIndexPath: (NSIndexPath *)indexPath;

/**
 * Called to inform the delegate that the collectionView will end display of item for the object at indexPath.
 */
- (void) collectionView: (NSCollectionView *)collectionView
   didEndDisplayingItem: (NSCollectionViewItem *)item
   forRepresentedObjectAtIndexPath: (NSIndexPath *)indexPath;

/**
 * Called to inform the delegate that the collectionView will end display of supplementaryView for the 
 * object at indexPath.
 */
- (void) collectionView: (NSCollectionView *)collectionView
         didEndDisplayingSupplementaryView: (NSView *)view
       forElementOfKind: (NSCollectionViewSupplementaryElementKind)elementKind
            atIndexPath: (NSIndexPath *)indexPath;

/* Layout Transition Support */

/**
 * Called to inform the delegate that the collectionView is transitioning from the old to the new
 * layout indicated.
 */
- (NSCollectionViewTransitionLayout *) collectionView: (NSCollectionView *)collectionView
                         transitionLayoutForOldLayout: (NSCollectionViewLayout *)fromLayout
                                            newLayout: (NSCollectionViewLayout *)toLayout;
#endif
@end

APPKIT_EXPORT_CLASS
@interface NSCollectionView : NSView //<NSDraggingDestination, NSDraggingSource>
{
  // Content
  NSArray *_content;
  NSMutableArray *_items;
  NSIndexSet *_selectionIndexes;
  NSSet *_selectionIndexPaths;  
  NSArray *_backgroundColors;

  // Delegate and datasource
  IBOutlet NSCollectionViewItem *itemPrototype;
  IBOutlet id <NSCollectionViewDelegate> _delegate;
  IBOutlet id <NSCollectionViewDataSource> _dataSource;
  IBOutlet NSView *_backgroundView;
  IBOutlet id <NSCollectionViewPrefetching> _prefetchDataSource;

  // Layout
  NSCollectionViewLayout *_collectionViewLayout;

  // Managing items
  NSMutableArray *_visibleItems;
  NSMutableDictionary *_visibleSupplementaryViews;
  NSMutableSet *_indexPathsForSupplementaryElementsOfKind;

  // Private
  // Map items -> indexPath
  NSMapTable *_itemsToIndexPaths;
  NSMapTable *_indexPathsToItems;
  NSMapTable *_itemsToAttributes;
  
  // Registered class/nib for item identifier
  NSMapTable *_registeredNibs;
  NSMapTable *_registeredClasses;

  // Selection management...
  BOOL _allowsMultipleSelection;
  BOOL _isSelectable;
  BOOL _allowsEmptySelection;
  BOOL _backgroundViewScrollsWithContent;
  BOOL _allowReload;

  // Size
  NSSize _itemSize;
  NSSize _maxItemSize;
  NSSize _minItemSize;
  CGFloat _tileWidth;
  CGFloat _verticalMargin;
  CGFloat _horizontalMargin;

  NSUInteger _maxNumberOfColumns;
  NSUInteger _maxNumberOfRows;
  NSUInteger _numberOfColumns;

  // Drag & Drop
  NSDragOperation _draggingSourceOperationMaskForLocal;
  NSDragOperation _draggingSourceOperationMaskForRemote;  
  NSUInteger _draggingOnRow;
  NSUInteger _draggingOnIndex;
}

- (BOOL) allowsMultipleSelection;
- (void) setAllowsMultipleSelection: (BOOL)flag;

- (NSArray *) backgroundColors;
- (void) setBackgroundColors: (NSArray *)colors;

- (NSArray *) content;
- (void) setContent: (NSArray *)content;

- (id < NSCollectionViewDelegate >) delegate;
- (void) setDelegate: (id < NSCollectionViewDelegate >)aDelegate;

- (NSCollectionViewItem *) itemPrototype;
- (void) setItemPrototype: (NSCollectionViewItem *)prototype;

- (NSSize) maxItemSize;
- (void) setMaxItemSize: (NSSize)size;

- (NSUInteger) maxNumberOfColumns;
- (void) setMaxNumberOfColumns: (NSUInteger)number;

- (NSUInteger) maxNumberOfRows;
- (void) setMaxNumberOfRows: (NSUInteger)number;

- (NSSize) minItemSize;
- (void) setMinItemSize: (NSSize)size;

- (BOOL) isSelectable;
- (void) setSelectable: (BOOL)flag;

- (NSIndexSet *) selectionIndexes;
- (void) setSelectionIndexes: (NSIndexSet *)indexes;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_11, GS_API_LATEST)
- (NSSet *) selectionIndexPaths;
- (void) setSelectionIndexPaths: (NSSet *)indexPaths;


- (NSCollectionViewLayout *) collectionViewLayout;
- (void) setCollectionViewLayout: (NSCollectionViewLayout *)layout;
#endif

- (NSRect) frameForItemAtIndex: (NSUInteger)index;
- (NSCollectionViewItem *) itemAtIndex: (NSUInteger)index;
- (NSCollectionViewItem *) newItemForRepresentedObject: (id)object;

- (void) tile;

- (void) setDraggingSourceOperationMask: (NSDragOperation)dragOperationMask 
                               forLocal: (BOOL)localDestination;
							   
- (NSImage *) draggingImageForItemsAtIndexes: (NSIndexSet *)indexes
                                   withEvent: (NSEvent *)event
                                      offset: (NSPointPointer)dragImageOffset;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_11, GS_API_LATEST)
/* Locating Items and Views */

- (NSArray *) visibleItems;

- (NSSet *) indexPathsForVisibleItems;

- (NSArray *) visibleSupplementaryViewsOfKind: (NSCollectionViewSupplementaryElementKind)elementKind;

- (NSSet *) indexPathsForVisibleSupplementaryElementsOfKind: (NSCollectionViewSupplementaryElementKind)elementKind;

- (NSIndexPath *) indexPathForItem: (NSCollectionViewItem *)item;

- (NSIndexPath *) indexPathForItemAtPoint: (NSPoint)point;

- (NSCollectionViewItem *) itemAtIndexPath: (NSIndexPath *)indexPath;

- (NSView *)supplementaryViewForElementKind: (NSCollectionViewSupplementaryElementKind)elementKind 
                                atIndexPath: (NSIndexPath *)indexPath;

- (void) scrollToItemsAtIndexPaths: (NSSet *)indexPaths 
                    scrollPosition: (NSCollectionViewScrollPosition)scrollPosition;

/* Creating Collection view Items */

- (NSCollectionViewItem *) makeItemWithIdentifier: (NSUserInterfaceItemIdentifier)identifier 
                                     forIndexPath: (NSIndexPath *)indexPath;

- (void) registerClass: (Class)itemClass 
 forItemWithIdentifier: (NSUserInterfaceItemIdentifier)identifier;

- (void) registerNib: (NSNib *)nib 
 forItemWithIdentifier: (NSUserInterfaceItemIdentifier)identifier;

- (NSView *) makeSupplementaryViewOfKind: (NSCollectionViewSupplementaryElementKind)elementKind 
                          withIdentifier: (NSUserInterfaceItemIdentifier)identifier 
                            forIndexPath: (NSIndexPath *)indexPath;

- (void)registerClass: (Class)viewClass 
        forSupplementaryViewOfKind: (NSCollectionViewSupplementaryElementKind)kind 
       withIdentifier: (NSUserInterfaceItemIdentifier)identifier;

- (void) registerNib: (NSNib *)nib 
         forSupplementaryViewOfKind: (NSCollectionViewSupplementaryElementKind)kind 
      withIdentifier: (NSUserInterfaceItemIdentifier)identifier;

/* Providing the collection view's data */

- (id<NSCollectionViewDataSource>) dataSource;

- (void) setDataSource: (id<NSCollectionViewDataSource>)dataSource;

/* Configuring the Collection view */

- (NSView *) backgroundView;

- (void) setBackgroundView: (NSView *)backgroundView;

- (BOOL) backgroundViewScrollsWithContent;

- (void) setBackgroundViewScrollsWithContent: (BOOL)f;

/* Reloading Content */

- (void) reloadData;

- (void) reloadSections: (NSIndexSet *)sections;

- (void) reloadItemsAtIndexPaths: (NSSet *)indexPaths;

/* Prefetching Collection View Cells and Data */

- (id<NSCollectionViewPrefetching>) prefetchDataSource;

- (void) setPrefetchDataSource: (id<NSCollectionViewPrefetching>)prefetchDataSource;

/* Getting the State of the Collection View */

- (NSInteger) numberOfSections;

- (NSInteger) numberOfItemsInSection: (NSInteger)section;

/* Inserting, Moving and Deleting Items */

- (void) insertItemsAtIndexPaths: (NSSet *)indexPaths;

- (void) moveItemAtIndexPath: (NSIndexPath *)indexPath 
                 toIndexPath: (NSIndexPath *)newIndexPath;

- (void) deleteItemsAtIndexPaths: (NSSet *)indexPaths;

/* Inserting, Moving, Deleting and Collapsing Sections */

- (void) insertSections: (NSIndexSet *)sections;

- (void) moveSection: (NSInteger)section 
           toSection: (NSInteger)newSection;

- (void) deleteSections: (NSIndexSet *)sections;
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_12, GS_API_LATEST)
- (IBAction) toggleSectionCollapse: (id)sender;
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_11, GS_API_LATEST)
- (BOOL) allowsEmptySelection;

- (void) setAllowsEmptySelection: (BOOL)flag;

- (NSSet *) selectionIndexPaths; // copy

- (IBAction) selectAll: (id)sender;

- (IBAction) deselectAll: (id)sender;

- (void) selectItemsAtIndexPaths: (NSSet *)indexPaths 
                  scrollPosition: (NSCollectionViewScrollPosition)scrollPosition;

- (void) deselectItemsAtIndexPaths: (NSSet *)indexPaths;

/* Getting Layout Information */

- (NSCollectionViewLayoutAttributes *) layoutAttributesForItemAtIndexPath: (NSIndexPath *)indexPath;

- (NSCollectionViewLayoutAttributes *) layoutAttributesForSupplementaryElementOfKind: (NSCollectionViewSupplementaryElementKind)kind 
                                                                         atIndexPath: (NSIndexPath *)indexPath;
/* Animating Multiple Changes */

DEFINE_BLOCK_TYPE_NO_ARGS(GSCollectionViewPerformBatchUpdatesBlock, void);
DEFINE_BLOCK_TYPE(GSCollectionViewCompletionHandlerBlock, void, BOOL);

- (void) performBatchUpdates: (GSCollectionViewPerformBatchUpdatesBlock) updates 
           completionHandler: (GSCollectionViewCompletionHandlerBlock) completionHandler;

#endif

@end

#endif /* _GNUstep_H_NSCollectionView */
