/*
 *  AppController.m 
 */

#import <DBusKit/DBusKit.h>
#import "NetworkManager/NMAccessPoint.h"

#define CONNECTION_NAME @"org.freedesktop.NetworkManager"
#define OBJECT_PATH     @"/org/freedesktop/NetworkManager"
#define DKNC [DKNotificationCenter systemBusCenter]

#import "AppController.h"

@implementation AppController

- (id)init
{
  if ((self = [super init])) {
  }
  return self;
}

- (void)_clearFields
{
  [statusInfo setStringValue:@""];
  [statusDescription setStringValue:@""];

  [ipAddress setStringValue:@""];
  [subnetMask setStringValue:@""];
  [defaultGateway setStringValue:@""];
  [dnsServers setStringValue:@""];
  [searchDomains setStringValue:@""];
}

- (void)awakeFromNib
{
  NSLog(@"awakeFromNib: NetworkManager: %@", _networkManager.Version);
  [window center];
  [window setTitle:@"Connecting to NetworkManager..."];
  [connectionAction setRefusesFirstResponder:YES];
  [self _clearFields];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notif
{
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
  [connection invalidate];
  [sendPort release];
  [_networkManager release];
}

// NetworkManager related methods
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
- (void)     browser:(NSBrowser *)sender
 createRowsForColumn:(NSInteger)column
            inMatrix:(NSMatrix *)matrix
{
  NSBrowserCell                 *cell;
  NSInteger                     row;
  NSString                      *title;
  NSArray                       *allDevices = [_networkManager GetAllDevices];
  DKProxy<NMActiveConnection>   *aconn;
  DKProxy<NMConnectionSettings> *conns;
    
  for (DKProxy<NMDevice> *device in allDevices) {
    if ([device.DeviceType intValue] != 14) {
      [matrix addRow];
      row = [matrix numberOfRows] - 1;
      cell = [matrix cellAtRow:row column:column];
      [cell setLeaf:YES];
      [cell setRefusesFirstResponder:YES];
      // title = [NSString stringWithFormat:@"%@ (%@)",
      //            [self _nameOfDeviceType:device.DeviceType], device.Interface];
      aconn = device.ActiveConnection;
      conns = (DKProxy<NMConnectionSettings> *)aconn.Connection;
      if ([conns respondsToSelector:@selector(GetSettings)]) {
        title = [[[conns GetSettings] objectForKey:@"connection"] objectForKey:@"id"];
        [cell setTitle:title];
        [cell setRepresentedObject:device];
      }
    }
  }
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

- (void)connectionListClick:(id)sender
{
  NSBrowserCell        *cell = [connectionList selectedCell];
  DKProxy<NMDevice>    *device;
  DKProxy<NMIP4Config> *ip4Config;
  NSDictionary         *configData = nil;
  NSString             *ip, *mask, *gw, *dns, *domains, *statusDesc;

  if (cell == nil)
    return;

  if ((device = [cell representedObject]) == nil)
    return;
   
  if ([device.State intValue] < 100) {
    statusDesc = [self _descriptionOfDeviceState:device.State];
    [self _clearFields];
    [statusInfo setStringValue:@"Not Connected"];
    [statusDescription setStringValue:statusDesc];
  }
  else {
    statusDesc = [self _descriptionOfDeviceState:device.State];
    if ([device respondsToSelector:@selector(Ip4Config)]) {
      ip4Config = device.Ip4Config;
      if (ip4Config && [ip4Config respondsToSelector:@selector(AddressData)]) {
        configData = [ip4Config.AddressData objectAtIndex:0];
      }
      else {
        [self _clearFields];
        return;
      }
    }
    else {
      [self _clearFields];
      return;
    }
    
    ip = [configData objectForKey:@"address"];
    mask = [configData objectForKey:@"prefix"];
    gw = ip4Config.Gateway;
    dns = [ip4Config.NameserverData[0] objectForKey:@"address"];
    domains  = [ip4Config.Domains componentsJoinedByString:@","];
    
    [self _clearFields];
    [statusInfo setStringValue:@"Connected"];
    [statusDescription setStringValue:statusDesc];
    [ipAddress setStringValue:ip];
    [subnetMask setStringValue:mask];
    [defaultGateway setStringValue:gw];
    [dnsServers setStringValue:dns];
    [searchDomains setStringValue:domains];
  }
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
  if (timer && [timer isValid]) {
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
