#import "BatteryStatus.h"

BOOL BatteryParseStatus(NSString *output, NSInteger *percent, NSInteger *ac,
                        NSInteger *state)
{
  if (output == nil) return NO;
  NSScanner *scanner = [NSScanner scannerWithString:output];
  int a, b, p;
  if (![scanner scanInt:&a] || ![scanner scanInt:&b] || ![scanner scanInt:&p])
    return NO;
  [scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]
                     intoString:NULL];
  /* 255 denotes an unavailable battery, not a full one. */
  if (![scanner isAtEnd] || p < 0 || p > 100 || b < 0 || b > 3 || a < 0 || a > 2)
    return NO;
  *percent = p;
  *ac = a;
  *state = b;
  return YES;
}
