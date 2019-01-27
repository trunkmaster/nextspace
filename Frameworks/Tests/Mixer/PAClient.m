#import "PulseAudio.h"
#import "PAClient.h"

@implementation PAClient

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

- (id)updateWithValue:(NSValue *)value
{
  // Convert PA structure into NSDictionary
  if (info != NULL) {
    free((void *)info);
  }
  info = malloc(sizeof(const pa_client_info));
  [value getValue:(void *)info];

  return self;
}

- (NSString *)name
{
  if (!strcmp(info->name, "sink-input-by-media-role:event"))
    return @"System Sounds";
  else
    return [NSString stringWithCString:info->name];
}

- (NSUInteger)index
{
  return info->index;
}

@end
