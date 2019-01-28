#import "PulseAudio.h"
#import "PAClient.h"
#import "PASink.h"
#import "PASinkInput.h"

@implementation PASinkInput

@synthesize mute = _mute;

- (void)dealloc
{
  if (_name)
    [_name release];
  [super dealloc];
}

- (id)updateWithValue:(NSValue *)val
{
   pa_sink_input_info *info = NULL;
  
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
  
  free((void *)info);

  return self;
}

// TODO
- (NSString *)nameForClients:(NSArray *)clientList
                       sinks:(NSArray *)sinkList
{
  // Get client name by index
  for (PAClient *c in clientList) {
    if (c.index == _clientIndex) {
      return c.name;
    }
  }
  // Get sink name by index
  //

  return nil;
}

- (void)setMute:(BOOL)isMute
{
  _mute = isMute;
  // TODO: call PA function
  // pa_operation* pa_context_set_sink_input_mute(pa_context *c,
  //                                              uint32_t idx,
  //                                              int mute,
  //                                              pa_context_success_cb_t cb,
  //                                              void *userdata);
}

@end
