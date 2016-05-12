/* All Rights reserved */

#include <AppKit/AppKit.h>
#include "LanguageList.h"
/*
@interface DraggedImage : NSImage
@end
@implementation DraggedImage

- (void)drawInRect:(NSRect)dstRect // Negative width/height => Nothing draws.
          fromRect:(NSRect)srcRect
         operation:(NSCompositingOperation)op
          fraction:(CGFloat)delta
    respectFlipped:(BOOL)respectFlipped
             hints:(NSDictionary*)hints
{
  NSGraphicsContext *ctxt = GSCurrentContext();

  [super drawInRect:dstRect
           fromRect:srcRect
          operation:op
           fraction:delta
     respectFlipped:respectFlipped
              hints:hints];
  
  DPSgsave(ctxt);
  [[NSColor blackColor] set];
  NSFrameRect(dstRect);
  DPSgrestore(ctxt);
}
@end

@implementation LanguageList

- (NSImage*)dragImageForRows:(NSArray*)dragRows
                       event:(NSEvent*)dragEvent
             dragImageOffset:(NSPoint*)dragImageOffset
{
  // NSTableColumn *tCol = [self tableColumnWithIdentifier:@"language"];
  // NSCell *aCell = [tCol dataCellForRow:[[dragRows lastObject] intValue]];
  NSRect dragRowsRect = NSMakeRect(0,0,0,0);
  // NSRect cellRect = [self rectOfRow:[[dragRows lastObject] intValue]];
  NSBitmapImageRep *imageRep;
  NSImage *image;
  int i;

  for (i=0; i < [dragRows count]; i++)
    {
      dragRowsRect = NSUnionRect(dragRowsRect,
                                 [self rectOfRow:[[dragRows objectAtIndex:i] intValue]]);
    }

  dragRowsRect.size.width += 2;
  dragRowsRect.size.height += 2;
  dragRowsRect.origin.x -= 1;
  dragRowsRect.origin.y -= 1;

  NSLog(@"Dragged cell bounds: %@", NSStringFromRect(dragRowsRect));
  
  [self lockFocus];
  imageRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:dragRowsRect];
  image = [DraggedImage new];
  [image addRepresentation:imageRep];
  [self unlockFocus];

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

  // // Remember current drop target
  // currentDragOperation = dragOperation;
  // lastQuarterPosition = quarterPosition;

  // // The user can retarget this default drop using -setDropRow:dropOperation:
  // // in -tableView:validateDrop:proposedRow:proposedDropOperation:.
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

  // // -setDropRow:dropOperation: can changes both currentDropRow and
  // //   currentDropOperation. Whether we have to redraw the drop indicator depends
  //    on this change.
  // if (currentDropRow != oldDropRow || currentDropOperation != oldDropOperation)
  //   {
  //     [self _drawDropIndicator];
  //     oldDropRow = (currentDropRow > -1 ? currentDropRow : _numberOfRows);
  //     oldDropOperation = currentDropOperation;
  //   }

  return dragOperation;
}

@end
*/

@implementation LanguageList

- (void)loadRowsFromArray:(NSArray *)array
{
  NSCell *cell;
  
  for (int i=0; i < [array count]; i++)
    {
      [self addRow];
      cell = [self makeCellAtRow:i column:0];
      [cell setObjectValue:[array objectAtIndex:i]];
      // [cell setRefusesFirstResponder:YES];
      [cell setSelectable:NO];
    }
}

- (void)mouseDown:(NSEvent *)event
{
  NSInteger row, column;
  NSPoint   mouseInWindow = [event locationInWindow];
  NSPoint   mouseInList;
  NSCell    *cell;

  mouseInList = [[[event window] contentView] convertPoint:mouseInWindow
                                                    toView:self];
  [self getRow:&row column:&column forPoint:mouseInList];
  cell = [self cellAtRow:row column:column];
  [cell setEnabled:NO];
  
  NSLog(@"LanguageList: mouseDown on '%@'",
        [[self cellAtRow:row column:column] title]);
}

@end
