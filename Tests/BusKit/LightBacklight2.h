/*

  % busctl introspect org.clightd.clightd /org/clightd/clightd/Backlight2

  NAME                                TYPE      SIGNATURE  RESULT/VALUE  FLAGS
  org.clightd.clightd.Backlight2      interface -          -             -
  .Get                                method    -          a(sd)         -
  .Lower                              method    d(du)      -             -
  .Raise                              method    d(du)      -             -
  .Set                                method    d(du)      -             -
  .Changed                            signal    sd         -             -
  org.freedesktop.DBus.Introspectable interface -          -             -
  .Introspect                         method    -          s             -
  org.freedesktop.DBus.ObjectManager  interface -          -             -
  .GetManagedObjects                  method    -          a{oa{sa{sv}}} -
  .InterfacesAdded                    signal    oa{sa{sv}} -             -
  .InterfacesRemoved                  signal    oas        -             -
  org.freedesktop.DBus.Peer           interface -          -             -
  .GetMachineId                       method    -          s             -
  .Ping                               method    -          -             -
  org.freedesktop.DBus.Properties     interface -          -             -
  .Get                                method    ss         v             -
  .GetAll                             method    s          a{sv}         -
  .Set                                method    ssv        -             -
  .PropertiesChanged                  signal    sa{sv}as   -             -

*/
#import <Foundation/Foundation.h>

#import <BusKit/BKConnection.h>
#import <BusKit/BKMessage.h>

@interface LightBacklight2 : NSObject
{
  BKConnection *connection;
  BOOL isOwnedConnection;
  const char *object_path;
  const char *service_name;
}

@property (readonly) NSArray *Get;
@property (readonly) NSArray *GetManagedObjects;

- (instancetype)initWithConnection:(BKConnection *)conn;

- (void)setTo:(NSNumber *)amount smoothStep:(NSNumber *)step smoothTimeout:(NSNumber *)timeout;
// - (void)lowerBy:(double)amount smoothStep:(double)step smoothTimeout:(unsigned)timeout;
// - (void)raiseBy:(double)amount smoothStep:(double)step smoothTimeout:(unsigned)timeout;

@end
