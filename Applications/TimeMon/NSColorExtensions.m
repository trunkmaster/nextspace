#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>
#import <AppKit/NSGraphics.h>
#import "NSColorExtensions.h"

@implementation NSColor (GetColorsFromString)
+ (NSColor *)colorFromStringRepresentation:(NSString *)colorString
{
  CGFloat r, g, b, a;
  NSArray *array = [colorString componentsSeparatedByString:@" "];

  if (!array) {
    return nil;
  }

  if ([array count] < 3) {
    NSLog(@"%@: + colorFromStringRepresentation", [[self class] description]);
    NSLog(@"%@: String must contain red, green, and blue components", [[self class] description]);
    return nil;
  }

  r = [[array objectAtIndex:0] floatValue];
  g = [[array objectAtIndex:1] floatValue];
  b = [[array objectAtIndex:2] floatValue];
  a = [array count] > 3 ? [[array objectAtIndex:3] floatValue] : 1.0;

  return [NSColor colorWithCalibratedRed:r green:g blue:b alpha:a];
}

- (NSString *)stringRepresentation
{
  CGFloat r, g, b, a;

  [[self colorUsingColorSpaceName:NSCalibratedRGBColorSpace] getRed:&r green:&g blue:&b alpha:&a];
  return [NSString stringWithFormat:@"%f %f %f %f",r,g,b,a];
}
@end
