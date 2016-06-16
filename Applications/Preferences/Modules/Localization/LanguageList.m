/* All Rights reserved */

#include <AppKit/AppKit.h>
#include "LanguageList.h"

@interface LanguageCell : NSActionCell
{
  BOOL isSelected;
}
@end
@implementation LanguageCell

- (id)init
{
  self = [super init];
  isSelected = NO;
  return self;
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame
                       inView:(NSView *)controlView
{
  NSLog(@"Draw cell with frame: %@", NSStringFromRect(cellFrame));
  if (!isSelected)
    {
      [[NSColor controlBackgroundColor] set];
      NSRectFill(cellFrame);
      cellFrame.origin.x += 2;
      [self _drawAttributedText:[self _drawAttributedString]
                        inFrame:[self titleRectForBounds:cellFrame]];
    }
}

- (BOOL)isSelected
{
  return isSelected;
}

- (void)setSelected:(BOOL)yn
{
  isSelected = yn;
  [[self controlView] setNeedsDisplay:YES];
}

@end

@implementation LanguageList

- (id)initWithFrame:(NSRect)frameRect
{
  self = [super initWithFrame:frameRect];
  [self setCellClass:[LanguageCell class]];

  // [super setMode:NSListModeMatrix];
  [self setIntercellSpacing:NSMakeSize(0,0)];
  [self setAllowsEmptySelection:YES];
  [self setAutoscroll:YES];
  // [self setCellSize:NSMakeSize(frameRect.size.width-24, 15)];
  [self setDrawsBackground:YES];
  [self setBackgroundColor:[NSColor darkGrayColor]];
    
  return self;
}

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
  NSInteger    row, column;
  NSPoint      mouseInWindow = [event locationInWindow];
  NSPoint      mouseInList;
  LanguageCell *cell;

  mouseInList = [[[event window] contentView] convertPoint:mouseInWindow
                                                    toView:self];
  [self getRow:&row column:&column forPoint:mouseInList];
  cell = [self cellAtRow:row column:column];
  [cell setSelected:![cell isSelected]];
  // [cell setEnabled:NO];
  
  NSLog(@"LanguageList: mouseDown on '%@'",
        [[self cellAtRow:row column:column] title]);

  /*****************************************************************************/
  NSWindow   *window = [self window];
  NSRect     boxRect = [box frame];
  NSPoint    location, initialLocation, lastLocation;
  NSRect     superFrame = [self frame];
  NSRect     displayFrame = [box displayFrame];
  NSPoint    initialOrigin, boxOrigin;
  NSUInteger eventMask = (NSLeftMouseDownMask | NSLeftMouseUpMask
                          | NSPeriodicMask | NSOtherMouseUpMask
                          | NSRightMouseUpMask);
  BOOL       done = NO;

  [NSEvent startPeriodicEventsAfterDelay:0.02 withPeriod:0.02];
  while (!done)
    {
      theEvent = [NSApp nextEventMatchingMask:eventMask
                                    untilDate:theDistantFuture
                                       inMode:NSEventTrackingRunLoopMode
                                      dequeue:YES];

      switch ([event type])
        {
        case NSRightMouseUp:
        case NSOtherMouseUp:
        case NSLeftMouseUp:
          // NSLog(@"Mouse UP.");
          done = YES;
          break;
        case NSPeriodic:
          location = [window mouseLocationOutsideOfEventStream];
          if (NSEqualPoints(location, lastLocation) == NO &&
              (fabs(location.x - initialLocation.x) > 5 ||
               fabs(location.y - initialLocation.y) > 5))
            {
              if (displayFrame.origin.x > 0 ||
                  boxOrigin.x > initialOrigin.x ||
                  (location.x - lastLocation.x) > 0)
                {
                  boxOrigin.x += (location.x - lastLocation.x);
                  if (boxOrigin.x < 0)
                    {
                      boxOrigin.x = 0;
                    }
                  else if ((boxOrigin.x + boxRect.size.width)
                           > superFrame.size.width)
                    {
                      boxOrigin.x =
                        superFrame.size.width - boxRect.size.width;
                    }
                }
                  
              boxOrigin.y += (location.y - lastLocation.y);
              if (boxOrigin.y < 0)
                {
                  boxOrigin.y = 0;
                }
              else if ((boxOrigin.y + boxRect.size.height)
                       > superFrame.size.height)
                {
                  boxOrigin.y = superFrame.size.height - boxRect.size.height;
                }
                  
              [box setFrameOrigin:boxOrigin];
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
