#import "OSEBusConnection.h"
#import "OSEBusService.h"

@implementation OSEBusService

- (void)dealloc
{
  if (_objectPath) {
    [_objectPath release];
  }
  if (_serviceName) {
    [_serviceName release];
  }
  [super dealloc];
}

- (instancetype)init
{
  [super init];

  _connection = [OSEBusConnection defaultConnection];

  return self;
}

@end