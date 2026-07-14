#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSHashTable.h>
#import "ObjectTesting.h"

@interface MyClass: NSObject
@end

@implementation	MyClass
- (NSUInteger) hash
{
  return 42;
}
- (BOOL) isEqual: (id)other
{
  return [other isKindOfClass: [self class]];
}
#if 0
- (oneway void) release
{
  NSLog(@"releasing %u", (unsigned)[self retainCount]);
  [super release];
}
- (id) retain
{
  id	result = [super retain];

  NSLog(@"retained %u", (unsigned)[self retainCount]);
  return result;
}
#endif
@end

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSHashTable		*t;
  MyClass		*o;
  MyClass		*o2;
  int			c;

  t = [[NSHashTable alloc] initWithOptions: NSHashTableObjectPointerPersonality
				  capacity: 10];

  o = [MyClass new];
  c = [o retainCount];
  PASS(c == 1, "initial retain count is one")

  [t addObject: @"a"];
  [t addObject: o];
  PASS([o retainCount] == c + 1, "add to hash table increments retain count")

  PASS(NSHashGet(t, o) == o, "object found in table")

  [t removeObject: o];
  PASS([o retainCount] == c, "remove from hash table decrements retain count")

  RELEASE(t);
  RELEASE(o);

  t = NSCreateHashTable(NSObjectHashCallBacks, 10);

  o = [MyClass new];
  c = [o retainCount];
  PASS(c == 1, "initial retain count is one")

  [t addObject: @"a"];
  [t addObject: o];
  PASS([o retainCount] == c + 1, "add to hash table increments retain count")

  PASS(NSHashGet(t, o) == o, "object found in table")

  [t removeObject: o];
  PASS([o retainCount] == c, "remove from hash table decrements retain count")

  o2 = [MyClass new];
  PASS([o2 retainCount] == 1, "initial retain count of second object OK")

  [t addObject: o];
  [t addObject: o2];
  PASS([o retainCount] == 1, "first object was removed")
  PASS([o2 retainCount] == 2, "second object was added")

  RELEASE(t);
  RELEASE(o);
  RELEASE(o2);

  [arp release]; arp = nil;
  return 0;
}
