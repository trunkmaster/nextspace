/* -*- mode: objc -*- */
#import <Foundation/Foundation.h>
#import "NetworkManager/NMIP4Config.h"
#import "NetworkManager/NMDHCP4Config.h"
#import "NetworkManager/NMActiveConnection.h"
#import "NetworkManager/NMConnectionSettings.h"

/* org.freedesktop.NetworkManager.Device.Generic */
@protocol NMDeviceGeneric

@property (readonly) NSString *TypeDescription;
@property (readonly) NSString *HwAddress;

@end

/* org.freedesktop.NetworkManager.Device.Wired */
@protocol NMDeviceWired

@property (readonly) NSNumber *Speed;
@property (readonly) NSNumber *Carrier;
@property (readonly) NSString *HwAddress;
@property (readonly) NSString *PermHwAddress;
@property (readonly) NSArray  *S390Subchannels;

@end

/* org.freedesktop.NetworkManager.Device.Statistics */
@protocol NMDeviceStatistics

@property (assign,readwrite) NSNumber *RefreshRateMs;
@property (readonly)         NSNumber *RxBytes;
@property (readonly)         NSNumber *TxBytes;

@end

// org.freedesktop.NetworkManager.Device
@protocol NMDevice <NMDeviceGeneric, NMDeviceWired, NMDeviceStatistics>

@property (readonly) NSArray<DKProxy<NMConnectionSettings> *> *AvailableConnections;
@property (readonly) DKProxy<NMActiveConnection>              *ActiveConnection;
@property (readonly) DKProxy<NMIP4Config>                     *Ip4Config;
@property (readonly) DKProxy<NMDHCP4Config>                   *Dhcp4Config;
@property (readonly) DKProxy                                  *Ip6Config;
@property (readonly) DKProxy                                  *Dhcp6Config;

// enum NMDeviceState
@property (readonly) NSNumber *State;
@property (readonly) NSArray  *StateReason;
// enum NMDeviceType
@property (readonly) NSNumber *DeviceType;
// enum NMDeviceCapabilities
@property (readonly) NSNumber *Capabilities;
@property (readonly) NSNumber *NmPluginMissing; // BOOL
@property (readonly) NSString *FirmwareVersion;
/* If TRUE, indicates the device is likely missing firmware necessary for its 
   operation. */
@property (readonly) NSNumber *FirmwareMissing; 
@property (readonly) NSNumber *Mtu; // MTU
/* True if the device exists, or False for placeholder devices that do not yet 
   exist but could be automatically created by NetworkManager if one of their 
   AvailableConnections was activated. */
@property (readonly) NSNumber *Real;
@property (readonly) NSNumber *Metered; // Boolean

@property (readonly) NSString *Udi;
@property (readonly) NSString *Driver;
@property (readonly) NSString *DriverVersion;
@property (readonly) NSString *Interface;
@property (readonly) NSString *IpInterface;
@property (readonly) NSString *PhysicalPortId;
@property (readonly) NSArray  *LldpNeighbors;

@property (copy,readwrite)   NSNumber *Managed; // BOOL
@property (assign,readwrite) NSNumber *Autoconnect; // BOOL

// Deprecated properties
// @property (readonly) NSNumber *Ip4Address; ---> Ip4Config

- (void)Delete;
- (void)Disconnect;
- (void)Reapply:(NSDictionary*)connection :(NSNumber*)version_id :(NSNumber*)flags;
- (NSArray*)GetAppliedConnection:(NSNumber*)flags;

@end

