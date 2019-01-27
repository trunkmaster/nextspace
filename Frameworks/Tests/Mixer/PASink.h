#import <Foundation/Foundation.h>

#import "PulseAudio.h"

@interface PASink : NSObject
{
  const pa_sink_info *info;
}

- (id)updateWithValue:(NSValue *)value;

- (NSString *)name;

@end
