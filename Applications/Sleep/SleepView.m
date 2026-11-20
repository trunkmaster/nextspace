#import "SleepView.h"

@implementation SleepView
- (void)setTarget:(id)object action:(SEL)selector
{
  target = object;
  action = selector;
  [self setToolTip:@"Sleep…"];
}
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
- (void)mouseDown:(NSEvent *)event
{
  if (target && action) [target performSelector:action withObject:self];
}
- (void)drawRect:(NSRect)dirty
{
  [[NSColor colorWithCalibratedWhite:0.65 alpha:1] set];
  NSRectFill([self bounds]);
  [[NSColor whiteColor] set];
  NSRectFill(NSMakeRect(0,63,64,1)); NSRectFill(NSMakeRect(0,0,1,64));
  [[NSColor darkGrayColor] set];
  NSRectFill(NSMakeRect(0,0,64,1)); NSRectFill(NSMakeRect(63,0,1,64));

  [[NSColor colorWithCalibratedWhite:0.25 alpha:1] set];
  [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(13,10,42,42)] fill];
  NSBezierPath *rim = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(11,12,42,42)];
  [[NSColor colorWithCalibratedWhite:0.9 alpha:1] set]; [rim fill];
  [rim setLineWidth:1]; [[NSColor colorWithCalibratedWhite:0.42 alpha:1] set]; [rim stroke];
  NSColor *night = [NSColor colorWithCalibratedRed:0.16 green:0.23 blue:0.34 alpha:1];
  [night set];
  [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(14,15,36,36)] fill];
  [[NSColor colorWithCalibratedRed:0.98 green:0.9 blue:0.64 alpha:1] set];
  [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(21,22,24,24)] fill];
  [night set];
  [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(28,28,22,22)] fill];
  [[NSColor colorWithCalibratedWhite:0.95 alpha:1] set];
  NSRectFill(NSMakeRect(21,39,2,2));
}
@end
