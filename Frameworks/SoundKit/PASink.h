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

@property (assign) NSUInteger channelCount;
@property (assign) NSUInteger volumeSteps;
@property (assign) NSUInteger baseVolume;
@property (assign) NSArray    *channelVolumes;

@property (assign,nonatomic) BOOL mute;

- (id)updateWithValue:(NSValue *)value;

- (NSUInteger)volume;
- (void)setVolume:(NSUInteger)v;
- (void)setMute:(BOOL)isMute;

@end
