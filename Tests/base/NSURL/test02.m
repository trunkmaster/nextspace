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
  NSMutableString	*m;
  NSData                *data;
  NSString              *str;
  NSTask		*t;
  NSTimeInterval	wake = 10.0;
  NSString		*helpers;
  NSString		*capture;
  NSMutableURLRequest   *request;
  NSHTTPURLResponse     *response = nil;
  NSError               *error = nil;
  NSFileManager         *fm;
  NSRange               r;
  NSString              *file = @"Capture.dat";

  fm = [NSFileManager defaultManager];
  helpers = [fm currentDirectoryPath];
  helpers = [helpers stringByAppendingPathComponent: @"Helpers"];
  helpers = [helpers stringByAppendingPathComponent: @"obj"];
  capture = [helpers stringByAppendingPathComponent: @"capture"];
  
  /* The following test cases depend on the capture
   * HTTP server. The server uses the GSInetServerStream
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

  m = [NSMutableString stringWithCapacity: 2048];
  for (i = 0; i < 128; i++)
    {
      [m appendFormat: @"Hello %d\r\n", i];
    }

  START_SET("Capture")

  t = [NSTask launchedHelperWithLaunchPath: capture
				 arguments: [NSArray arrayWithObjects: nil]
				   timeout: wake];

  NEED(testPassed = (t != nil))

  // remove the captured data from a possible previous run
  [fm removeItemAtPath: file error: NULL];
  // making a POST request
  url = [NSURL URLWithString: @"http://localhost:1234/"];
  request = [NSMutableURLRequest requestWithURL: url];
  data = [m dataUsingEncoding: NSUTF8StringEncoding];
  [request setHTTPBody: data];
  [request setHTTPMethod: @"POST"];

  // sending the request
  [NSURLConnection sendSynchronousRequest: request
			returningResponse: &response
				    error: &error];

  // analyzing the response
  PASS(response != nil && [response statusCode] == 204,
    "NSURLConnection synchronous load returns a response");

  data = [NSData dataWithContentsOfFile: file];
  str = [[NSString alloc] initWithData: data
			      encoding: NSUTF8StringEncoding];
  r = [str rangeOfString: m];
  PASS(r.location != NSNotFound,
       "NSURLConnection capture test OK");

  // Wait for server termination
  [t terminate];
  [t waitUntilExit];
  DESTROY(str);
  response = nil;
  error = nil;

  END_SET("Capture")


  START_SET("Secure")
  // the same but with secure connection (HTTPS)
  t = [NSTask launchedHelperWithLaunchPath: capture
				 arguments: [NSArray arrayWithObjects:
					      @"-Secure", @"YES",
					      nil]
				   timeout: wake];

  NEED(testPassed = (t != nil))

  // Pause to allow server subtask to set up.
  [NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.5]];
  // remove the captured data from a possible previous run
  [fm removeItemAtPath: file error: NULL];
  // making a POST request
  url = [NSURL URLWithString: @"https://localhost:1234/"];
  request = [NSMutableURLRequest requestWithURL: url];
  data = [m dataUsingEncoding: NSUTF8StringEncoding];
  [request setHTTPBody: data];
  [request setHTTPMethod: @"POST"];

  // sending the request
  [NSURLConnection sendSynchronousRequest: request
			returningResponse: &response
				    error: &error];

  // sending the request
  PASS(response != nil && [response statusCode] == 204,
    "NSURLConnection synchronous load returns a response");

  data = [NSData dataWithContentsOfFile: file];
  str = [[NSString alloc] initWithData: data
			      encoding: NSUTF8StringEncoding];      
  r = [str rangeOfString: m];
  PASS(r.location != NSNotFound,
       "NSURLConnection capture test OK");

  // Wait for server termination
  [t terminate];
  [t waitUntilExit];
  DESTROY(str);

  END_SET("Secure")

  LEAVE_POOL

#if defined(_WIN32)
  testHopeful = NO;
#endif

#endif
  return 0;
}
