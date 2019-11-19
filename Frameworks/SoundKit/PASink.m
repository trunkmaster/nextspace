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

#import "PASink.h"

@interface PASink ()
@property (assign) NSString   *activePort;
@property (assign) NSUInteger channelCount;
@property (assign) NSUInteger volumeSteps;
@property (assign) NSUInteger baseVolume;
@property (assign) CGFloat    balance;
@property (assign) NSArray    *channelVolumes;

@property (assign,nonatomic) BOOL mute;
@end

@implementation PASink

- (void)dealloc
{
  if (_description) {
    [_description release];
  }
  if (_name) {
    [_name release];
  }
  if (_activePort) {
    [_activePort release];
  }
  if (_ports){
    [_ports release];
  }
  if (_channelVolumes){
    [_channelVolumes release];
  }
  
  free(_channel_map);
  
 [super dealloc];
}

- (id)init
{
  self = [super init];
  _channel_map = NULL;
  return self;
}

// --- Initialize and update
- (void)_updatePorts:(const pa_sink_info *)info
{
  NSMutableArray *ports;
  NSDictionary   *d;
  NSString       *newActivePort;

  if (info->n_ports > 0) {
    ports = [NSMutableArray new];
    for (unsigned i = 0; i < info->n_ports; i++) {
      d = @{@"Name":[NSString stringWithCString:info->ports[i]->name],
            @"Description":[NSString stringWithCString:info->ports[i]->description]};
      [ports addObject:d];
    }
    if (_ports) {
      [_ports release];
    }
    _ports = [[NSArray alloc] initWithArray:ports];
    [ports release];
  }

  if (info->active_port) {
    newActivePort = [[NSString alloc] initWithCString:info->active_port->description];
    if (_activePort == nil || [_activePort isEqualToString:newActivePort] == NO) {
      if (_activePort) {
        [_activePort release];
      }
      if (info->active_port != NULL) {
        self.activePort = newActivePort;
      }
      else {
        self.activePort = nil;
      }
    }
  }
}

- (void)_updateVolume:(const pa_sink_info *)info
{
  NSMutableArray *vol;
  NSNumber       *v;
  BOOL           isVolumeChanged = NO;
  CGFloat        balance;

  if (_channelVolumes == nil) {
    isVolumeChanged = YES;
  }
  
  balance = pa_cvolume_get_balance(&info->volume, &info->channel_map);
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
    self.channelVolumes = [[NSArray alloc] initWithArray:vol]; // KVO compliance
  }
  [vol release];

  //
  _volumeSteps = info->n_volume_steps;
  
  if (_baseVolume != (NSUInteger)info->base_volume) {
    self.baseVolume = (NSUInteger)info->base_volume;
  }  
}

- (void)_updateChannels:(const pa_sink_info *)info
{
  _channelCount = info->volume.channels;
  
  // Channel map
  if (_channel_map) {
    free(_channel_map);
  }
  _channel_map = malloc(sizeof(pa_channel_map));
  pa_channel_map_init(_channel_map);
  _channel_map->channels = info->channel_map.channels;
  for (int i = 0; i < _channel_map->channels; i++) {
    _channel_map->map[i] = info->channel_map.map[i];
  }
}

- (void)_updateFormats:(const pa_sink_info *)info
{
  NSMutableArray *formats;
  
  if (info->n_formats > 0) {
    formats = [NSMutableArray new];
    for (unsigned i = 0; i < info->n_formats; i++) {
      [formats addObject:[NSNumber numberWithInt:info->formats[i]->encoding]];
    }
    if (_formats) {
      [_formats release];
    }
    _formats = [[NSArray alloc] initWithArray:formats];
    [formats release];
  }
}

- (id)updateWithValue:(NSValue *)val
{
  const pa_sink_info *info;
  NSMutableArray     *ports, *vol, *formats;
  
  // Convert PA structure into NSDictionary
  info = malloc(sizeof(const pa_sink_info));
  [val getValue:(void *)info];

  // Indexes
  _index = info->index;
  _cardIndex = info->card;

  // Name and description
  if (_description == nil) {
    _description = [[NSString alloc] initWithCString:info->description];
  }
  
  if (_name == nil) {
    _name = [[NSString alloc] initWithCString:info->name];
  }

  // Ports
  [self _updatePorts:info];

  // Volume
  [self _updateVolume:info];

  if (_mute != (BOOL)info->mute) {
    self.mute = (BOOL)info->mute;
  }

  if (_channel_map == NULL || pa_channel_map_equal(_channel_map, &info->channel_map)) {
    [self _updateChannels:info];
  }

  // Flags
  _flags = info->flags;
  // State
  _state = info->state;
  // Sample spec
  _sampleRate = info->sample_spec.rate;
  _sampleChannelCount = info->sample_spec.channels;
  _sampleFormat = info->sample_spec.format;
  // Supported formats
  // [self _updateFormats:info];

  free ((void *)info);

  return self;
}

// --- Actions
- (void)applyActivePort:(NSString *)portName
{
  const char   *port;
  pa_operation *o;

  for (NSDictionary *p in _ports) {
    if ([[p objectForKey:@"Description"] isEqualToString:portName]) {
      port = [[p objectForKey:@"Name"] cString];
      break;
    }
  }
  o = pa_context_set_sink_port_by_index(_context, _index, port, NULL, self);
  if (o) {
    pa_operation_unref(o);
  }
}

- (void)applyMute:(BOOL)isMute
{
  pa_operation *o;
  
  o = pa_context_set_sink_mute_by_index(_context, _index, (int)isMute, NULL, self);
  if (o) {
    pa_operation_unref(o);
  }
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
  pa_cvolume   *new_volume;
  pa_operation *o;

  new_volume = malloc(sizeof(pa_cvolume));
  pa_cvolume_init(new_volume);
  pa_cvolume_set(new_volume, _channelCount, v);
  
  o = pa_context_set_sink_volume_by_index(_context, _index, new_volume, NULL, self);
  if (o) {
    pa_operation_unref(o);
  }
  
  free(new_volume);
}

- (void)applyBalance:(CGFloat)balance
{
  pa_cvolume  *volume;
  pa_operation *o;

  volume = malloc(sizeof(pa_cvolume));
  pa_cvolume_init(volume);
  pa_cvolume_set(volume, _channelCount, self.volume);
  
  pa_cvolume_set_balance(volume, _channel_map, balance);
  o = pa_context_set_sink_volume_by_index(_context, _index, volume, NULL, self);
  if (o) {
    pa_operation_unref(o);
  }
  
  free(volume);
}

@end
