/* -*- mode: objc -*- */
//
// Project: Preferences
//
// Copyright (C) 2014-2019 Sergii Stoian
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free
// Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
//

#include <AppKit/AppKit.h>
#include "NXTListView.h"

// -----------------------------------------------------------------------------
// Cell
// -----------------------------------------------------------------------------
@interface NXTListCell : NSTextFieldCell
@property (assign) BOOL    selected;
@property (assign) NSColor *selectionColor;
@end
@implementation NXTListCell
- (void)drawInteriorWithFrame:(NSRect)cellFrame
                       inView:(NSView *)controlView
{
  if (_selected == NO) {
    [[self backgroundColor] set];
  }
  else {
    [_selectionColor set];
  }
  NSRectFill(cellFrame);
  
  [super drawInteriorWithFrame:cellFrame inView:controlView];
  
  if (_selected != NO) {
    [[NSColor darkGrayColor] set];
    PSnewpath();
    PSmoveto(cellFrame.origin.x, cellFrame.origin.y);
    PSlineto(NSMaxX(cellFrame), cellFrame.origin.y);
    PSmoveto(cellFrame.origin.x, NSMaxY(cellFrame)-1);
    PSlineto(NSMaxX(cellFrame), NSMaxY(cellFrame)-1);
    PSstroke();
  }      
}
@end

@interface NXTListMatrix : NSMatrix
@property (assign) NSScrollView *scrollView;
@property (assign) NSColor      *selectionColor;
- (void)loadTitles:(NSArray *)titles
        andObjects:(NSArray *)objects;
@end

// -----------------------------------------------------------------------------
// Matrix : NSMatrix
// -----------------------------------------------------------------------------
@implementation NXTListMatrix

- (void)dealloc
{
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect
{
  self = [super initWithFrame:frameRect];
  [self setCellClass:[NXTListCell class]];
  [self setMode:NSListModeMatrix];
  [self setAllowsEmptySelection:YES];
  [self setAutoscroll:YES];
  [self setDrawsBackground:YES];
  [self setBackgroundColor:[NSColor controlBackgroundColor]];
  _selectionColor = [[NSColor whiteColor] retain];
    
  return self;
}

- (void)loadTitles:(NSArray *)titles
        andObjects:(NSArray *)objects
{
  // NSCell *cell; 
  NXTListCell *cell;
 
  for (int i = 0; i < [titles count]; i++) {
    [self addRow];
    cell = (NXTListCell *)[self makeCellAtRow:i column:0];
    [cell setObjectValue:titles[i]];
    [cell setRepresentedObject:objects[i]];
    [cell setEditable:NO];
    [cell setSelectable:NO];
    [cell setRefusesFirstResponder:YES];
    [cell setDrawsBackground:YES];
    [cell setBackgroundColor:[self backgroundColor]];
    [cell setSelectionColor:_selectionColor];
  }
}

- (void)selectCellAtRow:(NSInteger)row
                 column:(NSInteger)column
{
  NXTListCell *selectedCell = [self selectedCell];
  NXTListCell *cell = [self cellAtRow:row column:column];

  selectedCell.selected = NO;
  cell.selected = YES;
  [super selectCellAtRow:row column:column];
}

- (void)mouseDown:(NSEvent *)event
{
  NSWindow    *window = [event window];
  NSView      *contentView = [window contentView];
  NSPoint     lastLocation, location;
  NSInteger   dRow, dColumn;
  NXTListCell *originalCell, *selectedCell, *clickedCell;
  id          repObject;
  NSUInteger  eventMask = (NSLeftMouseDownMask | NSLeftMouseUpMask
                           | NSPeriodicMask | NSOtherMouseUpMask
                           | NSRightMouseUpMask);
  NSRect      listRect = [_scrollView documentVisibleRect];
  CGFloat     listHeight = listRect.size.height;
  CGFloat     listWidth = listRect.size.width;
  NSInteger   y;
  BOOL        done = NO;

  [NSEvent startPeriodicEventsAfterDelay:0.02 withPeriod:0.02];
  originalCell = [self selectedCell];
  selectedCell = originalCell;

  while (!done) {
    event = [NSApp nextEventMatchingMask:eventMask
                               untilDate:[NSDate distantFuture]
                                  inMode:NSEventTrackingRunLoopMode
                                 dequeue:YES];
    switch ([event type])
      {
      case NSRightMouseUp:
      case NSOtherMouseUp:
      case NSLeftMouseUp:
        done = YES;
        [self getRow:&dRow column:&dColumn ofCell:selectedCell];
        [self selectCellAtRow:dRow column:dColumn];
        [_target performSelector:_action withObject:self];
        break;
      case NSPeriodic:
        location = [contentView
                       convertPoint:[window mouseLocationOutsideOfEventStream]
                             toView:self];
        location.y += [self cellSize].height/2;
        [self getRow:&dRow column:&dColumn forPoint:location];
        clickedCell = [self cellAtRow:dRow column:dColumn];
  
        if (selectedCell != clickedCell) {
          [selectedCell setSelected:NO];
        }
        if ([[clickedCell title] length] > 1) {
          repObject = [clickedCell representedObject];
          if (repObject != nil) {
            selectedCell = clickedCell;
            [clickedCell setSelected:YES];
          }
        }
        if (selectedCell != clickedCell) {
          selectedCell = originalCell;
        }
        lastLocation = location;
        [self setNeedsDisplay:YES];
        break;
      default:
        break;
      }
  }
  [NSEvent stopPeriodicEvents];
}

- (void)keyDown:(NSEvent *)theEvent
{
  unichar c = [[theEvent characters] characterAtIndex:0];

  switch(c) {
  case NSUpArrowFunctionKey:
    if (_selectedRow > 0) {
      [self selectCellAtRow:_selectedRow-1 column:0];
    }
    break;
  case NSDownArrowFunctionKey:
    if (_selectedRow < [[self cells] count]) {
      [self selectCellAtRow:_selectedRow+1 column:0];
    }
    break;
  }
}

- (void)keyUp:(NSEvent *)theEvent
{
  unichar c = [[theEvent characters] characterAtIndex:0];

  switch(c) {
  case NSUpArrowFunctionKey:
  case NSDownArrowFunctionKey:
    [self performClick:self];
    break;
  }
}

- (void)resizeWithOldSuperviewSize:(NSSize)oldSize
{
  NSSize currentSize= [[self superview] frame].size;
  NSSize cellSize;
    
  if (oldSize.width != currentSize.width) {
    cellSize = [self cellSize];
    cellSize.width = currentSize.width;
    [self setCellSize:cellSize];
  }
}

@end

// -----------------------------------------------------------------------------
// View : NSView
// -----------------------------------------------------------------------------
@implementation NXTListView

- (id)init
{
  return [self initWithFrame:NSMakeRect(0,0,100,100)];
}

- (id)initWithFrame:(NSRect)rect
{
  [super initWithFrame:rect];

  // rect.size.width -= 10; // why 10 ??
  // rect.size.height -= 10; // why 10 ??
  scrollView = [[NSScrollView alloc] initWithFrame:rect];
  [scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  [scrollView setHasVerticalScroller:YES];
  [scrollView setBorderType:NSBezelBorder];

  cellSize = NSMakeSize(rect.size.width-23, 15);
  listMatrix = [[NXTListMatrix alloc]
                 initWithFrame:NSMakeRect(0,0,cellSize.width,cellSize.height)];
  [listMatrix setCellSize:cellSize];
  [listMatrix setIntercellSpacing:NSMakeSize(0,0)];
  [listMatrix setAutosizesCells:NO];
  [listMatrix setDelegate:self];
  listMatrix.scrollView = scrollView;
  // [listMatrix setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  
  [scrollView setDocumentView:listMatrix];
  [scrollView setLineScroll:15.0];
  [listMatrix release];

  [self addSubview:scrollView];

  return self;
}

- (void)loadTitles:(NSArray *)titles
        andObjects:(NSArray *)objects
{
  [listMatrix loadTitles:titles andObjects:objects];
  [listMatrix sizeToCells];
}

- (void)addItemWithTitle:(NSAttributedString *)title
       representedObject:(id)object
{
  NXTListCell *cell;
  NSRect      docRect = [scrollView documentVisibleRect];
  NSUInteger  cellsCount;

  if ([[listMatrix cells] count] == 0) {
    initialLoadDidComplete = NO;
    items_count = 0;
  }
  
  [listMatrix addRow];

  cellsCount = [[listMatrix cells] count];
  cell = (NXTListCell *)[listMatrix makeCellAtRow:cellsCount-1
                                           column:0];
  [cell setObjectValue:title];
  [cell setRepresentedObject:object];
  [cell setEditable:NO];
  [cell setSelectable:NO];
  [cell setRefusesFirstResponder:YES];
  [cell setDrawsBackground:YES];
  [cell setBackgroundColor:[listMatrix backgroundColor]];
  [cell setSelectionColor:listMatrix.selectionColor];

  [listMatrix sizeToCells];
  items_count++;
  if ((cellSize.height * cellsCount) > docRect.size.height) {
    if (items_count >= (docRect.size.height/cellSize.height)) {
      [self display];
      items_count = 0;
    }
  }
}

// --- Target/action
- (void)setTarget:(id)target
{
  [listMatrix setTarget:target];
}

- (void)setAction:(SEL)action
{
  [listMatrix setAction:action];
}

// --- Graphic attributes
- (void)setBackgroundColor:(NSColor *)color
{
  [listMatrix setBackgroundColor:color];  
}

- (void)setSelectionBackgroundColor:(NSColor *)color
{
  [listMatrix setSelectionColor:color];
}

// --- Items
- (id)selectedItem
{
  return [listMatrix selectedCell];
}

- (void)selectItemAtIndex:(NSInteger)index
{
  if (index < 0) {
    [listMatrix deselectAllCells];
  }
  [listMatrix selectCellAtRow:index column:0];
}

- (NSCell *)itemAtIndex:(NSInteger)index
{
  return [listMatrix cellAtRow:index column:0];
}

- (NSInteger)indexOfItem:(NSCell *)item
{
  NSInteger row, column;
  [listMatrix getRow:&row column:&column ofCell:item];

  return row;
}

// Returns index of item that represented object is `object`
- (NSInteger)indexOfItemWithStringRep:(NSString *)string
{
  NSString *rep;
  
  for (NSCell *cell in [listMatrix cells]) {
    rep = [cell representedObject];
    if ([rep isKindOfClass:[NSString class]] && [rep isEqualToString:string]) {
      return [self indexOfItem:cell];
    }
  }
  
  return NSNotFound;
}
- (NSInteger)indexOfItemWithObjectRep:(id)object
{
  NSString *rep;
  
  for (NSCell *cell in [listMatrix cells]) {
    rep = [cell representedObject];
    if ([rep isEqualTo:object]) {
      return [self indexOfItem:cell];
    }
  }
  
 return NSNotFound;
}

// --- Interaction
- (void)keyDown:(NSEvent *)theEvent
{
  [listMatrix keyDown:theEvent];
}
- (void)keyUp:(NSEvent *)theEvent
{
  [listMatrix keyUp:theEvent];
}

@end
