#import "OSEBusConnection.h"
#import "OSEBusService.h"

@implementation OSEBusService

- (void)dealloc
{
  // NSLog(@"_objectPath retain count: %lu", [_objectPath retainCount]);
  // if (_objectPath) {
  //   NSLog(@"_objectPath release");
  //   [_objectPath release];
  // }
  // if (_serviceName) {
  //   [_serviceName release];
  // }
  NSDebugLLog(@"DBus", @"OSEBusService: connection retain count: %lu", [_connection retainCount]);

  [super dealloc];
}

- (instancetype)init
{
  [super init];

  _connection = [OSEBusConnection defaultConnection];

  return self;
}

@end