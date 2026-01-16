
#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSTheme.h>

#import "NextSpace.h"
#import "NXTScrollerKnobSlotCell.h"

// static NSImage *knobSlotPattern = nil;

@implementation NXTScrollerKnobSlotCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
  NSGraphicsContext *ctxt;
  NextSpace *theme = (NextSpace *)[GSTheme theme];

  if (NSIsEmptyRect(cellFrame)) {
    return;
  }

  ctxt = GSCurrentContext();
  if ([[ctxt className] isEqualToString:@"CairoContext"]) {
    [ctxt GSSetPatterColor:theme.knobSlotPattern];
    [ctxt DPSrectfill:cellFrame.origin.x:cellFrame.origin.y:cellFrame.size.width:cellFrame.size.height];
  }
}

@end
