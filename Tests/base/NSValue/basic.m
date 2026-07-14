#import <Foundation/Foundation.h>
#import "Testing.h"
#import "ObjectTesting.h"

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  NSValue *testObj;

  test_alloc_only(@"NSValue");

  int val = 5;
  int out;
  testObj = [NSValue valueWithBytes: &val objCType: @encode(int)];
  [testObj getValue: &out];
  PASS_EQUAL(val, out, "NSValue -getValue returned the same integer");

  NSRange range_val = NSMakeRange(1, 1);
  NSRange range_out;
  testObj = [NSValue valueWithBytes: &range_val objCType: @encode(NSRange)];
  [testObj getValue: &range_out];
  PASS(NSEqualRanges(range_val, range_out), "NSValue -getValue returned the same NSRange");
  range_out = [testObj rangeValue];
  PASS(NSEqualRanges(range_val, range_out), "NSValue -rangeValue returned the same NSRange");

  [arp release]; arp = nil;
  return 0;
}
