#import <AppKit/AppKit.h>

#import "NextSpace.h"
#import "NXTScrollerKnobSlotCell.h"

@implementation NextSpace

@synthesize knobSlotPattern;

#pragma mark - Init & dealloc

- (void)dealloc
{
  [knobSlotPattern release];
  [super dealloc];
}

- (NSImage *)knobSlotPattern
{
  if (knobSlotPattern == nil) {
    // NSLog(@"%s: Setting knob slot pattern image...", __func__);
    NSString *path = [[self bundle] pathForResource:@"SharedGrayAlpha"
                                             ofType:@"tiff"
                                        inDirectory:@"Resources"];
    // NSLog(@"SharedGrayAlpha path %@", path);
    NSImage *sharedGrayBits = [[NSImage alloc] initWithContentsOfFile:path];
    NSImage *pattern = [[NSImage alloc] initWithSize:NSMakeSize(12, 12)];
    NSData *tiffRep;

    [pattern lockFocusOnRepresentation:nil];
    [sharedGrayBits drawAtPoint:NSZeroPoint
                       fromRect:NSMakeRect(49, 88, 12, 12)
                      operation:NSCompositeSourceOver
                       fraction:1.0];
    [pattern unlockFocus];

    tiffRep = [pattern TIFFRepresentation];
    [pattern release];
    [sharedGrayBits release];
    knobSlotPattern = [[NSImage alloc] initWithData:tiffRep];

    // NSLog(@"%s: Setting knob slot pattern image - DONE!", __func__);
  }

  return knobSlotPattern;
}

#pragma mark - NSScroller

- (NSCell *)cellForScrollerKnobSlot:(BOOL)horizontal
{
  NXTScrollerKnobSlotCell *cell;

  cell = [NXTScrollerKnobSlotCell new];
  [cell setBordered:NO];
  [cell setTitle:nil];

  return cell;
}

#pragma mark - NSSlider

- (void)drawSliderBorderAndBackground:(NSBorderType)aType
                                frame:(NSRect)cellFrame
                               inCell:(NSCell *)cell
                         isHorizontal:(BOOL)horizontal
{
  if (NSIsEmptyRect(cellFrame)) {
    return;
  }

  if (aType == NSBezelBorder) {
    [self drawGrayBezel:cellFrame withClip:NSZeroRect];
  } else {
    [[GSTheme theme] drawBorderType:aType frame:cellFrame view:[cell controlView]];
  }
}

- (void)drawBarInside:(NSRect)rect inCell:(NSCell *)cell flipped:(BOOL)flipped
{
  if (NSIsEmptyRect(rect)) {
    return;
  }

  NSGraphicsContext *ctxt = GSCurrentContext();
  if ([[ctxt className] isEqualToString:@"CairoContext"]) {
    [ctxt GSSetPatterColor:self.knobSlotPattern];
    [ctxt DPSrectfill:rect.origin.x :rect.origin.y :rect.size.width :rect.size.height];
  }
}

// - (void)drawKnobInCell:(NSCell *)cell
// {
//   NSLog(@"%s", __func__);

//   NSView *controlView = [cell controlView];
//   NSSliderCell *sliderCell = (NSSliderCell *)cell;
//   NSRect knobRect = [sliderCell knobRectFlipped:[controlView isFlipped]];

//   [sliderCell drawKnob:knobRect];
// }

@end

