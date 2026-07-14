#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSTask.h>

int main()
{
  ENTER_POOL
  NSArray	*testObj = AUTORELEASE([NSTask new]);

  test_NSObject(@"NSTask", [NSArray arrayWithObject: testObj]); 

  LEAVE_POOL
  return 0;
}
