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

#import <SoundKit/SNDIn.h>

#import "PASource.h"
#import "PACard.h"

@implementation SNDIn

- (void)dealloc
{
  NSDebugLLog(@"Memory", @"[SNDIn] dealloc");
  [_source release];
  [super dealloc];
}

- (NSString *)name
{
  return _source.description;
}
- (NSString *)description
{
  return [NSString stringWithFormat:@"PulseAudio Source `%@`", _source.description];
}

// For debugging
- (void)printDescription
{
  fprintf(stderr, "+++ SNDDevice: %s +++++++++++++++++++++++++++++++++++++++++\n",
          [[super description] cString]);
  [super printDescription];
  
  fprintf(stderr, "+++ SNDIn: %s +++\n", [[self description] cString]);
  fprintf(stderr, "\t             Source : %s (%lu)\n",  [_source.name cString],
          [_source retainCount]);
  fprintf(stderr, "\t Source Description : %s\n",  [_source.description cString]);
  fprintf(stderr, "\t        Active Port : %s\n",  [_source.activePort cString]);
  fprintf(stderr, "\t         Card Index : %lu\n", _source.cardIndex);
  fprintf(stderr, "\t       Card Profile : %s\n",  [super.card.activeProfile cString]);
  fprintf(stderr, "\t      Channel Count : %lu\n", _source.channelCount);
  
  fprintf(stderr, "\t             Volume : %lu\n", _source.volume);
  for (NSUInteger i = 0; i < _source.channelCount; i++) {
    fprintf(stderr, "\t           Volume %lu : %lu\n", i,
            [_source.channelVolumes[i] unsignedIntegerValue]);
  }
  
  fprintf(stderr, "\t              Muted : %s\n", _source.mute ? "Yes" : "No");
  fprintf(stderr, "\t       Retain Count : %lu\n", [self retainCount]);

  fprintf(stderr, "\t    Available Ports : \n");
  for (NSDictionary *port in [self availablePorts]) {
    NSString *portDesc, *portString;
    portDesc = [port objectForKey:@"Description"];
    if ([portDesc isEqualToString:_source.activePort])
      portString = [NSString stringWithFormat:@"%s%@%s", "\e[1m- ", portDesc, "\e[0m"];
    else
      portString = [NSString stringWithFormat:@"%s%@%s", "- ", portDesc, ""];
    fprintf(stderr, "\t                    %s\n", [portString cString]);
  }
}

/*--- Source proxy ---*/
- (NSArray *)availablePorts
{
  if (_source == nil) {
    NSLog(@"SNDIn: avaliablePorts was called without Source was being set.");
    return nil;
  }
  return _source.ports;
}
- (NSString *)activePort
{
  return _source.activePort;
}
- (void)setActivePort:(NSString *)portName
{
  [_source applyActivePort:portName];
}

- (NSUInteger)volumeSteps
{
  return _source.volumeSteps;
}
- (NSUInteger)volume
{
  return [_source volume];
}
- (void)setVolume:(NSUInteger)volume
{
  [_source applyVolume:volume];
}
- (CGFloat)balance
{
  return _source.balance;
}
- (void)setBalance:(CGFloat)balance
{
  [_source applyBalance:balance];
}

- (void)setMute:(BOOL)isMute
{
  [_source applyMute:isMute];
}
- (BOOL)isMute
{
  return (BOOL)_source.mute;
}

// Flags
- (BOOL)hasHardwareVolumeControl
{
  return (_source.flags & PA_SOURCE_HW_VOLUME_CTRL) ? YES : NO;
}
- (BOOL)hasHardwareMuteControl
{
  return (_source.flags & PA_SOURCE_HW_MUTE_CTRL) ? YES : NO;
}
- (BOOL)hasFlatVolume
{
  return (_source.flags & PA_SOURCE_FLAT_VOLUME) ? YES : NO;
}
- (BOOL)canQueryLatency
{
  return (_source.flags & PA_SOURCE_LATENCY) ? YES : NO;
}
- (BOOL)canChangeLatency
{
  return (_source.flags & PA_SOURCE_DYNAMIC_LATENCY) ? YES : NO;
}
- (BOOL)isHardware
{
  return (_source.flags & PA_SOURCE_HARDWARE) ? YES : NO;
}
- (BOOL)isNetwork
{
  return (_source.flags & PA_SOURCE_NETWORK) ? YES : NO;
}
// State
- (SNDDeviceState)deviceState
{
  return _source.state;
}
// Sample
- (NSUInteger)sampleRate
{
  return _source.sampleRate;
}
- (NSUInteger)sampleChannelCount
{
  return _source.sampleChannelCount;
}
- (NSInteger)sampleFormat
{
  return _source.sampleFormat;
}
// Formats
- (NSArray *)formats
{
  return _source.formats;
}
// Channel map
- (NSArray *)channelNames
{
  NSMutableArray *cn = [NSMutableArray new];
  pa_channel_map *channel_map = _source.channel_map;

  if (channel_map->channels > 0) {
    for (unsigned i = 0; i < channel_map->channels; i++) {
      [cn addObject:[super channelPositionToName:channel_map->map[i]]];
    }
  }
  return [[[NSArray array] initWithArray:cn] autorelease];
}

@end
