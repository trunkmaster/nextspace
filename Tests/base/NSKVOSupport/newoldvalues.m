#import <Foundation/Foundation.h>
#import "ObjectTesting.h"
#import "Testing.h"

#if defined (__OBJC2__)
#define FLAKY_ON_GCC_START
#define FLAKY_ON_GCC_END
#else
#define FLAKY_ON_GCC_START \
  testHopeful = YES;
#define FLAKY_ON_GCC_END \
  testHopeful = NO;
#endif

@class Bar;

@interface                     Foo : NSObject
{
  Bar		*globalBar;
  NSInteger	a;
}
@end

@interface                         Bar : NSObject
{
  NSInteger	x;
  Foo		*firstFoo;
  Foo		*secondFoo;
}
- (NSInteger) x;
@end

@implementation Foo

+ (NSSet *) keyPathsForValuesAffectingB
{
  return [NSSet setWithArray: [NSArray arrayWithObjects:
    @"a", @"globalBar.x", nil]];
}

- (NSInteger) a
{
  return a;
}
- (void) setA: (NSInteger)v
{
  a = v;
}
- (NSInteger) b
{
  return [self a] + [globalBar x];
}
- (Bar*) globalBar
{
  return globalBar;
}
- (void) setGlobalBar: (Bar*)v
{
  globalBar = v;
}

@end

@implementation Bar

- (Foo*) firstFoo
{
  return firstFoo;
}
- (void) setFirstFoo: (Foo*)v
{
  firstFoo = v;
}
- (Foo*) secondFoo
{
  return secondFoo;
}
- (void) setSecondFoo: (Foo*)v
{
  secondFoo = v;
}
- (NSInteger) x
{
  return x;
}
- (void) setX: (NSInteger)v
{
  x = v;
}

- (id)init
{
  self = [super init];
  if (self)
    {
      [self setFirstFoo: [Foo new]];
      [[self firstFoo] setGlobalBar: self];
      [self setSecondFoo: [Foo new]];
      [[self secondFoo] setGlobalBar: self];
    }
  return self;
}

@end

@interface                   Observer : NSObject
{
  Foo      	*object;
  NSInteger 	expectedOldValue;
  NSInteger 	expectedNewValue;
  NSInteger 	receivedCalls;
}
@end

@implementation Observer

- (NSInteger) expectedOldValue
{
  return expectedOldValue;
}
- (void) setExpectedOldValue: (NSInteger)v
{
  expectedOldValue = v;
}
- (NSInteger) expectedNewValue
{
  return expectedNewValue;
}
- (void) setExpectedNewValue: (NSInteger)v
{
  expectedNewValue = v;
}
- (Foo*) object
{
  return object;
}
- (void) setObject: (Foo*)v
{
  object = v;
}
- (NSInteger) receivedCalls
{
  return receivedCalls;
}
- (void) setReceivedCalls: (NSInteger)v
{
  receivedCalls = v;
}

- (id)init
{
  self = [super init];
  if (self)
    {
      [self setReceivedCalls: 0];
    }
  return self;
}

static char observerContext;

- (void) startObserving:(Foo *)target
{
  [self setObject: target];
  [target
    addObserver:self
     forKeyPath:@"b"
        options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
        context:&observerContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)o
                        change:(NSDictionary *)change
                       context:(void *)context
{
  PASS(context == &observerContext, "context is correct");
  PASS(o == [self object], "object is correct");

  id newValue = [change objectForKey: NSKeyValueChangeNewKey];
  id oldValue = [change objectForKey: NSKeyValueChangeOldKey];

  PASS([oldValue integerValue] == self.expectedOldValue,
       "new value in change dict");
  PASS([newValue integerValue] == self.expectedNewValue,
       "old value in change dict");
  [self setReceivedCalls: [self receivedCalls] + 1];
}

@end

int
main(int argc, char *argv[])
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];

  START_SET("newoldvalues");
  FLAKY_ON_GCC_START

  Bar *bar = [Bar new];
  [bar setX: 0];
  [[bar firstFoo] setA: 1];
  [[bar secondFoo] setA: 2];

  Observer *obs1 = [Observer new];
  Observer *obs2 = [Observer new];
  [obs1 startObserving: [bar firstFoo]];
  [obs2 startObserving: [bar secondFoo]];

  [obs1 setExpectedOldValue: 1];
  [obs1 setExpectedNewValue: 2];
  [obs2 setExpectedOldValue: 2];
  [obs2 setExpectedNewValue: 3];
  [bar setX: 1];
  PASS(obs1.receivedCalls == 1, "num observe calls");
  PASS(obs2.receivedCalls == 1, "num observe calls");

  [obs1 setExpectedOldValue: 2];
  [obs1 setExpectedNewValue: 2];
  [obs2 setExpectedOldValue: 3];
  [obs2 setExpectedNewValue: 3];
  [bar setX: 1];
  PASS([obs1 receivedCalls] == 2, "num observe calls");
  PASS([obs2 receivedCalls] == 2, "num observe calls");

  [obs1 setExpectedOldValue: 2];
  [obs1 setExpectedNewValue: 3];
  [[bar firstFoo] setA: 2];
  PASS([obs1 receivedCalls] == 3, "num observe calls");
  PASS([obs2 receivedCalls] == 2, "num observe calls");
  
  FLAKY_ON_GCC_END
  END_SET("newoldvalues");


  DESTROY(arp);

  return 0;
}
