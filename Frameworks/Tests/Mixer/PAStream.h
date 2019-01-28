#import <Foundation/Foundation.h>

#include <pulse/pulseaudio.h>
#include <pulse/ext-stream-restore.h>

@interface PAStream : NSObject
{
}

@property (readonly) NSString *name;
@property (assign) NSMutableArray *volumes;
@property (assign,getter=isMute) BOOL mute;

- (id)updateWithValue:(NSValue *)value;

- (NSString *)visibleNameForClients:(NSArray *)clientList;

@end
