#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSPointerArray.h>

int main()
{
  START_SET("NSPointerArray weak objects")
  NSAutoreleasePool     *arp = [NSAutoreleasePool new];
  NSPointerArray        *array = [NSPointerArray weakObjectsPointerArray];
  int                   index;
  NSAutoreleasePool     *arp2 = [NSAutoreleasePool new];

  id testObj = [[[NSObject alloc] init] autorelease];
  for (index = 0; index < 10; index++)
    {
      [array addPointer: testObj];
    }
  PASS([[array allObjects] count] == index,
    "Array retains active weak reference");

  [arp2 release]; arp2 = nil;

  PASS([[array allObjects] count] == 0,
    "Array removes dead weak reference");

  [arp release]; arp = nil;
  END_SET("NSPointerArray weak objects")
  return 0;
}
