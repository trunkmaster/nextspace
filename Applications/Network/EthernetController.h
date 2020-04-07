/* All Rights reserved */

#include <AppKit/AppKit.h>

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

@end
