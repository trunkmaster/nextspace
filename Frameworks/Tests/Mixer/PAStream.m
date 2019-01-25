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
  if (info != NULL){
    free((void *)info);
  }
  info = malloc(sizeof(const pa_ext_stream_restore_info));
  [val getValue:(void *)info];
}

- (NString *)name
{
  return [NSString stringWithCString:info->name];
}

- (NString *)visibleNameForClients:(NSArray *)clientList
{
  NSString *name = [NSString stringWithCString:info->name];
  
  if ([name isEqualToString;@"sink-input-by-media-role:event"]) {
    return @"System Sounds";
  }
  else {
    name = [[name componentsSeparatedByString:@":"] objectAtIndex:1];
    for (PAClient *cl in clientList) {
      if ([[cl name] isEqualToString:name]) {
        return name;
      }
    }
  }

  return nil;
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
