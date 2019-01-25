#import "PulseAudio.h"
#import "PAClient.h"
@import "PASink.h"

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
  info = NULL;
  return self;
}

- (id)updateWithValue:(NSValue *)val
{
  // Convert PA structure into NSDictionary
  if (info != NULL) {
    free((void *)info);
  }
  info = malloc(sizeof(const pa_sink_input_info));
  [val getValue:(void *)info];

  return self;
}

- (NString *)name
{
  return [NSString stringWithCString:info->name];
}

- (NSString *)nameForClients:(NSArray *)clientList
                       sinks:(NSArray *)sinkList
{
  NSUInteger index = [self index];

  // Get client name by index
  // Get sink name by index
  // 
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
