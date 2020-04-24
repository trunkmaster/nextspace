/*
 *  AppController.m 
 */

#import <Foundation/NSNotification.h>
#import <DBusKit/DBusKit.h>
#import <DesktopKit/NXTAlert.h>

#import "EthernetController.h"
#import "AppController.h"

#define CONNECTION_NAME @"org.freedesktop.NetworkManager"
#define OBJECT_PATH     @"/org/freedesktop/NetworkManager"
#define DKNC [DKNotificationCenter systemBusCenter]

@implementation AppController (NetworkManager)

- (NSString *)_nameOfDeviceType:(NSNumber *)type
{
  NSString *typeName = nil;
  switch([type intValue]) {
  case 1:
    typeName = @"Ethernet";
    break;
  case 2:
    typeName = @"Wi-Fi";
    break;
  case 5:
    typeName = @"Bluetooth";
    break;
  case 14:
    typeName = @"Generic";
    break;
  }
  return typeName;
}

- (NSString *)_descriptionOfDeviceState:(NSNumber *)state
{
  NSString *desc = nil;
  switch([state intValue]) {
  case 0:
    desc = @"The device's state is unknown";
    break;
  case 10:
    desc = @"The device is recognized, but not managed by NetworkManager";
    break;
  case 20:
    desc = @"The device is managed by NetworkManager, but is not available for "
      @"use. Reasons may include the wireless switched off, missing firmware, no"
      @" ethernet carrier, missing supplicant or modem manager, etc.";
    break;
  case 30:
    desc = @"The device can be activated, but is currently idle and not connected "
      @"to a network.";
    break;
  case 40:
    desc = @"The device is preparing the connection to the network. This may "
      @"include operations like changing the MAC address, setting physical link "
      @"properties, and anything else required to connect to the requested network.";
    break;
  case 50:
    desc = @"The device is connecting to the requested network. This may include "
      @"operations like associating with the Wi-Fi AP, dialing the modem, connecting "
      @"to the remote Bluetooth device, etc.";
    break;
  case 60:
    desc = @"The device requires more information to continue connecting to the "
      @"requested network. This includes secrets like WiFi passphrases, login "
      @"passwords, PIN codes, etc.";
    break;
  case 70:
    desc = @"The device is requesting IPv4 and/or IPv6 addresses and routing "
      @"information from the network.";
    break;
  case 80:
    desc = @"The device is checking whether further action is required for the "
      @"requested network connection. This may include checking whether only "
      @"local network access is available, whether a captive portal is blocking "
      @"access to the Internet, etc.";
    break;
  case 90:
    desc = @"The device is waiting for a secondary connection (like a VPN) which "
      @"must activated before the device can be activated";
    break;
  case 100:
    desc = @"The device has a network connection, either local or global.";
    break;
  case 110:
    desc = @"A disconnection from the current network connection was requested, "
      @"and the device is cleaning up resources used for that connection. The "
      @"network connection may still be valid.";
    break;
  case 120:
    desc = @"The device failed to connect to the requested network and is "
      @"cleaning up the connection request";
    break;
  }
  return desc;
}

- (DKProxy<NMConnectionSettings> *)_connectionWithName:(NSString *)name
                                             forDevice:(DKProxy<NMDevice> *)device
{
  NSDictionary *settings;
  DKProxy<NMConnectionSettings> *conn = nil;
  
  // NSArray<DKProxy<NMConnectionSettings> *> *allConns;
  // allConns = device.AvailableConnections;
  for (DKProxy<NMConnectionSettings> *connSets in device.AvailableConnections) {
    settings = [connSets GetSettings];
    if ([[[settings objectForKey:@"connection"] objectForKey:@"id"]
          isEqualToString:name] != NO) {
      conn = connSets;
      break;
    }
  }

  return conn;
}

@end

@implementation AppController

//
// --- Application
//

- (void)applicationWillFinishLaunching:(NSNotification *)notif
{
  connections = [NSMutableArray new];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notif
{
  DKPort *receivePort;
    
  sendPort = [[DKPort alloc] initWithRemote:CONNECTION_NAME
                                      onBus:DKDBusSystemBus];
  receivePort = [DKPort portForBusType:DKDBusSessionBus];
  connection = [NSConnection connectionWithReceivePort:receivePort
                                              sendPort:sendPort];
  if (connection) {
    [DKPort enableWorkerThread];
    _networkManager = (DKProxy<NetworkManager> *)[connection proxyAtPath:OBJECT_PATH];
    [connection retain];
    [_networkManager retain];
    [window setTitle:@"Network Connections"];
    [connectionList loadColumnZero];
    [connectionList selectRow:0 inColumn:0];
    [self connectionListClick:connectionList];
    [DKNC addObserver:self
             selector:@selector(deviceStateDidChange:)
                 name:@"DKSignal_org.freedesktop.NetworkManager.Device_StateChanged"
               object:nil];
    [connectionAction setEnabled:YES];
  }
  else {
    [window setTitle:@"Connection to NetworkManager failed!"];
  }
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
  return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
  NSLog(@"AppController: applicationWillTerminate");
  [[EthernetController controller] release];
  [connection invalidate];
  [sendPort release];
  [_networkManager release];
  [connMan release];
}

//
// --- Main window
//

- (void)_clearFields
{
  [statusInfo setStringValue:@"Unknown"];
  [statusDescription setStringValue:@""];
}

- (void)awakeFromNib
{
  NSLog(@"awakeFromNib: NetworkManager: %@", _networkManager.Version);
  [statusBox retain];
  [statusBox removeFromSuperview];
  [window center];
  [window setTitle:@"Connecting to NetworkManager..."];
  [connectionAction setRefusesFirstResponder:YES];
  [self _clearFields];
}

- (void)     browser:(NSBrowser *)sender
 createRowsForColumn:(NSInteger)column
            inMatrix:(NSMatrix *)matrix
{
  NSBrowserCell *cell;
  NSInteger     row = 0;
  NSString      *title;
  NSArray       *allDevices = [_networkManager GetAllDevices];
    
  for (DKProxy<NMDevice> *device in allDevices) {
    if ([device.DeviceType intValue] == 14)
      continue;
    // Use list of available connections because device may not have
    // active connection (connection was deactivated and no way to know
    // its state).
    for (DKProxy<NMConnectionSettings> *conn in device.AvailableConnections) {
      if ([conn respondsToSelector:@selector(GetSettings)] == NO)
        continue;
      title = [[[conn GetSettings] objectForKey:@"connection"]
                    objectForKey:@"id"];
      if (title && [title isEqualToString:@""] == NO) {
        [matrix addRow];
        row = [matrix numberOfRows] - 1;
        cell = [matrix cellAtRow:row column:column];
        [cell setLeaf:YES];
        [cell setRefusesFirstResponder:YES];
        [cell setTitle:title];
        [cell setRepresentedObject:device];
      }
    }  
  }
}

- (void)_setConnectionView:(NSView *)view
{
  NSRect viewFrame;

  if (connectionView) {
    viewFrame = [connectionView frame];
    [connectionView removeFromSuperview];
  }
  if (view) {
    [view setFrame:viewFrame];
    [contentBox addSubview:view];
  }
  connectionView = view;
}

- (void)_updateStatusInfoForDevice:(DKProxy<NMDevice> *)device
{
  NSString *status, *statusDesc;
  
  status = ([device.State intValue] < 100) ? @"Not Connected": @"Connected";
  statusDesc = [self _descriptionOfDeviceState:device.State];
  
  [self _clearFields];
  [statusInfo setStringValue:status];
  [statusDescription setStringValue:statusDesc];
}

- (void)connectionListClick:(id)sender
{
  NSBrowserCell     *cell = [connectionList selectedCell];
  DKProxy<NMDevice> *device;
  id<NSMenuItem>    popupItem;

  if (cell == nil)
    return;

  if ((device = [cell representedObject]) == nil)
    return;

  if ([statusBox superview] == nil) {
    [[window contentView] addSubview:statusBox];
  }
  
  switch([device.DeviceType intValue]) {
  case 1: // Ethernet
    [[EthernetController controller] updateForDevice:device];
    [self _updateStatusInfoForDevice:device];
    [self _setConnectionView:[EthernetController view]];
    break;
  case 2: // Wi-Fi
    break;
  case 5: // Bluetooth
    break;
  case 14: // Generic
  default:
    [self _setConnectionView:nil];
    break;
  }

  popupItem = [connectionAction
                itemAtIndex:[connectionAction indexOfItemWithTag:3]];
  if ([device.State intValue] >= 100) {
    [popupItem setTitle:@"Deactivate..."];
  }
  else {
    [popupItem setTitle:@"Activate..."];
  }
}

// "Connection" pull down button
- (void)connectionActionClick:(id)sender
{
  switch ([[sender selectedItem] tag])
    {
    case 0: // Add
      // Delay message send to leave room for popup menu closing
      [NSTimer scheduledTimerWithTimeInterval:0.1
                                       target:self
                                     selector:@selector(addConnection)
                                     userInfo:nil
                                      repeats:NO];
      break;
    case 1: // Remove
      [NSTimer scheduledTimerWithTimeInterval:0.1
                                       target:self
                                     selector:@selector(removeConnection)
                                     userInfo:nil
                                      repeats:NO];
      break;
    case 2: // Rename
      NSLog(@"Rename Connection");
      break;
    case 3: // Deactivate
      if ([[[sender selectedItem] title] isEqualToString:@"Deactivate..."]) {
        [self deactivateConnection];
      }
      else {
        [self activateConnection];
      }
      break;
    default:
      break;
    }
}

- (void)addConnection
{
  if (connMan == nil) {
    connMan = [ConnectionManager new];
  }
  [connMan showAddConnectionPanel];
  [connectionList reloadColumn:0];
}

- (void)removeConnection
{
  NSInteger                     result;
  DKProxy<NMDevice>             *device;
  DKProxy<NMConnectionSettings> *conn;

  result = NXTRunAlertPanel(@"Remove",
                            @"Do you want to remove connection `%@`?",
                            @"Remove", @"Leave", nil,
                            [[connectionList selectedCell] title]);
  if (result == NSAlertDefaultReturn) {
    device = [[connectionList selectedCell] representedObject];
    conn = [self _connectionWithName:[[connectionList selectedCell] title]
                           forDevice:device];
    [conn Delete];
    [connectionList reloadColumn:0];
  }
}

- (void)deactivateConnection
{
  DKProxy<NMDevice> *device = [[connectionList selectedCell] representedObject];
  [_networkManager DeactivateConnection:device.ActiveConnection];
}
- (void)activateConnection
{
  DKProxy<NMDevice>             *device;
  DKProxy<NMConnectionSettings> *conn;

  device = [[connectionList selectedCell] representedObject];
  conn = [self _connectionWithName:[[connectionList selectedCell] title]
                         forDevice:device];
  
  // NSLog(@"Activate connection: %@ - %@", conn,
  //       [[[conn GetSettings] objectForKey:@"connection"] objectForKey:@"id"]);
  [_networkManager ActivateConnection:conn
                                     :device
                                     :device];
}

/* Signals/Notifications */
- (void)deviceStateDidChange:(NSNotification *)aNotif
{
  NSLog(@"Device sate was changed: \n%@\nuserInfo: %@",
        [aNotif object], [aNotif userInfo]);
  // if ([[connectionList selectedCell] representedObject] == [aNotif object]) {
  //   NSLog(@"Update selected connection info");
    // [self connectionListClick:connectionList];
  // }
  if (timer &&
      [timer isKindOfClass:[NSTimer class]] &&
      [timer isValid]) {
    [timer invalidate];
  }
  timer = [NSTimer scheduledTimerWithTimeInterval:.5
                                  target:self
                                selector:@selector(updateConnectionInfo:)
                                userInfo:nil
                                 repeats:NO];
}

- (void)updateConnectionInfo:(NSTimer *)ti
{
  [self connectionListClick:connectionList];
  [timer invalidate];
  timer = nil;
}

@end
