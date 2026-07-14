#import <Foundation/Foundation.h>
#import "Testing.h"
#import "ObjectTesting.h"

/* this test collection examines the behaviour of the
 * NSURLHandleClient protocol.
 * Graham J Lee <leeg@thaesofereode.info>
 */

typedef enum _URLHandleClientStatus {
  URLHandleClientNormal = 0,
  URLHandleClientDataDidBecomeAvailable,
  URLHandleClientDidFailLoadingWithReason,
  URLHandleClientDidBeginLoading,
  URLHandleClientDidCancelLoading,
  URLHandleClientDidFinishLoading } URLHandleClientStatus;

@interface TestObject : NSObject <NSURLHandleClient>
{
  @protected
  URLHandleClientStatus _status;
  NSData *_receivedData;
}
- (int) runTest;

- (URLHandleClientStatus) status;
- (void) setStatus: (URLHandleClientStatus)newStatus;

- (void) URLHandle: (NSURLHandle *)sender
resourceDataDidBecomeAvailable: (NSData *)newBytes;
- (void) URLHandle: (NSURLHandle *)sender
resourceDidFailLoadingWithReason: (NSString *)reason;
- (void) URLHandleResourceDidBeginLoading: (NSURLHandle *)sender;
- (void) URLHandleResourceDidCancelLoading: (NSURLHandle *)sender;
- (void) URLHandleResourceDidFinishLoading: (NSURLHandle *)sender;
@end

@implementation TestObject

- (id) init
{
  if ((self = [super init]))
    {
      _status = URLHandleClientNormal;
      _receivedData = nil;
    }
  return self;
}

- (void) dealloc
{
  if (_receivedData)
    {
      [_receivedData release];
    }
  [super dealloc];
}

- (URLHandleClientStatus) status { return _status; }
- (void) setStatus: (URLHandleClientStatus)newStatus { _status = newStatus; }

- (void) URLHandle: (NSURLHandle *)sender
resourceDataDidBecomeAvailable: (NSData *)newBytes
{
  [self setStatus: URLHandleClientDataDidBecomeAvailable];
  if (_receivedData)
    {
      [_receivedData release];
    }
  _receivedData = [newBytes retain];
}

- (void) URLHandle: (NSURLHandle *)sender
resourceDidFailLoadingWithReason: (NSString *)reason
{
  [self setStatus: URLHandleClientDidFailLoadingWithReason];
  NSLog(@"Load failed: further tests may fail.  Reason: %@", reason);
}

- (void) URLHandleResourceDidBeginLoading: (NSURLHandle *)sender
{
  [self setStatus: URLHandleClientDidBeginLoading];
}

- (void) URLHandleResourceDidCancelLoading: (NSURLHandle *)sender
{
  [self setStatus: URLHandleClientDidCancelLoading];
}

- (void) URLHandleResourceDidFinishLoading: (NSURLHandle *)sender
{
  [self setStatus: URLHandleClientDidFinishLoading];
}

- (int)runTest
{
  id handle;
  NSURL *url;
  Class cls;

  url = [NSURL URLWithString: @"https://www.w3.org/"];
  cls = [NSURLHandle URLHandleClassForURL: url];
  handle = [[cls alloc] initWithURL: url cached: NO];

  [handle addClient: self];
  [self setStatus: URLHandleClientNormal];

  [handle beginLoadInBackground];
  [handle cancelLoadInBackground];
  PASS([self status] == URLHandleClientDidCancelLoading,
    "URLHandleClientDidCancelLoading called");
  [handle release];

  handle = [[cls alloc] initWithURL: url cached: NO];
  [handle addClient: self];
  /* Don't get client messages in the foreground, so load in
   * background and wait a bit
   */
  [handle writeProperty: @"POST" forKey: GSHTTPPropertyMethodKey];
 NSData *d = [@"1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ"
   dataUsingEncoding: NSUTF8StringEncoding];
 NSMutableData *m = AUTORELEASE([d mutableCopy]);
 while ([m length] < 64 * 1024)
   {
     [m appendData: d];
   }

  [handle writeData: m];
  [handle setReturnAll: YES];
  [handle loadInBackground];
  PASS([self status] == URLHandleClientDidBeginLoading,
    "URLHandleClientDidBeginLoading called");

  NSDate *limit = [NSDate dateWithTimeIntervalSinceNow: 5.0];
  while ([limit timeIntervalSinceNow] > 0.0
    && [self status] != URLHandleClientDidFinishLoading)
    {
      [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
        beforeDate: limit];
    }
  PASS([self status] == URLHandleClientDidFinishLoading,
    "URLHandleClientDidFinishLoading called");

  NSLog(@"Data %@", [handle availableResourceData]);
  [handle release];
  return 0;
}

@end

int main(int argc, char **argv)
{
  int status;
  
  /* The following test cases depend on the GSInetServerStream
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

  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  status = [[[[TestObject alloc] init] autorelease] runTest];
  [arp release]; arp = nil;

#if defined(_WIN32)
  testHopeful = NO;
#endif

  return status;
}
