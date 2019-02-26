#import <pulse/pulseaudio.h>
#import <Foundation/Foundation.h>

@interface PASink : NSObject
{
  pa_channel_map *channel_map;
}

@property (assign) pa_context   *context;

@property (readonly) NSUInteger index;
@property (readonly) NSString   *description;
@property (readonly) NSString   *name;

@property (readonly) NSUInteger cardIndex;
@property (readonly) NSArray    *ports;
@property (readonly) NSString   *activePort;

// KVO-compliant
@property (assign) NSUInteger channelCount;
@property (assign) NSUInteger volumeSteps;
@property (assign) NSUInteger baseVolume;
@property (assign) CGFloat    balance;
@property (assign) NSArray    *channelVolumes;

@property (assign,nonatomic) BOOL mute;

- (id)updateWithValue:(NSValue *)value;

- (void)applyMute:(BOOL)isMute;
- (NSUInteger)volume;
- (void)applyVolume:(NSUInteger)v;
- (void)applyBalance:(CGFloat)balance;

@end
