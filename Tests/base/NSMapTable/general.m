#import <Foundation/NSAutoreleasePool.h>
#import "ObjectTesting.h"
#import <Foundation/NSMapTable.h>

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
  NSMapTable		*t;
  MyClass		*o;
  MyClass		*o2;
  int			c;

  t = [[NSMapTable alloc] initWithKeyOptions: NSMapTableObjectPointerPersonality
				valueOptions: NSMapTableObjectPointerPersonality
				    capacity: 10];

  o = [MyClass new];
  c = [o retainCount];
  PASS(c == 1, "initial retain count is one")

  [t setObject: @"a" forKey: o];
  PASS([o retainCount] == c + 1, "add map table key increments retain count")

  PASS_EQUAL((id)NSMapGet(t, o), @"a", "object found in table")

  [t removeObjectForKey: o];
  PASS([o retainCount] == c, "remove map table key decrements retain count")

  [t setObject: o forKey: @"a"];
  PASS([o retainCount] == c + 1, "add map table val increments retain count")

  PASS_EQUAL((id)NSMapGet(t, @"a"), o, "object found in table")

  [t removeObjectForKey: @"a"];
  PASS([o retainCount] == c, "remove map table val decrements retain count")

  RELEASE(t);
  RELEASE(o);

  t = NSCreateMapTable(NSObjectMapKeyCallBacks, NSObjectMapValueCallBacks, 10);

  o = [MyClass new];
  c = [o retainCount];
  PASS(c == 1, "initial retain count is one")

  [t setObject: @"a" forKey: o];
  PASS([o retainCount] == c + 1, "add map table key increments retain count")

  PASS_EQUAL((id)NSMapGet(t, o), @"a", "object found in table")

  [t removeObjectForKey: o];
  PASS([o retainCount] == c, "remove map table key decrements retain count")

  [t setObject: o forKey: @"a"];
  PASS([o retainCount] == c + 1, "add map table val increments retain count")

  PASS_EQUAL((id)NSMapGet(t, @"a"), o, "object found in table")

  [t removeObjectForKey: @"a"];
  PASS([o retainCount] == c, "remove map table val decrements retain count")

  [t setObject: o forKey: @"a"];
  o2 = [MyClass new];
  [t setObject: o2 forKey: @"a"];
  PASS([o retainCount] == 1, "old instance removed")
  PASS([o2 retainCount] == 2, "new instance added")

  RELEASE(t);
  RELEASE(o);
  RELEASE(o2);

  [arp release]; arp = nil;
  return 0;
}
