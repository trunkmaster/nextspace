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

#include <pulse/ext-stream-restore.h>

#import "PAClient.h"
#import "PAStream.h"

/*
typedef struct pa_ext_stream_restore_info {
  const char     *name;
  int            mute;
  pa_channel_map channel_map;
  pa_cvolume     volume;
  const char     *device;
} pa_ext_stream_restore_info;
*/

@implementation PAStream

- (void)dealloc
{
  if (_channelVolumes) {
    [_channelVolumes release];
  }
  if (channel_map) {
    free(channel_map);
  }
  if (info_copy) {
    free(info_copy);
  }
 [super dealloc];
}

- (void)_updateVolume:(const pa_ext_stream_restore_info *)info
{
  NSMutableArray *vol;
  NSNumber       *v;
  BOOL           isVolumeChanged = NO;

  if (_channelVolumes == nil) {
    isVolumeChanged = YES;
  }
  
  vol = [NSMutableArray new];
  for (int i = 0; i < info->volume.channels; i++) {
    v = [NSNumber numberWithUnsignedInteger:info->volume.values[i]];
    [vol addObject:v];
    if (isVolumeChanged == NO && [_channelVolumes[i] isEqualToNumber:v] == NO) {
      isVolumeChanged = YES;
    }
  }
  if (isVolumeChanged != NO) {
    if (_channelVolumes) {
      [_channelVolumes release];
    }
    self.channelVolumes = [[NSArray alloc] initWithArray:vol];
  }
  [vol release];
}
- (void)_updateChannels:(const pa_ext_stream_restore_info *)info
{
  _channelCount = info->volume.channels;
  
  // Channel map
  if (channel_map) {
    free(channel_map);
  }
  channel_map = malloc(sizeof(pa_channel_map));
  pa_channel_map_init(channel_map);
  channel_map->channels = info->channel_map.channels;
  for (int i = 0; i < channel_map->channels; i++) {
    channel_map->map[i] = info->channel_map.map[i];
  }
}
- (id)updateWithValue:(NSValue *)value
{
  const pa_ext_stream_restore_info *info;
  NSMutableArray *vol;
  NSNumber *v;
  
  info = malloc(sizeof(const pa_ext_stream_restore_info));
  [value getValue:(void *)info];

  if (info_copy == NULL) {
    info_copy = malloc(sizeof(struct pa_ext_stream_restore_info));
  }
  memcpy(info_copy, info, sizeof(*info));

  /****/
  if (_name)
    [_name release];
  _name = [[NSString alloc] initWithCString:info->name];

  [self _updateVolume:info];
  [self _updateChannels:info];
  
  self.mute = info->mute ? YES : NO;
  /***/

  free((void *)info);

  return self;
}

- (NSString *)clientName
{
  NSArray *comps = [_name componentsSeparatedByString:@":"];

  if ([comps count] > 1) {
    return comps[1];
  }

  return nil;
}

- (NSString *)typeName
{
  NSArray *comps = [_name componentsSeparatedByString:@":"];

  if ([comps count] > 1) {
    return comps[0];
  }

  return nil;
}

- (NSUInteger)volume
{
  NSUInteger v, i;

  for (i = 0, v = 0; i < info_copy->volume.channels; i++) {
    if (info_copy->volume.values[i] > v)
      v = info_copy->volume.values[i];
  }
  
  return v;
}
- (void)applyVolume:(NSUInteger)volume
{
  for (NSUInteger i = 0; i < info_copy->volume.channels; i++) {
    info_copy->volume.values[i] = volume;
  }

  pa_ext_stream_restore_write(_context, PA_UPDATE_REPLACE, info_copy,
                              1, YES, NULL, NULL);
}
- (void)applyMute:(BOOL)isMute
{
  info_copy->mute = isMute;
  pa_ext_stream_restore_write(_context, PA_UPDATE_REPLACE, info_copy,
                              1, YES, NULL, NULL);
}


@end
