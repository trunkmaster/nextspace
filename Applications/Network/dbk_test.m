#import <Foundation/Foundation.h>
#import <DBusKit/DBusKit.h>

#import "NetworkManager/NetworkManager.h"

#define CONNECTION_NAME @"org.freedesktop.NetworkManager"
#define OBJECT_PATH     @"/org/freedesktop/NetworkManager"

void showPermissions(id nm)
{
  NSDictionary *perms = [nm GetPermissions];
  fprintf(stderr, "=== Permissions ===\n");
  for (NSString *key in [perms allKeys]) {
    fprintf(stderr, "\t%s = %s\n",
            [key cString], [[perms objectForKey:key] cString]);
  }
}

void showNetInformation(id<NetworkManager> nm)
{
  NSArray *connections;
  DKProxy<NMConnectionSettings> *connSets;
  
  fprintf(stderr, "=== Network Preferences ===\n");
  fprintf(stderr, "  Devices/Connections: \n");
  for (DKProxy<NMDevice> *dev in nm.AllDevices) {
    fprintf(stderr, "    %s (%s): ",
            [dev.Interface cString],
            [dev.IpInterface cString]);
    connections = dev.AvailableConnections;
    if ([connections count] > 0) {
      connSets = connections[0];
      fprintf(stderr, "%s", [connSets.Filename cString]);
    }
    else {
      fprintf(stderr, "None");
    }
    fprintf(stderr, "\n");  
  }

  fprintf(stderr, "  Active Connection: \n");
  
}

NSString *nameOfDeviceType(NSNumber *type)
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

NSString *descriptionOfDeviceState(NSNumber *state)
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

void showDeviceInformation(DKProxy<NMDevice> *device)
{
  DKProxy<NMIP4Config> *ip4Config;
  NSDictionary *configData;
  
  ip4Config = device.Ip4Config;
  configData = [ip4Config.AddressData objectAtIndex:0];
  
  fprintf(stderr, "=== %s (%s) ===\n", [device.Interface cString],
          [nameOfDeviceType(device.DeviceType) cString]);
  fprintf(stderr, "State        : %s\n", [descriptionOfDeviceState(device.State) cString]);

  fprintf(stderr, "--- TCP/IP ---\n");
  fprintf(stderr, " Interface   :    %s\n", [device.IpInterface cString]);
  fprintf(stderr, " IPv4 Address:    %s\n", [[configData objectForKey:@"address"] cString]);
  fprintf(stderr, " Subnet Mask :    %d\n", [[configData objectForKey:@"prefix"] intValue]);
  fprintf(stderr, " Router      :    %s\n", [ip4Config.Gateway cString]);

  fprintf(stderr, "--- DNS ---\n");
  for (configData in ip4Config.NameserverData) {
    fprintf(stderr, " DNS Address :    %s\n", [[configData objectForKey:@"address"] cString]);
    fprintf(stderr, " DNS Prefix  :    %d\n", [[configData objectForKey:@"prefix"] intValue]);
  }
  
  fprintf(stderr, "--- Hardware ---\n");
  fprintf(stderr, " MTU         :    %d\n", [device.Mtu intValue]);
  fprintf(stderr, " Driver      :    %s (%s)\n",
          [device.Driver cString], [device.DriverVersion cString]);
  // fprintf(stderr, " Firmware:         %s\n", [device.FirmwareVersion cString]);
  // fprintf(stderr, " Port ID:          %s\n", [device.PhysicalPortId cString]);
  // fprintf(stderr, " DeviceType:       %d\n", [device.DeviceType intValue]);
  // fprintf(stderr, " Capabilities:     %d\n", [device.Capabilities intValue]);
  // fprintf(stderr, " State:            %d\n", [device.State intValue]);
  // fprintf(stderr, " Firmware missing: %s\n", [device.FirmwareMissing intValue] ? "Yes" : "No");
  // fprintf(stderr, " Plugin Missing:   %s\n", [device.NmPluginMissing intValue] ? "Yes" : "No");
  // fprintf(stderr, " Metered:          %s\n", [device.Metered intValue] ? "Yes" : "No");
  // fprintf(stderr, " Real:             %s\n", [device.Real intValue] ? "Yes" : "No");  
}

int main(int argc, char *argv[])
{
  DKPort       *sendPort;
  DKPort       *receivePort;
  NSConnection *connection;
  DKProxy<NetworkManager> *networkManager;
  
  sendPort = [[DKPort alloc] initWithRemote:CONNECTION_NAME
                                      onBus:DKDBusSystemBus];
  receivePort = [DKPort portForBusType:DKDBusSessionBus];
  connection = [NSConnection connectionWithReceivePort:receivePort
                                              sendPort:sendPort];
  if (connection) {
    networkManager = (DKProxy<NetworkManager> *)[connection proxyAtPath:OBJECT_PATH];

    // showPermissions(networkManager);
    // showDevices(networkManager);
    showNetInformation(networkManager);
    for (DKProxy<NMDevice> *device in [networkManager GetAllDevices]) {
      if ([device.IpInterface isEqualToString:@""] == NO) {
        showDeviceInformation(device);
      }
    }

    // Devices
    // NSLog(@"State: %i", [[networkManager state] intValue]);
    // NSLog(@"Active connections:");
    // NSArray *activeConns = [networkManager ActiveConnections];
    // for (id c in activeConns) {
    //   NSLog(@"\t%@ - %@", [c _path], c);
    // }
    // NSLog(@"Primary connection type: %@", [networkManager PrimaryConnectionType]);

    [connection invalidate];
    [sendPort release];
    [networkManager release];
  }

  return 0;
}
