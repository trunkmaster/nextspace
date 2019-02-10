#import <pulse/pulseaudio.h>
#import "PAClient.h"

/*
typedef struct pa_client_info {
  uint32_t    index;        // Index of this client
  const char  *name;        // Name of this client
  uint32_t    owner_module; // Index of the owning module, or PA_INVALID_INDEX.
  const char  *driver;      // Driver name
  pa_proplist *proplist;    // Property list
} pa_client_info;
*/

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
