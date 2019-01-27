#import <Foundation/Foundation.h>

@interface PASinkInput : NSObject
{
  const pa_sink_input_info *info;
}

// @property (readonly) NSString *name;
// @property (readonly) NSUInteger index;
// @property (readonly) NSUInteger clientIndex;
// @property (readonly) NSUInteger sinkIndex;

// @property BOOL isMute;
// @property BOOL isCorked;

- (id)updateWithValue:(NSValue *)val;

- (NSString *)name;

- (NSUInteger)index;
- (NSUInteger)clientIndex;
- (NSUInteger)sinkIndex;

- (BOOL)isMute;
- (void)setMute:(BOOL)isMute;

- (BOOL)isCorked;
- (void)setCorked:(BOOL)isCorked;

@end
