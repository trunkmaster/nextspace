#import <Foundation/Foundation.h>
#import <DBusKit/DBusKit.h>

#import "NetworkManager/NetworkManager.h"
#import "NetworkManager/NetworkManagerDevice.h"
#import "NetworkManager/NetworkManagerSettingsConnection.h"

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

void showDevices(id<NetworkManager> nm)
{
  NSArray *availableConnections;
  DKProxy<NetworkManagerDevice> *device;
  
  fprintf(stderr, "=== Devices ===\n");
  
  for (device in nm.AllDevices) {
    fprintf(stderr, "%s %s (%s)\n", [[object_getClass(device) description] cString],
            [device.Interface cString], [device.Udi cString]);
    fprintf(stderr, "\t Interface:        %s\n", [device.IpInterface cString]);
    fprintf(stderr, "\t Driver:           %s\n", [device.Driver cString]);
    fprintf(stderr, "\t Driver version:   %s\n", [device.DriverVersion cString]);
    fprintf(stderr, "\t Port ID:          %s\n", [device.PhysicalPortId cString]);
    fprintf(stderr, "\t Firmware:         %s\n", [device.FirmwareVersion cString]);
    
    fprintf(stderr, "\t DeviceType:       %d\n", [device.DeviceType intValue]);
    fprintf(stderr, "\t Capabilities:     %d\n", [device.Capabilities intValue]);
    fprintf(stderr, "\t State:            %d\n", [device.State intValue]);
    fprintf(stderr, "\t IPv4 address:     %d\n", [device.Ip4Address intValue]);
    fprintf(stderr, "\t MTU:              %d\n", [device.Mtu intValue]);
    fprintf(stderr, "\t Firmware missing: %s\n", [device.FirmwareMissing intValue] ? "Yes" : "No");
    fprintf(stderr, "\t Plugin Missing:   %s\n", [device.NmPluginMissing intValue] ? "Yes" : "No");
    fprintf(stderr, "\t Metered:          %s\n", [device.Metered intValue] ? "Yes" : "No");
    fprintf(stderr, "\t Real:             %s\n", [device.Real intValue] ? "Yes" : "No");

    id<NetworkManagerSettingsConnection> connectionSettings;
    availableConnections = device.AvailableConnections;
    if ([availableConnections count] > 0) {
      fprintf(stderr, "\t Avalilable connections:\n");
      for (id conn in availableConnections) {
        connectionSettings = conn;
        NSLog(@"%@", connectionSettings.GetSettings);
        fprintf(stderr, "\t\t %s\n", [connectionSettings.Filename cString]);
      }
    }
  }

  // for (id pr in nm.AllDevices) {
  //   NSLog(@"\t \t%@ - %@", [pr _path], pr);
  //   availConns = [pr AvailableConnections];
  //   if ([availConns count] > 0)
  //     NSLog(@"\t\tConnections:");
  //   for (id c in availConns) {
  //     NSLog(@"\t\t\t %@", [c _path]);
  //   }
  // }
}

int main(int argc, char *argv[])
{
  DKPort       *sendPort;
  DKPort       *receivePort;
  NSConnection *connection;
  id           networkManager;
  
  sendPort = [[DKPort alloc] initWithRemote:CONNECTION_NAME
                                      onBus:DKDBusSystemBus];
  receivePort = [DKPort portForBusType:DKDBusSessionBus];
  connection = [NSConnection connectionWithReceivePort:receivePort
                                              sendPort:sendPort];
  if (connection) {
    networkManager = [connection proxyAtPath:OBJECT_PATH];

    showPermissions(networkManager);
    showDevices(networkManager);

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
