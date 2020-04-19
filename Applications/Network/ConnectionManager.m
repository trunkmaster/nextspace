/* All Rights reserved */

#import <AppKit/AppKit.h>
#import <DBusKit/DBusKit.h>
#import "NetworkManager/NetworkManager.h"
#import "AppController.h"
#import "ConnectionManager.h"

@implementation ConnectionManager

- (void)showAddConnectionPanel
{
  if (window == nil) {
    if ([NSBundle loadNibNamed:@"AddConnection" owner:self] == NO) {
      NSLog(@"Error loading AddConnection model.");
      return;
    }
  }
  [window center];
  [window makeFirstResponder:connectionName];
  [window makeKeyAndOrderFront:self];
  [NSApp runModalForWindow:window];
}

- (void)awakeFromNib
{
  DKProxy<NetworkManager> *networkManager;

  [deviceList removeAllItems];
  networkManager = ((AppController *)[NSApp delegate]).networkManager;
  for (DKProxy<NMDevice> *device in [networkManager GetAllDevices]) {
    if ([device.DeviceType intValue] != 14) {
      [deviceList addItemWithTitle:device.Interface];
      [[deviceList itemWithTitle:device.Interface]
        setRepresentedObject:device];
    }
  }
}

- (void)addConnection:(id)sender
{
  DKProxy<NetworkManager> *networkManager;
  NSMutableDictionary     *settings = [NSMutableDictionary dictionary];
  DKProxy                 *device;

  networkManager = ((AppController *)[NSApp delegate]).networkManager;
  
  NSLog(@"Add connection with name `%@` for device `%@`",
        [connectionName stringValue], [[deviceList selectedItem] title]);

  [settings setObject:[connectionName stringValue] forKey:@"id"];
  device = [[deviceList selectedItem] representedObject];
  
  [networkManager AddAndActivateConnection:settings
                                          :device
                                          :nil];
  [window close];
}

@end
