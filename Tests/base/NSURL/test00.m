#import <Foundation/Foundation.h>
#import "Testing.h"
#import "ObjectTesting.h"
#import "Helpers/Launch.h"

int main()
{
#if     GNUSTEP
  ENTER_POOL
  unsigned		i, j;
  NSTimeInterval	wake = 10.0;
  NSURL			*url;
  NSURL			*u;
  NSData		*data;
  NSMutableData		*resp;
  NSData		*cont;
  NSString		*str;
  NSMutableString	*m;
  NSTask		*t;
  NSString		*helpers;
  NSString		*respond;
  NSString		*keepalive;
  
  helpers = [[NSFileManager defaultManager] currentDirectoryPath];
  helpers = [helpers stringByAppendingPathComponent: @"Helpers"];
  helpers = [helpers stringByAppendingPathComponent: @"obj"];
  keepalive = [helpers stringByAppendingPathComponent: @"keepalive"];
  respond = [helpers stringByAppendingPathComponent: @"respond"];

  /* The following test cases depend on the keepalive and response
   * HTTP servers. Both servers use the GSInetServerStream
   * class which is completely broken on Windows.
   *
   * See: https://github.com/gnustep/libs-base/issues/266
   *
   * We will mark the test cases as hopeful on Windows.
   */
#if defined(_WIN32)
  NSLog(@"Marking local web server tests as hopeful because GSInetServerStream is broken on Windows");
  testHopeful = YES;
#endif

  START_SET("-resourceDataUsingCache")
  const char *lit = "This is the data in the first chunk\r\n"
    "and this is the second one\r\n"
    "consequence";

  t = [NSTask launchedHelperWithLaunchPath: keepalive
    arguments: [NSArray arrayWithObjects:
		 @"-FileName", @"Chunked.dat",
		 @"-FileHdrs", @"YES",	// Headers are in file
		 @"-Port", @"1234",
		 @"-Count", @"1",
		 nil]
    timeout: wake];

  NEED(testPassed = (t != nil))

  cont = [NSData dataWithBytes: lit length: strlen(lit)];
  u = [NSURL URLWithString: @"http://localhost:1234/chunked"];
  // Talk to server.
  data = [u resourceDataUsingCache: NO];
  // Get status code
  str = [u propertyForKey: NSHTTPPropertyStatusCodeKey];
  PASS_EQUAL(data, cont, "NSURL chunked test OK");
  // Wait for server termination
  [t terminate];
  [t waitUntilExit];

  END_SET("-resourceDataUsingCache")

  START_SET("-sendSynchronousRequest:returningResponse:error:")
  NSURLRequest	*request;
  NSHTTPURLResponse	*response;
  NSError		*error;
  const char *lit = "This is the data in the first chunk\r\n"
    "and this is the second one\r\n"
    "consequence";

  t = [NSTask launchedHelperWithLaunchPath: keepalive
    arguments: [NSArray arrayWithObjects:
		 @"-FileName", @"Chunked.dat",
		 @"-FileHdrs", @"YES",	// Headers are in file
		 @"-Port", @"1234",
		 @"-Count", @"1",
		 nil]
    timeout: wake];

  NEED(testPassed = (t != nil))

  cont = [NSData dataWithBytes: lit length: strlen(lit)];

  u = [NSURL URLWithString: @"http://localhost:1234/chunked"];

  request = [NSURLRequest requestWithURL: u];
  response = nil;
  data = [NSURLConnection sendSynchronousRequest: request
			       returningResponse: &response
					   error: &error];
  // Get status code
  PASS(response != nil && [response statusCode] > 0,
    "NSURLConnection synchronous load returns a response");

  PASS([data isEqual: cont], "NSURLConnection chunked test OK");
  // Wait for server termination
  [t terminate];
  [t waitUntilExit];

  END_SET("-sendSynchronousRequest:returningResponse:error:")

  url = [NSURL URLWithString: @"http://localhost:1234/"];

  START_SET("Shrink")

#if defined(_WIN64) && defined(_MSC_VER)
  SKIP("Known to crash on 64-bit Windows with Clang/MSVC.")
#endif

  /* Ask the 'respond' helper to send back a response containing
   * 'hello' and to shrink the write buffer size it uses on each
   * request.  We do as many requests as the total response size
   * so that on the last one, the 'respond' program writes data
   * a byte at a time.
   * This tests that the URL loading code can handle a request
   * that arrives fragmented rather than in a single read.
   */
  m = [NSMutableString stringWithCapacity: 2048];
  for (i = 0; i < 128; i++)
    {
      [m appendFormat: @"Hello %d\r\n", i];
    }
  cont = [m dataUsingEncoding: NSASCIIStringEncoding];
  resp = AUTORELEASE([[@"HTTP/1.0 200\r\n\r\n"
    dataUsingEncoding: NSASCIIStringEncoding] mutableCopy]);
  [resp appendData: cont];
  [resp writeToFile: @"SimpleResponse.dat" atomically: YES];

  str = [NSString stringWithFormat: @"%lu", (unsigned long)[resp length]];
  t = [NSTask launchedHelperWithLaunchPath: respond
    arguments: [NSArray arrayWithObjects:
		 @"-FileName", @"SimpleResponse.dat",
		 @"-Shrink", @"YES",
		 @"-Count", str,
		 nil]
    timeout: wake];

  NEED(testPassed = (t != nil))

  i = [resp length];
  while (i-- > 0)
    {
      NSAutoreleasePool	*pool = [NSAutoreleasePool new];
      char	buf[128];

      /* Just to test caching of url handles, we use eighteen
       * different URLs (we know the cache size is 16) to ensure
       * that loads work when handles are flushed from the cache.
       */
      u = [NSURL URLWithString: [NSString stringWithFormat:
	@"http://localhost:1234/%d", i % 18]];
      // Talk to server.
      data = [u resourceDataUsingCache: NO];
      // Get status code
      str = [u propertyForKey: NSHTTPPropertyStatusCodeKey];
      sprintf(buf, "respond test %d OK", i);
      PASS([data isEqual: cont], "%s", buf)
      [pool release];
    }
  // Wait for server termination
  [t terminate];
  [t waitUntilExit];

  END_SET("Shrink")
  

  /* Now build a response which pretends to be an HTTP1.1 server and should
   * support connection keepalive ... so we can test that the keeplive code
   * correctly handles the case where the remote end drops the connection.
   */
  cont = [@"hello" dataUsingEncoding: NSASCIIStringEncoding];
  resp = AUTORELEASE([[@"HTTP/1.1 200\r\nContent-Length: 5\r\n\r\n"
    dataUsingEncoding: NSASCIIStringEncoding] mutableCopy]);
  [resp appendData: cont];
  [resp writeToFile: @"SimpleResponse.dat" atomically: YES];

  str = [NSString stringWithFormat: @"%lu", (unsigned long)[resp length]];

  for (j = 0; j < 13 ; j += 4)
    {
      NSString 	*delay = [NSString stringWithFormat: @"%u", j];
      NSString	*name = [NSString stringWithFormat: @"Keepalive drop %u", j];

      START_SET([name UTF8String])

#if defined(_WIN64) && defined(_MSC_VER)
      SKIP("Known to crash on 64-bit Windows with Clang/MSVC.")
#endif

      t = [NSTask launchedHelperWithLaunchPath: respond
         arguments: [NSArray arrayWithObjects:
		      @"-FileName", @"SimpleResponse.dat",
		      @"-Count", @"2",
		      @"-Pause", delay,
		      nil]
	timeout: wake];      

      NEED(testPassed = (t != nil))

      for (i = 0; i < 2; i++)
	{
	  NSAutoreleasePool	*pool = [NSAutoreleasePool new];
	  char	buf[128];

	  // Talk to server.
	  data = [url resourceDataUsingCache: NO];
	  // Get status code
	  str = [url propertyForKey: NSHTTPPropertyStatusCodeKey];
	  sprintf(buf, "respond with keepalive %d (pause %d) OK", i, j);
	  PASS([data isEqual: cont], "%s", buf)
	  [pool release];
	  /* Allow remote end time to close socket.
	   */
	  [NSThread sleepUntilDate:
	    [NSDate dateWithTimeIntervalSinceNow: 0.1]];
	}
      /* Kill helper task and wait for it to finish */
      [t terminate];
      [t waitUntilExit];

      END_SET([name UTF8String])
    }
  LEAVE_POOL

#if defined(_WIN32)
  testHopeful = NO;
#endif

#endif
  return 0;
}
