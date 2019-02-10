#include <pulse/pulseaudio.h>
#include <pulse/ext-stream-restore.h>

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
  [_volumes release];
  [super dealloc];
}

- (id)updateWithValue:(NSValue *)value
{
  const pa_ext_stream_restore_info *info;
  NSMutableArray *vol;
  NSNumber *v;
  
  info = malloc(sizeof(const pa_ext_stream_restore_info));
  [value getValue:(void *)info];

  if (_name)
    [_name release];
  _name = [[NSString alloc] initWithCString:info->name];
  if (_deviceName)
    [_deviceName release];
  _deviceName = [[NSString alloc] initWithCString:info->device];
  
  if (_volumes)
    [_volumes release];
  vol = [NSMutableArray new];
  for (int i = 0; i < info->volume.channels; i++) {
    v = [NSNumber numberWithUnsignedInteger:info->volume.values[i]];
    [vol addObject:v];
  }
  if ([vol count] > 0) {
    _volumes = [[NSArray alloc] initWithArray:vol];
  }
  [vol release];
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

@end
