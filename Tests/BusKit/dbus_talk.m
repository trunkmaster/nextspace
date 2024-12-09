// DBusKit
#import <DBusKit/DBusKit.h>
#import <ClightdBacklight2.h>

// BusKit
#import "LightService.h"
#import "LightBacklight2.h"

void talkClightD(void)
{
  BKConnection *connection = [[BKConnection alloc] init];

  // LightService *clight;
  // clight = [[LightService alloc] initWithConnection:connection];
  // // clight = [[LightService alloc] initWithConnection:nil];
  // NSLog(@"ClightD version: %@", clight.version);
  // [clight release];

  LightBacklight2 *backlight;
  backlight = [[LightBacklight2 alloc] initWithConnection:connection];
  NSLog(@"Backlight2.Get: %@", backlight.Get);
  [backlight release];
  
  [connection release];
}

void talk(void)
{
  BKConnection *connection;
  BKMessage *message;

  connection = [[BKConnection alloc] init];

  message = [[BKMessage alloc] initWithObject:"/org/clightd/clightd/Backlight2"
                                    interface:"org.clightd.clightd.Backlight2"
                                       method:"Get"
                                      service:"org.clightd.clightd"];
  [message setMethodArguments:nil];
  [message sendWithConnection:connection];

  [message release];
  [connection release];
}

void talkDBusKit(void)
{
  DKPort *sendPort;
  DKPort *receivePort;
  NSConnection *connection;
  DKProxy *proxy;
  id<org_clightd_clightd_Backlight2> clightd;

  sendPort = [[DKPort alloc] initWithRemote:@"org.clightd.clightd" onBus:DKDBusSystemBus];
  receivePort = [DKPort portForBusType:DKDBusSessionBus];
  connection = [NSConnection connectionWithReceivePort:receivePort sendPort:sendPort];
  proxy = [connection proxyAtPath:@"/org/clightd/clightd/Backlight2"];
  clightd = (id<org_clightd_clightd_Backlight2>)proxy;

  NSLog(@"%@", [clightd Get]);

  [connection invalidate];
  [sendPort release];
  [proxy release];
}

int main(int argc, char *argv[])
{
  talk();
//   talkDBusKit();
//   talkClightD();
}