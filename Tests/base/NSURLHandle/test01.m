#import <Foundation/Foundation.h>
#import "Testing.h"
#import "ObjectTesting.h"
#import "../NSURL/Helpers/Launch.h"

/* This test collection examines the responses when a variety of HTTP
* status codes are returned by the server. Relies on the
* StatusServer helper tool.
*
* Graham J Lee < leeg@thaesofereode.info >
*/

int main(int argc, char **argv)
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new] ;
  
  NSString *helpers;
  NSString *statusServer;
  NSURL *url;
  NSURLHandle *handle;
  NSTask *t;
  Class cls;
  NSData *resp;
  NSData *rxd;
  
  /* The following test cases depend on the GSInetServerStream
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
  
  url = [NSURL URLWithString: @"http://localhost:1234/200"];
  cls = [NSURLHandle URLHandleClassForURL: url];
  resp = [NSData dataWithBytes: "Hello\r\n" length: 7];
  
  helpers = [[NSFileManager defaultManager] currentDirectoryPath];
  helpers = [helpers stringByAppendingPathComponent: @"Helpers"];
  helpers = [helpers stringByAppendingPathComponent: @"obj"];
  statusServer = [helpers stringByAppendingPathComponent: @"StatusServer"];
  
  t = [NSTask launchedHelperWithLaunchPath: statusServer
				 arguments: nil
				   timeout: 10.0];

  if (t != nil)
    {
      // try some different requests
      handle = [[[cls alloc] initWithURL: url cached: NO] autorelease];
      rxd = [handle loadInForeground];
      PASS([rxd isEqual: resp],
           "Got the correct data from a 200 - status load") ;
      PASS([handle status] == NSURLHandleLoadSucceeded,
           "200 - status: Handle load succeeded") ;
      
      url = [NSURL URLWithString: @"http://localhost:1234/401"];
      handle = [[[cls alloc] initWithURL: url cached: NO] autorelease];
      rxd = [handle loadInForeground];
      PASS([handle status] == NSURLHandleNotLoaded,
           "401 - status: Handle load not loaded (unanswered auth challenge)");

      url = [NSURL URLWithString: @"http://localhost:1234/404"];
      handle = [[[cls alloc] initWithURL: url cached: NO] autorelease];
      rxd = [handle loadInForeground];
      PASS([handle status] == NSURLHandleNotLoaded,
	   "404 - status: Handle load not loaded (resource not found)");
      [t terminate];
      [t waitUntilExit];
    }

  END_SET("Keepalive")
  
  [arp release]; arp = nil ;

#if defined(_WIN32)
  testHopeful = NO;
#endif

  return 0;
}

