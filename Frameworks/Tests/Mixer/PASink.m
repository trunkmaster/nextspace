#import "PulseAudio.h"
#import "PASink.h"

@implementation PASink

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

- (void)updateWithValue:(NSValue *)val
{
  // Convert PA structure into NSDictionary
  if (info != NULL) {
    free((void *)info);
  }
  info = malloc(sizeof(const pa_sink_info));
  [val getValue:(void *)info];
}

- (NString *)name
{
  return [NSString stringWithCString:info->name];
}

@end
