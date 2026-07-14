#import "ObjectTesting.h"
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSTimer.h>
#import <Foundation/NSAutoreleasePool.h>

int main()
{
  ENTER_POOL
  id	testObj;
  
  PASS([NSRunLoop new] == nil, "run loop initialises to nil");
  testObj = [NSRunLoop currentRunLoop];
  test_NSObject(@"NSRunLoop", [NSArray arrayWithObject: testObj]);

  PASS(AUTORELEASE([NSTimer new]) == nil, "timer initialises to nil");
  testObj = AUTORELEASE([[NSTimer alloc] initWithFireDate: 0 interval: 0 target: [NSObject class] selector: @selector(description) userInfo: nil repeats: NO]);
  test_NSObject(@"NSTimer", [NSArray arrayWithObject: testObj]);
  
  LEAVE_POOL
  return 0;
}
