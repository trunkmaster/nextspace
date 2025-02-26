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
  // fprintf(stderr, "Signal arrived --> serial=%u path=%s; interface=%s; member=%s sender=%s\n",
  //         dbus_message_get_serial(message), dbus_message_get_path(message),
  //         dbus_message_get_interface(message), dbus_message_get_member(message),
  //         dbus_message_get_sender(message));

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
  } else {
    NSLog(@"OSEBusConnection signal handler warning: D-Bus message is NULL.");
  }

  return DBUS_HANDLER_RESULT_HANDLED;
}

@implementation OSEBusConnection

+ (instancetype)defaultConnection
{
  if (defaultConnection == nil) {
    defaultConnection = [[[self alloc] init] autorelease];
  }
  return defaultConnection;
}

- (void)dealloc
{
  NSDebugLLog(@"dealloc", @"OSEBusConnection: -dealloc (retain count: %lu)", [self retainCount]);
  if (isSignalFilterDidSet != NO) {
    dbus_connection_remove_filter(_dbus_connection, _dbus_signal_handler_func, NULL);
  }
  CFRelease(signalObservers);
#ifdef CF_BUS_CONNECTION
#else
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [socketFileHandle release];
#endif
  // [signalFilters release];
  dbus_connection_unref(_dbus_connection);
  defaultConnection = nil;
  [super dealloc];
}

- (instancetype)init
{
  if (defaultConnection != nil) {
    return defaultConnection;
  }

  [super init];
  defaultConnection = self;

  dbus_error_init(&_dbus_error);
  _dbus_connection = dbus_bus_get(DBUS_BUS_SYSTEM, &_dbus_error);
  // dbus_bus_set_unique_name(_dbus_connection, [[[NSProcessInfo processInfo] processName] cString]);
  dbus_connection_get_socket(_dbus_connection, &socketFileDescriptor);

  // NSLog(@"OSEBusConnection: initialized with socket FD: %i", socketFileDescriptor);
  dbus_connection_read_write_dispatch(_dbus_connection, 1);

  // signals
  signalObservers =
      CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &kCFCopyStringDictionaryKeyCallBacks,
                                &kCFTypeDictionaryValueCallBacks);

  if (dbus_connection_add_filter(_dbus_connection, _dbus_signal_handler_func, NULL, NULL)) {
    isSignalFilterDidSet = YES;
  } else {
    isSignalFilterDidSet = NO;
    NSLog(@"OSEBusConnection Error: Couldn't add D-Bus filter to observe signal!");
  }
  
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
  NSDebugLLog(@"DBus", @"OSEBusConnection -> Process connection data...");

  dbus_connection_read_write(_dbus_connection, 1);
  // dbus_connection_read_write_dispatch(_dbus_connection, 1);

  while (dbus_connection_get_dispatch_status(_dbus_connection) == DBUS_DISPATCH_DATA_REMAINS) {
    dbus_connection_dispatch(_dbus_connection);
  }

  [socketFileHandle waitForDataInBackgroundAndNotify];

  NSDebugLLog(@"DBus", @"OSEBusConnection <- Process connection data, end.");
}
#endif

//-------------------------------------------------------------------------------
#pragma mark - Signal handling
//-------------------------------------------------------------------------------
- (void)_registerSignalObserver:(id)anObserver selector:(SEL)aSelector withKey:(NSString *)key
{
  CFMutableDictionaryRef observer;
  CFStringRef observerKey;
  CFMutableArrayRef objectsList;

  // Try to find existing observers list
  observerKey =
      CFStringCreateWithCString(kCFAllocatorDefault, [key cString], kCFStringEncodingUTF8);
  objectsList = (CFMutableArrayRef)CFDictionaryGetValue(signalObservers, observerKey);
  if (objectsList == NULL) {
    objectsList = CFArrayCreateMutable(kCFAllocatorDefault, 1, &kCFTypeArrayCallBacks);
  }

  // Create observer
  observer =
      CFDictionaryCreateMutable(kCFAllocatorDefault, 2, &kCFCopyStringDictionaryKeyCallBacks, NULL);
  CFDictionaryAddValue(observer, CFSTR("Observer"), anObserver);
  CFDictionaryAddValue(observer, CFSTR("Selector"), aSelector);

  // Add observer to list of observers
  CFArrayAppendValue(objectsList, observer);

  // Set observers list to registered observers
  CFDictionaryAddValue(signalObservers, observerKey, objectsList);
  CFRelease(observerKey);
  CFRelease(observer);

  // Check if observer responds to selector
  id obs = CFDictionaryGetValue(observer, CFSTR("Observer"));
  SEL sel = (SEL)CFDictionaryGetValue(observer, CFSTR("Selector"));
  NSDebugLLog(@"DBus", @"Checking if object responds to selector...");
  if ([obs respondsToSelector:sel]) {
    NSDebugLLog(@"DBus", @"YES!!!");
  } else {
    NSDebugLLog(@"DBus", @"NO...");
  }
}

- (void)addSignalObserver:(id)anObserver
                 selector:(SEL)aSelector
                   signal:(NSString *)signalName
                   object:(NSString *)objectPath
                interface:(NSString *)aInterface
{
  NSString *rule;

  if (isSignalFilterDidSet == NO) {
    NSLog(@"OSEBusConnection Warning: D-Bus filter has not been set - ignoring addSignalObserver::::: message!");
    return;
  }

  rule = [NSString stringWithFormat:@"path='%@',interface='%@',member='%@',type='signal'",
                                    objectPath, aInterface, signalName];

  NSDebugLLog(@"DBus", @"OSEBusConnection: adding signal observer with rule: %@", rule);
  dbus_bus_add_match(_dbus_connection, [rule cString], &_dbus_error);
  if (dbus_error_is_set(&_dbus_error)) {
    NSLog(@"OSEBusConnection Error %s: %s", _dbus_error.name, _dbus_error.message);
  }
  if (!dbus_connection_add_filter(_dbus_connection, _dbus_signal_handler_func, NULL, NULL)) {
    NSLog(@"OSEBusConnection Error: Couldn't add D-Bus filter to observe signal!");
    return;
  }

  // identification: object path, interface, signal
  // action: observer, selector
  NSDebugLLog(@"DBus", @"Creating observer for %@ %@", objectPath, signalName);
  NSString *observerKey = [NSString stringWithFormat:@"%s-%s-%s", [objectPath cString],
                                                     [aInterface cString], [signalName cString]];

  [self _registerSignalObserver:anObserver selector:aSelector withKey:observerKey];
  NSDebugLLog(@"DBus", @"Observer for %@ %@ has been created.", objectPath, signalName);
}

- (void)removeSignalObserver:(id)anObserver
                      signal:(NSString *)signalName
                      object:(NSString *)objectPath
                   interface:(NSString *)aInterface
{
  CFStringRef observerKey;
  CFMutableArrayRef objectsList;
  CFIndex observersCount;
  CFDictionaryRef observer;
  id observerObject;

  NSDebugLLog(@"DBus", @"Removing observer %@ for `%@` signal", [anObserver className],
        [NSString stringWithFormat:@"%@-%@-%@", objectPath, aInterface, signalName]);

  observerKey =
      CFStringCreateWithFormat(kCFAllocatorDefault, 0, CFSTR("%s-%s-%s"), [objectPath cString],
                               [aInterface cString], [signalName cString]);
  objectsList = (CFMutableArrayRef)CFDictionaryGetValue(signalObservers, observerKey);

  if (objectsList != NULL && (observersCount = CFArrayGetCount(objectsList)) > 0) {
    NSDebugLLog(@"DBus", @"Observers count for %s is %li",
                CFStringGetCStringPtr(observerKey, kCFStringEncodingUTF8), observersCount);
    for (CFIndex i = 0; i < observersCount; i++) {
      observer = CFArrayGetValueAtIndex(objectsList, 0);
      observerObject = CFDictionaryGetValue(observer, CFSTR("Observer"));
      if ([observerObject isEqualTo:anObserver]) {
        CFArrayRemoveValueAtIndex(objectsList, 0);
      }
    }
  }

  // If observers list is empty - remove D-Bus match and observers entry
  if (objectsList != NULL && CFArrayGetCount(objectsList) == 0) {
    NSDebugLLog(@"DBus",
                @"Obsevers array is empty for %s - removing D-Bus rule and observers array.",
                CFStringGetCStringPtr(observerKey, kCFStringEncodingUTF8));

    NSString *rule;
    CFDictionaryRemoveValue(signalObservers, observerKey);
    rule = [NSString stringWithFormat:@"path='%@',interface='%@',member='%@',type='signal'",
                                      objectPath, aInterface, signalName];
    dbus_bus_remove_match(_dbus_connection, [rule cString], &_dbus_error);
    if (dbus_error_is_set(&_dbus_error)) {
      NSLog(@"OSEBusConnection Error while removing match %s: %s", _dbus_error.name, _dbus_error.message);
    }
  }
  NSDebugLLog(@"DBus", @"Observer %@ for `%@` signal removed.", [anObserver className],
              [NSString stringWithFormat:@"%@-%@-%@", objectPath, aInterface, signalName]);
}

- (void)handleSignal:(NSString *)signalName
              object:(NSString *)objectPath
           interface:(NSString *)aInterface
             message:(NSArray *)result
{
  NSDictionary *info;
  CFStringRef observerKey;
  CFArrayRef observersList;
  CFIndex observersCount;
  CFDictionaryRef observer;

  info = @{
    @"ObjectPath" : objectPath,
    // @"Signal" : signalName,
    // @"Interface" : aInterface,
    @"Message" : result
  };

  // Find observer-selector for signal-interface
  observerKey =
      CFStringCreateWithFormat(kCFAllocatorDefault, 0, CFSTR("%s-%s-%s"), [objectPath cString],
                               [aInterface cString], [signalName cString]);

  NSDebugLLog(@"DBus", @"Searching for %s observer", CFStringGetCStringPtr(observerKey, kCFStringEncodingUTF8));
  observersList = CFDictionaryGetValue(signalObservers, observerKey);

  if (observersList != NULL & (observersCount = CFArrayGetCount(observersList)) > 0) {
    NSDebugLLog(@"DBus", @"Observers count for %s is %li",
                CFStringGetCStringPtr(observerKey, kCFStringEncodingUTF8), observersCount);
    for (CFIndex i = 0; i < observersCount; i++) {
      observer = CFArrayGetValueAtIndex(observersList, i);
      if (observer != NULL) {
        NSDebugLLog(@"DBus", @"Observer for %@ found!", objectPath);
        id observerObject = CFDictionaryGetValue(observer, CFSTR("Observer"));
        SEL observerSelector = (SEL)CFDictionaryGetValue(observer, CFSTR("Selector"));
        NSDebugLLog(@"DBus", @"Checking if obsever responds to selector...");
        if ([observerObject respondsToSelector:observerSelector]) {
          NSDebugLLog(@"DBus", @"YES!!! Calling it...");
          [observerObject performSelector:observerSelector withObject:info];
        } else {
          NSDebugLLog(@"DBus", @"NO...");
        }
      }
    }
  }
}

@end