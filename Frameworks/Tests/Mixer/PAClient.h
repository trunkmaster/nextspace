#import <Foundation/Foundation.h>

#import "PulseAudio.h"

@interface PAClient : NSObject
{
}

@property (readonly) NSString  *name;
@property (readonly) NSUInteger index;

- (id)updateWithValue:(NSValue *)value;

@end
