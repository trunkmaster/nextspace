/* All Rights reserved */

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
  NSCell       *cell;
  NSBundle     *baseBundle = [NSBundle bundleForLibrary:@"gnustep-base"];
  NSString     *languagePath, *languageName;
  NSDictionary *languageDesc;
  
  for (int i=0; i < [array count]; i++)
    {
      languageName = [array objectAtIndex:i];
      languagePath = [baseBundle pathForResource:languageName
                                          ofType:@""
                                     inDirectory:@"Languages"];
      languageDesc = [NSDictionary dictionaryWithContentsOfFile:languagePath];
      
      [self addRow];
      cell = [self makeCellAtRow:i column:0];
      [cell setObjectValue:[languageDesc objectForKey:@"NSFormalName"]];
      [cell setRepresentedObject:languageName];
      [cell setSelectable:NO];
    }
}

- (void)setScrollView:(NSScrollView *)view
{
  scrollView = view;
}

- (void)mouseDown:(NSEvent *)event
{
  NSWindow     *window = [event window];
  NSView       *contentView = [window contentView];
  NSInteger    dRow, row, column;
  NSPoint      location, lastLocation;
  LanguageCell *draggedCell, *cell;
  NSRect       cellFrame;
  NSPoint      cellOrigin;
  CGFloat      cellHeight;

  // Determine clicked row
  lastLocation = [contentView convertPoint:[event locationInWindow]
                                    toView:[scrollView contentView]];
  [self getRow:&dRow column:&column forPoint:lastLocation];
  draggedCell = [self cellAtRow:dRow column:column];
  cellFrame = [self cellFrameAtRow:dRow column:column];
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

  /*****************************************************************************/
  NSUInteger  eventMask = (NSLeftMouseDownMask | NSLeftMouseUpMask
                           | NSPeriodicMask | NSOtherMouseUpMask
                           | NSRightMouseUpMask);
  CGFloat     listHeight = [[self superview] frame].size.height;
  CGFloat     listWidth = [[self superview] frame].size.width;
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
          break;
        case NSPeriodic:
          location = [contentView
                       convertPoint:[window mouseLocationOutsideOfEventStream]
                             toView:[scrollView contentView]];
          // NSLog(@"Mouse cursor in ScrollView: %@ (%@)",
          //       NSStringFromPoint(location),
          //       NSStringFromRect(superRect));
          if (NSEqualPoints(location, lastLocation) == NO &&
              location.x > 0 && location.x < listWidth)
            {
              [self getRow:&row column:&column forPoint:lastLocation];
              cell = [self cellAtRow:row column:column];
              if (cell != draggedCell)
                {
                  LanguageCell *tmpCell = [cell copy];
                  [self putCell:draggedCell atRow:row column:column];
                  [self putCell:tmpCell atRow:dRow column:column];
                  [tmpCell release];
                  // NSLog(@"LanguageList: drag over '%@'", [cell title]);
                  dRow = row;
                }
              if (location.y > 0 && location.y < listHeight)
                {
                  y = cellOrigin.y;
                  y += (location.y - lastLocation.y);
              
                  // NSLog(@"cellOrigin: %@, y:%li",
                  //       NSStringFromPoint(cellOrigin), y);

                  if (y >= 0 &&                         // top position
                      ((y + cellHeight) <= listHeight)) // bottom position
                    {
                      cellOrigin.y = y;
                    }
                }
              else if (location.y >= listHeight)
                {
                  cellOrigin.y = listHeight - cellHeight;
                }
              else if (location.y <= 0 && cellOrigin.y > 0)
                {
                  cellOrigin.y = 0;
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
