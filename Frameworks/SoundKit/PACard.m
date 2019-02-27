/* -*- mode: objc -*- */
/*
  Project: SoundKit framework.

  Copyright (C) 2019 Sergii Stoian

  This application is free software; you can redistribute it and/or
  modify it under the terms of the GNU General Public
  License as published by the Free Software Foundation; either
  version 2 of the License, or (at your option) any later version.

  This application is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  Library General Public License for more details.

  You should have received a copy of the GNU General Public
  License along with this library; if not, write to the Free
  Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

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
    
    for (unsigned i = 0; i < info->n_profiles; i++) {
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

- (void)applyActiveProfile:(NSString *)profileName
{
  const char *profile = [profileName cString];
  pa_context_set_card_profile_by_index(_context, _index, profile, NULL, self);
}

@end
