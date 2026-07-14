#import <Foundation/Foundation.h>
#include <objc/runtime.h>
#import "ObjectTesting.h"

static BOOL notifiedCurrent = NO;

@interface Toggle : NSObject
@end

@implementation Toggle
- (void) foo: (NSNotification*)n
{
  notifiedCurrent = NO;
}
- (void) bar: (NSNotification*)n
{
  notifiedCurrent = YES;
}
@end

int main(void)
{
  ENTER_POOL
  NSNotificationCenter *nc;
  id t = AUTORELEASE([Toggle new]);

  nc = AUTORELEASE([NSNotificationCenter new]);
  [nc addObserver: t selector: @selector(foo:) name: nil object: nil];
  class_replaceMethod([Toggle class],
    @selector(foo:),
    class_getMethodImplementation([Toggle class], @selector(bar:)),
    "v@:@");
  [nc postNotificationName: @"foo" object: t];
  PASS(YES == notifiedCurrent, "implementation not cached");
  LEAVE_POOL
  return 0;
}
