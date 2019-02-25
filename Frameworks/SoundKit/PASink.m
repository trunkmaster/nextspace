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
  
  [super dealloc];
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

  vol = [NSMutableArray new];
  [vol removeAllObjects];
  for (int i = 0; i < info->volume.channels; i++) {
    v = [NSNumber numberWithUnsignedInteger:info->volume.values[i]];
    [vol addObject:v];
  }
  if (_channelVolumes) {
    [_channelVolumes release];
  }
  _channelVolumes = [[NSArray alloc] initWithArray:vol];
  [vol release];

  //
  _channelCount = info->volume.channels;
  _volumeSteps = info->n_volume_steps;
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
  if (_description) {
    [_description release];
  }
  _description = [[NSString alloc] initWithCString:info->description];
  
  if (_name) {
    [_name release];
  }
  _name = [[NSString alloc] initWithCString:info->name];

  // Ports
  [self updatePorts:info];

  // Volume
  [self updateVolume:info];

  _baseVolume = (NSUInteger)info->base_volume;

  free ((void *)info);

  return self;
}

// --- Actions
- (void)setMute:(BOOL)isMute
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

- (void)setVolume:(NSUInteger)v
{
  pa_cvolume *new_volume;

  new_volume = malloc(sizeof(pa_cvolume));
  pa_cvolume_init(new_volume);
  pa_cvolume_set(new_volume, _channelCount, v);
  pa_context_set_sink_volume_by_index(_context, _index, new_volume, NULL, self);
  free(new_volume);
}

@end
