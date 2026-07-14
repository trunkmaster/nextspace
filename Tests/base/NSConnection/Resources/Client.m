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
  NSDistantObject		*proxy;
  TestServer			*test;
  int				result;

  [NSSocketPort setOptionsForTLS: [NSDictionary dictionaryWithObjectsAndKeys:
    @"9", GSTLSDebug, 
    nil]];

  conn = [NSConnection connectionWithRegisteredName: name
					       host: @""
				    usingNameServer: ns];
  proxy = [conn rootProxy];
  test = (TestServer*)proxy;
  result = [test doIt];
  printf("Result is %d\n", result);
  LEAVE_POOL
  exit(0);
}

@implementation TestServer
- (int) doIt
{
  return 42;
}
@end

