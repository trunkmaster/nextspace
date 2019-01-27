#import <Foundation/Foundation.h>

#import "PulseAudio.h"

@interface PAClient : NSObject
{
  const pa_client_info *info;
}

- (id)updateWithValue:(NSValue *)value;

- (NSString *)name;
- (NSUInteger)index;

@end
