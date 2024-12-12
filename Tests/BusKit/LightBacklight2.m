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

  [message setMethodArguments:nil withSignature:nil];
  result = [message sendWithConnection:connection];
  [message release];

  return result;
}

- (NSArray *)GetManagedObjects
{
  BKMessage *message = [[BKMessage alloc] initWithObject:object_path
                                               interface:"org.freedesktop.DBus.ObjectManager"
                                                  method:"GetManagedObjects"
                                                 service:service_name];
  id result;

  [message setMethodArguments:nil withSignature:nil];
  result = [message sendWithConnection:connection];
  [message release];

  return result;
}

- (void)setTo:(NSNumber *)amount smoothStep:(NSNumber *)step smoothTimeout:(NSNumber *)timeout
{
  BKMessage *message = [[BKMessage alloc] initWithObject:object_path
                                               interface:"org.clightd.clightd.Backlight2"
                                                  method:"Set"
                                                 service:service_name];

  [message setMethodArguments:@[ amount, @[ step, timeout ] ] withSignature:@"d(du)"];
  [message sendWithConnection:connection];
  [message release];
}

// - (void)lowerBy:(double)amount smoothStep:(double)step smoothTimeout:(unsigned)timeout
// {
// }
// - (void)raiseBy:(double)amount smoothStep:(double)step smoothTimeout:(unsigned)timeout
// {
// }

@end