#import "OSEBusConnection.h"
#import "OSEBusMessage.h"

#ifdef CF_BUS_CONNECTION
static void _runLoopHandleEvent(CFFileDescriptorRef fdref, CFOptionFlags callBackTypes, void *info)
{
  OSEBusConnection *connection = info;
  DBusConnection *dbus_connection = connection.dbus_connection;

  NSLog(@"-> CFRunLoop event handler, info: %@", info);

  dbus_connection_read_write(connection.dbus_connection, 1);

  while (dbus_connection_get_dispatch_status(connection.dbus_connection) == DBUS_DISPATCH_DATA_REMAINS) {
    dbus_connection_dispatch(connection.dbus_connection);
  }

  CFFileDescriptorEnableCallBacks(fdref, kCFFileDescriptorReadCallBack);
  NSLog(@"<- CFRunLoop event handler");
}
#endif

static OSEBusConnection *defaultConnection = nil;

static DBusHandlerResult _dbus_signal_handler_func(DBusConnection *connection, DBusMessage *message,
                                                   void *info)
{
  printf("Signal arrived --> serial=%u path=%s; interface=%s; member=%s sender=%s\n",
         dbus_message_get_serial(message), dbus_message_get_path(message),
         dbus_message_get_interface(message), dbus_message_get_member(message),
         dbus_message_get_sender(message));

  // if (dbus_message_is_signal(message, DBUS_INTERFACE_LOCAL, "Disconnected")) {
  //   return DBUS_HANDLER_RESULT_HANDLED;
  // }

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
  } else {
    NSLog(@"OSEBusConnection signal handler warning: D-Bus message is NULL.");
  }

  return DBUS_HANDLER_RESULT_HANDLED;
}

@implementation OSEBusConnection

+ (instancetype)defaultConnection
{
  if (defaultConnection == nil) {
    defaultConnection = [[OSEBusConnection alloc] init];
  }
  return defaultConnection;
}

- (void)dealloc
{
  NSDebugLLog(@"dealloc", @"OSEBusConnection: -dealloc (retain count: %lu)", [self retainCount]);
#ifdef CF_BUS_CONNECTION
#else
  [socketFileHandle release];
#endif
  // [signalFilters release];
  CFRelease(signalObservers);
  dbus_connection_unref(_dbus_connection);
  defaultConnection = nil;
  [super dealloc];
}

- (oneway void)release
{
  NSDebugLLog(@"dealloc", @"OSEBusConnection: -release (retain count: %lu)", [self retainCount]);
  [super release];
}

- (instancetype)init
{
  if (defaultConnection != nil) {
    return defaultConnection;
  }

  [super init];
  defaultConnection = self;

  // signalFilters = [NSMutableDictionary new];
  signalObservers =
      CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &kCFCopyStringDictionaryKeyCallBacks,
                                &kCFTypeDictionaryValueCallBacks);

  dbus_error_init(&_dbus_error);
  _dbus_connection = dbus_bus_get(DBUS_BUS_SYSTEM, &_dbus_error);
  // dbus_bus_set_unique_name(_dbus_connection, [[[NSProcessInfo processInfo] processName] cString]);
  dbus_connection_get_socket(_dbus_connection, &socketFileDescriptor);

  // NSLog(@"OSEBusConnection: initialized with socket FD: %i", socketFileDescriptor);
  dbus_connection_read_write_dispatch(_dbus_connection, 1);

#ifndef CF_BUS_CONNECTION
  // Setup signal handling
  socketFileHandle = [[NSFileHandle alloc] initWithFileDescriptor:socketFileDescriptor];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(processSocketData:)
                                               name:NSFileHandleDataAvailableNotification
                                             object:socketFileHandle];
  [socketFileHandle waitForDataInBackgroundAndNotify];
#endif

  return self;
}

#ifdef CF_BUS_CONNECTION
- (void)run
{
  // CFRunLoopRef run_loop;
  // CFFileDescriptorRef dbus_fd;
  // CFRunLoopSourceRef runloop_fd_source;
  CFFileDescriptorContext *fd_context = malloc(sizeof(CFFileDescriptorContext));
  fd_context->info = self;

  dbus_fd = CFFileDescriptorCreate(kCFAllocatorDefault, socketFileDescriptor, true,
                                   _runLoopHandleEvent, fd_context);
  // CFFileDescriptorGetContext(dbus_fd, &fd_context);
  CFFileDescriptorEnableCallBacks(dbus_fd, kCFFileDescriptorReadCallBack);

  run_loop = CFRunLoopGetCurrent();
  runloop_fd_source = CFFileDescriptorCreateRunLoopSource(kCFAllocatorDefault, dbus_fd, 0);
  CFRunLoopAddSource(run_loop, runloop_fd_source, kCFRunLoopDefaultMode);
  CFRelease(runloop_fd_source);
  CFRelease(dbus_fd);

  NSLog(@"--> Going into CFRunLoop...");

  CFRunLoopRun();

  CFFileDescriptorDisableCallBacks(dbus_fd, kCFFileDescriptorReadCallBack);
  CFRunLoopRemoveSource(run_loop, runloop_fd_source, kCFRunLoopDefaultMode);
  /* Do not call CFFileDescriptorInvalidate(xfd)!
     This FD is a connection of Workspace application to X server. */

  NSLog(@"<-- CFRunLoop finished.");
}
#else
- (void)processSocketData:(NSNotification *)aNotif
{
  NSDebugLLog(@"UDisks", @"-> Process connection data...");

  dbus_connection_read_write(_dbus_connection, 1);
  // dbus_connection_read_write_dispatch(_dbus_connection, 1);

  while (dbus_connection_get_dispatch_status(_dbus_connection) == DBUS_DISPATCH_DATA_REMAINS) {
    dbus_connection_dispatch(_dbus_connection);
  }

  [socketFileHandle waitForDataInBackgroundAndNotify];

  NSDebugLLog(@"UDisks", @"<- Process connection data, end.");
}
#endif

//-------------------------------------------------------------------------------
#pragma mark - Signal handling
//-------------------------------------------------------------------------------
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
  NSDebugLLog(@"UDisks", @"OSEBusConnection: adding signal observer with rule: %@", rule);
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
  // objectSignals = signalFilters[objectPath];
  // if (objectSignals == nil) {
  //   objectSignals = [NSMutableArray array];
  // }
  // [objectSignals addObject:@{
  //   @"Interface" : aInterface,
  //   @"Signal" : signalName,
  //   @"Notification" : notificationName
  // }];
  // [signalFilters setObject:objectSignals forKey:objectPath];

  // Setup notification observer
  // [[NSNotificationCenter defaultCenter] addObserver:anObserver
  //                                          selector:aSelector
  //                                              name:notificationName
  //                                            object:self];
  {
    // identification: object path, interface, signal
    // action: observer, selector
    NSLog(@"Creating observer for %@", objectPath);
    CFMutableDictionaryRef observer = CFDictionaryCreateMutable(
        kCFAllocatorDefault, 2, &kCFCopyStringDictionaryKeyCallBacks, NULL);
    CFDictionaryAddValue(observer, CFSTR("Observer"), anObserver);
    CFDictionaryAddValue(observer, CFSTR("Selector"), aSelector);

    CFStringRef observerKey =
        CFStringCreateWithFormat(kCFAllocatorDefault, 0, CFSTR("%s-%s-%s"), [objectPath cString],
                                 [aInterface cString], [signalName cString]);
    CFDictionaryAddValue(signalObservers, observerKey, observer);
    CFRelease(observerKey);
    CFRelease(observer);

    id obs = CFDictionaryGetValue(observer, CFSTR("Observer"));
    SEL sel = (SEL)CFDictionaryGetValue(observer, CFSTR("Selector"));
    NSLog(@"Checking if object responds to selector...");
    if ([obs respondsToSelector:sel]) {
      NSLog(@"YES!!!");
    } else {
      NSLog(@"NO...");
    }
    NSLog(@"Observer for %@ created and released", objectPath);
  }
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
  // NSArray<NSDictionary *> *objectSignals = signalFilters[objectPath];
  NSDictionary *info;
  CFStringRef observerKey =
      CFStringCreateWithFormat(kCFAllocatorDefault, 0, CFSTR("%s-%s-%s"), [objectPath cString],
                               [aInterface cString], [signalName cString]);

  info = @{
    @"ObjectPath" : objectPath,
    // @"Signal" : signalName,
    // @"Interface" : aInterface,
    @"Message" : result
  };
  {
    // Find observer-selector for signal-interface
    observerKey =
        CFStringCreateWithFormat(kCFAllocatorDefault, 0, CFSTR("%s-%s-%s"), [objectPath cString],
                                 [aInterface cString], [signalName cString]);
    NSLog(@"Searching for %s observer", CFStringGetCStringPtr(observerKey, kCFStringEncodingUTF8));
    CFDictionaryRef observer = CFDictionaryGetValue(signalObservers, observerKey);
    if (observer != NULL) {
      NSLog(@"Observer for %@ found!", objectPath);
      id observerObject = CFDictionaryGetValue(observer, CFSTR("Observer"));
      SEL observerSelector = (SEL)CFDictionaryGetValue(observer, CFSTR("Selector"));
      NSLog(@"Checking if obsever responds to selector...");
      if ([observerObject respondsToSelector:observerSelector]) {
        NSLog(@"YES!!! Calling it...");
        [observerObject performSelector:observerSelector withObject:info];
      } else {
        NSLog(@"NO...");
      }
    }
  }
  // for (NSDictionary *signal in objectSignals) {
  //   if ([signal[@"Signal"] isEqualToString:signalName] &&
  //       [signal[@"Interface"] isEqualToString:aInterface]) {
  //     [[NSNotificationCenter defaultCenter]
  //     postNotificationName:signal[@"Notification"]
  //                                                         object:self
  //                                                       userInfo:info];
  //     NSDebugLLog(@"DBus", @"OSEBusConnection: notification %@ was sent", signal[@"Notification"]);
  //   }
  // }
}

@end