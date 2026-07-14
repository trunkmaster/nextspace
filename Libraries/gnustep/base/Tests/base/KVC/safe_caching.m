#import <Foundation/NSKeyValueCoding.h>
#import <Foundation/NSValue.h>
#import <objc/runtime.h>

#import "Testing.h"

@interface TestClass : NSObject

- (float)floatVal;
@end

@implementation TestClass

- (float)floatVal
{
  return 1.0f;
}
@end

static float
getFloatValIMP(id receiver, SEL cmd)
{
  return 2.0f;
}

void
testInstallingNewMethodAfterCaching(void)
{
  TestClass *obj = [TestClass new];

  START_SET("Installing Methods after initial Cache")

  // Initial lookups
  PASS_EQUAL([obj valueForKey:@"floatVal"], [NSNumber numberWithFloat:1.0f],
             "Initial lookup has the correct value");
  // Slots are now cached

  // Register getFloatVal which should be used if available according to search
  // pattern
  SEL sel = sel_registerName("getFloatVal");
  class_addMethod([TestClass class], sel, (IMP) getFloatValIMP, "f@:");

  PASS_EQUAL([obj valueForKey:@"floatVal"], [NSNumber numberWithFloat:2.0f],
             "Slot was correctly invalidated");

  END_SET("Installing Methods after initial Cache")

  [obj release];
}

int
main(int argc, char *argv[])
{
  testInstallingNewMethodAfterCaching();
  return 0;
}
