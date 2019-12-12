/* -*- mode: objc -*- */
//
// D-Bus org.freedesktop.NetworkManager.IP4Config interface.
//
#import <Foundation/Foundation.h>

@protocol NetworkManagerIP4Config

@property (readonly) NSArray  *Addresses;
@property (readonly) NSArray  *AddressData;
@property (readonly) NSString *Gateway;
@property (readonly) NSArray  *Routes;
@property (readonly) NSArray  *RouteData;
@property (readonly) NSArray  *Nameservers;
@property (readonly) NSArray  *Domains;
@property (readonly) NSArray  *WinsServers;
@property (readonly) NSNumber *DnsPriority;
@property (readonly) NSArray  *Searches;
@property (readonly) NSArray  *DnsOptions;

@end
