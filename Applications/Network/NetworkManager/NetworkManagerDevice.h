/* -*- mode: objc -*- */
#import <Foundation/Foundation.h>

// org.freedesktop.NetworkManager.Device.Statistics
@protocol NetworkManagerDeviceStatistics

@property (assign,readwrite) NSNumber *RefreshRateMs;
@property (readonly)         NSNumber *RxBytes;
@property (readonly)         NSNumber *TxBytes;

@end

// org.freedesktop.NetworkManager.Device.Generic
@protocol NetworkManagerDeviceGeneric

@property (readonly) NSString *TypeDescription;
@property (readonly) NSString *HwAddress;

@end

// org.freedesktop.NetworkManager.Device
@protocol NetworkManagerDevice

- (void)Delete;
- (void)Disconnect;
- (void)Reapply:(NSDictionary*)connection :(NSNumber*)version_id :(NSNumber*)flags;
- (NSArray*)GetAppliedConnection:(NSNumber*)flags;

@property (readonly) NSNumber *State; // enum NMDeviceState
@property (readonly) NSNumber *DeviceType; // enum NMDeviceType
@property (readonly) NSNumber *Capabilities; // enum NMDeviceCapabilities
@property (readonly) NSNumber *NmPluginMissing; // BOOL
@property (readonly) NSNumber *Metered; // BOOL
@property (readonly) NSNumber *Ip4Address; // DEPRECATED; use the 'Addresses' property of the 'Ip4Config' object instead. 
@property (readonly) NSNumber *FirmwareMissing; // If TRUE, indicates the device is likely missing firmware necessary for its operation. 
@property (readonly) NSNumber *Mtu; // MTU
@property (readonly) NSNumber *Real; // True if the device exists, or False for placeholder devices that do not yet exist but could be automatically created by NetworkManager if one of their AvailableConnections was activated. 

@property (readonly) NSString *Udi;
@property (readonly) NSString *Driver;
@property (readonly) NSString *Interface;
@property (readonly) NSString *IpInterface;
@property (readonly) NSString *DriverVersion;
@property (readonly) NSString *PhysicalPortId;
@property (readonly) NSString *FirmwareVersion;

@property (readonly) NSArray  *LldpNeighbors;
@property (readonly) NSArray  *StateReason;
// Array of DKProxy <NetworkManagerSettingsConnection> objects
@property (readonly) NSArray  *AvailableConnections;

@property (readonly) DKProxy  *Ip4Config;
@property (readonly) DKProxy  *Dhcp4Config;
@property (readonly) DKProxy  *Ip6Config;
@property (readonly) DKProxy  *Dhcp6Config;
@property (readonly) DKProxy  *ActiveConnection;

@property (copy,readwrite) NSNumber *Managed; // BOOL
@property (assign,readwrite) NSNumber *Autoconnect; // BOOL

@end
