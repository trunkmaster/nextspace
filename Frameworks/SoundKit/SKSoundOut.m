/* -*- mode: objc -*- */
/*
      Project: SoundKit framework.

  Description: SKSoundOut is the one of the final link in chain:
               SKSoundServer <- SKSoundDevice |-> SKSoundOut
               SKSoundOut has acces to own device (Sink) and inherited from 
               SKSoundDevice (Server and Card). SKSoundOut is enough if your
               application will read info about sound output as well as change 
               sound device properties (volume, balance, mute, profile, port).
               To play sound you also need SKSoundStream connected to SKSounOut.
               (see SKSoundStream description).

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

#import <dispatch/dispatch.h>

#import "PACard.h"
#import "PASink.h"
#import "SKSoundOut.h"

@implementation SKSoundOut

- (void)dealloc
{
  NSLog(@"[SKSoundOut] dealloc");
  [_sink release];
  [super dealloc];
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"PulseAudio Sink `%@`", _sink.description];
}

// For debugging
- (void)printDescription
{
  fprintf(stderr, "+++ SKSoundDevice: %s +++\n", [[super description] cString]);
  [super printDescription];
  
  fprintf(stderr, "+++ SKSoundOut: %s +++\n", [[self description] cString]);
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
  for (NSString *port in [self availablePorts]) {
    NSString *portString;
    if ([port isEqualToString:_sink.activePort])
      portString = [NSString stringWithFormat:@"%s%@%s", "\e[1m- ", port, "\e[0m"];
    else
      portString = [NSString stringWithFormat:@"%s%@%s", "- ", port, ""];
    fprintf(stderr, "\t                    %s\n", [portString cString]);
  }
}

/*--- Sink proxy ---*/
- (NSArray *)availablePorts
{
  if (_sink == nil) {
    NSLog(@"SKSoundOut: avaliablePorts was called without Sink was being set.");
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

- (void)setMuted:(BOOL)isMute
{
  [_sink applyMute:isMute];
}
- (BOOL)isMuted
{
  return (BOOL)_sink.mute;
}

// - samples
// {}
// - latency
// {}

@end
