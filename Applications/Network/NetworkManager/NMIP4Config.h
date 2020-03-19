/* -*- mode: objc -*- */
// dbus-send --system  --type=method_call --print-reply \
//           --dest=org.freedesktop.NetworkManager \
//           /org/freedesktop/NetworkManager/IP4Config/3 \
//           org.freedesktop.DBus.Introspectable.Introspect 

#import <Foundation/Foundation.h>

/*
 * org.freedesktop.NetworkManager.IP4Config interface.
 */
@protocol NMIP4Config

/* Array of IP address data objects. All addresses will include "address"
   (an IP address string), and "prefix" (a uint). */
@property (readonly) NSArray  *AddressData;
/* The gateway in use. */
@property (readonly) NSString *Gateway;
/* Array of IP route data objects. All routes will include "dest"
   (an IP address string) and "prefix" (a uint). Some routes may include
   "next-hop" (an IP address string), "metric" (a uint). */
@property (readonly) NSArray  *RouteData;

/* The nameservers in use. Currently only the value "address" is recognized
   (with an IP address string). */
@property (readonly) NSArray  *NameserverData;
/* The relative priority of DNS servers. */
@property (readonly) NSNumber *DnsPriority;
/* A list of DNS options that modify the behavior of the DNS resolver.
   See resolv.conf(5) manual page for the list of supported options. */
@property (readonly) NSArray  *DnsOptions;
/* A list of domains this address belongs to. */
@property (readonly) NSArray  *Domains;
/* A list of dns searches. */
@property (readonly) NSArray  *Searches;
/* he Windows Internet Name Service servers associated with the connection. */
@property (readonly) NSArray  *WinsServerData;

// Deprecated properties
// @property (readonly) NSArray  *Addresses;	--> AddressData
// @property (readonly) NSArray  *Routes;	--> RouteData
// @property (readonly) NSArray  *Nameservers;	--> NameserverData
// @property (readonly) NSArray  *WinsServers;	--> WinsServerData

@end
