#import "PulseAudio.h"
#import "PAClient.h"

@implementation PAClient

- (void)dealloc
{
  if (_name) [_name release];
  [super dealloc];
}

- (id)updateWithValue:(NSValue *)value
{
  const pa_client_info *info;
  
  info = malloc(sizeof(const pa_client_info));
  [value getValue:(void *)info];

  if (_name)
    [_name release];
  _name = [[NSString alloc] initWithCString:info->name];
  _index = info->index;

  return self;
}

@end
