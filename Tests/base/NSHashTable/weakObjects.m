#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSHashTable.h>

int main()
{
  START_SET("NSHashTable weak objects")
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSHashTable 		*hashTable = [NSHashTable weakObjectsHashTable];

  NSAutoreleasePool 	*arp2 = [NSAutoreleasePool new];

  id testObj = [[[NSObject alloc] init] autorelease];
  [hashTable addObject:testObj];
  PASS([[hashTable allObjects] count] == 1, "Table retains active weak reference");

  [arp2 release]; arp2 = nil;

  PASS([[hashTable allObjects] count] == 0, "Table removes dead weak reference");

  [arp release]; arp = nil;
  END_SET("NSHashTable weak objects")
  return 0;
}
