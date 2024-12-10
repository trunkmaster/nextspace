#import "LightService.h"

@implementation LightService

- (void)dealloc
{
  NSLog(@"LightService -dealloc, connection is owned: %@", isOwnedConnection ? @"Yes" : @"No");
  if (isOwnedConnection != NO) {
    [connection release];
  }
  [super dealloc];
}

- (instancetype)initWithConnection:(BKConnection *)conn
{
  [super init];

  if (conn != nil) {
    connection = conn;
    isOwnedConnection = NO;
  } else {
    connection = [[BKConnection alloc] init];
    isOwnedConnection = YES;
  }
  object_path = "/org/clightd/clightd";
  service_name = "org.clightd.clightd";

  return self;
}

- (NSString *)version
{
  BKMessage *message = [[BKMessage alloc] initWithObject:object_path
                                               interface:"org.freedesktop.DBus.Properties"
                                                  method:"Get"
                                                 service:service_name];
  id result;

  [message setMethodArguments:@[@"org.clightd.clightd", @"Version"]];
  result = [message sendWithConnection:connection];
  [message release];

  return result;
}

@end