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

- (void)mouseDown:(NSEvent *)event
{
  NSInteger    row, column;
  NSPoint      mouseInWindow = [event locationInWindow];
  NSPoint      mouseInList;
  LanguageCell *cell;
  NSRect       cellFrame;

  mouseInList = [[[event window] contentView] convertPoint:mouseInWindow
                                                    toView:self];
  [self getRow:&row column:&column forPoint:mouseInList];
  cell = [self cellAtRow:row column:column];
  cellFrame = [self cellFrameAtRow:row column:column];
  [cell setDragged:YES];
  // [cell setEnabled:NO];
  
  NSLog(@"LanguageList: mouseDown on '%@'",
        [[self cellAtRow:row column:column] title]);

  /*****************************************************************************/
  NSWindow    *window = [event window];
  NSRect      superviewFrame = [[self superview] frame];
  CGFloat     cellHeight, superHeight;
  NSPoint     location, initialLocation, lastLocation;
  NSPoint     cellOrigin = cellFrame.origin;
  NSInteger   y;
  NSUInteger  eventMask = (NSLeftMouseDownMask | NSLeftMouseUpMask
                           | NSPeriodicMask | NSOtherMouseUpMask
                           | NSRightMouseUpMask);
  BOOL        done = NO;
  NSTextField *draggedRow;

  lastLocation = initialLocation = [window mouseLocationOutsideOfEventStream];
  cellHeight = cellFrame.size.height;
  superHeight = [[self superview] frame].size.height;

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
  [self addSubview:draggedRow];

  NSLog(@"Superview %@ frame %@",
        [[self superview] className], NSStringFromRect(superviewFrame));
  
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
          [cell setDragged:NO];
          [draggedRow removeFromSuperview];
          [draggedRow release];
          break;
        case NSPeriodic:
          location = [window mouseLocationOutsideOfEventStream];
          if (NSEqualPoints(location, lastLocation) == NO)
            {
              y = cellOrigin.y;
              y += (lastLocation.y - location.y);
              NSLog(@"cellOrigin: %@, y:%li",
                    NSStringFromPoint(cellOrigin), y);

              if (y > 0 && ((y + cellHeight) < superHeight))
                {
                  cellOrigin.y = y;
                }
              else if (y < 0 && cellOrigin.y > 1)
                {
                  cellOrigin.y = 1;
                }
              else
                {
                  continue;
                }
              [draggedRow setFrameOrigin:cellOrigin];
              [self setNeedsDisplay:YES];
              lastLocation = location;
            }
          break;
        default:
          break;
        }
    }
  [NSEvent stopPeriodicEvents];
}

@end
