#import <Foundation/Foundation.h>
#import <GNUstepBase/GSTLS.h>

@interface	TestServer : NSObject
{
}
- (int) doIt;
@end

int
main()
{
  ENTER_POOL
  NSSocketPortNameServer        *ns = [NSSocketPortNameServer sharedInstance];
  NSString			*name = @"TestServer";
  NSConnection			*conn;
  NSPort			*port;
  TestServer			*test = AUTORELEASE([TestServer new]);
      
  port = [NSSocketPort port];
  [(NSSocketPort*)port setOptionsForTLS:
    [NSDictionary dictionaryWithObjectsAndKeys:
      @"9", GSTLSDebug, 
      nil]];
  conn = [[NSConnection alloc] initWithReceivePort: port
					  sendPort: nil];
  [conn setRootObject: test];
  if ([conn registerName: name withNameServer: ns] == NO)
    {
      NSPort	*p = [ns portForName: name onHost: @""];

      DESTROY(conn);
      NSLog(@"There is already a process: %@, on %@", name, p);
      return NO;
    }

  [[NSRunLoop currentRunLoop] run];
  LEAVE_POOL
  exit(0);
}

@implementation TestServer
- (int) doIt
{
  return 42;
}
@end

