#import "PulseAudio.h"
#import "PAStream.h"

@implementation PAStream

- (void)dealloc
{
  free((void *)info);
  [super dealloc];
}

- (void)updateWithValue:(NSValue *)val
{
  // Convert PA structure into NSDictionary
  info = malloc(sizeof(const pa_ext_stream_restore_info));
  [val getValue:(void *)info];
}

- (NString *)name
{
  if (!strcmp(info->name, "sink-input-by-media-role:event"])
    return @"System Sounds";
  else
    return [NSString stringWithCString:info->name];
}

- (NSArray *)volumes
{
  NSMutableArray *volumes = [NSMutableArray new];
  
  for (int i = 0; i < info->volume.channels; i++) {
    v = [NSNumber numberWithUnsignedInteger:info->volume.values[i]];
    [volumes addObject:v];
  }

  return volumes;
}
// TODO
- (void)setVolume:(NSArray *)volumes
{
}

- (CGFloat)balance
{
}
- (void)setBalance:(CGFloat)bal
{
}

- (BOOL)isMute
{
}
- (void)setIsMute:(BOOL)
{
}

@end
