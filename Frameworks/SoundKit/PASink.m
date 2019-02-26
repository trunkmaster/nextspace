#import "PASink.h"

@implementation PASink

- (void)dealloc
{
  if (_description) {
    [_description release];
  }
  if (_name) {
    [_name release];
  }
  if (_activePort) {
    [_activePort release];
  }
  
  free(channel_map);
  
 [super dealloc];
}

- (id)init
{
  self = [super init];
  channel_map = NULL;
  return self;
}

// --- Initialize and update
- (void)updatePorts:(const pa_sink_info *)info
{
  NSMutableArray *ports;
    
  if (info->n_ports > 0) {
    ports = [NSMutableArray new];
    for (unsigned i = 0; i < info->n_ports; i++) {
      [ports addObject:[NSString stringWithCString:info->ports[i]->description]];
    }
    if (_ports) {
      [_ports release];
    }
    _ports = [[NSArray alloc] initWithArray:ports];
    [ports release];
  }

  if (_activePort) {
    [_activePort release];
  }
  if (info->active_port != NULL) {
    _activePort = [[NSString alloc] initWithCString:info->active_port->description];
  }
  else {
    _activePort = nil;
  }
}

- (void)updateVolume:(const pa_sink_info *)info
{
  NSMutableArray *vol;
  NSNumber       *v;
  BOOL           isVolumeChanged = NO;
  CGFloat        balance;

  if (_channelVolumes == nil) {
    isVolumeChanged = YES;
  }
  
  balance = pa_cvolume_get_balance(&info->volume, &info->channel_map);
  fprintf(stderr, "[SoundKit] Sink balance: %f\n", balance);
  if (_balance != balance) {
    self.balance = balance;
  }
  
  vol = [NSMutableArray new];
  for (int i = 0; i < info->volume.channels; i++) {
    v = [NSNumber numberWithUnsignedInteger:info->volume.values[i]];
    [vol addObject:v];
    if (isVolumeChanged == NO && [_channelVolumes[i] isEqualToNumber:v] == NO) {
      isVolumeChanged = YES;
    }
  }
  if (isVolumeChanged != NO) {
    if (_channelVolumes) {
      [_channelVolumes release];
    }
    self.channelVolumes = [[NSArray alloc] initWithArray:vol]; // KVO compliance
  }
  [vol release];

  //
  _volumeSteps = info->n_volume_steps;
  
  if (_baseVolume != (NSUInteger)info->base_volume) {
    self.baseVolume = (NSUInteger)info->base_volume;
  }  
}

- (void)updateChannels:(const pa_sink_info *)info
{
  _channelCount = info->volume.channels;
  
  // Channel map
  if (channel_map) {
    free(channel_map);
  }
  channel_map = malloc(sizeof(pa_channel_map));
  pa_channel_map_init(channel_map);
  channel_map->channels = info->channel_map.channels;
  for (int i = 0; i < channel_map->channels; i++) {
    channel_map->map[i] = info->channel_map.map[i];
  }
}

- (id)updateWithValue:(NSValue *)val
{
  const pa_sink_info *info;
  NSMutableArray     *ports, *vol;
  
  // Convert PA structure into NSDictionary
  info = malloc(sizeof(const pa_sink_info));
  [val getValue:(void *)info];

  // Indexes
  _index = info->index;
  _cardIndex = info->card;

  // Name and description
  if (_description == nil) {
    _description = [[NSString alloc] initWithCString:info->description];
  }
  
  if (_name == nil) {
    _name = [[NSString alloc] initWithCString:info->name];
  }

  // Ports
  [self updatePorts:info];

  // Volume
  [self updateVolume:info];

  if (_mute != (BOOL)info->mute) {
    self.mute = (BOOL)info->mute;
  }

  if (channel_map == NULL || pa_channel_map_equal(channel_map, &info->channel_map)) {
    [self updateChannels:info];
  }

  free ((void *)info);

  return self;
}

// --- Actions
- (void)applyMute:(BOOL)isMute
{
  pa_context_set_sink_mute_by_index(_context, _index, (int)isMute, NULL, self);
}

- (NSUInteger)volume
{
  NSUInteger v, i;

  for (i = 0, v = 0; i < _channelCount; i++) {
    if ([_channelVolumes[i] unsignedIntegerValue] > v)
      v = [_channelVolumes[i] unsignedIntegerValue];
  }
  
  return v;
}

- (void)applyVolume:(NSUInteger)v
{
  pa_cvolume *new_volume;

  new_volume = malloc(sizeof(pa_cvolume));
  pa_cvolume_init(new_volume);
  pa_cvolume_set(new_volume, _channelCount, v);
  
  pa_context_set_sink_volume_by_index(_context, _index, new_volume, NULL, self);
  
  free(new_volume);
}

- (void)applyBalance:(CGFloat)balance
{
  pa_cvolume *volume;

  volume = malloc(sizeof(pa_cvolume));
  pa_cvolume_init(volume);
  pa_cvolume_set(volume, _channelCount, self.volume);
  
  pa_cvolume_set_balance(volume, channel_map, balance);
  pa_context_set_sink_volume_by_index(_context, _index, volume, NULL, self);
  
  free(volume);
}

@end
