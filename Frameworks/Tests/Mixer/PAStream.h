#import <Foundation/Foundation.h>

#include <pulse/pulseaudio.h>
#include <pulse/ext-stream-restore.h>

@interface PAStream : NSObject
{
  // const pa_ext_stream_restore_info *info;
}

@property (readonly) NSString *name;
@property (assign) NSMutableArray *volumes;
@property (assign, getter=isMute) BOOL mute;

- (id)updateWithValue:(NSValue *)value;

// - (NSString *)name;
- (NSString *)visibleNameForClients:(NSArray *)clientList;

// - (NSArray *)volumes;
// - (void)setVolume:(NSArray *)volumes;

// - (BOOL)isMute;
// - (void)setMute:(BOOL)isMute;

@end
