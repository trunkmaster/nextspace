#import "PAClient.h"
#import "PAStream.h"
#import "PASink.h"
#import "PASinkInput.h"

/*
typedef struct pa_sink_input_info {
  // Index of the sink input
  uint32_t index;
  // Name of the sink input
  const char *name;

  // Index of the client this sink input belongs to, or PA_INVALID_INDEX
  uint32_t client;
  // Index of the connected sink
  uint32_t sink;
  // Stream muted
  int mute;
  // Stream corked
  int corked;
  
  // The sample specification of the sink input.
  pa_sample_spec sample_spec;
  // The resampling method used by this sink input.
  const char *resample_method;
  
  // Channel map
  pa_channel_map channel_map;
  // Stream has volume. 
  // If not set, then the meaning of this struct's volume member is unspecified.
  int has_volume;
  // The volume can be set. 
  // If not set, the volume can still change even though clients can't control the volume.
  int volume_writable;
  // The volume of this sink input.
  pa_cvolume volume;
  
  // Latency due to buffering in sink input, see pa_timing_info for details.
  pa_usec_t buffer_usec;
  // Latency of the sink device, see pa_timing_info for details.
  pa_usec_t sink_usec;

  // Index of the module this sink input belongs to, or PA_INVALID_INDEX
  uint32_t owner_module;
  // Driver name
  const char *driver;
  // Property list
  pa_proplist *proplist;
  // Stream format information.
  pa_format_info *format;
} pa_sink_input_info;
*/

@implementation PASinkInput

- (void)dealloc
{
  if (_name)
    [_name release];
  if (_volumes)
    [_volumes release];
  [super dealloc];
}

- (id)updateWithValue:(NSValue *)val
{
  pa_sink_input_info *info = NULL;
  NSMutableArray *vol;
  NSNumber *v;
  
  info = malloc(sizeof(const pa_sink_input_info));
  [val getValue:info];

  if (_name)
    [_name release];
  _name = [[NSString alloc] initWithCString:info->name];

  _index = info->index;
  _clientIndex = info->client;
  _sinkIndex = info->sink;
  _mute = info->mute;
  _corked = info->corked;

  if (info->has_volume) {
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
  }
  
  free((void *)info);

  return self;
}

// TODO
- (NSString *)nameForClients:(NSArray *)clientList
                     streams:(NSArray *)streamList
{
  NSString *clientName = @"";
  NSString *streamName = @"";
  
  if (_clientIndex == PA_INVALID_INDEX) {
    NSLog(@"SinkInput `%@` doesn't belong to any client.\n", _name);
    return nil;
  }
  else { // get client name by index
    for (PAClient *c in clientList) {
      if (c.index == _clientIndex) {
        clientName = c.name;
      }
    }
  }

  if (clientName) { // get stream name by name
    for (PAStream *s in streamList) {
      if ([[s clientName] isEqualToString:clientName]) {
        streamName = s.name;
      }
    }
  }

  return [NSString stringWithFormat:@"%@ : %@",
                   clientName, _name];
}

- (void)setVolumes:(NSArray *)vol
{
}

- (void)setMute:(BOOL)isMute
{
  // TODO: call PA function
  // pa_operation* pa_context_set_sink_input_mute(pa_context *c,
  //                                              uint32_t idx,
  //                                              int mute,
  //                                              pa_context_success_cb_t cb,
  //                                              void *userdata);
  pa_context_set_sink_input_mute(_context, _index, isMute, NULL, NULL);
}

@end
