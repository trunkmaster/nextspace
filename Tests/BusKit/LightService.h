#import <Foundation/Foundation.h>

#import <BusKit/BKConnection.h>
#import <BusKit/BKMessage.h>

@interface LightService : NSObject
{
  BKConnection *connection;
  BOOL isOwnedConnection;
  const char *object_path;
  const char *service_name;
}

@property (readonly) NSString *version;

- (instancetype)initWithConnection:(BKConnection *)conn;

@end
