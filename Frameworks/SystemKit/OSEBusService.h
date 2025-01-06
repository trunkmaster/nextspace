#import <Foundation/Foundation.h>

@class OSEBusConnection;

@interface OSEBusService : NSObject

@property (readonly, retain, nonnull) OSEBusConnection *connection;
@property (readwrite, retain, nonnull) NSString *objectPath;
@property (readwrite, retain, nonnull) NSString *serviceName;

@end