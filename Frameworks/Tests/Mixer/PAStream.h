#import <Foundation/Foundation.h>

@interface PAStream : NSObject
{
  const pa_ext_stream_restore_info *info;

  NSValue *value;
}

- (id)initWithValue:(NSValue *)val;

- (NString *)name;

- (NSArray *)volumes;
- (void)setVolume:(NSArray *)volumes;

- (CGFloat)balance;
- (void)setBalance:(CGFloat)bal;

- (BOOL)isMute;
- (void)setIsMute:(BOOL);

@end
