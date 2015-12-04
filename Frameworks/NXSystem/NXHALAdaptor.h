//
//
//

#import <Foundation/Foundation.h>
#import <hal/libhal.h>

@interface NXHALAdaptor : NSObject <DeviceEventsAdaptor>
{
  DBusConnection *conn;
  LibHalContext  *hal_ctx;

  // NSMutableArray *volumes;
}

@end

@interface NXHALAdaptor (Private)

- (void)_messageArrived:(NSNotification *)aNotif;
- (void)_proceedEvent:(NSString *)deviceEvent
               forUDI:(NSString *)udi
                  key:(NSString *)key;

//--- Accessing attributes (properties and capabilities) of HAL object
- (NSArray *)_registeredDevices;
- (id)_propertyValue:(NSString *)key forUDI:(NSString *)udi;
- (BOOL)_deviceWithUDI:(NSString *)UDI hasCapability:(NSString *)capability;

//--- Accessing volumes (filesystems) attributes
- (NSArray *)_availableVolumes;
- (NSDictionary *)_volumeDescriptionForUDI:(NSString *)UDI;
- (NSDictionary *)_volumeDescriptionForPath:(NSString *)path;

- (BOOL)_isDeviceRemovable:(NSString *)UDI;
- (BOOL)_isVolumeOptical:(NSString *)UDI;
- (BOOL)_isVolumeMountable:(NSString *)UDI;

@end
