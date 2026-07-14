#import "ObjectTesting.h"
#import <Foundation/NSBundle.h>
#import <Foundation/NSAutoreleasePool.h>

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
   
  test_alloc(@"NSBundle");
  test_NSObject(@"NSBundle",
    [NSArray arrayWithObject: AUTORELEASE([NSBundle new])]); 
  [arp release]; arp = nil;
  return 0;
}
