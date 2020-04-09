/* All Rights reserved */

#import <AppKit/AppKit.h>
#import <DBusKit/DBusKit.h>
#import "NetworkManager/NetworkManager.h"

@interface EthernetController : NSObject
{
  NSBox         *ethernetView;
  NSPopUpButton *configureMethod;
  NSTextField   *ipAddress;
  NSTextField   *subnetMask;
  NSTextField   *defaultGateway;
  NSTextField   *dnsServers;
  NSTextField   *searchDomains;
}

+ (instancetype)controller;
+ (NSView *)view;
- (void)updateForDevice:(DKProxy<NMDevice> *)device;

@end
