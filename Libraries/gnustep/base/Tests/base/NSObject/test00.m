#import "Testing.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

int main()
{
  ENTER_POOL
  Class theClass = NSClassFromString(@"NSObject"); 
  PASS(theClass == [NSObject class],
       "'NSObject' %s","uses +class to return self");
  LEAVE_POOL
  return 0;
}
