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

@interface NXTListCell : NSTextFieldCell
{
}
@property (assign) BOOL selected;
@end

@implementation NXTListCell

- (id)init
{
  self = [super init];
  self.selected = NO;
  return self;
}

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
    [[NSColor blackColor] set];
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

- (void)mouseDown:(NSEvent *)event
{
  NSWindow    *window = [event window];
  NSView      *contentView = [window contentView];
  NSPoint     mouseLocation;
  NSInteger   dRow, dColumn;
  NXTListCell *selectedCell, *clickedCell;

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
  
  if (selectedCell != clickedCell) {
    [selectedCell setSelected:NO];
  }
  [clickedCell setSelected:YES];
  
  [super mouseDown:event];  
}

@end

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

  cellSize = NSMakeSize(rect.size.width-23, 19);
  listMatrix = [[NXTListMatrix alloc]
                 initWithFrame:NSMakeRect(0,0,cellSize.width,cellSize.height)];
  [listMatrix setCellSize:cellSize];
  [listMatrix setIntercellSpacing:NSMakeSize(0,0)];
  [listMatrix setAutosizesCells:NO];
  [listMatrix setDelegate:self];
  listMatrix.scrollView = scrollView;
  // [listMatrix setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  
  [scrollView setDocumentView:listMatrix];
  [scrollView setLineScroll:19.0];
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

- (id)selectedCell
{
  return [listMatrix selectedCell];
}

- (void)setCellSize:(NSSize)size
{
  [listMatrix setCellSize:size];
}

@end
