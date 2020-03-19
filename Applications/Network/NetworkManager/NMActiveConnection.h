/* -*- mode: objc -*- */
#import <Foundation/Foundation.h>
#import "NetworkManager/DBusIntrospectable.h"
#import "NetworkManager/DBusPeer.h"
#import "NetworkManager/DBusProperties.h"

/* org.freedesktop.NetworkManager.Connection.Active */
@protocol NMActiveConnection <DBusIntrospectable, DBusPeer, DBusProperties>

@property (readonly) DKProxy *Connection;  // <NMConnectionSettings>
@property (readonly) DKProxy *Ip4Config;   // <NMIP4Config>
@property (readonly) DKProxy *Dhcp4Config; // <NMDHCP4Config>
@property (readonly) NSArray *Devices;     // <NMDevice>
/* Whether this active connection is the default IPv4 connection, 
   i.e. whether it currently owns the default IPv4 route. */
@property (readonly) NSNumber                      *Default; // Boolean
@property (readonly) NSNumber *State; // NMActiveConnectionState
@property (readonly) NSNumber *StateFlags; // NMActivationStateFlags
/* A specific object associated with the active connection. This property 
   reflects the specific object used during connection activation, and will not 
   change over the lifetime of the ActiveConnection once set. */
@property (readonly) DKProxy  *SpecificObject;
@property (readonly) NSNumber *Vpn; // Boolean
/* The path to the master device if the connection is a slave. */
@property (readonly) DKProxy  *Master;

// Convenience
@property (readonly) NSString *Id;
@property (readonly) NSString *Uuid;
@property (readonly) NSString *Type;

// IPv6
@property (readonly) DKProxy  *Ip6Config;
@property (readonly) DKProxy  *Dhcp6Config;
@property (readonly) NSNumber *Default6; // Boolean

@end
