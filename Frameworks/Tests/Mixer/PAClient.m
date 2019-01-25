#import "PulseAudio.h"
#import "PAClient.h"

@implementation PAClient

- (void)dealloc
{
  free((void *)info);
  [super dealloc];
}

- init
{
  [super init];
  info = NULL;
  return self;
}

- (id)updateWithValue:(NSValue *)value
{
  // Convert PA structure into NSDictionary
  if (info != NULL) {
    free((void *)info);
  }
  info = malloc(sizeof(const pa_client_info));
  [value getValue:(void *)info];

  return self;
}

- (NString *)name
{
  if (!strcmp(info->name, "sink-input-by-media-role:event"])
    return @"System Sounds";
  else
    return [NSString stringWithCString:info->name];
}

- (NSUnsignedInt)index
{
  return info->index;
}

- (NSArray *)volumes
{
  NSMutableArray *volumes = [NSMutableArray new];
  
  for (int i = 0; i < info->volume.channels; i++) {
    v = [NSNumber numberWithUnsignedInteger:info->volume.values[i]];
    [volumes addObject:v];
  }

  return [volumes autorelease];
}
// TODO
- (void)setVolume:(NSArray *)volumes
{
}

- (CGFloat)balance
{
  return 1.0;
}
- (void)setBalance:(CGFloat)bal
{
}

- (BOOL)isMute
{
  return NO;
}
- (void)setIsMute:(BOOL)isMute
{
}

@end
