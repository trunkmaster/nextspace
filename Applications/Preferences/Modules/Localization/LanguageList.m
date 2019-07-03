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
#include "LanguageList.h"

@interface LanguageCell : NSTextFieldCell
{
  BOOL isDragged;
  BOOL isDrawEdges;
}
@end

@implementation LanguageCell

- (id)init
{
  self = [super init];
  isDragged = NO;
  isDrawEdges = NO;
  return self;
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame
                       inView:(NSView *)controlView
{
  // NSLog(@"Draw cell with frame: %@", NSStringFromRect(cellFrame));
  if (!isDragged)
    {
      [[NSColor controlBackgroundColor] set];
      NSRectFill(cellFrame);
      cellFrame.origin.x += 2;
      [self _drawAttributedText:[self _drawAttributedString]
                        inFrame:[self titleRectForBounds:cellFrame]];

      if (isDrawEdges)
        {
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
}

- (BOOL)isDragged
{
  return isDragged;
}

- (void)setDragged:(BOOL)yn
{
  isDragged = yn;
  [[self controlView] setNeedsDisplay:YES];
}

- (void)setDrawEdges:(BOOL)yn
{
  isDrawEdges = yn;
}

@end

@implementation LanguageList

- (id)initWithFrame:(NSRect)frameRect
{
  self = [super initWithFrame:frameRect];
  [self setCellClass:[LanguageCell class]];

  [self setIntercellSpacing:NSMakeSize(0,0)];
  [self setAllowsEmptySelection:YES];
  [self setAutoscroll:YES];
  [self setDrawsBackground:YES];
  [self setBackgroundColor:[NSColor darkGrayColor]];
    
  return self;
}

- (void)dealloc
{
  TEST_RELEASE(draggedRow);
  [super dealloc];
}


- (void)loadRowsFromArray:(NSArray *)array
{
  NSCell        *cell;
  NSBundle      *baseBundle = [NSBundle bundleForLibrary:@"gnustep-base"];
  NSString      *languagePath, *languageName;
  NSDictionary  *languageDesc;
  NSFileManager *fm = [NSFileManager defaultManager];
  
  for (int i=0; i < [array count]; i++)
    {
      languageName = [array objectAtIndex:i];
      languagePath = [baseBundle pathForResource:languageName
                                          ofType:@""
                                     inDirectory:@"Languages"];
      if ([fm fileExistsAtPath:languagePath] == NO)
        continue;
      
      languageDesc = [NSDictionary dictionaryWithContentsOfFile:languagePath];
      
      [self addRow];
      cell = [self makeCellAtRow:i column:0];
      [cell setObjectValue:[languageDesc objectForKey:@"NSFormalName"]];
      [cell setRepresentedObject:languageName];
      [cell setSelectable:NO];
    }
}

- (NSArray *)arrayFromRows
{
  NSMutableArray *languages = [NSMutableArray array];

  for (id cell in [self cells])
    {
      [languages addObject:[cell representedObject]];
    }
  
  return languages;
}

- (void)setScrollView:(NSScrollView *)view
{
  scrollView = view;
}

- (NSInteger)swapCellAtPoint:(NSPoint)location
                    withCell:(LanguageCell *)draggedCell
                       atRow:(NSInteger)dRow
{
  LanguageCell *cell, *tmpCell;
  NSInteger    row, column;
  
  [self getRow:&row column:&column forPoint:location];
  cell = [self cellAtRow:row column:column];
  if (cell && cell != draggedCell)
    {
      tmpCell = [cell copy];
      [self putCell:draggedCell atRow:row column:column];
      [self putCell:tmpCell atRow:dRow column:column];
      [tmpCell release];
      dRow = row;
    }
  return dRow;
}

- (void)mouseDown:(NSEvent *)event
{
  NSWindow     *window = [event window];
  NSView       *contentView = [window contentView];
  NSInteger    dRow, dColumn;
  NSPoint      location, lastLocation;
  LanguageCell *draggedCell;
  NSRect       cellFrame;
  NSPoint      cellOrigin;
  CGFloat      cellHeight;

  // Determine clicked row
  lastLocation = [contentView convertPoint:[event locationInWindow]
                                    toView:[scrollView contentView]];
  [self getRow:&dRow column:&dColumn forPoint:lastLocation];
  draggedCell = [self cellAtRow:dRow column:dColumn];
  cellFrame = [self cellFrameAtRow:dRow column:dColumn];
  cellOrigin = cellFrame.origin;
  cellHeight = cellFrame.size.height;
  // NSLog(@"LanguageList: mouseDown on '%@'", [cell title]);

  // Prepare for dragging
  [draggedCell setDragged:YES];
  if (!draggedRow)
    {
      [NSTextField setCellClass:[LanguageCell class]];
      draggedRow = [[NSTextField alloc] initWithFrame:cellFrame];
      [draggedRow setBordered:NO];
      [draggedRow setBezeled:NO];
      [draggedRow setEditable:NO];
      [draggedRow setSelectable:NO];
      [draggedRow setDrawsBackground:YES];
      [draggedRow setBackgroundColor:[NSColor controlBackgroundColor]];
      [[draggedRow cell] setDrawEdges:YES];
    }
  else
    {
      [draggedRow setFrame:cellFrame];
    }
  [draggedRow setStringValue:[draggedCell title]];
  [self addSubview:draggedRow];

  // NSLog(@"NSMatrix superview visible rect: %@", NSStringFromRect([[self superview] visibleRect]));

  /*****************************************************************************/
  NSUInteger  eventMask = (NSLeftMouseDownMask | NSLeftMouseUpMask
                           | NSPeriodicMask | NSOtherMouseUpMask
                           | NSRightMouseUpMask);
  // NSRect      listRect = [[self superview] visibleRect];
  NSRect      listRect = [scrollView documentVisibleRect];
  CGFloat     listHeight = listRect.size.height;
  CGFloat     listWidth = listRect.size.width;
  NSInteger   y;
  BOOL        done = NO;

  [NSEvent startPeriodicEventsAfterDelay:0.02 withPeriod:0.02];
  
  while (!done)
    {
      event = [NSApp nextEventMatchingMask:eventMask
                                 untilDate:[NSDate distantFuture]
                                    inMode:NSEventTrackingRunLoopMode
                                   dequeue:YES];

      switch ([event type])
        {
        case NSRightMouseUp:
        case NSOtherMouseUp:
        case NSLeftMouseUp:
          // NSLog(@"Mouse UP.");
          done = YES;
          [draggedCell setDragged:NO];
          [draggedRow removeFromSuperview];
          if (_target)
            [_target performSelector:_action];
          break;
        case NSPeriodic:
          location = [contentView
                       convertPoint:[window mouseLocationOutsideOfEventStream]
                             toView:[scrollView contentView]];
          if (NSEqualPoints(location, lastLocation) == NO &&
              location.x > listRect.origin.x &&
              location.x < listWidth)
            {
              if (location.y > listRect.origin.y &&
                  location.y < (listRect.origin.y + listHeight))
                {
                  y = cellOrigin.y;
                  y += (location.y - lastLocation.y);
              
                  // NSLog(@"cellOrigin: %@, y:%li", NSStringFromPoint(cellOrigin), y);

                  if (y >= listRect.origin.y &&                               // top position
                      ((y + cellHeight) <= (listRect.origin.y + listHeight))) // bottom position
                    {
                      cellOrigin.y = y;
                    }

                  // Swap cells during dragging
                  dRow = [self swapCellAtPoint:location
                                      withCell:draggedCell
                                         atRow:dRow];
                }
              else if (location.y >= (listRect.origin.y + listHeight) &&
                       [[scrollView verticalScroller] floatValue] < 1.0)
                {
                  listRect.origin.y += [scrollView lineScroll];
                  [[scrollView documentView] scrollRectToVisible:listRect];
                  cellOrigin.y = (listRect.origin.y + listHeight) - cellHeight;
                  // Swap cells during dragging
                  dRow = [self swapCellAtPoint:location
                                      withCell:draggedCell
                                         atRow:dRow];
                }
              else if (location.y <= listRect.origin.y &&
                       listRect.origin.y > 0)
                {
                  listRect.origin.y -= [scrollView lineScroll];
                  [[scrollView documentView] scrollRectToVisible:listRect];
                  cellOrigin.y = listRect.origin.y;
                  // Swap cells during dragging
                  dRow = [self swapCellAtPoint:location
                                      withCell:draggedCell
                                         atRow:dRow];
                }
              else
                {
                  continue;
                }
              lastLocation = location;
              [draggedRow setFrameOrigin:cellOrigin];
              [self setNeedsDisplay:YES];
            }
          break;
        default:
          break;
        }
    }
  [NSEvent stopPeriodicEvents];
}

@end
