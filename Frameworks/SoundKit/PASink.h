#import <Foundation/Foundation.h>

@interface PASink : NSObject
{
}

@property (readonly) NSUInteger index;
@property (readonly) NSString   *description;
@property (readonly) NSString   *name;

@property (readonly) NSUInteger cardIndex;
@property (readonly) NSArray    *portsDesc;
@property (readonly) NSString   *activePortDesc;
@property (readonly) NSArray    *volume;

- (id)updateWithValue:(NSValue *)value;

@end
