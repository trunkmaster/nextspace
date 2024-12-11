#import <Foundation/Foundation.h>

#import <BusKit/BKConnection.h>
#import <BusKit/BKMessage.h>

@interface LightBacklight2 : NSObject
{
  BKConnection *connection;
  BOOL isOwnedConnection;
  const char *object_path;
  const char *service_name;
}

@property (readonly) NSArray *Get;
@property (readonly) NSArray *GetManagedObjects;

- (instancetype)initWithConnection:(BKConnection *)conn;

@end
