#import <Foundation/NSException.h>
#import <Foundation/NSAutoreleasePool.h>
#import "ObjectTesting.h"

static void
handler(NSException *e)
{
  PASS (YES == [[e reason] isEqual: @"Terminate"],
    "uncaught exceptionhandler called as expected");
  abort();
}

@interface      MyClass : NSObject
+ (void) testAbc;
@end
@implementation MyClass
+ (void) simulateProblem
{
  [NSException raise: NSGenericException format: @"In MyClass"];
}
+ (void) testAbc
{
  [self simulateProblem];
}
@end

int main()
{
  NSException *obj;
  NSMutableArray *testObjs = [[NSMutableArray alloc] init];
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];

  test_alloc_only(@"NSException"); 
  obj = [NSException exceptionWithName: NSGenericException
                                reason: nil
                              userInfo: nil];
  PASS((obj != nil), "can create an exception");
  PASS(([[obj name] isEqualToString: NSGenericException]), "name works");
  obj = [NSException exceptionWithName: NSGenericException
                                reason: nil
                              userInfo: nil];
  [testObjs addObject: obj];
  test_NSObject(@"NSException", testObjs);
  
  NS_DURING
    [MyClass testAbc];
  NS_HANDLER
    {
      NSArray   *addresses = [localException callStackReturnAddresses];
      NSArray   *a = [localException callStackSymbols];
      NSString  *s = nil;
      BOOL	ok = YES;

      PASS([addresses count] > 0, "call stack addresses is not empty");
      PASS([addresses count] == [a count], "addresses and symbols match");

NSLog(@"Got %@", a);
      testHopeful = YES;
      PASS([a count] > 0
	&& [(s = [a objectAtIndex: 0]) rangeOfString: @"NSException"].length > 0
	&& [s rangeOfString: @"raise"].length > 0,
	"Exception raised at start of stack")
      PASS([a count] > 1
	&& [(s = [a objectAtIndex: 1]) rangeOfString: @"MyClass"].length > 0
	&& [s rangeOfString: @"simulateProblem"].length > 0,
	"simulateProblem is where exception was raised")
      if (NO == testPassed) ok = NO;
      PASS([a count] > 2
	&& [(s = [a objectAtIndex: 2]) rangeOfString: @"MyClass"].length > 0
	&& [s rangeOfString: @"testAbc"].length > 0,
	"testAbc called simulateProblem to raise exception")
      if (NO == testPassed) ok = NO;

      PASS(ok, "working callStackSymbols ... if this has failed it is probably due to a lack of support for objective-c method names (local symbols) in the backtrace_symbols() function of your libc. If so, you might lobby your operating system provider for a fix.");
      testHopeful = NO;
    }
  NS_ENDHANDLER

  PASS(NSGetUncaughtExceptionHandler() == 0, "default handler is null");
  NSSetUncaughtExceptionHandler(handler);
  PASS(NSGetUncaughtExceptionHandler() == handler, "setting handler works");

  fprintf(stderr, "We expect a single FAIL without any explanation as\n"
    "the test is terminated by an uncaught exception ...\n");
  [NSException raise: NSGenericException format: @"Terminate"];
  PASS(NO, "shouldn't get here ... exception should have terminated process");

  [arp release]; arp = nil;
  return 0;
}
