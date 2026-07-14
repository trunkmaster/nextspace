#import <GNUstepBase/GNUstep.h>

#import <Foundation/NSProxy.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSKeyValueObserving.h>

#import "Testing.h"

/**
 * The new KVO implementation for libobjc2/clang, located in Source/NSKVO*,
 * reuses or installs a hidden class and subsequently adds the swizzled
 * method to the hidden class. Make sure that the invocation mechanism calls
 * the swizzled method.
 */

@interface Observee : NSObject
{
 NSString	*_name;
 NSString	*_derivedName;
}

- (NSString *) name;
- (void) setName: (NSString *)name;

- (NSString *) derivedName;
- (void) setDerivedName: (NSString *)name;

@end

@implementation Observee

- (NSString *) name
{
  return AUTORELEASE(RETAIN(_name));
}
- (void) setName: (NSString *)name
{
    ASSIGN(_name, name);
}

- (NSString *) derivedName
{
  return [NSString stringWithFormat: @"Derived %@", [self name]];
}
- (void) setDerivedName: (NSString *)name
{
  ASSIGN(_derivedName, name);
}

+ (NSSet *) keyPathsForValuesAffectingDerivedName
{
  return [NSSet setWithObject: @"name"];
}

- (void) dealloc
{
  RELEASE(_name);
  RELEASE(_derivedName);
  DEALLOC
}

@end

@interface TProxy : NSProxy
{
  id _proxiedObject;
}
@end

@implementation TProxy

- (instancetype)initWithProxiedObject:(id)proxiedObject
{
  ASSIGN(_proxiedObject, proxiedObject);
  return self;
}

- (void) forwardInvocation: (NSInvocation *)invocation
{
  [invocation invokeWithTarget: _proxiedObject];
}

- (NSMethodSignature*) methodSignatureForSelector: (SEL)sel
{
  return [_proxiedObject methodSignatureForSelector: sel];
}

- (void) dealloc
{
  RELEASE(_proxiedObject);
  DEALLOC
}

@end

@interface Wrapper : NSObject
{
  TProxy	*_proxy;
}

- (instancetype) initWithProxy: (TProxy *) proxy; 

- (TProxy *) proxy;

@end

@implementation Wrapper

- (instancetype) initWithProxy: (TProxy *) proxy
{
  self = [super init];
  if (self)
    {
      _proxy = proxy;
    }

  return self;
}

- (TProxy *) proxy
{
  return _proxy;
}

@end

@interface Observer: NSObject
{
  int count;
  NSArray *keys;
}

@end

@implementation Observer

- (void) simpleKeypathTest
{
  Observee	*obj = [[Observee alloc] init];
  TProxy 	*proxy = [[TProxy alloc] initWithProxiedObject: obj];

  keys = [NSArray arrayWithObjects: @"derivedName", @"name", nil];
  count = 0;
	
  [(Observee *)proxy addObserver: self
		      forKeyPath: @"name"
			 options: NSKeyValueObservingOptionNew
			 context: NULL];
  [(Observee *)proxy addObserver: self
		      forKeyPath: @"derivedName"
			 options: NSKeyValueObservingOptionNew
			 context: NULL];
	
  [((Observee *)proxy) setName: @"MOO"];
  PASS(count == 2, "Got two change notifications");
	
  [obj setName: @"BAH"];
  PASS(count == 4, "Got two change notifications");
	
  [(Observee *)proxy removeObserver: self forKeyPath: @"name" context: NULL];
  [(Observee *)proxy removeObserver: self
			 forKeyPath: @"derivedName"
			    context: NULL];

  RELEASE(proxy);
  RELEASE(obj);
}

- (void) nestedKeypathTest
{
    Observee *obj = [[Observee alloc] init];
    TProxy *proxy = [[TProxy alloc] initWithProxiedObject: obj];
    Wrapper *w = [[Wrapper alloc] initWithProxy: proxy];

    keys = [NSArray arrayWithObjects: @"proxy.derivedName", @"proxy.name", nil];
    count = 0;

    [w addObserver: self
	forKeyPath: @"proxy.name"
	   options: NSKeyValueObservingOptionNew
	   context: NULL];
    [w addObserver: self
	forKeyPath: @"proxy.derivedName"
	   options: NSKeyValueObservingOptionNew
	   context: NULL];
	
    [((Observee *)proxy) setName: @"MOO"];
    PASS(count == 2, "Got two change notifications");
	
    [obj setName: @"BAH"];
    PASS(count == 4, "Got two change notifications");
	
    [w removeObserver: self forKeyPath: @"proxy.name" context: NULL];
    [w removeObserver: self forKeyPath: @"proxy.derivedName" context: NULL];

    RELEASE(w);
    RELEASE(proxy);
    RELEASE(obj);

    count = 0;

}

- (void) observeValueForKeyPath: (NSString *)keyPath
		       ofObject: (id)object
			 change: (NSDictionary *)change
			context: (void *)context
{
  count += 1;
  switch (count)
    {
      case 1:
	PASS_EQUAL(keyPath, [keys objectAtIndex: 0],
	  "change notification for dependent key 'derivedName'"
	  " is emitted first")
	break;
      case 2:
	PASS_EQUAL(keyPath, [keys objectAtIndex: 1],
	  "'name' change notification for proxy is second")
	break;
      case 3:
	PASS_EQUAL(keyPath, [keys objectAtIndex: 0],
	  "'derivedName' change notification for object is third")
	break;
      case 4:
	PASS_EQUAL(keyPath, [keys objectAtIndex: 1],
	  "'name' change notification for object is fourth")
	break;
      default:
	PASS(0,
	  "unexpected -[Observer observeValueForKeyPath:ofObject:"
	  "change:context:] callback")
    }
}

@end

int
main(int argc, char *argv[])
{
  START_SET("KVO Proxy Tests")
  Observer *obs = [Observer new];

  testHopeful = YES;
  [obs simpleKeypathTest];
  [obs nestedKeypathTest];
  testHopeful = NO;

  RELEASE(obs);
  END_SET("KVO Proxy Tests")
  return 0;
}
