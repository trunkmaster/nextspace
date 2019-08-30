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

#import <dispatch/dispatch.h>

#import "PACard.h"
#import "PASink.h"
#import "SNDOut.h"

@implementation SNDOut

- (void)dealloc
{
  NSDebugLLog(@"Memory", @"[SNDOut] dealloc");
  [_sink release];
  [super dealloc];
}

- (NSString *)name
{
  return _sink.description;
}
- (NSString *)description
{
  return [NSString stringWithFormat:@"PulseAudio Sink `%@`", _sink.description];
}
// For debugging
- (void)printDescription
{
  fprintf(stderr, "+++ SNDDevice: %s +++++++++++++++++++++++++++++++++++++++++\n",
          [[super description] cString]);
  [super printDescription];
  
  fprintf(stderr, "+++ SNDOut: %s +++\n", [[self description] cString]);
  fprintf(stderr, "\t               Sink : %s (%lu)\n",  [_sink.name cString],
          [_sink retainCount]);
  fprintf(stderr, "\t   Sink Description : %s\n",  [_sink.description cString]);
  fprintf(stderr, "\t        Active Port : %s\n",  [_sink.activePort cString]);
  fprintf(stderr, "\t         Card Index : %lu\n", _sink.cardIndex);
  fprintf(stderr, "\t       Card Profile : %s\n",  [super.card.activeProfile cString]);
  fprintf(stderr, "\t      Channel Count : %lu\n", _sink.channelCount);
  
  fprintf(stderr, "\t             Volume : %lu\n", _sink.volume);
  for (NSUInteger i = 0; i < _sink.channelCount; i++) {
    fprintf(stderr, "\t           Volume %lu : %lu\n", i,
            [_sink.channelVolumes[i] unsignedIntegerValue]);
  }
  
  fprintf(stderr, "\t              Muted : %s\n", _sink.mute ? "Yes" : "No");
  fprintf(stderr, "\t       Retain Count : %lu\n", [self retainCount]);

  fprintf(stderr, "\t    Available Ports : \n");
  for (NSDictionary *port in [self availablePorts]) {
    NSString *portDesc, *portString;
    portDesc = [port objectForKey:@"Description"];
    if ([portDesc isEqualToString:_sink.activePort])
      portString = [NSString stringWithFormat:@"%s%@%s", "\e[1m- ", portDesc, "\e[0m"];
    else
      portString = [NSString stringWithFormat:@"%s%@%s", "- ", portDesc, ""];
    fprintf(stderr, "\t                    %s\n", [portString cString]);
  }
}

/*--- Sink proxy ---*/
- (NSArray *)availablePorts
{
  if (_sink == nil) {
    NSLog(@"SNDOut: avaliablePorts was called without Sink was being set.");
    return nil;
  }
  return _sink.ports;
}
- (NSString *)activePort
{
  return _sink.activePort;
}
- (void)setActivePort:(NSString *)portName
{
  [_sink applyActivePort:portName];
}

- (NSUInteger)volumeSteps
{
  return _sink.volumeSteps;
}
- (NSUInteger)volume
{
  return [_sink volume];
}
- (void)setVolume:(NSUInteger)volume
{
  [_sink applyVolume:volume];
}
- (CGFloat)balance
{
  return _sink.balance;
}
- (void)setBalance:(CGFloat)balance
{
  [_sink applyBalance:balance];
}

- (void)setMute:(BOOL)isMute
{
  [_sink applyMute:isMute];
}
- (BOOL)isMute
{
  return (BOOL)_sink.mute;
}

// Flags
- (BOOL)hasHardwareVolumeControl
{
  return (_sink.flags & PA_SINK_HW_VOLUME_CTRL) ? YES : NO;
}
- (BOOL)hasHardwareMuteControl
{
  return (_sink.flags & PA_SINK_HW_MUTE_CTRL) ? YES : NO;
}
- (BOOL)hasFlatVolume
{
  return (_sink.flags & PA_SINK_FLAT_VOLUME) ? YES : NO;
}
- (BOOL)canQueryLatency
{
  return (_sink.flags & PA_SINK_LATENCY) ? YES : NO;
}
- (BOOL)canChangeLatency
{
  return (_sink.flags & PA_SINK_DYNAMIC_LATENCY) ? YES : NO;
}
- (BOOL)canSetFormats
{
  return (_sink.flags & PA_SINK_SET_FORMATS) ? YES : NO;
}
- (BOOL)isHardware
{
  return (_sink.flags & PA_SINK_HARDWARE) ? YES : NO;
}
- (BOOL)isNetwork
{
  return (_sink.flags & PA_SINK_NETWORK) ? YES : NO;
}
// State
- (SNDDeviceState)deviceState
{
  return _sink.state;
}
// Sample
- (NSUInteger)sampleRate
{
  return _sink.sampleRate;
}
- (NSUInteger)sampleChannelCount
{
  return _sink.sampleChannelCount;
}
- (NSInteger)sampleFormat
{
  return _sink.sampleFormat;
}
// Formats
- (NSArray *)formats
{
  return _sink.formats;
}
// Channel map
- (NSArray *)channelNames
{
  NSMutableArray *cn = [NSMutableArray new];
  pa_channel_map *channel_map = _sink.channel_map;

  if (channel_map->channels > 0) {
    for (unsigned i = 0; i < channel_map->channels; i++) {
      [cn addObject:[super channelPositionToName:channel_map->map[i]]];
    }
  }
  return [[[NSArray array] initWithArray:cn] autorelease];
}

@end
