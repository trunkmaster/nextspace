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

static BOOL isPlayFinished = NO;

@implementation NXTSound

- (void)dealloc
{
  NSLog(@"[NXTSound] dealloc");
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self setDelegate:nil];
  if (_stream) {
    [_stream setDelegate:nil];
    [_stream deactivate];
    [_stream release];
    _stream = nil;
  }
  
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
                        type:_streamType];
  [_stream setDelegate:self];
  if (_state == NXTSoundPlay) {
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
                  streamType:(SNDStreamType)sType
{
  SNDServer *server;
  
  self = [super initWithContentsOfFile:path byReference:byRef];
  if (self == nil) {
    return nil;
  }

  if ([_source duration] < 0.30) {
    _isShort = YES;
  }

  NSLog(@"[NXTSound] channels: %lu rate: %lu format: %i duraction: %.3f",
        [_source channelCount], [_source sampleRate], [_source byteOrder],
        [_source duration]);

  _state = NXTSoundInitial;
  _streamType = sType;
  
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
  else {
    [self _initStream];
  }

  return self;
}

- (BOOL)play
{
  isPlayFinished = NO;
  
  if (_stream != nil) {
    if (_stream.isActive == NO) {
      [_stream activate];
    }
    else {
      [self soundStream:_stream bufferReady:[_stream bufferLength]];
    }
    [self resume];
    return YES;
  }

  _state = NXTSoundPlay;
  return NO;
}
- (BOOL)stop
{
  if (_stream && _state != NXTSoundStop) {
    NSLog(@"Current song time: %f", [self currentTime]);
    [self pause];
    [self setCurrentTime:0];
    [_stream empty:YES];
    _state = NXTSoundStop;
  }
  return YES;
}
- (BOOL)pause
{
  if (_stream && _state != NXTSoundPause) {
    [_stream pause:self];
    _state = NXTSoundPause;
  }
  return YES;
}
- (BOOL)resume
{
  if (_stream) {
    [_stream resume:self];
    _state = NXTSoundPlay;
  }
  return YES;
}
- (BOOL)isPlaying
{
  if (_stream == nil) return NO;
  return (_state == NXTSoundPlay || _state == NXTSoundPause);
}

// --- SNDPlayStream delegate
- (void)soundStream:(SNDPlayStream *)sndStream bufferReady:(NSNumber *)count
{
  NSUInteger bytes_length;
  NSUInteger bytes_read;
  float      *buffer;

  if (isPlayFinished != NO) {
    return;
  }

  bytes_length = [count unsignedIntValue];
  // NSLog(@"[NXTSound] PLAY %lu bytes of sound", bytes_length);
  
  buffer = malloc(sizeof(short) * bytes_length);
  bytes_read = [_source readBytes:buffer length:bytes_length];
  // NSLog(@"[NXTSound] READ %lu bytes of sound", bytes_read);
  
  if (bytes_read == 0) {
    free(buffer);
    isPlayFinished = YES;
    [_stream empty:NO];
    return;
  }
  // buffer will be freed by PA function called by SNDPlayStream
  [_stream playBuffer:buffer size:bytes_read tag:0];
  if (_isShort)
    [_stream empty:NO];
}
- (void)soundStreamBufferEmpty:(SNDPlayStream *)sndStream
{
  NSLog(@"[NXTSound] stream buffer is empty %.2f/%0.2f",
        [_source currentTime], [_source duration]);
  if (isPlayFinished == NO) {
    // isPlayFinished will be set to 'YES' in called method below
    // if no more bytes to read.
    [self soundStream:_stream bufferReady:[_stream bufferLength]];
  }
  else {
    [self stop];
    if (_delegate &&
        [_delegate respondsToSelector:@selector(sound:didFinishPlaying:)] != NO) {
      [_delegate sound:self didFinishPlaying:YES];
    }
  }
}

@end
