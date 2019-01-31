#import <Foundation/Foundation.h>

#include <pulse/pulseaudio.h>
#include <pulse/ext-stream-restore.h>

@interface PAStream : NSObject
{
  NSMutableArray *volumes;
}

@property (readonly) NSString *name;
// @property (assign) NSMutableArray *volumes;
@property (assign,getter=isMute) BOOL mute;

- (id)updateWithValue:(NSValue *)value;

- (NSString *)clientName;
- (NSString *)typeName;

- (NSArray *)volumes;
- (void)setVolumes:(NSArray *)volumes;

@end
