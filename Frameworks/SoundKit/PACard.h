#import <Foundation/Foundation.h>

@interface PACard : NSObject
{
}

@property (readonly) NSUInteger index;
@property (readonly) NSString   *name;

@property (readonly) NSArray    *outProfiles;
@property (readonly) NSArray    *inProfiles;
@property (readonly) NSString   *activeProfile;

- (id)updateWithValue:(NSValue *)value;

@end
