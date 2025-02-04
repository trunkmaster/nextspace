#import <Foundation/Foundation.h>

#include <dbus/dbus.h>
#include <dbus/dbus-protocol.h>

#ifdef CF_BUS_CONNECTION
#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFFileDescriptor.h>
#endif

@interface OSEBusConnection : NSObject
{
 @private
  int socketFileDescriptor;
  CFMutableDictionaryRef signalObservers;
  BOOL isSignalFilterDidSet;

#ifdef CF_BUS_CONNECTION
  CFRunLoopRef run_loop;
  CFFileDescriptorRef dbus_fd;
  CFRunLoopSourceRef runloop_fd_source;
#else
  NSFileHandle *socketFileHandle;
#endif
}

@property (readonly) DBusConnection *dbus_connection;
@property (readonly) DBusError dbus_error;

+ (instancetype)defaultConnection;

#ifdef CF_BUS_CONNECTION
- (void)run;
#endif

- (void)addSignalObserver:(id)anObserver
                 selector:(SEL)aSelector
                   signal:(NSString *)signalName
                   object:(NSString *)objectPath
                interface:(NSString *)aInterface;

- (void)removeSignalObserver:(id)anObserver
                      signal:(NSString *)signalName
                      object:(NSString *)objectPath
                   interface:(NSString *)aInterface;

- (void)handleSignal:(NSString *)signalName
              object:(NSString *)objectPath
           interface:(NSString *)aInterface
             message:(NSArray *)result;

@end

//* org.freedesktop.DBus.Introspectable
@protocol DBus_Introspectable

- (NSString *)Introspect;

@end

//* org.freedesktop.DBus.ObjectManager
@protocol DBus_ObjectManager

- (NSArray *)GetManagedObjects;

@end

//* org.freedesktop.DBus.Peer
@protocol DBus_Peer

- (NSString *)GetMachineId;
- (void)Ping;

@end

//* org.freedesktop.DBus.Properties
@protocol DBus_Properties

- (void)Set:(NSString *)interfaceName name:(NSString *)propertyName value:(id)propertyValue;
- (id)Get:(NSString *)interfaceName name:(NSString *)propertyName;
- (NSArray *)GetAll;

@end

