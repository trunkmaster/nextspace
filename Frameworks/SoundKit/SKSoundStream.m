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

// #import "PASink.h"
// #import "PASource.h"
// #import "PASinkInput.h"
// #import "PAStream.h"
// #import "PAClient.h"

#import "SKSoundStream.h"

@implementation SKSoundStream

- (void)dealloc
{
  [super dealloc];
}

- (id)initOnDevice:(SKSoundDevice *)device
      samplingRate:(NSUInteger)rate
      channelCount:(NSUInteger)channels
            format:(NSUInteger)format
{
  NSLog(@"[SoundKit] initOnDevice:samplingRate:channelCount:format:"
        " was send to SKSoundStream."
        " SKSoundPlayStream or SKSoundRecordStream subclasses should be used instead.");
  return nil;
}
- (void)playBuffer:(void *)data
              size:(NSUInteger)bytes
               tag:(NSUInteger)anUInt
{
  NSLog(@"[SoundKit] playBuffer:size:tag: was send to SKSoundStream."
        " SKSoundPlayStream or SKSoundRecordStream subclasses should be used instead.");
}

- (BOOL)isActive
{
  NSLog(@"[SoundKit] isActive was send to SKSoundStream."
        " SKSoundPlayStream or SKSoundRecordStream subclasses should be used instead.");
  return NO;
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
