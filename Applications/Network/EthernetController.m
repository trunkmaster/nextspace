/* All Rights reserved */

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

- (void)_updateConfigureMethod:(NSString *)type
{
  if ([type isEqualToString:@"auto"]) {
    [configureMethod selectItemWithTag:0];
  }
  else if ([type isEqualToString:@"manual"]) {
    [configureMethod selectItemWithTag:1];
  }
  else if ([type isEqualToString:@"link-local"]) {
    [configureMethod selectItemWithTag:2];
  }
  else if ([type isEqualToString:@"disabled"]) {
    [configureMethod selectItemWithTag:3];
  }
}

// FIXME: unused
- (void)updateForDevice:(DKProxy<NMDevice> *)device
{
  DKProxy<NMIP4Config> *ip4Config;
  NSDictionary         *configData = nil;
  NSString             *ip, *mask, *gw, *dns, *domains;
   
  [self _clearFields];
  if (device == nil || [device.State intValue] < 100) {
    return;
  }
  else {
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
    
    ip = [configData objectForKey:@"address"];
    mask = [configData objectForKey:@"prefix"];
    gw = ip4Config.Gateway;
    dns = [ip4Config.NameserverData[0] objectForKey:@"address"];
    domains  = [ip4Config.Domains componentsJoinedByString:@","];
    
    [ipAddress setStringValue:ip];
    [subnetMask setStringValue:mask];
    [defaultGateway setStringValue:gw];
    [dnsServers setStringValue:dns];
    [searchDomains setStringValue:domains];
  }
}

- (void)updateForConnection:(DKProxy<NMConnectionSettings> *)conn
{
  NSDictionary *settings;
  NSDictionary *ipv4;
  NSArray      *address_data;
  NSString     *ip=@"", *mask=@"", *gw, *dns, *domains, *method;
   
  [self _clearFields];

  if ([conn respondsToSelector:@selector(Connection)]) {
    DKProxy<NMDevice> *device;

    device = [(DKProxy<NMActiveConnection> *)conn Devices][0];
    conn = (DKProxy<NMConnectionSettings> *)[(DKProxy<NMActiveConnection> *)conn Connection];
    method = [conn GetSettings][@"ipv4"][@"method"];
    
    [self updateForDevice:device];
  }
  else {
    settings = [conn GetSettings];
    ipv4 = settings[@"ipv4"];

    address_data = ipv4[@"address-data"];

    if ([address_data count] > 0) {
      ip = [address_data[0] objectForKey:@"address"];
      mask = [address_data[0] objectForKey:@"prefix"];
    }
    gw = ipv4[@"gateway"];
    dns = [ipv4[@"dns"] componentsJoinedByString:@","];
    domains  = [ipv4[@"dns-search"] componentsJoinedByString:@","];
    
    [ipAddress setStringValue:ip];
    [subnetMask setStringValue:mask];
    [defaultGateway setStringValue:gw];
    [dnsServers setStringValue:dns];
    [searchDomains setStringValue:domains];
    method = ipv4[@"method"];
  }

  [self _updateConfigureMethod:method];
}

@end
