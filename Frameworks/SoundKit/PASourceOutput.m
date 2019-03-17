/* -*- mode: objc -*- */
//
// Project: SoundKit framework.
//
// Copyright (C) 2019 Sergii Stoian
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
// 
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free
// Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
//

#import "PAClient.h"
#import "PAStream.h"
#import "PASource.h"
#import "PASourceOutput.h"

// typedef struct pa_source_output_info {
//   uint32_t		index;
//   const char		*name;
//
//   uint32_t		client;
//   uint32_t		source;
//   int			 mute;
//   int			corked;
//
//   pa_sample_spec	sample_spec;
//   const char		*resample_method;
//  
//   pa_channel_map	channel_map;
//   int			has_volume;
//   int			volume_writable;
//   pa_cvolume		volume;
//  
//   pa_usec_t		buffer_usec;
//   pa_usec_t		source_usec;
//  
//   uint32_t		owner_module;
//   const char		*driver;
//   pa_proplist		*proplist;
//   pa_format_info	*format;
// } pa_source_output_info;

@implementation PASourceOutput

- (void)dealloc
{
  if (_name) {
    [_name release];
  }
  if (_channelVolumes) {
    [_channelVolumes release];
  }
  [super dealloc];
}

- (void)_updateVolume:(const pa_source_output_info *)info
{
  NSMutableArray *vol;
  NSNumber       *v;
  BOOL           isVolumeChanged = NO;
  CGFloat        balance;

  _hasVolume = info->has_volume;
  _isVolumeWritable = info->volume_writable;

  if (_channelVolumes == nil) {
    isVolumeChanged = YES;
  }
  
  balance = pa_cvolume_get_balance(&info->volume, &info->channel_map);
  fprintf(stderr, "[SoundKit] Source Output balance: %f\n", balance);
  if (_balance != balance) {
    self.balance = balance;
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
- (void)_updateChannels:(const pa_source_output_info *)info
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
- (id)updateWithValue:(NSValue *)val
{
  pa_source_output_info *info = NULL;
  
  info = malloc(sizeof(const pa_source_output_info));
  [val getValue:info];

  if (_name)
    [_name release];
  _name = [[NSString alloc] initWithCString:info->name];

  _index = info->index;
  _clientIndex = info->client;
  _sourceIndex = info->source;
  
  _mute = info->mute;
  _corked = info->corked;

  [self _updateVolume:info];
  [self _updateChannels:info];
  
  free((void *)info);

  return self;
}

- (NSUInteger)volume
{
  NSUInteger v, i;

  for (i = 0, v = 0; i < _channelCount; i++) {
    if ([_channelVolumes[i] unsignedIntegerValue] > v)
      v = [_channelVolumes[i] unsignedIntegerValue];
  }
  
  return v;
}
- (void)applyVolume:(NSUInteger)v
{
  pa_cvolume *new_volume;

  new_volume = malloc(sizeof(pa_cvolume));
  pa_cvolume_init(new_volume);
  pa_cvolume_set(new_volume, _channelCount, v);
  
  pa_context_set_source_output_volume(_context, _index, new_volume, NULL, self);
  
  free(new_volume);
}
- (void)applyBalance:(CGFloat)balance
{
  pa_cvolume *volume;

  volume = malloc(sizeof(pa_cvolume));
  pa_cvolume_init(volume);
  pa_cvolume_set(volume, _channelCount, self.volume);
  
  pa_cvolume_set_balance(volume, channel_map, balance);
  pa_context_set_source_output_volume(_context, _index, volume, NULL, self);
  
  free(volume);
}
- (void)applyMute:(BOOL)isMute
{
  pa_context_set_source_output_mute(_context, _index, isMute, NULL, NULL);
}

@end
