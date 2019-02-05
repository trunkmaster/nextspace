#import "PulseAudio.h"
#import "PACard.h"

@implementation PACard

- (void)dealloc
{
  if (_name) {
    [_name release];
  }
  if (_outProfiles) {
    [_outProfiles release];
  }
  if (_inProfiles) {
    [_inProfiles release];
  }
  
  [super dealloc];
}

- (id)updateWithValue:(NSValue *)val
{
  const pa_card_info *info;
  NSString           *profileType;
  NSMutableArray     *outProfs;
  NSMutableArray     *inProfs;
  
  // Convert PA structure into NSDictionary
  info = malloc(sizeof(const pa_card_info));
  [val getValue:(void *)info];

  _index = info->index;
  
  if (_name) {
    [_name release];
  }
  _name = [[NSString alloc] initWithCString:info->name];

  if (info->n_profiles > 0) {
    outProfs = [NSMutableArray new];
    inProfs = [NSMutableArray new];
    
    for (int i = 0; i < info->n_profiles; i++) {
      profileType = [[[NSString stringWithCString:info->profiles2[i]->name]
                       componentsSeparatedByString:@":"] objectAtIndex:0];
      if ([profileType isEqualToString:@"output"]) {
        [outProfs addObject:[NSString stringWithCString:info->profiles2[i]->description]];
      }
      else {
        [inProfs addObject:[NSString stringWithCString:info->profiles2[i]->description]];
      }
    }
    
    if ([outProfs count] > 0) {
      if (_outProfiles) {
        [_outProfiles release];
      }
      _outProfiles = [[NSArray alloc] initWithArray:outProfs];
      [outProfs release];
    }
    if ([inProfs count] > 0) {
      if (_inProfiles) {
        [_inProfiles release];
      }
      _inProfiles = [[NSArray alloc] initWithArray:inProfs];
      [inProfs release];
    }
  }

  if (_activeProfile)
    [_activeProfile release];
  if (info->active_profile != NULL) {
    _activeProfile = [[NSString alloc] initWithCString:info->active_profile->description];
  }
  else {
    _activeProfile = nil;
  }

 free ((void *)info);

  return self;
}

@end
