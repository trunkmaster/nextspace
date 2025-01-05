#import <Foundation/Foundation.h>

@class OSEBusConnection;

@interface OSEBusService : NSObject

@property (readonly, nonnull) OSEBusConnection *connection;
@property (readwrite, retain, nonnull) NSString *objectPath;
@property (readwrite, retain, nonnull) NSString *serviceName;

@end