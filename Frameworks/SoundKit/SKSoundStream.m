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

#import "SKSoundStream.h"

@implementation SKSoundStream

- (void)dealloc
{
  [super dealloc];
}

- (id)initOnDevice:(SKSoundDevice *)device
{
  return [self initOnDevice:device
               samplingRate:44100
               channelCount:2
                     format:PA_SAMPLE_FLOAT32LE];
}
- (id)initOnDevice:(SKSoundDevice *)device
      samplingRate:(NSUInteger)rate
      channelCount:(NSUInteger)channels
            format:(NSUInteger)format
{
  pa_sample_spec sample_spec;
  pa_proplist    *proplist;

  if ((self = [super init]) == nil)
    return nil;

  [self setDevice:device];

  sample_spec.rate = rate;
  sample_spec.channels = channels;
  sample_spec.format = format;
  
  // Create stream
  proplist = pa_proplist_new();
  pa_proplist_sets(proplist, PA_PROP_MEDIA_ROLE, "event");
  _name = [[NSProcessInfo processInfo] processName];
  
  paStream = pa_stream_new_with_proplist(_server.pa_ctx, [_name cString],
                                         &sample_spec, NULL, proplist);
  
  return self;
}

- (void)activate
{
  NSLog(@"[SoundKit] `activate` was send to SKSoundStream."
        " SKSoundPlayStream or SKSoundRecordStream subclasses should be used instead.");
}
- (void)deactivate
{
  NSLog(@"[SoundKit] `deactivate` was send to SKSoundStream."
        " SKSoundPlayStream or SKSoundRecordStream subclasses should be used instead.");
}

- (NSUInteger)volume
{
  NSLog(@"[SoundKit] `volume` was send to SKSoundStream."
        " SKSoundPlayStream or SKSoundRecordStream subclasses should be used instead.");
  return 0;
}
- (void)setVolume:(NSUInteger)volume
{
  NSLog(@"[SoundKit] `setVolume` was send to SKSoundStream."
        " SKSoundPlayStream or SKSoundRecordStream subclasses should be used instead.");
}
- (CGFloat)balance
{
  NSLog(@"[SoundKit] `balance` was send to SKSoundStream."
        " SKSoundPlayStream or SKSoundRecordStream subclasses should be used instead.");
  return 0.0;
}
- (void)setBalance:(CGFloat)balance
{
  NSLog(@"[SoundKit] setBalance was send to SKSoundStream."
        " SKSoundPlayStream or SKSoundRecordStream subclasses should be used instead.");
}
- (void)setMute:(BOOL)isMute
{
  NSLog(@"[SoundKit] `setMute` was send to SKSoundStream."
        " SKSoundPlayStream or SKSoundRecordStream subclasses should be used instead.");
}
- (BOOL)isMute
{
  NSLog(@"[SoundKit] `isMute` was send to SKSoundStream."
        " SKSoundPlayStream or SKSoundRecordStream subclasses should be used instead.");
  return YES;
}

// - (BOOL)isPaused {}
// - (void)pause:(id)sender {}
// - (void)resume:(id)sender {}
// - (void)abort:(id)sender {}

// - (NXSoundDeviceError)pauseAtTime:(struct timeval *)time;
// - (NXSoundDeviceError)resumeAtTime:(struct timeval *)time;
// - (NXSoundDeviceError)abortAtTime:(struct timeval *)time;

// - (unsigned int)bytesProcessed;
// - (NXSoundDeviceError)lastError;
// - (id)delegate;
// - (void)setDelegate:(id)anObject;

@end
