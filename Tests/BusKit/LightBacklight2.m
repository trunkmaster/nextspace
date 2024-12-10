#import "LightBacklight2.h"

@implementation LightBacklight2

- (void)dealloc
{
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
  object_path = "/org/clightd/clightd/Backlight2";
  service_name = "org.clightd.clightd";

  return self;
}

- (NSArray *)Get
{
  BKMessage *message = [[BKMessage alloc] initWithObject:object_path
                                               interface:"org.clightd.clightd.Backlight2"
                                                  method:"Get"
                                                 service:service_name];
  id result;

  [message setMethodArguments:nil];
  result = [message sendWithConnection:connection];
  [message release];

  return result;
}

@end