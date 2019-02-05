#import <Foundation/Foundation.h>

@interface PASinkInput : NSObject
{
}

@property (assign) pa_context   *context;

@property (readonly) NSString   *name;
@property (readonly) NSUInteger index;
@property (readonly) NSUInteger clientIndex;
@property (readonly) NSUInteger sinkIndex;

@property (readonly) BOOL mute;
@property (readonly) BOOL corked;

@property (readonly) BOOL    hasVolume;
@property (readonly) BOOL    isVolumeWritable;
@property (readonly) NSArray *volumes;


- (id)updateWithValue:(NSValue *)val;
- (NSString *)nameForClients:(NSArray *)clientList
                     streams:(NSArray *)streamList;

@end
