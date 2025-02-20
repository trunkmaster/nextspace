#import <Foundation/Foundation.h>

#include <dbus/dbus.h>

@class OSEBusConnection;
@class OSEBusService;

@interface OSEBusMessage : NSObject
{
  DBusMessage *dbus_message;
  DBusError dbus_error;
  OSEBusService *busService;
}

@property (readonly) DBusMessageIter dbus_message_iterator;

- (instancetype)initWithService:(OSEBusService *)service
                      interface:(NSString *)interfacePath  // org.clightd.clightd.Backlight2
                         method:(NSString *)methodName;    // Get

- (instancetype)initWithService:(OSEBusService *)service
                      interface:(NSString *)interfacePath
                         method:(NSString *)methodName
                      arguments:(NSArray *)args
                      signature:(NSString *)signature;

- (instancetype)initWithServiceName:(NSString *)servicePath
                             object:(NSString *)objectPath
                          interface:(NSString *)interfacePath
                             method:(NSString *)methodName
                          arguments:(NSArray *)args
                          signature:(NSString *)signature;

- (instancetype)initWithServiceName:(NSString *)servicePath    // org.clightd.clightd
                             object:(NSString *)objectPath     // /org/clightd/clightd/Backlight2
                          interface:(NSString *)interfacePath  // org.clightd.clightd.Backlight2
                             method:(NSString *)methodName;    // Get

- (void)setMethodArguments:(NSArray *)args withSignature:(NSString *)signature;

- (id)send;
- (id)sendWithConnection:(OSEBusConnection *)connection;
- (BOOL)sendAsync;
- (BOOL)sendAsyncWithConnection:(OSEBusConnection *)connection;

- (id)decodeDBusMessage:(DBusMessage *)message;

@end