#import "BatteryView.h"

@implementation BatteryView
- (void)setPercentage:(NSInteger)percent ac:(NSInteger)ac state:(NSInteger)state
{
  percentage = percent;
  acLine = ac;
  batteryState = state;
  available = YES;
  [self setToolTip:[NSString stringWithFormat:@"Battery: %ld%% — %@",
    (long)percent, state == 3 ? @"charging" : (ac == 1 ? @"AC power" : @"battery power")]];
  [self setNeedsDisplay:YES];
}

- (void)setUnavailable
{
  available = NO;
  [self setToolTip:@"Battery information unavailable"];
  [self setNeedsDisplay:YES];
}

- (void)drawLabel:(NSString *)text y:(CGFloat)y size:(CGFloat)size color:(NSColor *)color
{
  NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
    [NSFont boldSystemFontOfSize:size], NSFontAttributeName,
    color, NSForegroundColorAttributeName, nil];
  NSSize extent = [text sizeWithAttributes:attributes];
  [text drawAtPoint:NSMakePoint(floor(33.5 - extent.width / 2), y)
    withAttributes:attributes];
}

/* Scanline shading also works with the legacy GNUstep art backend. */
- (void)shadeRect:(NSRect)rect from:(NSColor *)bottom to:(NSColor *)top
{
  for (NSInteger row = 0; row < (NSInteger)rect.size.height; row++) {
    CGFloat fraction = rect.size.height > 1 ? row / (rect.size.height - 1) : 0;
    [[bottom blendedColorWithFraction:fraction ofColor:top] set];
    NSRectFill(NSMakeRect(rect.origin.x, rect.origin.y + row, rect.size.width, 1));
  }
}

- (void)drawRect:(NSRect)dirtyRect
{
  /* The same 64-point, raised gray tile used by the Preferences dock icon. */
  [[NSColor colorWithCalibratedWhite:0.65 alpha:1] set];
  NSRectFill([self bounds]);
  [[NSColor whiteColor] set];
  NSRectFill(NSMakeRect(0, 63, 64, 1));
  NSRectFill(NSMakeRect(0, 0, 1, 64));
  [[NSColor darkGrayColor] set];
  NSRectFill(NSMakeRect(0, 0, 64, 1));
  NSRectFill(NSMakeRect(63, 0, 1, 64));

  /* Small, beveled objects and a cast shadow match the Gorm/ProjectCenter
     icons while retaining the uncluttered gauge layout. */
  [[NSColor colorWithCalibratedWhite:0.22 alpha:1] set];
  NSRectFill(NSMakeRect(12, 27, 47, 26));
  NSRectFill(NSMakeRect(59, 35, 2, 10));
  NSColor *metalBottom = [NSColor colorWithCalibratedWhite:0.42 alpha:1];
  NSColor *metalTop = [NSColor colorWithCalibratedWhite:0.94 alpha:1];
  [self shadeRect:NSMakeRect(10, 29, 47, 26) from:metalBottom to:metalTop];
  [self shadeRect:NSMakeRect(57, 37, 3, 10) from:metalBottom to:metalTop];
  [[NSColor colorWithCalibratedWhite:0.98 alpha:1] set];
  NSRectFill(NSMakeRect(10, 54, 47, 1));
  NSRectFill(NSMakeRect(10, 30, 1, 24));
  [[NSColor colorWithCalibratedWhite:0.18 alpha:1] set];
  NSRectFill(NSMakeRect(11, 30, 45, 24));
  [self shadeRect:NSMakeRect(12, 31, 43, 22)
             from:[NSColor colorWithCalibratedWhite:0.71 alpha:1]
               to:[NSColor colorWithCalibratedWhite:0.89 alpha:1]];
  if (available) {
    NSColor *fill = percentage <= 10 || batteryState == 2
      ? [NSColor colorWithCalibratedRed:0.92 green:0.25 blue:0.22 alpha:1]
      : (percentage <= 20 || batteryState == 1
        ? [NSColor colorWithCalibratedRed:0.96 green:0.76 blue:0.18 alpha:1]
        : [NSColor colorWithCalibratedRed:0.28 green:0.78 blue:0.34 alpha:1]);
    NSRect charge = NSMakeRect(12, 31, floor(43 * percentage / 100.0), 22);
    if (charge.size.width > 0) {
      [self shadeRect:charge from:[fill shadowWithLevel:0.25]
                               to:[fill highlightWithLevel:0.28]];
      [[fill highlightWithLevel:0.55] set];
      NSRectFill(NSMakeRect(12, 52, charge.size.width, 1));
    }
  }
  [self drawLabel:available ? [NSString stringWithFormat:@"%ld%%", (long)percentage] : @"--"
                y:35 size:13 color:[NSColor blackColor]];
  /* Keep a clear gap below the gauge; power details remain in the tooltip. */
  if (available && (acLine == 1 || batteryState == 3)) {
    NSBezierPath *bolt = [NSBezierPath bezierPath];
    [bolt moveToPoint:NSMakePoint(35, 22)];
    [bolt lineToPoint:NSMakePoint(27, 12)];
    [bolt lineToPoint:NSMakePoint(32, 12)];
    [bolt lineToPoint:NSMakePoint(29, 5)];
    [bolt lineToPoint:NSMakePoint(38, 16)];
    [bolt lineToPoint:NSMakePoint(33, 16)];
    [bolt closePath];
    [NSGraphicsContext saveGraphicsState];
    NSAffineTransform *shadow = [NSAffineTransform transform];
    [shadow translateXBy:1 yBy:-1];
    [shadow concat];
    [[NSColor colorWithCalibratedWhite:0.25 alpha:1] set];
    [bolt fill];
    [NSGraphicsContext restoreGraphicsState];
    [NSGraphicsContext saveGraphicsState];
    [bolt addClip];
    [self shadeRect:NSMakeRect(26, 4, 13, 19)
               from:[NSColor colorWithCalibratedRed:0.82 green:0.40 blue:0.04 alpha:1]
                 to:[NSColor colorWithCalibratedRed:1 green:0.90 blue:0.37 alpha:1]];
    [NSGraphicsContext restoreGraphicsState];
    [[NSColor colorWithCalibratedRed:0.40 green:0.24 blue:0.04 alpha:1] set];
    [bolt setLineWidth:0.8];
    [bolt stroke];
  }
}
@end
