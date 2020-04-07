/* All Rights reserved */

#import <AppKit/AppKit.h>
#import <DBusKit/DBusKit.h>
#import "NetworkManager/NetworkManager.h"
#import "EthernetController.h"

static EthernetController *_controller = nil;

@implementation EthernetController

+ (instancetype)controller
{
  if (_controller == nil) {
    _controller = [EthernetController new];
  }

  return _controller;
}

+ (NSView *)view
{
  if (_controller == nil) {
    _controller = [EthernetController controller];
  }

  return [_controller view];
}

- (void)dealloc
{
  NSLog(@"EthernetController: dealloc");
  [super dealloc];
}

- (id)init
{
  if ((self = [super init])) {
    if (![NSBundle loadNibNamed:@"EthernetView" owner:self]) {
      NSLog (@"EthernetView: Could not load NIB, aborting.");
      return nil;
    }
  }  
  
  return self;
}

- (void)awakeFromNib
{
  [ethernetView retain];
  [ethernetView removeFromSuperview];
  [configureMethod setRefusesFirstResponder:YES];
}

- (NSView *)view
{
  return ethernetView;
}

- (void)_clearFields
{
  [ipAddress setStringValue:@""];
  [subnetMask setStringValue:@""];
  [defaultGateway setStringValue:@""];
  [dnsServers setStringValue:@""];
  [searchDomains setStringValue:@""];
}

- (void)updateForDevice:(DKProxy<NMDevice> *)device
{
  DKProxy<NMIP4Config> *ip4Config;
  NSDictionary         *configData = nil;
  NSString             *ip, *mask, *gw, *dns, *domains;
  
  if ([device.State intValue] < 100) {
    [self _clearFields];
    return;
  }
  else {
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
    [ipAddress setStringValue:ip];
    [subnetMask setStringValue:mask];
    [defaultGateway setStringValue:gw];
    [dnsServers setStringValue:dns];
    [searchDomains setStringValue:domains];
  }
}

@end
