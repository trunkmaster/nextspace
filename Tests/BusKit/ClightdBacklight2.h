#import <Foundation/Foundation.h>

/*
 * Objective-C protocol declaration for the D-Bus org.freedesktop.DBus.Properties interface.
 */
@protocol org_freedesktop_DBus_Properties

- (void)Set: (NSString*)interface_name : (NSString*)property_name : (id)value;

- (id)Get: (NSString*)interface_name : (NSString*)property_name;

- (NSDictionary*)GetAll: (NSString*)interface_name;

@end

/*
 * Objective-C protocol declaration for the D-Bus org.freedesktop.DBus.ObjectManager interface.
 */
@protocol org_freedesktop_DBus_ObjectManager

- (NSDictionary*)GetManagedObjects;

@end

/*
 * Objective-C protocol declaration for the D-Bus org.clightd.clightd.Backlight2 interface.
 */
@protocol org_clightd_clightd_Backlight2

- (void)Set: (NSNumber*)argument0 : (NSArray*)argument1;

- (void)Lower: (NSNumber*)argument0 : (NSArray*)argument1;

- (void)Raise: (NSNumber*)argument0 : (NSArray*)argument1;

- (NSArray*)Get;

@end

/*
 * Objective-C protocol declaration for the D-Bus org.freedesktop.DBus.Peer interface.
 */
@protocol org_freedesktop_DBus_Peer

- (NSString*)GetMachineId;

- (void)Ping;

@end
