#import "../BatteryStatus.h"
#include <assert.h>
int main(void)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  NSInteger p = -1, a = -1, b = -1;
  assert(BatteryParseStatus(@"1\n0\n100\n", &p, &a, &b) && p == 100 && a == 1 && b == 0);
  assert(BatteryParseStatus(@"0\n2\n5\n", &p, &a, &b) && p == 5 && b == 2);
  assert(BatteryParseStatus(@"1\n3\n20\n", &p, &a, &b) && b == 3);
  assert(BatteryParseStatus(@"0\n2\n0\n", &p, &a, &b) && p == 0);
  for (NSString *s in @[@"1\n0\n255\n", @"1\n4\n100\n", @"1\n0\n-1\n",
                        @"", @"error", @"1\n0\n", @"1\n0\n20junk", @"3\n0\n50\n"])
    assert(!BatteryParseStatus(s, &p, &a, &b));
  assert(!BatteryParseStatus(nil, &p, &a, &b));
  puts("battery status parser: PASS");
  [pool drain];
  return 0;
}
