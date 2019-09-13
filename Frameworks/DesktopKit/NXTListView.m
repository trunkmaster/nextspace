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
@property (assign) BOOL selected;
@end
@implementation NXTListCell
- (void)drawInteriorWithFrame:(NSRect)cellFrame
                       inView:(NSView *)controlView
{
  // NSLog(@"Draw interior for `%@` selected: %@",
  //       [self title], _drawEdges ? @"YES" : @"NO");
  if (_selected == NO) {
    [[NSColor controlBackgroundColor] set];
  }
  else {
    [[NSColor whiteColor] set];
  }
  NSRectFill(cellFrame);
  
  [self _drawAttributedText:[self _drawAttributedString]
                    inFrame:[self titleRectForBounds:cellFrame]];
  
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
  [self setBackgroundColor:[NSColor grayColor]];
    
  return self;
}

- (void)loadTitles:(NSArray *)titles
        andObjects:(NSArray *)objects
{
  NSCell *cell;
  
  for (int i = 0; i < [titles count]; i++) {
    [self addRow];
    cell = [self makeCellAtRow:i column:0];
    [cell setObjectValue:titles[i]];
    [cell setRepresentedObject:objects[i]];
    [cell setEditable:NO];
    [cell setSelectable:NO];
    [cell setRefusesFirstResponder:YES];
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
  NSPoint     mouseLocation;
  NSInteger   dRow, dColumn;
  NXTListCell *selectedCell, *clickedCell;
  id          repObject;

  selectedCell = [self selectedCell];
  
  // Determine clicked row
  mouseLocation = [contentView convertPoint:[event locationInWindow]
                                     toView:[_scrollView contentView]];
  mouseLocation.y += [self cellSize].height/2; // mouse cursor hit point?
  [self getRow:&dRow column:&dColumn forPoint:mouseLocation];

  // Select clicked cell
  clickedCell = [self cellAtRow:dRow column:dColumn];
  if ([[clickedCell title] length] <= 1)
    return;
  repObject = [clickedCell representedObject];
  if ([repObject isKindOfClass:[NSString class]] &&
      [repObject isEqualToString:@""])
    return;
  
  if (selectedCell != clickedCell) {
    [selectedCell setSelected:NO];
  }
  [clickedCell setSelected:YES];
  
  [super mouseDown:event];  
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
  NSSize cellSize;
  
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

- (void)setTarget:(id)target
{
  [listMatrix setTarget:target];
}

- (void)setAction:(SEL)action
{
  [listMatrix setAction:action];
}

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

@end
