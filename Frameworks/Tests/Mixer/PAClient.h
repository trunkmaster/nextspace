#import <Foundation/Foundation.h>

@interface PAClient : NSObject
{
  const pa_client__info *info;
}

- (id)updateWithValue:(NSValue *)value;

- (NString *)name;

- (NSArray *)volumes;
- (void)setVolume:(NSArray *)volumes;

- (CGFloat)balance;
- (void)setBalance:(CGFloat)bal;

- (BOOL)isMute;
- (void)setIsMute:(BOOL)isMute;

@end
