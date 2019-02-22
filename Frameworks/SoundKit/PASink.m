#import <pulse/pulseaudio.h>
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
  if (_volume) {
    [_volume release];
  }
  _volume = [[NSArray alloc] initWithArray:vol];
  [vol release];
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

@end
