#import "OSEBusConnection.h"
#import "OSEBusService.h"

@implementation OSEBusService

- (void)dealloc
{
  NSDebugLLog(@"DBus",
              @"OSEBusService: -dealloc (retain count: %lu) (connection retain count: %lu)",
              [self retainCount], [_connection retainCount]);
  // OSEBusConnection will be released by AutoReleasePool

  [super dealloc];
}

- (instancetype)init
{
  [super init];

  _connection = [OSEBusConnection defaultConnection];

  return self;
}

@end