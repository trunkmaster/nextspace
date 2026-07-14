#import <Foundation/Foundation.h>
#import "Testing.h"
#import "ObjectTesting.h"
#import "Helpers/Launch.h"


int main()
{
#if     GNUSTEP
  ENTER_POOL
  unsigned		i;
  NSURL			*url;
  NSData		*data;
  NSData		*resp;
  NSString		*str;
  NSTimeInterval	wake = 10.0;
  NSMutableString	*m;
  NSTask		*t;
  NSString		*helpers;
  NSString		*keepalive;
  
  helpers = [[NSFileManager defaultManager] currentDirectoryPath];
  helpers = [helpers stringByAppendingPathComponent: @"Helpers"];
  helpers = [helpers stringByAppendingPathComponent: @"obj"];
  keepalive = [helpers stringByAppendingPathComponent: @"keepalive"];

  /* The following test cases depend on the keepalive
   * HTTP server. This server uses the GSInetServerStream
   * class which is completely broken on Windows.
   *
   * See: https://github.com/gnustep/libs-base/issues/266
   *
   * We will mark the test cases as hopeful on Windows.
   */

  START_SET("Keepalive")

#if defined(_WIN64) && defined(_MSC_VER)
  SKIP("Known to crash on 64-bit Windows with Clang/MSVC.")
#elif defined(_WIN32)
  NSLog(@"Marking local web server tests as hopeful because GSInetServerStream is broken on Windows");
  testHopeful = YES;
#endif
  
  url = [NSURL URLWithString: @"http://localhost:4322/"];

  m = [NSMutableString stringWithCapacity: 2048];
  for (i = 0; i < 128; i++)
    {
      [m appendFormat: @"Hello %d\r\n", i];
    }
  resp = [m dataUsingEncoding: NSASCIIStringEncoding];
  [resp writeToFile: @"KAResponse.dat" atomically: YES];

  t = [NSTask launchedHelperWithLaunchPath: keepalive
    arguments: [NSArray arrayWithObjects:
		 @"-FileName", @"KAResponse.dat",
		 @"-CloseFreq", @"3",
		 @"-Count", @"10",
		 nil]
    timeout: wake];

  NEED(testPassed = (t != nil))
  
  for (i = 0; i < 10; i++)
    {
      /*we just get the response every time.  It should be the
       *same every time, even though the headers change and
       *sometimes the connection gets dropped
       */
      char buf[BUFSIZ];
      data = [url resourceDataUsingCache: NO];
      str = [url propertyForKey: NSHTTPPropertyStatusCodeKey];
      sprintf(buf, "keep-alive test %d OK",i);
      PASS([data isEqual:resp], "%s", buf)
    }
  [t terminate];
  [t waitUntilExit];

  END_SET("Keepalive")

  LEAVE_POOL

#if defined(_WIN32)
  testHopeful = NO;
#endif

#endif
  return 0;
}
