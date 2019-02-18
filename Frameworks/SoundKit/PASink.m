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
  if (_activePortDesc) {
    [_activePortDesc release];
  }
  
  [super dealloc];
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
  if (info->n_ports > 0) {
    ports = [NSMutableArray new];
    for (unsigned i = 0; i < info->n_ports; i++) {
      [ports addObject:[NSString stringWithCString:info->ports[i]->description]];
    }
    if (_portsDesc) {
      [_portsDesc release];
    }
    _portsDesc = [[NSArray alloc] initWithArray:ports];
    [ports release];
  }

  if (_activePortDesc) {
    [_activePortDesc release];
  }
  if (info->active_port != NULL) {
    _activePortDesc = [[NSString alloc] initWithCString:info->active_port->description];
  }
  else {
    _activePortDesc = nil;
  }

  // Volume
  NSNumber *v;
  
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

 free ((void *)info);

  return self;
}

@end
