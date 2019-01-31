#import "PulseAudio.h"
#import "PAClient.h"
#import "PAStream.h"

/*
typedef struct pa_ext_stream_restore_info {
  const char     *name;
  int            mute;
  pa_channel_map channel_map;
  pa_cvolume     volume;
  const char     *device;
} pa_ext_stream_restore_info;
*/

@implementation PAStream

- (void)dealloc
{
  [volumes release];
  [super dealloc];
}

- init
{
  [super init];
  volumes = [[NSMutableArray alloc] init];
  return self;
}

- (id)updateWithValue:(NSValue *)value
{
  const pa_ext_stream_restore_info *info;
  NSNumber *v;
  
  info = malloc(sizeof(const pa_ext_stream_restore_info));
  [value getValue:(void *)info];

  if (_name) [_name release];
  _name = [[NSString alloc] initWithCString:info->name];
  
  [volumes removeAllObjects];
  for (int i = 0; i < info->volume.channels; i++) {
    v = [NSNumber numberWithUnsignedInteger:info->volume.values[i]];
    [volumes addObject:v];
  }
  _mute = info->mute ? YES : NO;

  free((void *)info);

  return self;
}

- (NSString *)clientName
{
  NSArray *comps = [_name componentsSeparatedByString:@":"];

  if ([comps count] > 1) {
    return comps[1];
  }

  return nil;
}

- (NSString *)typeName
{
  NSArray *comps = [_name componentsSeparatedByString:@":"];

  if ([comps count] > 1) {
    return comps[0];
  }

  return nil;
}

- (NSArray *)volumes
{
  return volumes;
}
//TODO
- (void)setVolumes:(NSArray *)volumes
{
}

@end
