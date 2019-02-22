#import <Foundation/Foundation.h>

@interface PASink : NSObject
{
}

@property (readonly) NSUInteger index;
@property (readonly) NSString   *description;
@property (readonly) NSString   *name;

@property (readonly) NSUInteger cardIndex;
@property (readonly) NSArray    *ports;
@property (readonly) NSString   *activePort;
@property (readonly) NSArray    *volume;
@property (readonly) NSUInteger baseVolume;

- (id)updateWithValue:(NSValue *)value;

@end
