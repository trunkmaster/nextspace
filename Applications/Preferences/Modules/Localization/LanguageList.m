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
  NSInteger    row, column;
  NSPoint      mouseInWindow = [event locationInWindow];
  NSPoint      mouseInList;
  LanguageCell *cell;
  NSRect       cellFrame;

  // Determine clicked row
  mouseInList = [contentView convertPoint:mouseInWindow toView:self];
  [self getRow:&row column:&column forPoint:mouseInList];
  cell = [self cellAtRow:row column:column];
  cellFrame = [self cellFrameAtRow:row column:column];
  NSLog(@"LanguageList: mouseDown on '%@'", [cell title]);

  // Prepare for dragging
  [cell setDragged:YES];
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
      [draggedRow setStringValue:[cell title]];
      [[draggedRow cell] setDrawEdges:YES];
    }
  [self addSubview:draggedRow];

  /*****************************************************************************/
  NSPoint     cellOrigin = cellFrame.origin;
  CGFloat     cellHeight = cellFrame.size.height;
  NSRect      superRect = [[self superview] frame];
  CGFloat     listHeight = [[self superview] frame].size.height;
  NSPoint     location, lastLocation;
  NSInteger   y;
  NSUInteger  eventMask = (NSLeftMouseDownMask | NSLeftMouseUpMask
                           | NSPeriodicMask | NSOtherMouseUpMask
                           | NSRightMouseUpMask);
  BOOL        done = NO;

  [NSEvent startPeriodicEventsAfterDelay:0.02 withPeriod:0.02];
  
  lastLocation = [window mouseLocationOutsideOfEventStream];
  lastLocation = [contentView convertPoint:lastLocation toView:scrollView];
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
          [cell setDragged:NO];
          [draggedRow removeFromSuperview];
          break;
        case NSPeriodic:
          location = [window mouseLocationOutsideOfEventStream];
          // NSLog(@"Mouse cursor in Window: %@", NSStringFromPoint(location));
          location = [contentView convertPoint:location toView:scrollView];
          // NSLog(@"Mouse cursor in ScrollView: %@ (%@)",
          //       NSStringFromPoint(location),
          //       NSStringFromRect(superRect));
          if (NSEqualPoints(location, lastLocation) == NO &&
              location.x > 0 && location.x < superRect.size.width)
            {
              if (location.y > 0 && location.y < superRect.size.height)
                {
                  y = cellOrigin.y;
                  y += (location.y - lastLocation.y);
              
                  // NSLog(@"cellOrigin: %@, y:%li",
                  //       NSStringFromPoint(cellOrigin), y);

                  if (y > 0 && y < listHeight &&        // top position
                      ((y + cellHeight) <= listHeight)) // bottom position
                    {
                      cellOrigin.y = y;
                    }
                }
              else if (location.y > superRect.size.height)
                {
                  cellOrigin.y = superRect.size.height - cellHeight;
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
