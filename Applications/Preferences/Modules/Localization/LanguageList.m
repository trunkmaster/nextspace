/* All Rights reserved */

#include <AppKit/AppKit.h>
#include "LanguageList.h"

@implementation LanguageList

- (NSImage*)dragImageForRows:(NSArray*)dragRows
                       event:(NSEvent*)dragEvent
             dragImageOffset:(NSPoint*)dragImageOffset
{
  // return [super dragImageForRows:dragRows
  //                          event:dragEvent
  //                dragImageOffset:dragImageOffset];
  
  // NSTableColumn *tCol = [self tableColumnWithIdentifier:@"language"];
  // NSCell *aCell = [tCol dataCellForRow:[[dragRows lastObject] intValue]];
  NSRect cellRect = [self rectOfRow:[[dragRows lastObject] intValue]];
  NSBitmapImageRep *imageRep;
  // NSEPSImageRep *epsRep;
  NSImage *image;

  NSLog(@"Dragged cell bounds: %@", NSStringFromRect(cellRect));
  
  [self lockFocus];
  imageRep = [[NSBitmapImageRep alloc]
               initWithFocusedViewRect:NSMakeRect(10,100,10,10)];
  // imageRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:cellRect];
  // image = [[NSImage alloc] initWithData:[self dataWithEPSInsideRect:cellRect]];
  // epsRep = [[NSEPSImageRep alloc] initWithData:[self dataWithEPSInsideRect:cellRect]];
  image = [NSImage new];
  [image addRepresentation:imageRep];
  // [epsRep release];
  [self unlockFocus];

  NSLog(@"Image");
  // return [NSImage imageNamed:@"common_outlineCollapsed"];
  return image;
}

NSDragOperation currentDragOperation;
NSInteger lastQuarterPosition;

- (NSDragOperation) draggingUpdated: (id <NSDraggingInfo>) sender
{
  // NSPoint p = [self convertPoint: [sender draggingLocation] fromView: nil];
  // NSInteger positionInRow = (NSInteger)(p.y - _bounds.origin.y) % (int)_rowHeight;
  // NSInteger quarterPosition = (NSInteger)([self _computedRowAtPoint: p] * 4.);
  // NSInteger row = [self _dropRowFromQuarterPosition: quarterPosition];
  NSDragOperation dragOperation = [sender draggingSourceOperationMask];
  // BOOL isSameDropTargetThanBefore = (lastQuarterPosition == quarterPosition
  //   && currentDragOperation == dragOperation);

  NSLog(@"Dragging updated");
  
  // [self _scrollRowAtPointToVisible: p];

  // if (isSameDropTargetThanBefore)
  //   return currentDragOperation;

  // /* Remember current drop target */
  // currentDragOperation = dragOperation;
  // lastQuarterPosition = quarterPosition;

  // /* The user can retarget this default drop using -setDropRow:dropOperation:
  //    in -tableView:validateDrop:proposedRow:proposedDropOperation:. */
  // [self _setDropOperationAndRow: row
  //            usingPositionInRow: positionInRow
  //                       atPoint: p];

  // if ([_dataSource respondsToSelector:
  //     @selector(tableView:validateDrop:proposedRow:proposedDropOperation:)])
  //   {
  //     currentDragOperation = [_dataSource tableView: self
  //                                      validateDrop: sender
  //                                       proposedRow: currentDropRow
  //                             proposedDropOperation: currentDropOperation];
  //   }

  // /* -setDropRow:dropOperation: can changes both currentDropRow and
  //    currentDropOperation. Whether we have to redraw the drop indicator depends
  //    on this change. */
  // if (currentDropRow != oldDropRow || currentDropOperation != oldDropOperation)
  //   {
  //     [self _drawDropIndicator];
  //     oldDropRow = (currentDropRow > -1 ? currentDropRow : _numberOfRows);
  //     oldDropOperation = currentDropOperation;
  //   }

  return dragOperation;
}

@end
