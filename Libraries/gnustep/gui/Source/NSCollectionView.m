/** <title>NSCollectionView</title>

   Copyright (C) 2013, 2021 Free Software Foundation, Inc.

   Author: Doug Simons (doug.simons@testplant.com)
	   Frank LeGrand (frank.legrand@testplant.com)
	   Gregory Casamento (greg.casamento@gmail.com)
	   (Incorporate NSCollectionViewLayout logic)

   Date: February 2013, December 2021

   This file is part of the GNUstep GUI Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/> or write to the
   Free Software Foundation, 51 Franklin Street, Fifth Floor,
   Boston, MA 02110-1301, USA.
*/

#import <Foundation/NSGeometry.h>
#import <Foundation/NSIndexSet.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSMapTable.h>
#import <Foundation/NSKeyedArchiver.h>

#import "AppKit/NSApplication.h"
#import "AppKit/NSClipView.h"
#import "AppKit/NSCollectionView.h"
#import "AppKit/NSCollectionViewItem.h"
#import "AppKit/NSCollectionViewLayout.h"
#import "AppKit/NSCollectionViewGridLayout.h"
#import "AppKit/NSEvent.h"
#import "AppKit/NSGraphics.h"
#import "AppKit/NSImage.h"
#import "AppKit/NSKeyValueBinding.h"
#import "AppKit/NSNib.h"
#import "AppKit/NSPasteboard.h"
#import "AppKit/NSWindow.h"

#import "GSGuiPrivate.h"
#import "GSFastEnumeration.h"

#include <math.h>

APPKIT_DECLARE NSString* NSCollectionViewMinItemSizeKey              = @"NSMinGridSize";
APPKIT_DECLARE NSString* NSCollectionViewMaxItemSizeKey              = @"NSMaxGridSize";
APPKIT_DECLARE NSString* NSCollectionViewMaxNumberOfRowsKey          = @"NSMaxNumberOfGridRows";
APPKIT_DECLARE NSString* NSCollectionViewMaxNumberOfColumnsKey       = @"NSMaxNumberOfGridColumns";
APPKIT_DECLARE NSString* NSCollectionViewSelectableKey               = @"NSSelectable";
APPKIT_DECLARE NSString* NSCollectionViewAllowsMultipleSelectionKey  = @"NSAllowsMultipleSelection";
APPKIT_DECLARE NSString* NSCollectionViewBackgroundColorsKey         = @"NSBackgroundColors";
APPKIT_DECLARE NSString* NSCollectionViewLayoutKey                   = @"NSCollectionViewLayout";

APPKIT_DECLARE NSCollectionViewSupplementaryElementKind GSNoSupplementaryElement  = @"GSNoSupplementaryElement"; // private

/*
 * Private helper macro to check, if the method given via the selector sel
 * has been overridden in the current subclass.
 */
#define OVERRIDDEN(sel) ([_collectionViewLayout methodForSelector: @selector(sel)] != [[NSCollectionViewLayout class] instanceMethodForSelector: @selector(sel)])

/*
 * Class variables
 */
static NSString *_placeholderItem = nil;

@interface NSCollectionView (CollectionViewInternalPrivate)

- (void) _initDefaults;
- (void) _resetItemSize;
- (void) _removeItemsViews;
- (NSInteger) _indexAtPoint: (NSPoint)point;

- (NSRect) _frameForRowOfItemAtIndex: (NSUInteger)theIndex;
- (NSRect) _frameForRowsAroundItemAtIndex: (NSUInteger)theIndex;
- (NSRect) _frameForRowOfItemAtIndexPath: (NSIndexPath *)theIndex;
- (NSRect) _frameForRowsAroundItemAtIndexPath: (NSIndexPath *)theIndex;

- (void) _modifySelectionWithNewIndex: (NSUInteger)anIndex
			    direction: (int)aDirection
			       expand: (BOOL)shouldExpand;

- (void) _modifySelectionWithNewIndexPath: (NSIndexPath *)anIndex
				direction: (int)aDirection
				   expand: (BOOL)shouldExpand;

- (void) _moveDownAndExpandSelection: (BOOL)shouldExpand;
- (void) _moveUpAndExpandSelection: (BOOL)shouldExpand;
- (void) _moveLeftAndExpandSelection: (BOOL)shouldExpand;
- (void) _moveRightAndExpandSelection: (BOOL)shouldExpand;

- (BOOL) _writeItemsAtIndexes: (NSIndexSet *)indexes
		 toPasteboard: (NSPasteboard *)pasteboard;

- (BOOL) _writeItemsAtIndexPaths: (NSSet *)indexes
		    toPasteboard: (NSPasteboard *)pasteboard;

- (BOOL) _startDragOperationWithEvent: (NSEvent*)event
			 clickedIndex: (NSUInteger)index;

- (BOOL) _startDragOperationWithEvent: (NSEvent*)event
		     clickedIndexPath: (NSIndexPath *)index;

- (void) _selectWithEvent: (NSEvent *)theEvent
		    index: (NSUInteger)index;

- (void) _selectWithEvent: (NSEvent *)theEvent
		indexPath: (NSIndexPath *)indexPath;

- (void) _updateSelectionIndexPaths;
- (void) _updateSelectionIndexes;

@end

// Private class to track items so that we do not need to maintain multiple maps
// or manually track items
@interface _GSCollectionViewItemTrackingView : NSView
{
  NSCollectionViewItem *_item; // weak reference to the item...
  NSCollectionView *_collectionView; // weak reference to the CV
  NSIndexPath *_indexPath;
}

- (void) setIndexPath: (NSIndexPath *)p;
- (NSIndexPath *) indexPath;

- (void) setItem: (NSCollectionViewItem *)i;
- (NSCollectionViewItem *) item;

- (void) setCollectionView: (NSCollectionView *)cv;
- (NSCollectionView *) collectionView;

@end


@implementation _GSCollectionViewItemTrackingView : NSView

- (void) setIndexPath: (NSIndexPath *)p
{
  _indexPath = p;
}

- (NSIndexPath *) indexPath
{
  return _indexPath;
}

- (void) setItem: (NSCollectionViewItem *)i
{
  _item = i; // weak
}

- (NSCollectionViewItem *) item
{
  return _item;
}

- (void) setCollectionView: (NSCollectionView *) cv
{
  _collectionView = cv; // weak
}

- (NSCollectionView *) collectionView
{
  return _collectionView;
}

- (void) mouseDown: (NSEvent *)theEvent
{
  NSPoint initialLocation = [theEvent locationInWindow];
  // NSPoint location = [self convertPoint: initialLocation fromView: nil];
  NSEvent *lastEvent = theEvent;
  BOOL done = NO;
  NSUInteger eventMask = (NSLeftMouseUpMask
			  | NSLeftMouseDownMask
			  | NSLeftMouseDraggedMask
			  | NSPeriodicMask);
  NSDate *distantFuture = [NSDate distantFuture];

  while (!done)
    {
      lastEvent = [NSApp nextEventMatchingMask: eventMask
				     untilDate: distantFuture
					inMode: NSEventTrackingRunLoopMode
				       dequeue: YES];

      NSEventType eventType = [lastEvent type];
      NSPoint mouseLocationWin = [lastEvent locationInWindow];
      switch (eventType)
	{
	case NSLeftMouseDown:
	  break;
	case NSLeftMouseDragged:
	  if (fabs(mouseLocationWin.x - initialLocation.x) >= 2
	      || fabs(mouseLocationWin.y - initialLocation.y) >= 2)
	    {
	      if ([_collectionView _startDragOperationWithEvent: theEvent
					       clickedIndexPath: _indexPath])
		{
		  done = YES;
		}
	    }
	  break;
	case NSLeftMouseUp:
	  [_collectionView _selectWithEvent: theEvent indexPath: _indexPath];
	  done = YES;
	  break;
	default:
	  done = NO;
	  break;
	}
    }

  [[_item view] mouseDown: theEvent];
}

@end

@implementation NSCollectionView

//
// Class methods
//
+ (void) initialize
{
  if (self == [NSCollectionView class])
    {
      _placeholderItem = @"Placeholder";
      [self exposeBinding: NSContentBinding];
      [self setVersion: 1];
    }
}

- (id) initWithFrame: (NSRect)frame
{
  if ((self = [super initWithFrame:frame]))
    {
      [self _initDefaults];
    }
  return self;
}

- (void) _updateSelectionIndexPaths
{
  NSMutableSet *indexPathsSet = [NSMutableSet set];
  NSUInteger currentIndex = [_selectionIndexes firstIndex];

  while (currentIndex != NSNotFound)
    {
      [indexPathsSet addObject: [NSIndexPath indexPathForRow: currentIndex
						   inSection: 0]];
      currentIndex = [_selectionIndexes indexGreaterThanIndex: currentIndex];
    }

  ASSIGN(_selectionIndexPaths, indexPathsSet);
}

- (void) _updateSelectionIndexes
{
  NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];

  FOR_IN(NSIndexPath*, indexPath, _selectionIndexPaths)
    {
      if ([indexPath section] != 0)
	{
	  GSOnceMLog(@"Warning - NSCollectionView: section is !=0 when converting from selectionIndexPaths to selectionIndexes");
	}

      [indexSet addIndex: [indexPath item]];
    }
  END_FOR_IN(_selectionIndexPaths);

  ASSIGN(_selectionIndexes, indexSet);
}

- (void) dealloc
{
  DESTROY (_content);

  // FIXME: Not clear if we should destroy the top-level item "itemPrototype" loaded in the nib file.
  DESTROY (itemPrototype);

  DESTROY (_backgroundColors);
  DESTROY (_selectionIndexes);
  DESTROY (_items);

  // Managing items.
  DESTROY(_visibleItems);
  DESTROY(_visibleSupplementaryViews);
  DESTROY(_indexPathsForSupplementaryElementsOfKind);
  DESTROY(_itemsToAttributes);
  DESTROY(_itemsToIndexPaths);
  DESTROY(_indexPathsToItems);

  // Registered nib/class
  DESTROY(_registeredNibs);
  DESTROY(_registeredClasses);

  //DESTROY (_mouseDownEvent);
  [super dealloc];
}

-(void) _initDefaults
{
  _itemSize = NSMakeSize(0, 0);
  _tileWidth = -1.0;
  _draggingSourceOperationMaskForLocal = NSDragOperationGeneric | NSDragOperationMove | NSDragOperationCopy;
  _draggingSourceOperationMaskForRemote = NSDragOperationGeneric | NSDragOperationMove | NSDragOperationCopy;

  [self _resetItemSize];
  _content = [[NSArray alloc] init];
  _items = [[NSMutableArray alloc] init];
  _selectionIndexes = [[NSIndexSet alloc] init];
  _draggingOnIndex = NSNotFound;

  // 10.11 variables

  // Managing items.
  _visibleItems = [[NSMutableArray alloc] init];
  _visibleSupplementaryViews = [[NSMutableDictionary alloc] init];
  _indexPathsForSupplementaryElementsOfKind = [[NSMutableSet alloc] init];
  _itemsToAttributes = RETAIN([NSMapTable strongToStrongObjectsMapTable]);
  _itemsToIndexPaths = RETAIN([NSMapTable strongToStrongObjectsMapTable]);
  _indexPathsToItems = RETAIN([NSMapTable strongToStrongObjectsMapTable]);

  // Registered nib/class
  _registeredNibs = RETAIN([NSMapTable weakToStrongObjectsMapTable]);
  _registeredClasses = RETAIN([NSMapTable weakToStrongObjectsMapTable]);

  _allowReload = YES;
}

- (void) _resetItemSize
{
  if (itemPrototype && ([itemPrototype view] != nil))
    {
      _itemSize = [[itemPrototype view] frame].size;
      _minItemSize = NSMakeSize (_itemSize.width, _itemSize.height);
      _maxItemSize = NSMakeSize (_itemSize.width, _itemSize.height);
    }
  else
    {
      // FIXME: This is just arbitrary.
      // What are we suppose to do when we don't have a prototype?
      _itemSize = NSMakeSize(120.0, 100.0);
      _minItemSize = NSMakeSize(120.0, 100.0);
      _maxItemSize = NSMakeSize(120.0, 100.0);
    }
}

- (void) drawRect: (NSRect)dirtyRect
{
  // TODO: Implement "use Alternating Colors"
  if (_backgroundColors && [_backgroundColors count] > 0)
    {
      NSColor *bgColor = [_backgroundColors objectAtIndex: 0];
      [bgColor set];
      NSRectFill(dirtyRect);
    }

  NSPoint origin = dirtyRect.origin;
  NSSize size = dirtyRect.size;
  NSPoint oppositeOrigin = NSMakePoint (origin.x + size.width, origin.y + size.height);

  NSInteger firstIndexInRect = MAX(0, [self _indexAtPoint: origin]);
  // I had to extract these values from the macro to get it
  // working correctly.
  NSInteger index = [self _indexAtPoint: oppositeOrigin];
  NSInteger last = [_items count] - 1;
  NSInteger lastIndexInRect = MIN(last, index);

  for (index = firstIndexInRect; index <= lastIndexInRect; index++)
    {
      // Calling itemAtIndex: will eventually instantiate the collection view item,
      // if it hasn't been done already.
      NSCollectionViewItem *collectionItem = [self itemAtIndex: index];
      NSView *view = [collectionItem view];
      [view setFrame: [self frameForItemAtIndex: index]];
    }
}

- (BOOL) isFlipped
{
  return YES;
}

- (BOOL) allowsMultipleSelection
{
  return _allowsMultipleSelection;
}

- (void) setAllowsMultipleSelection: (BOOL)flag
{
  _allowsMultipleSelection = flag;
}

- (NSArray *) backgroundColors
{
  return _backgroundColors;
}

- (void) setBackgroundColors: (NSArray *)colors
{
  _backgroundColors = [colors copy];
  [self setNeedsDisplay: YES];
}

- (NSArray *) content
{
  return _content;
}

- (void) setContent: (NSArray *)content
{
  NSInteger i;

  ASSIGN(_content, content);
  [self _removeItemsViews];

  RELEASE (_items);
  _items = [[NSMutableArray alloc] initWithCapacity: [_content count]];

  for (i = 0; i < [_content count]; i++)
    {
      [_items addObject: _placeholderItem];
    }

  if (!itemPrototype)
    {
      return;
    }
  else
    {
      [self _resetItemSize];
      // Force recalculation of each item's frame
      _itemSize = _minItemSize;
      _tileWidth = -1.0;
      [self tile];
    }
}

- (id < NSCollectionViewDelegate >) delegate
{
  return _delegate;
}

- (void) setDelegate: (id < NSCollectionViewDelegate >)aDelegate
{
  _delegate = aDelegate;
}

- (NSCollectionViewItem *) itemPrototype
{
  return itemPrototype;
}

- (void) setItemPrototype: (NSCollectionViewItem *)prototype
{
  ASSIGN(itemPrototype, prototype);
  [self _resetItemSize];
}

- (CGFloat) verticalMargin
{
  return _verticalMargin;
}

- (void) setVerticalMargin: (CGFloat)margin
{
  if (_verticalMargin == margin)
    return;

  _verticalMargin = margin;
  [self tile];
}

- (NSSize) maxItemSize
{
  return _maxItemSize;
}

- (void) setMaxItemSize: (NSSize)size
{
  if (NSEqualSizes(_maxItemSize, size))
    return;

  _maxItemSize = size;
  [self tile];
}

- (NSUInteger) maxNumberOfColumns
{
  return _maxNumberOfColumns;
}

- (void) setMaxNumberOfColumns: (NSUInteger)number
{
  _maxNumberOfColumns = number;
}

- (NSUInteger) maxNumberOfRows
{
  return _maxNumberOfRows;
}

- (void) setMaxNumberOfRows: (NSUInteger)number
{
  _maxNumberOfRows = number;
}

- (NSSize) minItemSize
{
  return _minItemSize;
}

- (void) setMinItemSize: (NSSize)size
{
  if (NSEqualSizes(_minItemSize, size))
    return;

  _minItemSize = size;
  [self tile];
}

- (BOOL) isSelectable
{
  return _isSelectable;
}

- (void) setSelectable: (BOOL)flag
{
  _isSelectable = flag;
  if (!_isSelectable)
    {
      NSInteger index = -1;
      while ((index = [_selectionIndexes indexGreaterThanIndex: index]) != NSNotFound)
	{
	  id item = [_items objectAtIndex: index];
	  if ([item respondsToSelector: @selector(setSelected:)])
	    {
	      [item setSelected: NO];
	    }
	}

      FOR_IN(NSIndexPath*, i, _selectionIndexPaths)
	{
	  id item = [self itemAtIndexPath: i];
	  if ([item respondsToSelector: @selector(setSelected:)])
	    {
	      [item setSelected: NO];
	    }
	}
      END_FOR_IN(_selectionIndexPaths);
    }
}

- (NSSet *) selectionIndexPaths
{
  return _selectionIndexPaths;
}

- (void) setSelectionIndexPaths: (NSSet *)paths
{
  NSSet *indexPaths = paths;

  if (!_isSelectable)
    {
      return;
    }

  if ([_selectionIndexPaths isEqual: indexPaths])
    {
      return;
    }
  else
    {
      ASSIGN(_selectionIndexPaths, indexPaths);
    }


  if ([_delegate respondsToSelector: @selector(collectionView:shouldSelectItemsAtIndexPaths:)])
    {
      indexPaths = [_delegate collectionView: self
			      shouldSelectItemsAtIndexPaths: indexPaths];
    }

  // First unselect all of the items
  FOR_IN(id, item, _visibleItems)
    {
      if ([item respondsToSelector: @selector(setSelected:)])
	{
	  [item setSelected: NO];
	}
    }
  END_FOR_IN(_visibleItems);

  // Now select all that are selected
  FOR_IN(NSIndexPath*, p, indexPaths)
    {
      id item = [self itemAtIndexPath: p];
      if ([item respondsToSelector: @selector(setSelected:)])
	{
	  [item setSelected: YES];
	}
    }
  END_FOR_IN(indexPaths);

  if ([_delegate respondsToSelector: @selector(collectionView:didSelectItemsAtIndexPaths:)])
    {
      [_delegate collectionView: self didSelectItemsAtIndexPaths: indexPaths];
    }

  [self _updateSelectionIndexes];
}

- (NSIndexSet *) selectionIndexes
{
  return _selectionIndexes;
}

- (void) setSelectionIndexes: (NSIndexSet *)indexes
{
  if (!_isSelectable)
    {
      return;
    }

  if (![_selectionIndexes isEqual: indexes])
    {
      ASSIGN(_selectionIndexes, indexes);
    }

  NSUInteger index = 0;
  while (index < [_items count])
    {
      id item = [_items objectAtIndex: index];
      if ([item respondsToSelector: @selector(setSelected:)])
	{
	  [item setSelected: NO];
	}
      index++;
    }

  index = -1;
  while ((index = [_selectionIndexes indexGreaterThanIndex: index]) !=
	 NSNotFound)
    {
      id item = [_items objectAtIndex: index];
      if ([item respondsToSelector: @selector(setSelected:)])
	{
	  [item setSelected: YES];
	}
    }

  [self _updateSelectionIndexPaths];
}

- (NSCollectionViewLayout *) collectionViewLayout
{
  return _collectionViewLayout;
}

- (void) setCollectionViewLayout: (NSCollectionViewLayout *)layout
{
  if (_collectionViewLayout != layout)
    {
      ASSIGN(_collectionViewLayout, layout);

      [_collectionViewLayout setCollectionView: self]; // weak reference
      [self reloadData];
    }
}

- (NSRect) frameForItemAtIndex: (NSUInteger)theIndex
{
  NSRect itemFrame = NSMakeRect (0,0,0,0);
  NSInteger index;
  NSUInteger count = [_items count];
  CGFloat x = 0;
  CGFloat y = -_itemSize.height;

  if (_maxNumberOfColumns > 0 && _maxNumberOfRows > 0)
    {
      count = MIN(count, _maxNumberOfColumns * _maxNumberOfRows);
    }

  for (index = 0; index < count; ++index)
    {
      if (index % _numberOfColumns == 0)
	{
	  x = 0;
	  y += _verticalMargin + _itemSize.height;
	}

      if (index == theIndex)
	{
	  NSInteger draggingOffset = 0;

	  if (_draggingOnIndex != NSNotFound)
	    {
	      NSInteger draggingOnRow = (_draggingOnIndex / _numberOfColumns);
	      NSInteger currentIndexRow = (theIndex / _numberOfColumns);

	      if (draggingOnRow == currentIndexRow)
		{
		  if (index < _draggingOnIndex)
		    {
		      draggingOffset = -20;
		    }
		  else
		    {
		      draggingOffset = 20;
		    }
		}
	    }
	  itemFrame = NSMakeRect ((x + draggingOffset), y, _itemSize.width, _itemSize.height);
	  break;
	}

      x += _itemSize.width + _horizontalMargin;
    }
    if(_maxNumberOfColumns == 1) {
      itemFrame.size.width = self.frame.size.width;
    }
  return itemFrame;
}

- (NSRect) _frameForRowOfItemAtIndex: (NSUInteger)theIndex
{
  NSRect itemFrame = [self frameForItemAtIndex: theIndex];

  return NSMakeRect (0, itemFrame.origin.y, [self bounds].size.width, itemFrame.size.height);
}

// Returns the frame of an item's row with the row above and the row below
- (NSRect) _frameForRowsAroundItemAtIndex: (NSUInteger)theIndex
{
  NSRect itemRowFrame = [self _frameForRowOfItemAtIndex: theIndex];
  CGFloat y = MAX (0, itemRowFrame.origin.y - itemRowFrame.size.height);
  CGFloat height = MIN (itemRowFrame.size.height * 3, [self bounds].size.height);

  return NSMakeRect(0, y, itemRowFrame.size.width, height);
}

- (NSCollectionViewItem *) itemAtIndex: (NSUInteger)index
{
  id item = [_items objectAtIndex: index];

  if (item == _placeholderItem)
    {
      item = [self newItemForRepresentedObject: [_content objectAtIndex: index]];
      [_items replaceObjectAtIndex: index withObject: item];
      if ([[self selectionIndexes] containsIndex: index])
	{
	  [item setSelected: YES];
	}
      [self addSubview: [item view]];
      RELEASE(item);
    }
  return item;
}

- (NSCollectionViewItem *) newItemForRepresentedObject: (id)object
{
  NSCollectionViewItem *collectionItem = nil;
  if (itemPrototype)
    {
      collectionItem = [itemPrototype copy];
      [collectionItem setRepresentedObject: object];
    }
  return collectionItem;
}

- (void) _removeItemsViews
{
  if (!_items)
    return;

  NSUInteger count = [_items count];

  while (count--)
    {
      id item = [_items objectAtIndex: count];

      if ([item respondsToSelector: @selector(view)])
	{
	  [[item view] removeFromSuperview];
	  [item setSelected: NO];
	}
    }
}

- (void) tile
{
  // TODO: - Animate items, Add Fade-in/Fade-out (as in Cocoa)
  //       - Put the tiling on a delay
  if (_collectionViewLayout)
    {
      [self reloadData];
      return;
    }

  if (!_items)
    return;

  CGFloat width = [self bounds].size.width;

  if (width == _tileWidth)
    return;

  NSSize itemSize = NSMakeSize(_minItemSize.width, _minItemSize.height);

  _numberOfColumns = MAX(1.0, floor(width / itemSize.width));

  if (_maxNumberOfColumns > 0)
    {
      _numberOfColumns = MIN(_maxNumberOfColumns, _numberOfColumns);
    }

  if (_numberOfColumns == 0)
    {
      _numberOfColumns = 1;
    }

  CGFloat remaining = width - _numberOfColumns * itemSize.width;

  if (remaining > 0 && itemSize.width < _maxItemSize.width)
    {
      itemSize.width = MIN(_maxItemSize.width, itemSize.width +
			   floor(remaining / _numberOfColumns));
    }

  if (_maxNumberOfColumns == 1 && itemSize.width <
      _maxItemSize.width && itemSize.width < width)
    {
      itemSize.width = MIN(_maxItemSize.width, width);
    }

  if (!NSEqualSizes(_itemSize, itemSize))
    {
      _itemSize = itemSize;
    }

  NSInteger index;
  NSUInteger count = [_items count];

  if (_maxNumberOfColumns > 0 && _maxNumberOfRows > 0)
    {
      count = MIN(count, _maxNumberOfColumns * _maxNumberOfRows);
    }

  _horizontalMargin = floor((width - _numberOfColumns * itemSize.width) /
			    (_numberOfColumns + 1));
  CGFloat y = -itemSize.height;

  for (index = 0; index < count; ++index)
    {
      if (index % _numberOfColumns == 0)
	{
	  y += _verticalMargin + itemSize.height;
	}
    }

  id superview = [self superview];
  CGFloat proposedHeight = y + itemSize.height + _verticalMargin;
  if ([superview isKindOfClass: [NSClipView class]])
    {
      NSSize superviewSize = [superview bounds].size;
      proposedHeight = MAX(superviewSize.height, proposedHeight);
    }

  _tileWidth = width;
  [self setFrameSize: NSMakeSize(width, proposedHeight)];
  [self setNeedsDisplay: YES];
}

- (void) resizeSubviewsWithOldSize: (NSSize)aSize
{
  NSSize currentSize = [self frame].size;
  if (!NSEqualSizes(currentSize, aSize))
    {
      [self tile];
    }
}

- (id) initWithCoder: (NSCoder *)aCoder
{
  self = [super initWithCoder:aCoder];

  if (self)
    {
      [self _initDefaults];
      if ([aCoder allowsKeyedCoding])
	{
	  if ([aCoder containsValueForKey: NSCollectionViewMinItemSizeKey])
	    {
	      _minItemSize = [aCoder decodeSizeForKey: NSCollectionViewMinItemSizeKey];
	    }

	  if ([aCoder containsValueForKey: NSCollectionViewMaxItemSizeKey])
	    {
	      _maxItemSize = [aCoder decodeSizeForKey: NSCollectionViewMaxItemSizeKey];
	    }

	  if ([aCoder containsValueForKey: NSCollectionViewMaxNumberOfRowsKey])
	    {
	      _maxNumberOfRows = [aCoder decodeIntForKey: NSCollectionViewMaxNumberOfRowsKey];
	    }

	  if ([aCoder containsValueForKey: NSCollectionViewMaxNumberOfColumnsKey])
	    {
	      _maxNumberOfColumns = [aCoder decodeIntForKey: NSCollectionViewMaxNumberOfColumnsKey];
	    }

	  //_verticalMargin = [aCoder decodeFloatForKey: NSCollectionViewVerticalMarginKey];

	  if ([aCoder containsValueForKey: NSCollectionViewSelectableKey])
	    {
	      _isSelectable = [aCoder decodeBoolForKey: NSCollectionViewSelectableKey];
	    }

	  if ([aCoder containsValueForKey: NSCollectionViewAllowsMultipleSelectionKey])
	    {
	      _allowsMultipleSelection = [aCoder decodeBoolForKey: NSCollectionViewAllowsMultipleSelectionKey];
	    }

	  if ([aCoder containsValueForKey: NSCollectionViewBackgroundColorsKey])
	    {
	      [self setBackgroundColors: [aCoder decodeObjectForKey: NSCollectionViewBackgroundColorsKey]];
	    }

	  if ([aCoder containsValueForKey: NSCollectionViewLayoutKey])
	    {
	      [self setCollectionViewLayout: [aCoder decodeObjectForKey: NSCollectionViewLayoutKey]];
	    }
	}
      else
	{
	  int version = [aCoder versionForClassName: @"NSCollectionView"];

	  _minItemSize = [aCoder decodeSize];
	  _maxItemSize = [aCoder decodeSize];
	  decode_NSUInteger(aCoder, &_maxNumberOfRows);
	  decode_NSUInteger(aCoder, &_maxNumberOfColumns);
	  [aCoder decodeValueOfObjCType: @encode(BOOL) at: &_isSelectable];
	  [self setBackgroundColors: [aCoder decodeObject]]; // decode color...

	  if (version > 0)
	    {
	      [self setCollectionViewLayout: [aCoder decodeObject]];
	    }
	}

      if (NSEqualSizes(_minItemSize, NSZeroSize))
	{
	  _minItemSize = NSMakeSize(10.0, 10.0);
	}


      if (NSEqualSizes(_maxItemSize, NSZeroSize))
	{
	  _maxItemSize = NSMakeSize(100.0, 100.0);
	}
    }

  return self;
}

- (void) encodeWithCoder: (NSCoder *)aCoder
{
  [super encodeWithCoder: aCoder];
  if ([aCoder allowsKeyedCoding])
    {
      if (!NSEqualSizes(_minItemSize, NSMakeSize(0, 0)))
	{
	  [aCoder encodeSize: _minItemSize forKey: NSCollectionViewMinItemSizeKey];
	}

      if (!NSEqualSizes(_maxItemSize, NSMakeSize(0, 0)))
	{
	  [aCoder encodeSize: _maxItemSize forKey: NSCollectionViewMaxItemSizeKey];
	}

      [aCoder encodeInt: _maxNumberOfRows
		 forKey: NSCollectionViewMaxNumberOfRowsKey];
      [aCoder encodeInt: _maxNumberOfColumns
		 forKey: NSCollectionViewMaxNumberOfColumnsKey];

      [aCoder encodeBool: _isSelectable
		  forKey: NSCollectionViewSelectableKey];
      [aCoder encodeBool: _allowsMultipleSelection
		  forKey: NSCollectionViewAllowsMultipleSelectionKey];

      //[aCoder encodeCGFloat: _verticalMargin forKey: NSCollectionViewVerticalMarginKey];
      [aCoder encodeObject: _backgroundColors
		    forKey: NSCollectionViewBackgroundColorsKey];

      [aCoder encodeObject: _collectionViewLayout
		    forKey: NSCollectionViewLayoutKey];
    }
  else
    {
      [aCoder encodeSize: _minItemSize];
      [aCoder encodeSize: _maxItemSize];
      encode_NSUInteger(aCoder, &_maxNumberOfRows);
      encode_NSUInteger(aCoder, &_maxNumberOfColumns);
      [aCoder encodeValueOfObjCType: @encode(BOOL) at: &_isSelectable];
      [aCoder encodeObject: [self backgroundColors]]; // encode color...
      [aCoder encodeObject: [self collectionViewLayout]];
    }
}

- (void) mouseDown: (NSEvent *)theEvent
{
  NSPoint initialLocation = [theEvent locationInWindow];
  NSPoint location = [self convertPoint: initialLocation fromView: nil];
  NSEvent *lastEvent = theEvent;
  BOOL done = NO;
  NSUInteger eventMask = (NSLeftMouseUpMask
			  | NSLeftMouseDownMask
			  | NSLeftMouseDraggedMask
			  | NSPeriodicMask);
  NSDate *distantFuture = [NSDate distantFuture];

  if (_collectionViewLayout)
    {
      [self hitTest: initialLocation]; // resets selection so one click touches the tracking view.
    }
  else
    {
      NSInteger index = [self _indexAtPoint: location];

      while (!done)
	{
	  lastEvent = [NSApp nextEventMatchingMask: eventMask
					 untilDate: distantFuture
					    inMode: NSEventTrackingRunLoopMode
					   dequeue: YES];
	  NSEventType eventType = [lastEvent type];
	  NSPoint mouseLocationWin = [lastEvent locationInWindow];
	  switch (eventType)
	    {
	    case NSLeftMouseDown:
	      break;
	    case NSLeftMouseDragged:
	      if (fabs(mouseLocationWin.x - initialLocation.x) >= 2
		  || fabs(mouseLocationWin.y - initialLocation.y) >= 2)
		{
		  if ([self _startDragOperationWithEvent: theEvent clickedIndex: index])
		    {
		      done = YES;
		    }
		}
	      break;
	    case NSLeftMouseUp:
	      [self _selectWithEvent: theEvent index: index];
	      done = YES;
	      break;
	    default:
	      done = NO;
	      break;
	    }
	}
    }
}

- (void) _selectWithEvent: (NSEvent *)theEvent index: (NSUInteger)index
{
  NSMutableIndexSet *currentIndexSet = [[NSMutableIndexSet alloc] initWithIndexSet: [self selectionIndexes]];

  if (_isSelectable && (index < [_items count]))
    {
      if (_allowsMultipleSelection
	  && (([theEvent modifierFlags] & NSControlKeyMask)
	      || ([theEvent modifierFlags] & NSShiftKeyMask)))
	{
	  if ([theEvent modifierFlags] & NSControlKeyMask)
	    {
	      if ([currentIndexSet containsIndex: index])
		{
		  [currentIndexSet removeIndex: index];
		}
	      else
		{
		  [currentIndexSet addIndex: index];
		}
	      [self setSelectionIndexes: currentIndexSet];
	    }
	  else if ([theEvent modifierFlags] & NSShiftKeyMask)
	    {
	      NSUInteger firstSelectedIndex = [currentIndexSet firstIndex];
	      NSRange selectedRange;

	      if (firstSelectedIndex == NSNotFound)
		{
		  selectedRange = NSMakeRange(index, index);
		}
	      else if (index < firstSelectedIndex)
		{
		  selectedRange = NSMakeRange(index, (firstSelectedIndex - index + 1));
		}
	      else
		{
		  selectedRange = NSMakeRange(firstSelectedIndex, (index - firstSelectedIndex + 1));
		}
	      [currentIndexSet addIndexesInRange: selectedRange];
	      [self setSelectionIndexes: currentIndexSet];
	    }
	}
      else
	{
	  [self setSelectionIndexes: [NSIndexSet indexSetWithIndex: index]];
	}
      [[self window] makeFirstResponder: self];
    }
  else
    {
      [self setSelectionIndexes: [NSIndexSet indexSet]];
    }
  RELEASE (currentIndexSet);
}

- (NSInteger) _indexAtPoint: (NSPoint)point
{
  NSInteger row = floor(point.y / (_itemSize.height + _verticalMargin));
  NSInteger column = floor(point.x / (_itemSize.width + _horizontalMargin));
  return (column + (row * _numberOfColumns));
}

- (void) _selectWithEvent: (NSEvent *)theEvent indexPath: (NSIndexPath *)index
{
  NSMutableSet *currentSet = [[NSMutableSet alloc] initWithSet: [self selectionIndexPaths]];

  if (_isSelectable)
    {
      if (_allowsMultipleSelection
	  && (([theEvent modifierFlags] & NSControlKeyMask)
	      || ([theEvent modifierFlags] & NSShiftKeyMask)))
	{
	  if ([theEvent modifierFlags] & NSControlKeyMask)
	    {
	      if ([currentSet containsObject: index])
		{
		  [currentSet removeObject: index];
		}
	      else
		{
		  [currentSet addObject: index];
		}
	      [self setSelectionIndexPaths: currentSet];
	    }
	  else if ([theEvent modifierFlags] & NSShiftKeyMask)
	    {
	      // TODO: Implement multiple selection logic
	      [self setSelectionIndexPaths: currentSet];
	    }
	}
      else
	{
	  [self setSelectionIndexPaths: [NSSet setWithObject: index]];
	}
      [[self window] makeFirstResponder: self];
    }
  else
    {
      [self setSelectionIndexPaths: [NSSet set]];
    }

  RELEASE (currentSet);
}

- (BOOL) acceptsFirstResponder
{
  return YES;
}

/* MARK: Keyboard Interaction */

- (void) keyDown: (NSEvent *)theEvent
{
  [self interpretKeyEvents: [NSArray arrayWithObject: theEvent]];
}

-(void) moveUp: (id)sender
{
  [self _moveUpAndExpandSelection: NO];
}

-(void) moveUpAndModifySelection: (id)sender
{
  [self _moveUpAndExpandSelection: YES];
}

- (void) _moveUpAndExpandSelection: (BOOL)shouldExpand
{
  NSInteger index = [[self selectionIndexes] firstIndex];
  if (index != NSNotFound && index >= _numberOfColumns)
    {
      [self _modifySelectionWithNewIndex: index - _numberOfColumns
			       direction: -1
				  expand: shouldExpand];
    }
}

-(void) moveDown: (id)sender
{
  [self _moveDownAndExpandSelection: NO];
}

-(void) moveDownAndModifySelection: (id)sender
{
  [self _moveDownAndExpandSelection: YES];
}

-(void) _moveDownAndExpandSelection: (BOOL)shouldExpand
{
  NSInteger index = [[self selectionIndexes] lastIndex];
  if (index != NSNotFound && (index + _numberOfColumns) < [_items count])
    {
      [self _modifySelectionWithNewIndex: index + _numberOfColumns
			       direction: 1
				  expand: shouldExpand];
    }
}

-(void) moveLeft: (id)sender
{
  [self _moveLeftAndExpandSelection: NO];
}

-(void) moveLeftAndModifySelection: (id)sender
{
  [self _moveLeftAndExpandSelection: YES];
}

-(void) moveBackwardAndModifySelection: (id)sender
{
  [self _moveLeftAndExpandSelection: YES];
}

-(void) _moveLeftAndExpandSelection: (BOOL)shouldExpand
{
  NSUInteger index = [[self selectionIndexes] firstIndex];
  if (index != NSNotFound && index != 0)
    {
      [self _modifySelectionWithNewIndex: index - 1 direction: -1 expand: shouldExpand];
    }
}

-(void) moveRight: (id)sender
{
  [self _moveRightAndExpandSelection: NO];
}

-(void) moveRightAndModifySelection: (id)sender
{
  [self _moveRightAndExpandSelection: YES];
}

-(void) moveForwardAndModifySelection: (id)sender
{
  [self _moveRightAndExpandSelection: YES];
}

-(void) _moveRightAndExpandSelection: (BOOL)shouldExpand
{
  NSUInteger index = [[self selectionIndexes] lastIndex];
  if (index != NSNotFound && index != ([_items count] - 1))
    {
      [self _modifySelectionWithNewIndex: index + 1 direction: 1 expand: shouldExpand];
    }
}

- (void) _modifySelectionWithNewIndex: (NSUInteger)anIndex
			    direction: (int)aDirection
			       expand: (BOOL)shouldExpand
{
  anIndex = MIN(MAX(anIndex, 0), [_items count] - 1);

  if (_allowsMultipleSelection && shouldExpand)
    {
      NSMutableIndexSet *newIndexSet = [[NSMutableIndexSet alloc] initWithIndexSet: _selectionIndexes];
      NSUInteger firstIndex = [newIndexSet firstIndex];
      NSUInteger lastIndex = [newIndexSet lastIndex];
      if (aDirection == -1)
	{
	  [newIndexSet addIndexesInRange:NSMakeRange (anIndex, firstIndex - anIndex + 1)];
	}
      else
	{
	  [newIndexSet addIndexesInRange:NSMakeRange (lastIndex, anIndex - lastIndex + 1)];
	}
      [self setSelectionIndexes: newIndexSet];
      RELEASE (newIndexSet);
    }
  else
    {
      [self setSelectionIndexes: [NSIndexSet indexSetWithIndex: anIndex]];
    }

  [self scrollRectToVisible: [self frameForItemAtIndex: anIndex]];
}


/* MARK: Drag & Drop */

-(NSDragOperation) draggingSourceOperationMaskForLocal: (BOOL)isLocal
{
  if (isLocal)
    {
      return _draggingSourceOperationMaskForLocal;
    }
  else
    {
      return _draggingSourceOperationMaskForRemote;
    }
}

-(void) setDraggingSourceOperationMask: (NSDragOperation)mask
			      forLocal: (BOOL)isLocal
{
  if (isLocal)
    {
      _draggingSourceOperationMaskForLocal = mask;
    }
  else
    {
      _draggingSourceOperationMaskForRemote = mask;
    }
}

- (BOOL) _startDragOperationWithEvent: (NSEvent*)event
			 clickedIndex: (NSUInteger)index
{
  NSIndexSet *dragIndexes = _selectionIndexes;

  if (![dragIndexes containsIndex: index]
      && (index < [_items count]))
    {
      dragIndexes = [NSIndexSet indexSetWithIndex: index];
    }

  if (![dragIndexes count])
    return NO;

  if (![_delegate respondsToSelector: @selector(collectionView:writeItemsAtIndexes:toPasteboard:)])
    return NO;

  if ([_delegate respondsToSelector: @selector(collectionView:canDragItemsAtIndexes:withEvent:)])
    {
      if (![_delegate collectionView: self
	      canDragItemsAtIndexes: dragIndexes
			  withEvent: event])
	{
	  return NO;
	}
    }

  NSPoint downPoint = [event locationInWindow];
  NSPoint convertedDownPoint = [self convertPoint: downPoint fromView: nil];

  NSPasteboard *pasteboard = [NSPasteboard pasteboardWithName: NSDragPboard];
  if ([self _writeItemsAtIndexes:dragIndexes toPasteboard: pasteboard])
    {
      NSImage *dragImage = [self draggingImageForItemsAtIndexes: dragIndexes
						      withEvent: event
							 offset: NULL];

      [self dragImage: dragImage
		   at: convertedDownPoint
	       offset: NSMakeSize(0,0)
		event: event
	   pasteboard: pasteboard
	       source: self
	    slideBack: YES];

      return YES;
    }
  return NO;
}

- (NSImage *) draggingImageForItemsAtIndexes: (NSIndexSet *)indexes
				   withEvent: (NSEvent *)event
				      offset: (NSPointPointer)dragImageOffset
{
  if ([_delegate respondsToSelector: @selector(collectionView:draggingImageForItemsAtIndexes:withEvent:offset:)])
    {
      return [_delegate collectionView: self
		       draggingImageForItemsAtIndexes: indexes
			    withEvent: event
			       offset: dragImageOffset];
    }
  else
    {
      return [[NSImage alloc] initWithData: [self dataWithPDFInsideRect: [self bounds]]];
    }
}

- (BOOL) _writeItemsAtIndexes: (NSIndexSet *)indexes
		 toPasteboard: (NSPasteboard *)pasteboard
{
  if (![_delegate respondsToSelector: @selector(collectionView:writeItemsAtIndexes:toPasteboard:)])
    {
      return NO;
    }
  else
    {
      return [_delegate collectionView: self
		  writeItemsAtIndexes: indexes
			 toPasteboard: pasteboard];
    }
}

- (void) draggedImage: (NSImage *)image
	      endedAt: (NSPoint)point
	    operation: (NSDragOperation)operation
{
}

- (NSDragOperation) _draggingEnteredOrUpdated: (id<NSDraggingInfo>)sender
{
  NSDragOperation result = NSDragOperationNone;

  if ([_delegate respondsToSelector: @selector(collectionView:validateDrop:proposedIndex:dropOperation:)])
    {
      NSPoint location = [self convertPoint: [sender draggingLocation] fromView: nil];
      NSInteger index = [self _indexAtPoint: location];
      index = (index > [_items count] - 1) ? [_items count] - 1 : index;
      _draggingOnIndex = index;

      NSInteger *proposedIndex = &index;
      NSInteger dropOperationInt = NSCollectionViewDropOn;
      NSCollectionViewDropOperation *dropOperation = &dropOperationInt;

      // TODO: We currently don't do anything with the proposedIndex & dropOperation that
      // may get altered by the delegate.
      result = [_delegate collectionView: self
			   validateDrop: sender
			  proposedIndex: proposedIndex
			  dropOperation: dropOperation];

      if (result == NSDragOperationNone)
	{
	  _draggingOnIndex = NSNotFound;
	}
      [self setNeedsDisplayInRect: [self _frameForRowsAroundItemAtIndex: index]];
    }

  return result;
}

- (NSDragOperation) draggingEntered: (id<NSDraggingInfo>)sender
{
  return [self _draggingEnteredOrUpdated: sender];
}

- (void) draggingExited: (id<NSDraggingInfo>)sender
{
  [self setNeedsDisplayInRect: [self _frameForRowsAroundItemAtIndex: _draggingOnIndex]];
  _draggingOnIndex = NSNotFound;
}

- (NSDragOperation) draggingUpdated: (id<NSDraggingInfo>)sender
{
  return [self _draggingEnteredOrUpdated: sender];
}

- (BOOL) prepareForDragOperation: (id<NSDraggingInfo>)sender
{
  NSPoint location = [self convertPoint: [sender draggingLocation] fromView: nil];
  NSInteger index = [self _indexAtPoint: location];

  _draggingOnIndex = NSNotFound;
  [self setNeedsDisplayInRect: [self _frameForRowsAroundItemAtIndex: index]];
  return YES;
}

- (BOOL) performDragOperation: (id<NSDraggingInfo>)sender
{
  NSPoint location = [self convertPoint: [sender draggingLocation] fromView: nil];
  NSInteger index = [self _indexAtPoint: location];
  index = (index > [_items count] - 1) ? [_items count] - 1 : index;

  BOOL result = NO;
  if ([_delegate respondsToSelector: @selector(collectionView:acceptDrop:index:dropOperation:)])
    {
      // TODO: dropOperation should be retrieved from the validateDrop delegate method.
      result = [_delegate collectionView: self
			     acceptDrop: sender
				  index: index
			  dropOperation: NSCollectionViewDropOn];
    }
  return result;
}

- (BOOL) wantsPeriodicDraggingUpdates
{
  return YES;
}

/* New methods for later versions of macOS */

// 10.11 methods...

/* Locating Items and Views */

- (NSArray *) visibleItems
{
  return _visibleItems;
}

- (NSSet *) indexPathsForVisibleItems
{
  NSMutableSet *result = [NSMutableSet setWithCapacity: [_visibleItems count]];

  FOR_IN(NSCollectionViewItem*, item, _visibleItems)
    {
      NSIndexPath *p = [_itemsToIndexPaths objectForKey: item];
      [result addObject: p];
    }
  END_FOR_IN(_visibleItems);

  return [result copy];
}

- (NSArray *) visibleSupplementaryViewsOfKind: (NSCollectionViewSupplementaryElementKind)elementKind
{
  return [_visibleSupplementaryViews objectForKey: elementKind];
}

- (NSSet *) indexPathsForVisibleSupplementaryElementsOfKind: (NSCollectionViewSupplementaryElementKind)elementKind
{
  NSArray *views = [self visibleSupplementaryViewsOfKind: elementKind];
  NSMutableSet *indxs = [NSMutableSet setWithCapacity: [views count]];

  FOR_IN(id, item, views)
    {
      NSIndexPath *p = [self indexPathForItem: item];
      [indxs addObject: p];
    }
  END_FOR_IN(views);

  return [indxs copy];
}

- (NSIndexPath *) indexPathForItem: (NSCollectionViewItem *)item
{
  return [_itemsToIndexPaths objectForKey: item];
}

- (NSIndexPath *) indexPathForItemAtPoint: (NSPoint)point
{
  NSIndexPath *p = nil;
  NSEnumerator *ke = [_itemsToAttributes keyEnumerator];
  NSCollectionViewItem *item = nil;
  BOOL isFlipped = [self isFlipped];

  while ((item = [ke nextObject]) != nil)
    {
      NSCollectionViewLayoutAttributes *attr = [_itemsToAttributes objectForKey: item];

      if (attr != nil)
	{
	  NSRect f = [attr frame];

	  if (NSMouseInRect(point, f, isFlipped))
	    {
	      p = [self indexPathForItem: item];
	      break;
	    }
	}
      else
	{
	  NSLog(@"No attributes found");
	}
    }

  return p;
}

- (NSCollectionViewItem *) itemAtIndexPath: (NSIndexPath *)indexPath
{
  return [_indexPathsToItems objectForKey: indexPath];
}

- (NSView *) supplementaryViewForElementKind: (NSCollectionViewSupplementaryElementKind)elementKind
				 atIndexPath: (NSIndexPath *)indexPath
{
  return nil;
}

- (void) scrollToItemsAtIndexPaths: (NSSet *)indexPaths
		    scrollPosition: (NSCollectionViewScrollPosition)scrollPosition
{
}

/* Creating Collection view Items */

- (NSNib *) _nibForClass: (Class)cls
{
  NSString *clsName = NSStringFromClass(cls);
  NSNib *nib = [[NSNib alloc] initWithNibNamed: clsName
					bundle: [NSBundle bundleForClass: cls]];
  AUTORELEASE(nib);
  return nib;
}

- (NSCollectionViewItem *) makeItemWithIdentifier: (NSUserInterfaceItemIdentifier)identifier
				     forIndexPath: (NSIndexPath *)indexPath
{
  NSCollectionViewItem *item =
    [_dataSource collectionView: self itemForRepresentedObjectAtIndexPath: indexPath];
  NSNib *nib = [self _nibForClass: [item class]];
  BOOL loaded = [nib instantiateWithOwner: item
			  topLevelObjects: NULL];

  if (loaded == NO)
    {
      item = nil;
      NSLog(@"Could not load model %@", nib);
    }
  else
    {
      // Add to maps...
      [_itemsToIndexPaths setObject: indexPath
			     forKey: item];
      [_indexPathsToItems setObject: item
			     forKey: indexPath];
    }

  return item;
}

- (NSView *) makeSupplementaryViewOfKind: (NSCollectionViewSupplementaryElementKind)elementKind
			  withIdentifier: (NSUserInterfaceItemIdentifier)identifier
			    forIndexPath: (NSIndexPath *)indexPath
{
  return nil;
}

- (void) registerClass: (Class)itemClass
 forItemWithIdentifier: (NSUserInterfaceItemIdentifier)identifier
{
  [self registerClass: itemClass
	forSupplementaryViewOfKind: GSNoSupplementaryElement
	withIdentifier: identifier];
}

- (void) registerNib: (NSNib *)nib
	 forItemWithIdentifier: (NSUserInterfaceItemIdentifier)identifier
{
  [self registerNib: nib
	forSupplementaryViewOfKind: GSNoSupplementaryElement
	withIdentifier: identifier];
}

- (void) registerClass: (Class)viewClass
	 forSupplementaryViewOfKind: (NSCollectionViewSupplementaryElementKind)kind
	 withIdentifier: (NSUserInterfaceItemIdentifier)identifier
{
  NSMapTable *t = nil;

  t = [_registeredClasses objectForKey: kind];
  if (t == nil)
    {
      t = [NSMapTable weakToWeakObjectsMapTable];
      [_registeredClasses setObject: t
			     forKey: kind];
    }

  [t setObject: viewClass forKey: identifier];
}

- (void) registerNib: (NSNib *)nib
	 forSupplementaryViewOfKind: (NSCollectionViewSupplementaryElementKind)kind
      withIdentifier: (NSUserInterfaceItemIdentifier)identifier
{
  NSMapTable *t = nil;

  t = [_registeredNibs objectForKey: kind];
  if (t == nil)
    {
      t = [NSMapTable weakToWeakObjectsMapTable];
      [_registeredNibs setObject: t
			  forKey: kind];
    }

  [t setObject: nib forKey: identifier];
}

/* Providing the collection view's data */

- (id<NSCollectionViewDataSource>) dataSource
{
  return _dataSource;
}

- (void) setDataSource: (id<NSCollectionViewDataSource>)dataSource
{
  _dataSource = dataSource;
  [self reloadData];
}

/* Configuring the Collection view */

- (NSView *) backgroundView
{
  return _backgroundView;
}

- (void) setBackgroundView: (NSView *)backgroundView
{
  _backgroundView = backgroundView; // weak since view retains this
}

- (BOOL) backgroundViewScrollsWithContent
{
  return _backgroundViewScrollsWithContent;
}

- (void) setBackgroundViewScrollsWithContent: (BOOL)f
{
  _backgroundViewScrollsWithContent = f;
}

/* Reloading Content */
- (void) _loadItemAtIndexPath: (NSIndexPath *)path
{
  NSCollectionViewItem *item = [self makeItemWithIdentifier: nil
					       forIndexPath: path];

  if (item != nil)
    {
      NSView *v = [item view];
      NSRect f = [v frame];
      _GSCollectionViewItemTrackingView *tv =
	[[_GSCollectionViewItemTrackingView alloc]
	  initWithFrame: NSMakeRect(0.0, 0.0, f.size.width, f.size.height)];

      // Set up tracking view...
      [v setNextResponder: tv];
      [tv setAlphaValue: 0.0];
      [tv setItem: item];
      [tv setCollectionView: self];
      [tv setIndexPath: path];
      [v addSubview: tv positioned: NSWindowAbove relativeTo: nil];
      RELEASE(tv);

      [_visibleItems addObject: item];
      if (_collectionViewLayout)
	{
	  NSCollectionViewLayoutAttributes *attrs =
	    [self layoutAttributesForItemAtIndexPath: path];
	  NSRect frame = [attrs frame];
	  BOOL hidden = [attrs isHidden];
	  CGFloat alpha = [attrs alpha];
	  NSSize sz = [attrs size];

	  // set attributes of item based on currently selected layout...
	  frame.size = sz;
	  [v setFrame: frame];
	  [v setHidden: hidden];
	  [v setAlphaValue: alpha];

	  [_itemsToAttributes setObject: attrs
				 forKey: item];

	  [self addSubview: v];
	}
      else
	{
	  NSLog(@"NSCollectionViewLayout subclass is not set");
	}
    }
}

- (void) _loadSectionAtIndex: (NSUInteger)cs
{
  NSInteger ni = [self numberOfItemsInSection: cs];
  NSInteger ci = 0;

  for (ci = 0; ci < ni; ci++)
    {
      NSIndexPath *p = [NSIndexPath indexPathForItem: ci inSection: cs];
      [self _loadItemAtIndexPath: p];
    }
}

- (void) _clearMaps
{
  // Remove objects from set/dict/maps
  [_visibleItems removeAllObjects];
  [_itemsToIndexPaths removeAllObjects];
  [_indexPathsToItems removeAllObjects];
  [_itemsToAttributes removeAllObjects];

  [self setSubviews: [NSArray array]];
  [_collectionViewLayout prepareLayout];

  // destroy maps...
  DESTROY(_indexPathsToItems);
  DESTROY(_itemsToIndexPaths);
  DESTROY(_itemsToAttributes);

  // reallocate the maps...
  _itemsToAttributes = RETAIN([NSMapTable strongToStrongObjectsMapTable]);
  _itemsToIndexPaths = RETAIN([NSMapTable strongToStrongObjectsMapTable]);
  _indexPathsToItems = RETAIN([NSMapTable strongToStrongObjectsMapTable]);
}

- (void) _updateParentViewFrame
{
  NSEnumerator *oe = [_itemsToAttributes objectEnumerator];
  NSCollectionViewLayoutAttributes *attrs = nil;
  NSRect cf = [self frame];
  NSSize ps = cf.size;

  while ((attrs = [oe nextObject]) != nil)
    {
      NSRect f = [attrs frame];
      CGFloat w = f.origin.x + f.size.width;
      CGFloat h = f.origin.y + f.size.height;

      ps.width  = (w > ps.width) ? w : ps.width;
      ps.height = (h > ps.height) ? h : ps.height;
    }

  // Get the size proposed by the layout...
  if (_collectionViewLayout != nil && OVERRIDDEN(collectionViewContentSize))
    {
      ps = [_collectionViewLayout collectionViewContentSize];
    }
  else
    {
      NSLog(@"%@ does not override -collectionViewContentSize, some items may not be shown", NSStringFromClass([_collectionViewLayout class]));
    }

  cf.size = ps;
  _frame = cf;
}

- (void) reloadData
{
  if (_allowReload)
    {
      NSInteger ns = [self numberOfSections];
      NSInteger cs = 0;
      NSSize s = _itemSize;
      CGFloat h = s.height;
      CGFloat proposedHeight = ns * h;
      id sv = [self superview];
      NSRect newRect = [sv frame];
      BOOL f = [self postsFrameChangedNotifications];

      if (proposedHeight < newRect.size.height)
	{
	  proposedHeight = newRect.size.height;
	}

      _allowReload = NO;
      [self setPostsFrameChangedNotifications: NO]; // prevent recursion...
      [self _clearMaps];
      newRect.size.height = proposedHeight;
      [self setFrame: newRect];
      for (cs = 0; cs < ns; cs++)
	{
	  [self _loadSectionAtIndex: cs];
	}
      [self _updateParentViewFrame];
      [self setPostsFrameChangedNotifications: f]; // reset
      _allowReload = YES;
    }
}

- (void) reloadSections: (NSIndexSet *)sections
{
  NSUInteger *buffer = NULL;
  NSUInteger c = 0;
  NSUInteger i = 0;

  c = [sections getIndexes: buffer
		  maxCount: [sections count]
	      inIndexRange: NULL];

  if (buffer != NULL)
    {
      for (i = 0; i < c; i++)
	{
	  NSUInteger cs = buffer[i];
	  [self _loadSectionAtIndex: cs];
	}
    }
}

- (void) reloadItemsAtIndexPaths: (NSSet *)indexPaths
{
  FOR_IN(NSIndexPath*, p, indexPaths)
    {
      [self _loadItemAtIndexPath: p];
    }
  END_FOR_IN(indexPaths);
}

/* Prefetching Collection View Cells and Data */

- (id<NSCollectionViewPrefetching>) prefetchDataSource
{
  return _prefetchDataSource;
}

- (void) setPrefetchDataSource: (id<NSCollectionViewPrefetching>)prefetchDataSource
{
  _prefetchDataSource = prefetchDataSource;
}

/* Getting the State of the Collection View */

- (NSInteger) numberOfSections
{
  NSInteger n = 0;

  if ([_dataSource respondsToSelector: @selector(numberOfSectionsInCollectionView:)])
    {
      n = [_dataSource numberOfSectionsInCollectionView: self];
    }

  return n;
}

- (NSInteger) numberOfItemsInSection: (NSInteger)section
{
  // Since this is a required method by the delegate we can assume it's presence
  // if it is not there, tests on macOS indicate that an unrecognized selector
  // exception is thrown.
  return [_dataSource collectionView: self numberOfItemsInSection: section];
}

/* Inserting, Moving and Deleting Items */

- (void) insertItemsAtIndexPaths: (NSSet *)indexPaths
{
}

- (void) moveItemAtIndexPath: (NSIndexPath *)indexPath
		 toIndexPath: (NSIndexPath *)newIndexPath
{
}

- (void) deleteItemsAtIndexPaths: (NSSet *)indexPaths
{
}

/* Inserting, Moving, Deleting and Collapsing Sections */

- (void) insertSections: (NSIndexSet *)sections
{
}

- (void) moveSection: (NSInteger)section
	   toSection: (NSInteger)newSection
{
}

- (void) deleteSections: (NSIndexSet *)sections
{
}

// 10.12 method...

- (IBAction) toggleSectionCollapse: (id)sender
{
}

// 10.11 methods...

- (BOOL) allowsEmptySelection
{
  return _allowsEmptySelection;
}

- (void) setAllowsEmptySelection: (BOOL)flag
{
  _allowsEmptySelection = flag;
}

- (IBAction) selectAll: (id)sender
{
  NSMutableSet *paths = [NSMutableSet setWithCapacity: [_itemsToIndexPaths count]];

  FOR_IN(NSCollectionViewItem*, obj, _itemsToIndexPaths)
    {
      NSIndexPath *p = [_itemsToIndexPaths objectForKey: obj];

      [paths addObject: p];
    }
  END_FOR_IN(_itemsToIndexPaths);

  [self setSelectionIndexPaths: paths];
}

- (IBAction) deselectAll: (id)sender
{
  NSMutableSet *paths = [NSMutableSet setWithCapacity: [_itemsToIndexPaths count]];

  FOR_IN(NSCollectionViewItem*, obj, _itemsToIndexPaths)
    {
      NSIndexPath *p = [_itemsToIndexPaths objectForKey: obj];

      [paths addObject: p];
    }
  END_FOR_IN(_itemsToIndexPaths);

  [self deselectItemsAtIndexPaths: paths];
}

- (void) selectItemsAtIndexPaths: (NSSet *)indexPaths
		  scrollPosition: (NSCollectionViewScrollPosition)scrollPosition
{
  NSMutableSet *paths = [NSMutableSet setWithCapacity: [_itemsToIndexPaths count]];

  FOR_IN (NSIndexPath*, p, indexPaths)
    {
      [paths addObject: p];
    }
  END_FOR_IN(indexPaths);

  [self setSelectionIndexPaths: paths];
}

- (void) deselectItemsAtIndexPaths: (NSSet *)indexPaths
{
  NSMutableSet *newSelection = [NSMutableSet setWithSet: _selectionIndexPaths];

  FOR_IN (NSIndexPath*, p, indexPaths)
    {
      [newSelection removeObject: p];
    }
  END_FOR_IN(indexPaths);

  [self setSelectionIndexPaths: newSelection];
}

/* Getting Layout Information */

- (NSCollectionViewLayoutAttributes *) layoutAttributesForItemAtIndexPath: (NSIndexPath *)indexPath
{
  NSCollectionViewLayoutAttributes *attrs =
    [_collectionViewLayout layoutAttributesForItemAtIndexPath: indexPath];
  return attrs;
}

- (NSCollectionViewLayoutAttributes *) layoutAttributesForSupplementaryElementOfKind: (NSCollectionViewSupplementaryElementKind)kind
									 atIndexPath: (NSIndexPath *)indexPath
{
  NSCollectionViewLayoutAttributes *attrs =
    [_collectionViewLayout layoutAttributesForSupplementaryViewOfKind: kind
							  atIndexPath: indexPath];
  return attrs;
}

/* Animating Multiple Changes */

- (void) performBatchUpdates: (GSCollectionViewPerformBatchUpdatesBlock) updates
	   completionHandler: (GSCollectionViewCompletionHandlerBlock) completionHandler
{
}

@end
