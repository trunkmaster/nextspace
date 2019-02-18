
#import <unistd.h>
#import "SoundKitClient.h"

@implementation SoundKitClient

- (void)dealloc
{
  [server release];
  [super dealloc];
}

- init
{
  self = [super init];

  // server = [[NXSoundServer alloc] init];
  server = [NXSoundServer defaultServer];
  [server retain];
  
  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(connectionStateChanged:)
           name:SKServerStateDidChangeNotification
         object:server];
  
  return self;
}

- (void)runLoopRun
{
  NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
  
  isRunning = YES;
  while (isRunning) {
    NSLog(@"RunLoop is running");
    [runLoop runUntilDate:[NSDate distantFuture]];
  }
}

- (void)connectionStateChanged:(NSNotification *)notif
{
  // NSLog(@"Connection state changed.");
  if ([notif object] == server) {
    switch ([server state]) {
    case SKServerNoConnnectionState:
      NSLog(@"Server state is Unconnected.");
      break;
    case SKServerConnectingState:
      NSLog(@"Server state is Connecting.");
      break;
    case SKServerAuthorizingState:
      NSLog(@"Server state is Authorizing.");
      break;
    case SKServerSettingNameState:
      NSLog(@"Server state is Setting Name.");
      break;
    case SKServerInventoryState:
      NSLog(@"Server state is Inventory.");
      break;
    case SKServerReadyState:
      NSLog(@"Server state is Ready.");
      break;
    case SKServerFailedState:
      NSLog(@"Server state is Failed.");
      isRunning = NO;
      break;
    case SKServerTerminatedState:
      NSLog(@"Server state is Terminated.");
      isRunning = NO;
      break;
    default:
      isRunning = NO;
      NSLog(@"Server state is Unknown.");
    }
  }
}

@end
