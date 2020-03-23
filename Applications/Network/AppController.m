/*
 *  AppController.m 
 */

#import <DBusKit/DBusKit.h>
#import "NetworkManager/NMAccessPoint.h"

#define CONNECTION_NAME @"org.freedesktop.NetworkManager"
#define OBJECT_PATH     @"/org/freedesktop/NetworkManager"

#import "AppController.h"

@implementation AppController

- (id)init
{
  if ((self = [super init])) {
    DKPort *receivePort;
    
    sendPort = [[DKPort alloc] initWithRemote:CONNECTION_NAME
                                        onBus:DKDBusSystemBus];
    receivePort = [DKPort portForBusType:DKDBusSessionBus];
    connection = [NSConnection connectionWithReceivePort:receivePort
                                                sendPort:sendPort];
    if (connection) {
      _networkManager = (DKProxy<NetworkManager> *)[connection proxyAtPath:OBJECT_PATH];
      [connection retain];
      [_networkManager retain];
    }
  }

  NSLog(@"AppController: init");
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
  [connectionAction setRefusesFirstResponder:YES];
  [self _clearFields];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notif
{
}
- (void)applicationDidFinishLaunching:(NSNotification *)notif
{
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
  NSBrowserCell *cell;
  NSInteger     row;
  NSString      *title;
  NSArray       *allDevices = [_networkManager GetAllDevices];
    
  for (DKProxy<NMDevice> *device in allDevices) {
    [matrix addRow];
    row = [matrix numberOfRows] - 1;
    cell = [matrix cellAtRow:row column:column];
    [cell setLeaf:YES];
    [cell setRefusesFirstResponder:YES];
    title = [NSString stringWithFormat:@"%@ (%@)",
               [self _nameOfDeviceType:device.DeviceType], device.Interface];
    [cell setTitle:title];
    [cell setRepresentedObject:device];
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

  [self _clearFields];
  
  if (cell) {
    device = [cell representedObject];
    if (!device) {
      return;
    }
    
    if ([device.State intValue] < 100) {
      [statusInfo setStringValue:@"Not Connected"];
      [statusDescription setStringValue:[self _descriptionOfDeviceState:device.State]];
      return;
    }
    else {
      [statusInfo setStringValue:@"Connected"];
      [statusDescription setStringValue:[self _descriptionOfDeviceState:device.State]];
    }

    if ([device respondsToSelector:@selector(Ip4Config)]) {
      ip4Config = device.Ip4Config;
      if (ip4Config && [ip4Config respondsToSelector:@selector(AddressData)]) {
        configData = [ip4Config.AddressData objectAtIndex:0];
      }
      else {
        return;
      }
    }
    else {
      return;
    }
    [ipAddress setStringValue:[configData objectForKey:@"address"]];
    [subnetMask setStringValue:[configData objectForKey:@"prefix"]];
    [defaultGateway setStringValue:ip4Config.Gateway];
    [dnsServers setStringValue:[ip4Config.NameserverData[0] objectForKey:@"address"]];
    [searchDomains setStringValue:[ip4Config.Domains componentsJoinedByString:@","]];
  }
}

@end
