/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - DesktopKit framework
//
// Copyright (C) 2014-2019 Sergii Stoian
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

#import "NXTSound.h"
#import <GNUstepGUI/GSSoundSource.h>

@implementation NXTSound

- (void)dealloc
{
  NSLog(@"[NXTSound] dealloc");
  if (_stream) {
    [_stream deactivate];
    [_stream release];
    _stream = nil;
  }
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [super dealloc];
}

- (void)_initStream
{
  NSLog(@"[NXTSound] creating play stream...");
  _stream = [[SNDPlayStream alloc]
                initOnDevice:(SNDDevice *)[[SNDServer sharedServer] defaultOutput]
                samplingRate:[_source sampleRate]
                channelCount:[_source channelCount]
                      format:3 // PA
                        type:SNDEventType];
  [_stream setDelegate:self];
  if (desiredState == NXTSoundPlay) {
    NSLog(@"[NXTSound] desired state is `Play`...");
    [self play];
  }
}

- (void)_serverStateChanged:(NSNotification *)notif
{
  SNDServer *server = [notif object];
  
  NSLog(@"[NXTSound] serverStateChanged - %i", server.status);
  
  if (server.status == SNDServerReadyState) {
    [self _initStream];
  }
  else if (server.status == SNDServerFailedState ||
           server.status == SNDServerTerminatedState) {
    if (_delegate &&
        [_delegate respondsToSelector:@selector(sound:didFinishPlaying:)] != NO) {
      [_delegate sound:self didFinishPlaying:YES];
    }
  }
}

// --- NSSound overriding
- (id)initWithContentsOfFile:(NSString *)path
                 byReference:(BOOL)byRef
{
  SNDServer *server;
  
  self = [super initWithContentsOfFile:path byReference:byRef];
  if (self == nil) {
    return nil;
  }

  NSLog(@"[NXTSound] channels: %lu rate: %lu format: %i duraction: %.3f",
        [_source channelCount], [_source sampleRate], [_source byteOrder],
        [_source duration]);

  // 1. Connect to PulseAudio on locahost
  server = [SNDServer sharedServer];
  // 2. Wait for server to be ready
  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(_serverStateChanged:)
           name:SNDServerStateDidChangeNotification
         object:server];
  // 3. Connect to sound server (pulseaudio)
  NSLog(@"[NXTSound] server status == %i", server.status);
  if (server.status != SNDServerReadyState) {
    NSLog(@"[NXTSound] connecting to sound server");
    [server connect];
  }

  desiredState = NXTSoundInitial;
  
  return self;
}

- (BOOL)play
{
  if (_stream == nil) {
    desiredState = NXTSoundPlay;
  }
  else {
    [_stream activate];
  }
  
  return YES;
}
- (BOOL)stop
{
  if (_stream) {
    NSLog(@"Current song time: %f", [self currentTime]);
    [self pause];
    [self setCurrentTime:0];
    [_stream empty:YES];
  }
  return YES;
}
- (BOOL)pause
{
  [_stream pause:self];
  return YES;
}
- (BOOL)resume
{
  [_stream resume:self];
  return YES;
}
- (BOOL)isPlaying
{
  return ([_stream isActive] && ![_stream isPaused]);
}

// --- SNDPlayStream delegate
- (void)soundStream:(SNDPlayStream *)sndStream bufferReady:(NSNumber *)count
{
  NSUInteger bytes_length = [count unsignedIntValue];
  NSUInteger bytes_read;
  float      *buffer;

  // NSLog(@"[NXTSound] PLAY %lu bytes of sound", bytes_length);

  buffer = malloc(sizeof(short) * bytes_length);
  bytes_read = [_source readBytes:buffer length:bytes_length];
  // NSLog(@"[NXTSound] READ %lu bytes of sound", bytes_length);
  
  if (bytes_read == 0) {
    free(buffer);
    [_stream empty:NO];
    return;
  }

  [_stream playBuffer:buffer size:bytes_length tag:0];
}
- (void)soundStreamBufferEmpty:(SNDPlayStream *)sndStream
{
  NSLog(@"[NXTSound] stream buffer is empty");
  // [_stream deactivate];
  if (_delegate &&
      [_delegate respondsToSelector:@selector(sound:didFinishPlaying:)] != NO) {
    [_delegate sound:self didFinishPlaying:YES];
  }
}

@end
