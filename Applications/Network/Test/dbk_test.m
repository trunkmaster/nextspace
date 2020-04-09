#import <Foundation/Foundation.h>
#import <DBusKit/DBusKit.h>

#import "NetworkManager/NetworkManager.h"
#import "NetworkManager/NMAccessPoint.h"
#import "NetworkManager/NMConnectionSettings.h"

#define CONNECTION_NAME @"org.freedesktop.NetworkManager"
#define OBJECT_PATH     @"/org/freedesktop/NetworkManager"

NSDictionary *validateSettings(NSDictionary *settings)
{
  NSMutableDictionary *validSettings = [settings mutableCopy];
  id value;

  for (NSString *key in [settings allKeys]) {
    value = [settings objectForKey:key];
    if ([value isKindOfClass:[NSArray class]]) {
      if ([value count] == 0)
        [validSettings removeObjectForKey:key];
    }
    else if ([value isKindOfClass:[NSDictionary class]]) {
      if ([[value allKeys] count] == 0)
        [validSettings removeObjectForKey:key];        
    }
  }

  return [NSDictionary dictionaryWithDictionary:validSettings];
}


void showPermissions(id nm)
{
  NSLog(@"NetworkManager GetPermissions: start");
  NSDictionary *perms = [nm GetPermissions];
  NSLog(@"NetworkManager GetPermissions: end");
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
  fprintf(stderr, "  Networking : ");
  if ([nm.NetworkingEnabled boolValue] != NO)
    fprintf(stderr, "OK\n");
  else
    fprintf(stderr, "Disabled\n");
    
  fprintf(stderr, "  WiMax      : ");
  if ([nm.WimaxEnabled boolValue] != NO)
    fprintf(stderr, "OK\n");
  else
    fprintf(stderr, "Disabled\n");
  
  fprintf(stderr, "  Wireless   : ");
  if ([nm.WirelessEnabled boolValue] != NO)
    fprintf(stderr, "OK\n");
  else
    fprintf(stderr, "Disabled\n");
  
  fprintf(stderr, "  Wwan       : ");
  if ([nm.WwanEnabled boolValue] != NO)
    fprintf(stderr, "OK\n");
  else
    fprintf(stderr, "Disabled\n");
  
  fprintf(stderr, "  Devices/Connections: \n");
  for (DKProxy<NMDevice> *dev in nm.AllDevices) {
    [dev setPrimaryDBusInterface:@"org.freedesktop.NetworkManager.Device"];
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
    fprintf(stderr, " %d", [dev.State intValue]);  
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
  NSDictionary *configData = nil;

  // [device setPrimaryDBusInterface:@"org.freedesktop.NetworkManager.Device"];
  if ([device.State intValue] < 100) {
    fprintf(stderr, "=== %s ===\n", [device.Interface cString]);
    fprintf(stderr, "State           : %s\n", [descriptionOfDeviceState(device.State) cString]);
    return;
  }

  if (device && [device respondsToSelector:@selector(Ip4Config)]) {
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

  fprintf(stderr, "=== %s (%s) ===\n", [device.Interface cString],
          [nameOfDeviceType(device.DeviceType) cString]);
  fprintf(stderr, "State           : %s\n", [descriptionOfDeviceState(device.State) cString]);

  fprintf(stderr, "--- TCP/IP ---\n");
  fprintf(stderr, " Interface      :    %s\n", [device.IpInterface cString]);
  fprintf(stderr, " IPv4 Address   :    %s\n", [[configData objectForKey:@"address"] cString]);
  fprintf(stderr, " Subnet Mask    :    %d\n", [[configData objectForKey:@"prefix"] intValue]);
  fprintf(stderr, " Router         :    %s\n", [ip4Config.Gateway cString]);

  fprintf(stderr, "--- DNS ---\n");
  for (configData in ip4Config.NameserverData) {
    fprintf(stderr, " DNS Server     :    %s\n",
            [[configData objectForKey:@"address"] cString]);
    fprintf(stderr, " DNS Prefix     :    %d\n",
            [[configData objectForKey:@"prefix"] intValue]);
    fprintf(stderr, " Search Domains :    %s\n",
            [[ip4Config.Domains componentsJoinedByString:@","] cString]);
  }
  
  fprintf(stderr, "--- Hardware ---\n");
  // TypeDescription is a property of org.freedesktop.NetworkManager.Device.Generic
  // `conformsToProtocol:` is not working for DKProxy objects - bug?
  if ([device respondsToSelector:@selector(TypeDescription)]) {
    fprintf(stderr, " Type           :    %s\n", [device.TypeDescription cString]);
  }
  // TypeDescription is a property of org.freedesktop.NetworkManager.Device.Wired
  // and org.freedesktop.NetworkManager.Device.Generic
  if ([device respondsToSelector:@selector(HwAddress)]) {
    fprintf(stderr, " MAC Address    :    %s\n", [device.HwAddress cString]);
  }    
  if ([device respondsToSelector:@selector(Speed)]) {
    fprintf(stderr, " Speed          :    %d Mb/s\n", [device.Speed intValue]);
  }
  fprintf(stderr, " MTU            :    %d\n", [device.Mtu intValue]);
  fprintf(stderr, " Driver         :    %s (%s)\n",
          [device.Driver cString], [device.DriverVersion cString]);
  if ([device.FirmwareMissing boolValue] != NO) {
    fprintf(stderr, " Firmware       :    %s\n", [device.FirmwareVersion cString]);
  }

  // Wi-Fi
  if ([device respondsToSelector:@selector(AccessPoints)]) {
    // @try {
    //   [device RequestScan:nil];
    // }
    // @catch (NSException *ex) {
    //   NSLog(@"Rescan of access points failed: %@", [ex reason]);
    // }
    fprintf(stderr, " Access Points  : \n");
    for (DKPort<NMAccessPoint> *ap in device.GetAllAccessPoints) {
      for (id c in ap.Ssid) {
        fprintf(stderr, "%c", [c charValue]);
      }
      fprintf(stderr, "(%s)", [ap.HwAddress cString]);
      fprintf(stderr, " - Strength: %d%% Bitrate: %d Mb/s Frequency: %.2f Hz\n",
              [ap.Strength intValue], [ap.MaxBitrate intValue]/1000,
              [ap.Frequency floatValue]/1000.0);
    }
    // fprintf(stderr, "\n");
  }

  {
    DKProxy<NMActiveConnection> *aconn = device.ActiveConnection;
    DKProxy<NMConnectionSettings> *conn = (DKProxy<NMConnectionSettings> *)aconn.Connection;
    NSLog(@"Connection Settings: %@", [conn GetSettings]);
    {
      NSDictionary *validSets;
      NSMutableDictionary /**cSets1,*/ *cSets2, *nSets;
      // cSets1 = [NSMutableDictionary
      //            dictionaryWithDictionary:[conn GetSettings]];
      // cSets2 = [NSMutableDictionary
      //            dictionaryWithDictionary:[cSets1 objectForKey:@"connection"]];
      validSets = validateSettings([[conn GetSettings] objectForKey:@"connection"]);
      cSets2 = [NSMutableDictionary dictionaryWithDictionary:validSets];
      // NSLog(@"Connection Settings: %@", cSets2);
      // [cSets2 setObject:[NSNumber numberWithInt:1] forKey:@"autoconnect-priority"];
      // [cSets2 removeObjectForKey:@"permissions"];
      [cSets2 setObject:[NSNumber numberWithInt:0] forKey:@"autoconnect-priority"];
      nSets = [NSMutableDictionary new];
      [nSets setObject:cSets2 forKey:@"connection"];
      
      NSLog(@"Will `Update` to: %@", nSets);
      NSLog(@"Call `Update` to connection settings");
      @try {
        [conn Update:nSets];
      }
      @catch (NSException *ex) {
        NSLog(@"%@", [ex userInfo]);
      }
      @finally {
        [nSets release];
      }
    }
    NSLog(@"\nConnection Settings after `Update`: %@", [conn GetSettings]);
    
    // NSLog(@"Setting autoconnect-priority to 1");
    // [(DKProxy<NMConnectionSettings> *)conn Set:@"org.freedesktop.DBus.Properties"
    //                                           :@"autoconnect-priority"
    //                                           :[NSNumber numberWithInt:1]];
    // NSLog(@"Connection Settings after change: %@",
    //       [(DKProxy<NMConnectionSettings> *)conn GetSettings]);
  }
}

// Returns list of available devices
NSArray *deviceList(DKProxy<NetworkManager> *nm)
{
  NSArray        *allDevices = [nm GetAllDevices];
  NSMutableArray *deviceList = [NSMutableArray new];
    
  for (DKProxy<NMDevice> *device in allDevices) {
    [deviceList addObject:device];
    // if ([device.IpInterface isEqualToString:@""] == NO
    //     && device.State != [NSNumber numberWithInt:10]) {
    // if (device.State != [NSNumber numberWithInt:10]) {
    //   [deviceList addObject:device];
    // }
    // else {
    //   fprintf(stderr, "Device `%s` will be skipped. Reason: %s\n",
    //           [device.Interface cString],
    //           [descriptionOfDeviceState(device.State) cString]);
    // }
  }

  return [NSArray arrayWithArray:[deviceList autorelease]];
}

int main(int argc, char *argv[])
{
  DKPort       *sendPort;
  DKPort       *receivePort;
  NSConnection *connection;
  DKProxy<NetworkManager> *networkManager;

  NSLog(@"Setting up connection to the NetworkManager...");
  sendPort = [[DKPort alloc] initWithRemote:CONNECTION_NAME
                                      onBus:DKDBusSystemBus];
  receivePort = [DKPort portForBusType:DKDBusSessionBus];
  connection = [NSConnection connectionWithReceivePort:receivePort
                                              sendPort:sendPort];
  if (connection) {
    networkManager = (DKProxy<NetworkManager> *)[connection proxyAtPath:OBJECT_PATH];
    NSLog(@"Done!");

    [DKPort enableWorkerThread];  
    showPermissions(networkManager);
    showNetInformation(networkManager);
    for (DKProxy<NMDevice> *device in deviceList(networkManager)) {
      showDeviceInformation(device);
    }

    [connection invalidate];
    [sendPort release];
    [networkManager release];
  }

  return 0;
}
