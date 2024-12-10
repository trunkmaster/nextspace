#import "BKConnection.h"
#include "objc/objc.h"
#include "BKMessage.h"

@implementation BKConnection

- (void)dealloc
{
  dbus_connection_unref(dbus_connection);
  [super dealloc];
}

- (instancetype)init
{
  [super init];

  dbus_error_init(&dbus_error);
  dbus_connection = dbus_bus_get(DBUS_BUS_SYSTEM, &dbus_error);

  return self;
}

- (DBusConnection *)dbusConnection
{
  return dbus_connection;
}

@end