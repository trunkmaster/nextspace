#import <Foundation/Foundation.h>

@interface PAStream : NSObject
{
}

@property (readonly) NSString *name;
@property (readonly) NSString *deviceName;
@property (readonly) NSArray *volumes;
@property (readonly) BOOL mute;

- (id)updateWithValue:(NSValue *)value;

- (NSString *)clientName;
- (NSString *)typeName;

@end
