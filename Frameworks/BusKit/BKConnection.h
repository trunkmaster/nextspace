#import <Foundation/Foundation.h>
#import <dbus/dbus.h>

@interface BKConnection : NSObject
{
  DBusConnection *dbus_connection;
  DBusError dbus_error;
}

- (DBusConnection *)dbusConnection;

@end