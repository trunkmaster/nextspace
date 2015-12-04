/*
 * 
 */

#import <Foundation/Foundation.h>

// Device events
extern NSString *NXDeviceAdded;
extern NSString *NXDeviceRemoved;
extern NSString *NXDevicePropertyChanged;
extern NSString *NXDevicePropertyRemoved;
extern NSString *NXDevicePropertyAdded;
extern NSString *NXDeviceConditionChanged;

// Class which adopts <DeviceEventsAdaptor> protocol aimed to implement
// interaction with OS's method of getting information about devices and
// device events (add, remove, ).
@protocol DeviceEventsAdaptor
// For future use
@end

@interface NXDeviceManager : NSObject
{
}

+ (id)defaultManager;

@end
