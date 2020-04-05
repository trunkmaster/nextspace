/* -*- mode: objc -*- */
// D-Bus org.freedesktop.NetworkManager.Settings.Connection interface.

#import <Foundation/Foundation.h>

@protocol NMConnectionSettings <DBusPeer, DBusProperties>

- (void)Update:(NSDictionary*)properties;
- (NSDictionary*)Update2:(NSDictionary*)settings
                        :(NSNumber*)flags
                        :(NSDictionary*)args;
- (void)UpdateUnsaved:(NSDictionary*)properties;

- (NSDictionary*)GetSettings;
- (NSDictionary*)GetSecrets:(NSString*)setting_name;
- (void)ClearSecrets;
- (void)Save;
- (void)Delete;

@property (readonly) NSString *Filename;
@property (readonly) NSNumber *Flags;
@property (readonly) NSNumber *Unsaved;

@end
