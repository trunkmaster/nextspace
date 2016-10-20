//
//
//

#import <NXSystem/NXMediaManager.h>

#ifdef WITH_HAL
#import <NXSystem/NXHALAdaptor.h>
#endif
#ifdef WITH_UDISKS
#import <NXSystem/NXUDisksAdaptor.h>
#endif

// Volume events
NSString *NXDiskAppeared = @"NXDiskAppeared";
NSString *NXDiskDisappeared = @"NXDiskDisappeared";
NSString *NXVolumeAppeared = @"NXVolumeAppeared";
NSString *NXVolumeDisappeared = @"NXVolumeDisappeared";
NSString *NXVolumeMounted = @"NXVolumeMounted";
NSString *NXVolumeUnmounted = @"NXVolumeUnmounted";
// Operations
NSString *NXMediaOperationDidStart = @"NXMediaOperationDidStart";
NSString *NXMediaOperationDidUpdate = @"NXMediaOperationDidUpdate";
NSString *NXMediaOperationDidEnd = @"NXMediaOperationDidEnd";

//-----------------------------------------------------------------------
static id<MediaManager> adaptor;

@implementation NXMediaManager

+ (id<MediaManager>)defaultManager
{
  if (!adaptor)
    {
      [[NXMediaManager alloc] init];
    }
  return adaptor;
}

- (id)init
{
  if (!(self = [super init]))
    {
      return nil;
    }
  
#ifdef WITH_HAL
  adaptor = [[NXHALAdaptor alloc] init];
#endif

#ifdef WITH_UDISKS
  adaptor = [[NXUDisksAdaptor alloc] init];
#endif

  return self;
}

- (id<MediaManager>)adaptor
{
  return adaptor;
}

- (void)dealloc
{
  NSLog(@"NXMediaManager: dealloc");

  [adaptor release];
  
  [super dealloc];
}

@end
