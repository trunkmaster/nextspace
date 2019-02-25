#import <pulse/pulseaudio.h>
#import <Foundation/Foundation.h>

@interface PASink : NSObject
{
}

@property (assign) pa_context   *context;

@property (readonly) NSUInteger index;
@property (readonly) NSString   *description;
@property (readonly) NSString   *name;

@property (readonly) NSUInteger cardIndex;
@property (readonly) NSArray    *ports;
@property (readonly) NSString   *activePort;

@property (readonly) NSUInteger channelCount;
@property (readonly) NSUInteger volumeSteps;
@property (readonly) NSUInteger baseVolume;
@property (readonly) NSArray    *channelVolumes;

@property (readonly) BOOL       mute;

- (id)updateWithValue:(NSValue *)value;

- (NSUInteger)volume;
- (void)setVolume:(NSUInteger)v;
- (void)setMute:(BOOL)isMute;

@end
