#import <Foundation/Foundation.h>

@interface PAClient : NSObject
{
}

@property (readonly) NSString  *name;
@property (readonly) NSUInteger index;

- (id)updateWithValue:(NSValue *)value;

@end
