#import <Foundation/Foundation.h>

@interface PASinkInput : NSObject
{
  NSMutableArray *volumes;
}

@property (readonly) NSString *name;
@property (readonly) NSUInteger index;
@property (readonly) NSUInteger clientIndex;
@property (readonly) NSUInteger sinkIndex;

@property (nonatomic,setter=setMute:) BOOL mute;
@property (readonly) BOOL corked;

@property (readonly) BOOL hasVolume;
@property (readonly) BOOL isVolumeWritable;
// @property (nonatomic) NSMutableArray *volume;


- (id)updateWithValue:(NSValue *)val;
- (NSString *)nameForClients:(NSArray *)clientList
                     streams:(NSArray *)streamList;

@end
