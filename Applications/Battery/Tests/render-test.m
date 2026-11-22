#import "../BatteryView.h"

int main(int argc, const char **argv)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  [NSApplication sharedApplication];
  NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(256, 64)];
  [image lockFocus];
  for (int i = 0; i < 4; i++) {
    BatteryView *view = [[BatteryView alloc] initWithFrame:NSMakeRect(0, 0, 64, 64)];
    if (i == 3) [view setUnavailable];
    else [view setPercentage:(i == 0 ? 100 : (i == 1 ? 20 : 5))
                         ac:(i == 0 ? 1 : 0) state:(i == 0 ? 0 : (i == 1 ? 1 : 2))];
    [NSGraphicsContext saveGraphicsState];
    NSAffineTransform *transform = [NSAffineTransform transform];
    [transform translateXBy:i * 64 yBy:0];
    [transform concat];
    [view drawRect:[view bounds]];
    [NSGraphicsContext restoreGraphicsState];
    [view release];
  }
  NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
    initWithFocusedViewRect:NSMakeRect(0, 0, 256, 64)];
  [image unlockFocus];
  NSData *png = [bitmap representationUsingType:NSPNGFileType properties:[NSDictionary dictionary]];
  NSString *path = argc > 1 ? [NSString stringWithUTF8String:argv[1]] : @"/tmp/battery-states.png";
  BOOL ok = [png writeToFile:path atomically:YES];
  [bitmap release]; [image release];
  [pool drain];
  return ok ? 0 : 1;
}
