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

#import "PACard.h"
#import "PASink.h"

#import <SoundKit/SNDDevice.h>

@implementation SNDDevice

- (void)dealloc
{
  NSDebugLLog(@"Memory", @"[SNDDevice] dealloc");
  [_card release];
  [super dealloc];
}

- (id)init
{
  return [self initWithServer:[SNDServer sharedServer]];
}

- (id)initWithServer:(SNDServer *)server
{
  if ((self = [super init]) == nil)
    return nil;
  
  _server = server;
  
  return self;
}

// --- Accesorries --- //
- (NSString *)host
{
  return _server.hostName;
}
- (NSString *)name
{
  return _card.description;
}
- (NSString *)cardDescription
{
  return _card.description;
}
- (NSString *)description
{
  return _card.description;
}
- (void)printDescription
{
  // Print header only if it's not subclass `super` call
  if ([self class] == [SNDDevice class] ) {
    fprintf(stderr, "+++ SNDDevice: %s +++\n", [[self description] cString]);
  }
  fprintf(stderr, "\t           Index : %lu\n", _card.index);
  fprintf(stderr, "\t            Name : %s\n", [_card.name cString]);
  fprintf(stderr, "\t    Retain Count : %lu\n", [self retainCount]);

  fprintf(stderr, "\t        Profiles : \n");
  for (NSDictionary *prof in _card.profiles) {
    NSString *profDesc, *profString;
    profDesc = prof[@"Description"];
    if ([profDesc isEqualToString:_card.activeProfile])
      profString = [NSString stringWithFormat:@"%s%@%s", "\e[1m- ", profDesc, "\e[0m"];
    else
      profString = [NSString stringWithFormat:@"%s%@%s", "- ", profDesc, ""];
    fprintf(stderr, "\t                 %s\n", [profString cString]);
  }
}

// --- Card proxy --- //
- (NSArray *)availableProfiles
{
  if (_card == nil) {
    NSLog(@"SoundDevice: avaliableProfiles was called without Card was being set.");
    return nil;
  }
  return _card.profiles;
}
- (NSString *)activeProfile
{
  return _card.activeProfile;
}
- (void)setActiveProfile:(NSString *)profileName
{
  if (_card == nil) {
    NSLog(@"SoundDevice: setActiveProfile was called without Card was being set.");
    return;
  }
  [_card applyActiveProfile:profileName];
}

// --- Subclass responsiblity
- (NSArray *)availablePorts
{
  return [_card.outPorts arrayByAddingObjectsFromArray:_card.inPorts];
}
- (NSString *)activePort
{
  return nil;
}
- (void)setActivePort:(NSString *)portName
{
  NSLog(@"[SoundKit] setActivePort: was send to SNDDevice."
        " SNDOut or SNDIn subclasses should be used instead.");
}

- (NSUInteger)volumeSteps
{
  return 0;
}
- (NSUInteger)volume
{
  return 0;
}
- (void)setVolume:(NSUInteger)volume
{
  NSLog(@"[SoundKit] setVolume: was send to SNDDevice."
        " SNDOut or SNDIn subclasses should be used instead.");
}

- (CGFloat)balance
{
  return 0.0;
}
- (void)setBalance:(CGFloat)balance
{
  NSLog(@"[SoundKit] setBalance: was send to SNDDevice."
        " SNDOut or SNDIn subclasses should be used instead.");
}

- (BOOL)isMute
{
  return NO;
}
- (void)setMute:(BOOL)isMute
{
  NSLog(@"[SoundKit] setMute: was send to SNDDevice. "
        "SNDOut or SNDIn subclasses should be used instead.");
}

// Flags
- (BOOL)hasHardwareVolumeControl
{
  return NO;
}
- (BOOL)hasHardwareMuteControl
{
  return NO;
}
- (BOOL)hasFlatVolume
{
  return NO;
}
- (BOOL)canQueryLatency
{
  return NO;
}
- (BOOL)canChangeLatency
{
  return NO;
}
- (BOOL)canSetFormats
{
  return NO;
}
- (BOOL)isHardware
{
  return NO;
}
- (BOOL)isNetwork
{
  return NO;
}
// State
- (SNDDeviceState)deviceState
{
  return SNDDeviceInvalidState;
}
// Sample
- (NSUInteger)sampleRate
{
  return 0;
}
- (NSUInteger)sampleChannelCount
{
  return 0;
}
- (NSInteger)sampleFormat
{
  return -1;
}
// Formats
- (NSArray *)formats
{
  return nil;
}
// Channel map
- (NSString *)channelPositionToName:(pa_channel_position_t)position
{
  switch (position)
    {
    case PA_CHANNEL_POSITION_MONO:
      return @"Mono";
      
    case PA_CHANNEL_POSITION_FRONT_LEFT:
      return @"Left";
    case PA_CHANNEL_POSITION_FRONT_RIGHT:
      return @"Right";
    case PA_CHANNEL_POSITION_FRONT_CENTER:
      return @"Center";
      
    case PA_CHANNEL_POSITION_REAR_CENTER:
      return @"Center Surround";
    case PA_CHANNEL_POSITION_REAR_LEFT:
      return @"Left Surround";
    case PA_CHANNEL_POSITION_REAR_RIGHT:
    return @"Right Surround";

    case PA_CHANNEL_POSITION_LFE:
      return @"Subwoofer";

    case PA_CHANNEL_POSITION_FRONT_LEFT_OF_CENTER:
      return @"Left Center";
    case PA_CHANNEL_POSITION_FRONT_RIGHT_OF_CENTER:
      return @"Right Center";

    case PA_CHANNEL_POSITION_SIDE_LEFT:
      return @"Left Surround Direct";
    case PA_CHANNEL_POSITION_SIDE_RIGHT:
      return @"Right Surround Direct";

    case PA_CHANNEL_POSITION_TOP_CENTER:
      return @"Top Center Surround";
    case PA_CHANNEL_POSITION_TOP_FRONT_LEFT:
      return @"Vertical Height Left";
    case PA_CHANNEL_POSITION_TOP_FRONT_RIGHT:
      return @"Vertical Height Right";
    case PA_CHANNEL_POSITION_TOP_FRONT_CENTER:
      return @"Vertical Height Center";

    case PA_CHANNEL_POSITION_TOP_REAR_LEFT:
      return @"Top Back Left";
    case PA_CHANNEL_POSITION_TOP_REAR_RIGHT:
      return @"Top Back Right";
    case PA_CHANNEL_POSITION_TOP_REAR_CENTER:
      return @"Top Back Center";
    case PA_CHANNEL_POSITION_INVALID:
    default:
      return @"Unknown";
    }
}
- (NSArray *)channelNames
{
  return nil;
}

@end
