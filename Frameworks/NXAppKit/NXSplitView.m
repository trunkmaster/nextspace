/**
   @class NXSplitView

   @brief NSSplitView modifications:
   Divider thickness set to 12.

   @author Sergii Stoian
*/

#import <Foundation/NSNotification.h>
#import "NXSplitView.h"

NSString *NXSplitViewDividerDidDraw = @"NXSplitViewDividerDidDraw";

@implementation NXSplitView

// --- Overridings

- (CGFloat)dividerThickness
{
  return 12.0f;
}

- (void)mouseDown:(NSEvent *)theEvent
{
  if (!resizableState)
    return;

  [super mouseDown:theEvent];
}

- (void)resetCursorRects
{
  if (!resizableState)
    return;

  [super resetCursorRects];
}

- (NSRect)dividerRect
{
  return dividerRect;
}

- (void)drawDividerInRect:(NSRect)aRect
{
  if (resizableState == 0)
    return;
  
  [super drawDividerInRect:aRect];

  dividerRect = aRect;

  [[NSNotificationCenter defaultCenter] 
    postNotificationName:NXSplitViewDividerDidDraw
		  object:self];
}

// --- Extentions

- (void)setResizableState:(NSInteger)state
{
  resizableState = state;
  [self setNeedsDisplay:YES];
}

- (NSInteger)resizableState
{
  return resizableState;
}

@end
