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
@property (assign) BOOL drawEdges;
@end

@implementation NXTListCell

- (id)init
{
  self = [super init];
  self.drawEdges = NO;
  return self;
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame
                       inView:(NSView *)controlView
{
  // NSLog(@"Draw cell with frame: %@", NSStringFromRect(cellFrame));
  // TODO: draw only if selected
  [[NSColor controlBackgroundColor] set];
  NSRectFill(cellFrame);
  // cellFrame.origin.y -= 2;
  [self _drawAttributedText:[self _drawAttributedString]
                    inFrame:[self titleRectForBounds:cellFrame]];

  if (_drawEdges) {
    [[NSColor darkGrayColor] set];
    PSnewpath();
    PSmoveto(0, 0);
    PSlineto(cellFrame.size.width, 0);
    // PSstroke();
    // [[NSColor darkGrayColor] set];
    // PSnewpath();
    PSmoveto(0, cellFrame.size.height-1);
    PSlineto(cellFrame.size.width, cellFrame.size.height-1);
    PSstroke();
  }      
}

@end

@interface NXTListMatrix : NSMatrix
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

  [self setAllowsEmptySelection:YES];
  [self setAutoscroll:YES];
  [self setDrawsBackground:YES];
  [self setBackgroundColor:[NSColor lightGrayColor]];
    
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
    [cell setSelectable:YES];
  }
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

  cellSize = NSMakeSize(rect.size.width-23, 13);
  listMatrix = [[NXTListMatrix alloc]
                 initWithFrame:NSMakeRect(0,0,cellSize.width,cellSize.height)];
  [listMatrix setCellSize:cellSize];
  [listMatrix setIntercellSpacing:NSMakeSize(0,0)];
  [listMatrix setAutosizesCells:NO];
  [listMatrix setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  
  [scrollView setDocumentView:listMatrix];
  [scrollView setLineScroll:17.0];
  [listMatrix release];
  
  [self addSubview:scrollView];
  
  return self;
}

- (void)loadTitles:(NSArray *)titles
        andObjects:(NSArray *)objects
{
  [listMatrix loadTitles:titles andObjects:objects];
  [listMatrix setCellSize:[listMatrix cellSize]];
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

- (void)mouseDown:(NSEvent *)event
{
  NSWindow  *window = [event window];
  NSView    *contentView = [window contentView];
  NSPoint   lastLocation;
  NSInteger dRow, dColumn;
  // NSCell    *cell;

  NSLog(@"[NXTLIstView] mouseDown");
  
  // Determine clicked row
  lastLocation = [contentView convertPoint:[event locationInWindow]
                                    toView:[scrollView contentView]];
  [listMatrix getRow:&dRow column:&dColumn forPoint:lastLocation];
  [listMatrix selectCellAtRow:dRow column:dColumn];
  // cell = [self cellAtRow:dRow column:dColumn];
  // [listMatrix ];
}

@end
