
#define FAKE_PROXY 1

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

#ifndef __has_feature
#define __has_feature(x) 0
#endif


// Real object
@interface RealObject : NSObject
{
  int notificationCounter;
}
- (int) count;
- (void) reset;
- (void) test: (NSNotification *)aNotification;
@end

@implementation RealObject
- (int) count
{
  return notificationCounter;
}
- (void) reset
{
  notificationCounter = 0;
}
- (void) test: (NSNotification *)aNotification
{
  notificationCounter++;
}
@end

// Proxy object
@interface ProxyObject : NSObject
{
  RealObject *realObject;
}
- (id) initWithRealObject: (RealObject *)anObject;
@end
@interface ProxyObject(ForwardedMethods)
- (void) test: (NSNotification *)aNotification;
@end

@implementation ProxyObject
- (id) initWithRealObject: (RealObject *)anObject
{
  if ((self = [super init]) != nil)
    {
      realObject = [anObject retain];
    }
  return self;
}
- (void) dealloc
{
  [realObject release];
  [super dealloc];
}

- (BOOL) respondsToSelector: (SEL)aSelector
{
  return [super respondsToSelector: aSelector]
    || sel_isEqual(aSelector, @selector(test:));
}
- (NSMethodSignature *) methodSignatureForSelector: (SEL)aSelector
{
  NSMethodSignature *methodSignature;

  if ([super respondsToSelector: aSelector])
    {
      methodSignature = [super methodSignatureForSelector: aSelector];
    }
  else if (sel_isEqual(aSelector, @selector(test:)))
    {
      methodSignature = [realObject methodSignatureForSelector: aSelector];
    }
  else
    {
      methodSignature = nil;
    }
  return methodSignature;
}

- (void) forwardInvocation: (NSInvocation *)anInvocation
{
  if (sel_isEqual([anInvocation selector], @selector(test:)))
    {
      [anInvocation invokeWithTarget: realObject];
    }
  else
    {
      [super forwardInvocation: anInvocation];
    }
}
@end


// Test program
int
main(int argc, char **argv)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  NSObject *testObject = [[[NSObject alloc] init] autorelease];
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

  NSNotification *aNotification =
    [NSNotification notificationWithName: @"TestNotification"
                                  object: testObject];

  // Create the real object and its proxy
  RealObject *real = [[[RealObject alloc] init] autorelease];
  ProxyObject *proxy = [[[ProxyObject alloc]
    initWithRealObject: real] autorelease];

  // Make the proxy object an observer for the sample notification
  // NB It is important (for the test) to perform this with a local
  //    autorelease pool.
  ENTER_POOL
    NSLog(@"Adding proxy observer");
    [nc addObserver: proxy
	   selector: @selector(test:)
	       name: @"TestNotification"
	     object: testObject];
    [nc postNotification: aNotification];
    PASS(1 == [real count], "notification via proxy works immediately")
  LEAVE_POOL

  // Post the notification
  // NB It is not important that this code is performed with a
  //    local autorelease pool
  {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    [nc postNotification: aNotification];
    PASS(2 == [real count], "notification via proxy works after pool")
    [pool release];
  }
  [nc postNotification: aNotification];
  PASS(3 == [real count], "notification via proxy works repeatedly")

  [nc removeObserver: proxy];

#if __has_feature(blocks)
  {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    id<NSObject>	o;
    unsigned		c;

    NSLog(@"Adding block observer");
    o = [nc addObserverForName: @"TestNotification"
		        object: testObject
			 queue: nil
		    usingBlock: ^(NSNotification *n)
    {
      [real test: n];
    }];
    o = AUTORELEASE(RETAIN(o));
    c = [o retainCount];
    [nc postNotification: aNotification];
    PASS(4 == [real count], "notification via block works immediately")
    PASS([o retainCount] == c,
      "observer retain count unaltered on notification")
    [nc removeObserver: o];
    PASS([o retainCount] + 1 == c,
      "observer retain count decremented on removal")
    [pool release];
  }
#endif

  /* Now test the feature whereby a deallocated instance is automatically
   * removed as an observer (so we don't post to it and crash).
   */
  real = [RealObject new];
  PASS(0 == [real count], "initial count is zero")
  ENTER_POOL
    NSLog(@"Adding real observer");
    [nc addObserver: real
	   selector: @selector(test:)
	       name: @"TestNotification"
	     object: testObject];
    [nc postNotification: aNotification];
    PASS(1 == [real count], "notification works immediately")
  LEAVE_POOL

  ENTER_POOL
    PASS([real retainCount] == 1, "retain count ready for dealloc")
    DESTROY(real);
    PASS_RUNS([nc postNotification: aNotification];,
      "automatic removal of deallocated instance OK")
  LEAVE_POOL

  [pool release];
  return 0;
}
