#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSTimeZone.h>

int main()
{
  ENTER_POOL
  NSTimeZone	*testObj = [NSTimeZone defaultTimeZone];

  test_NSObject(@"NSTimeZone", [NSArray arrayWithObject: testObj]); 

  LEAVE_POOL
  return 0;
}
