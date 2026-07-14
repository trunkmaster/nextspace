#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

@interface                              Foo : NSObject
{
@public
  BOOL		a;
  NSInteger	b;
  NSString	*c;
  NSArray	*d;
}
- (void) setA: (BOOL)v;
- (void) setB: (NSInteger)v;
- (void) setC: (NSString *)v;
@end

@implementation Foo
- (void) setA: (BOOL)v
{
  a = v;
}
- (void) setB: (NSInteger)v
{
  b = v;
}
- (void) setC: (NSString *)v
{
  c = v;
}
@end

@interface                   Observer : NSObject
{
  Foo		*object;
  NSString	*expectedKeyPath;
  NSInteger	receivedCalls;
}
- (NSString*) expectedKeyPath;
- (void) setExpectedKeyPath: (NSString*)s;
- (NSInteger) receivedCalls;
- (void) setReceivedCalls: (NSInteger)i;
@end

@implementation Observer

- (id)init
{
  self = [super init];
  if (self)
    {
      receivedCalls = 0;
    }
  return self;
}

static char observerContext;

- (void)startObserving:(Foo *)target
{
  object = target;
  [target addObserver:self forKeyPath:@"a" options:0 context:&observerContext];
  [target addObserver:self forKeyPath:@"b" options:0 context:&observerContext];
  [target addObserver:self forKeyPath:@"c" options:0 context:&observerContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)o
                        change:(NSDictionary *)change
                       context:(void *)context
{
  PASS(context == &observerContext, "context");
  PASS(o == self->object, "object");
  PASS([keyPath isEqualToString: [self expectedKeyPath]], "key path");
  [self setReceivedCalls: [self receivedCalls] + 1];
}

- (NSString*) expectedKeyPath
{
  return expectedKeyPath;
}
- (void) setExpectedKeyPath: (NSString*)s
{
  expectedKeyPath = s;
}
- (NSInteger) receivedCalls
{
  return receivedCalls;
}
- (void) setReceivedCalls: (NSInteger)i
{
  receivedCalls = i;
}

@end

int
main(int argc, char *argv[])
{
  [NSAutoreleasePool new];

  Foo      *foo = [Foo new];
  Observer *obs = [Observer new];

  [obs startObserving: foo];

  [obs setExpectedKeyPath: @"a"];
  [foo setA: YES];
  PASS([obs receivedCalls] == 1, "received calls")

  [obs setExpectedKeyPath: @"b"];
  [foo setB: 1];
  PASS([obs receivedCalls] == 2, "received calls")

  [obs setExpectedKeyPath: @"c"];
  [foo setC: @"henlo"];
  PASS([obs receivedCalls] == 3, "received calls")

  return 0;
}

