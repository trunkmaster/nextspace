#import <Foundation/Foundation.h>
#include "BKConnection.h"
#import <dbus/dbus.h>

@interface BKMessage : NSObject
{
  DBusMessage *dbus_message;
  DBusMessageIter dbus_message_iterator;
  DBusError dbus_error;
}

- (instancetype)initWithObject:(const char *)object_path     // /org/clightd/clightd/Backlight2
                     interface:(const char *)interface_path  // org.clightd.clightd.Backlight2
                        method:(const char *)method_name     // Get
                       service:(const char *)service_path;   // org.clightd.clightd
- (void)setMethodArguments:(NSArray *)args;

- (id)sendWithConnection:(BKConnection *)connection;

@end