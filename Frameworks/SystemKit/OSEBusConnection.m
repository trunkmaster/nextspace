#import "OSEBusConnection.h"
#import "OSEBusMessage.h"

static OSEBusConnection *defaultConnection = nil;

static DBusHandlerResult _dbus_signal_handler_func(DBusConnection *connection, DBusMessage *message,
                                                   void *info)
{
  // printf("Signal arrived --> serial=%u path=%s; interface=%s; member=%s sender=%s\n",
  //        dbus_message_get_serial(message), dbus_message_get_path(message),
  //        dbus_message_get_interface(message), dbus_message_get_member(message),
  //        dbus_message_get_sender(message));

  if (dbus_message_is_signal(message, DBUS_INTERFACE_LOCAL, "Disconnected")) {
    return DBUS_HANDLER_RESULT_HANDLED;
  }

  if (message != NULL) {
    OSEBusMessage *msg = [OSEBusMessage new];
    NSMutableArray *result = [msg decodeDBusMessage:message];

    if (result != nil) {
      // NSLog(@"Signal message --> %@", result);
      [defaultConnection
          handleSignal:[NSString stringWithCString:dbus_message_get_member(message)]
                object:[NSString stringWithCString:dbus_message_get_path(message)]
             interface:[NSString stringWithCString:dbus_message_get_interface(message)]
               message:result];
      [result release];
    }
    [msg release];
  }

  return DBUS_HANDLER_RESULT_HANDLED;
}

@implementation OSEBusConnection

+ (instancetype)defaultConnection
{
  if (defaultConnection == nil) {
    [[self alloc] init];
  }
  return defaultConnection;
}

- (void)dealloc
{
  dbus_connection_unref(_dbus_connection);
  [super dealloc];
}

- (instancetype)init
{
  if (defaultConnection != nil) {
    return defaultConnection;
  }

  [super init];

  dbus_error_init(&_dbus_error);
  _dbus_connection = dbus_bus_get(DBUS_BUS_SYSTEM, &_dbus_error);
  dbus_bus_set_unique_name(_dbus_connection, "org.nextspace.dbus_talk");
  dbus_connection_get_socket(_dbus_connection, &socketFileDescriptor);

  NSLog(@"OSEBusConnection: initialized with socket FD: %i", socketFileDescriptor);
  socketFileHandle = [[NSFileHandle alloc] initWithFileDescriptor:socketFileDescriptor];

  defaultConnection = self;
  signalFilters = [NSMutableDictionary new];

  // Setup signal handling
  dbus_connection_read_write_dispatch(_dbus_connection, 10);

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(processSocketData:)
                                               name:NSFileHandleDataAvailableNotification
                                             object:socketFileHandle];
  [socketFileHandle waitForDataInBackgroundAndNotify];

  return self;
}

- (void)processSocketData:(NSNotification *)aNotif
{
  NSLog(@"-> Process connection data...");

  dbus_connection_read_write(_dbus_connection, 1);
  dbus_connection_read_write_dispatch(_dbus_connection, 1);
  
  [socketFileHandle waitForDataInBackgroundAndNotify];

  NSLog(@"<- Process connection data, end.");
}

- (void)addSignalObserver:(id)anObserver
                 selector:(SEL)aSelector
                   signal:(NSString *)signalName
                   object:(NSString *)objectPath
                interface:(NSString *)aInterface
             notification:(NSString *)notificationName
{
  NSString *rule;
  NSMutableArray<NSDictionary *> *objectSignals;

  rule = [NSString stringWithFormat:@"path='%@',interface='%@',member='%@',type='signal'",
                                    objectPath, aInterface, signalName];
  dbus_bus_add_match(_dbus_connection, [rule cString], &_dbus_error);
  if (dbus_error_is_set(&_dbus_error)) {
    NSLog(@"OSEBusConnection Error %s: %s", _dbus_error.name, _dbus_error.message);
  }

  if (!dbus_connection_add_filter(_dbus_connection, _dbus_signal_handler_func, notificationName,
                                  NULL)) {
    NSLog(@"OSEBusConnection Error: Couldn't add D-Bus filter to observe signal!");
    return;
  }

  // Add registered filter
  // objectPath = ({Interface = aInterface; Signal = signalName;, ...)
  objectSignals = signalFilters[objectPath];
  if (objectSignals == nil) {
    objectSignals = [NSMutableArray array];
  }
  [objectSignals addObject:@{
    @"Interface" : aInterface,
    @"Signal" : signalName,
    @"Notification" : notificationName
  }];
  [signalFilters setObject:objectSignals forKey:objectPath];

  // Setup notification observer
  [[NSNotificationCenter defaultCenter] addObserver:anObserver
                                           selector:aSelector
                                               name:notificationName
                                             object:self];
}

- (void)removeSignalObserver:(id)anObserver name:(NSString *)notificationName
{
  // TODO: remove D-Bus filter
  [[NSNotificationCenter defaultCenter] removeObserver:anObserver
                                                  name:notificationName
                                                object:self];
}

- (void)handleSignal:(NSString *)signalName
              object:(NSString *)objectPath
           interface:(NSString *)aInterface
             message:(NSArray *)result
{
  NSArray<NSDictionary *> *objectSignals = signalFilters[objectPath];

  for (NSDictionary *signal in objectSignals) {
    if ([signal[@"Signal"] isEqualToString:signalName] &&
        [signal[@"Interface"] isEqualToString:aInterface]) {
      // NSLog(@"notification %@ was sent", signal[@"Notification"]);
      [[NSNotificationCenter defaultCenter] postNotificationName:signal[@"Notification"]
                                                          object:self
                                                        userInfo:@{@"Message" : result}];
    }
  }
}

@end