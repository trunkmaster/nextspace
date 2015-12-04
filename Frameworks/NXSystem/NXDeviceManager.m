//
//
//

#import "NXDeviceManager.h"

// Device events
NSString *NXDeviceAdded = @"NXDeviceAdded";
NSString *NXDeviceRemoved = @"NXDeviceRemoved";
NSString *NXDevicePropertyChanged = @"NXDevicePropertyChanged";
NSString *NXDevicePropertyRemoved = @"NXDevicePropertyRemoved";
NSString *NXDevicePropertyAdded = @"NXDevicePropertyAdded";
NSString *NXDeviceConditionChanged = @"NXDeviceConditionChanged";

//-----------------------------------------------------------------------
static NXDeviceManager      *defaultManager;
static NSNotificationCenter *notificationCenter;

@implementation NXDeviceManager

+ (id)defaultManager
{
  if (defaultManager == nil)
    {
      [[self alloc] init];
    }

  return defaultManager;
}

- (id)init
{
  if (!(self = [super init]))
    {
      return nil;
    }
  
  defaultManager = self;
  notificationCenter = [NSNotificationCenter defaultCenter];

  return self;
}

- (void)dealloc
{
  NSLog(@"NXDeviceManager: dealloc");
  
  [super dealloc];
}

@end
