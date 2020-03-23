#import <Foundation/Foundation.h>

/* org.freedesktop.NetworkManager.Device.Statistics. */
@protocol org_freedesktop_NetworkManager_Device_Statistics

@property (readwrite) NSNumber* RefreshRateMs;

@property (readonly) NSNumber* RxBytes;

@property (readonly) NSNumber* TxBytes;

@end
#import <Foundation/Foundation.h>

/* org.freedesktop.NetworkManager.Device.Wireless. */
@protocol org_freedesktop_NetworkManager_Device_Wireless

- (void)RequestScan: (NSDictionary*)options;

- (NSArray*)GetAccessPoints;

- (NSArray*)GetAllAccessPoints;

@property (readonly) NSString* PermHwAddress;

@property (readonly) NSString* HwAddress;

@property (readonly) NSNumber* Mode;

@property (readonly) NSNumber* Bitrate;

@property (readonly) NSNumber* WirelessCapabilities;

@property (readonly) DKProxy* ActiveAccessPoint;

@property (readonly) NSNumber* LastScan;

@property (readonly) NSArray* AccessPoints;

@end
