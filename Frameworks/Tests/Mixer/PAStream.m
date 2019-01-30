#import "PulseAudio.h"
#import "PAClient.h"
#import "PAStream.h"

@implementation PAStream

- (void)dealloc
{
  [_volumes release];
  [super dealloc];
}

- init
{
  [super init];
  _volumes = [[NSMutableArray alloc] init];
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
  [_volumes removeAllObjects];
  for (int i = 0; i < info->volume.channels; i++) {
    v = [NSNumber numberWithUnsignedInteger:info->volume.values[i]];
    [_volumes addObject:v];
  }
  _mute = info->mute ? YES : NO;

  free((void *)info);

  return self;
}

- (NSString *)clientName
{
  NSArray *comps = [_name componentsSeparatedByString:@":"];

  if ([comps count] > 1) {
    return [comps objectAtIndex:1];
  }

  return nil;
}

- (NSString *)visibleNameForClients:(NSArray *)clientList
{
  // NSString *name = [NSString stringWithCString:info->name];
  NSString *name;
  NSArray  *comps;
  
  if ([_name isEqualToString:@"sink-input-by-media-role:event"]) {
    return @"System Sounds";
  }
  else {
    if ((name = [self clientName]) != nil) {
      for (PAClient *cl in clientList) {
        if ([[cl name] isEqualToString:name]) {
          return name;
        }
      }
    }
  }

  return nil;
}

// - (NSArray *)volumes
// {
  // NSMutableArray *volumes = [NSMutableArray new];
  // NSNumber *v;
  
  // for (int i = 0; i < info->volume.channels; i++) {
  //   v = [NSNumber numberWithUnsignedInteger:info->volume.values[i]];
  //   [volumes addObject:v];
  // }

//   return volumes;
// }
// TODO
// - (void)setVolumes:(NSArray *)volumes
// {
// }

// - (BOOL)isMute
// {
//   return NO;
// }
// - (void)setMute:(BOOL)isMute
// {
// }

@end
