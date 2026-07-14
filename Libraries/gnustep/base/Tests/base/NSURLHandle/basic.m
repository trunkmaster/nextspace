#import <Foundation/Foundation.h>
#import "Testing.h"
#import "ObjectTesting.h"

@interface DummyHandle : NSURLHandle
@end
@implementation DummyHandle
@end

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  Class cls;
  NSURL *httpURL, *foobarURL;
  id handle1, handle2;


  httpURL = [NSURL URLWithString: @"http://www.gnustep.org"];
  foobarURL = [NSURL URLWithString: @"foobar://localhost/madeupscheme"];

  TEST_FOR_CLASS(@"NSURLHandle", AUTORELEASE([NSURLHandle alloc]),
    "NSURLHandle +alloc returns an NSURLHandle");

  PASS_EXCEPTION([DummyHandle cachedHandleForURL: httpURL];,
    NSInvalidArgumentException,
    "NSURLHandle subclass must implement +cachedHandleForURL:");

  cls = [NSURLHandle URLHandleClassForURL: httpURL];

  PASS([cls canInitWithURL: httpURL] == YES,
    "Appropriate subclass found for +URLHandleClassForURL:");
  handle1 = AUTORELEASE([[cls alloc] initWithURL: httpURL cached: YES]);
  handle2 = [NSURLHandle cachedHandleForURL: httpURL];

  PASS(handle2 != nil, "Available handle returned from cache");

#if	!defined(GNUSTEP_BASE_LIBRARY)
  PASS(NO, "URLHandleClassForURL: seems to hang on MacOS-X when given an unknown URL scheme ... you may want to check to see if it has been fixed");
#else
  cls = [NSURLHandle URLHandleClassForURL: foobarURL];
  PASS(cls == Nil, "Nil class returned for unknown URL scheme");
#endif

  [arp release]; arp = nil;
  return 0;
}
