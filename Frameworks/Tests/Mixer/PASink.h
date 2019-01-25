#import <Foundation/Foundation.h>

@interface PASink : NSObject
{
  const pa_sink_info *info;
}

- (id)updateWithValue:(NSValue *)value;

- (NString *)name;

@end
