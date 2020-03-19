/* -*- mode: objc -*- */
#import <Foundation/Foundation.h>

// org.freedesktop.DBus.Peer
@protocol DBusPeer
- (NSString*)GetMachineId;
- (void)Ping;
@end
