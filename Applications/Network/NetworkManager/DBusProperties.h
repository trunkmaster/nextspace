/* -*- mode: objc -*- */
#import <Foundation/Foundation.h>

// org.freedesktop.DBus.Properties
@protocol DBusProperties

- (void)Set:(NSString*)interface_name
           :(NSString*)property_name
           :(id)value;
- (id)Get:(NSString*)interface_name
         :(NSString*)property_name;
- (NSDictionary*)GetAll:(NSString*)interface_name;

@end
