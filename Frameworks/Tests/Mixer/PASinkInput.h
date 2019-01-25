#import <Foundation/Foundation.h>

@interface PASinkInput : NSObject
{
  const pa_sink_input_info *info;
}

- (id)updateWithValue:(NSValue *)val;

- (NString *)name;

- (NSUInteger)index;
- (NSUInteger)clientIndex;
- (NSUInteger)sinkIndex;

- (BOOL)isMute;
- (void)setMute:(BOOL)isMute;

- (BOOL)isCorked
- (void)setCorked:(BOOL)isCorked;

@end
