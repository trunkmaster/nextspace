#import "PulseAudio.h"
#import "PAClient.h"
#import "PASink.h"
#import "PASinkInput.h"

@implementation PASinkInput

- (void)dealloc
{
  free((void *)info);
  [super dealloc];
}

- init
{
  [super init];
  info = malloc(sizeof(const pa_sink_input_info));
  return self;
}

- (id)updateWithValue:(NSValue *)val
{
  void *info_from_value = NULL;
  
  // Convert PA structure into NSDictionary
  if (info != NULL) {
    free((void *)info);
    info = malloc(sizeof(const pa_sink_input_info));
  }
  
  info_from_value = malloc(sizeof(const pa_sink_input_info));
  [val getValue:info_from_value];
  
  memcpy((void *)info, info_from_value, sizeof(const pa_sink_input_info));
  free(info_from_value);

  return self;
}

- (NSString *)name
{
  return [NSString stringWithCString:info->name];
}

// TODO
- (NSString *)nameForClients:(NSArray *)clientList
                       sinks:(NSArray *)sinkList
{
  NSUInteger index = [self index];

  // Get client name by index
  // Get sink name by index
  //

  return nil;
}

- (NSUInteger)index
{
  return info->index;
}
- (NSUInteger)clientIndex
{
  return info->client;
}
- (NSUInteger)sinkIndex
{
  return info->sink;
}

- (BOOL)isMute
{
  return info->mute;
}
- (void)setMute:(BOOL)isMute
{
}
- (BOOL)isCorked
{
  return info->corked;
}
- (void)setCorked:(BOOL)isCorked
{
}

@end
