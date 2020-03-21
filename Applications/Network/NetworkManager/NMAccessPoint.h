/* -*- mode: objc -*- */
#import <Foundation/Foundation.h>

/* org.freedesktop.NetworkManager.AccessPoint */
@protocol NMAccessPoint

@property (readonly) NSArray  *Ssid;
@property (readonly) NSString *HwAddress;
@property (readonly) NSNumber *Strength;
@property (readonly) NSNumber *Flags;
@property (readonly) NSNumber *MaxBitrate;
@property (readonly) NSNumber *RsnFlags;
@property (readonly) NSNumber *Mode;
@property (readonly) NSNumber *WpaFlags;
@property (readonly) NSNumber *Frequency;
@property (readonly) NSNumber *LastSeen;

@end
