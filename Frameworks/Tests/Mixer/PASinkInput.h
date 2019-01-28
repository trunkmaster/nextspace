#import <Foundation/Foundation.h>

@interface PASinkInput : NSObject
{
}

@property (readonly) NSString *name;
@property (readonly) NSUInteger index;
@property (readonly) NSUInteger clientIndex;
@property (readonly) NSUInteger sinkIndex;

@property (nonatomic,setter=setMute:) BOOL mute;
@property (readonly) BOOL corked;

- (id)updateWithValue:(NSValue *)val;
- (NSString *)nameForClients:(NSArray *)clientList
                       sinks:(NSArray *)sinkList;

// - (NSString *)name;

// - (NSUInteger)index;
// - (NSUInteger)clientIndex;
// - (NSUInteger)sinkIndex;

// - (BOOL)isMute;
// - (void)setMute:(BOOL)isMute;

// - (BOOL)isCorked;
// - (void)setCorked:(BOOL)isCorked;

@end
