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
#import "PASinkInput.h"

#import "SNDOut.h"
#import "SNDPlayStream.h"

extern void _stream_buffer_ready(pa_stream *stream, size_t length, void *sndStream);
extern void _stream_buffer_empty(pa_stream *stream, int success, void *sndStream);

void _stream_underflow(pa_stream *stream, void *sndStream)
{
  NSDebugLLog(@"SoundKit", @"[SNDPlayStream] UNDERflow!");
}
void _stream_overflow(pa_stream *stream, void *sndStream)
{
  NSDebugLLog(@"SoundKit", @"[SoundKit] PlayStream OVERflow!");
}

@implementation SNDPlayStream

- (void)dealloc
{
  NSDebugLLog(@"Memory", @"[SNDPlayStream] dealloc");
  if (super.isActive != NO) {
    [self setDelegate:nil];
    [self deactivate];
  }
  [super dealloc];
}

- (void)activate
{
  SNDOut *output;
  
  if (super.device == nil) {
    super.device = [super.server defaultOutput];
  }
  output = (SNDOut *)super.device;
  
  pa_stream_connect_playback(_pa_stream, [output.sink.name cString], NULL, 0, NULL, NULL);
  pa_stream_set_write_callback(_pa_stream, _stream_buffer_ready, self);
  pa_stream_set_underflow_callback(_pa_stream, _stream_underflow, self);
  pa_stream_set_overflow_callback(_pa_stream, _stream_overflow, self);
  
  super.isActive = YES;
}
- (void)deactivate
{
  pa_stream_set_write_callback(_pa_stream, NULL, NULL);
  pa_stream_set_underflow_callback(_pa_stream, NULL, NULL);
  pa_stream_set_overflow_callback(_pa_stream, NULL, NULL);
  pa_stream_disconnect(_pa_stream);
  super.isActive = NO;
}

- (BOOL)isPaused
{
  return _sinkInput.corked;
}

- (void)playBuffer:(void *)data
              size:(NSUInteger)bytes
               tag:(NSUInteger)anUInt
{
  pa_stream_write(_pa_stream, data, bytes, pa_xfree, 0, PA_SEEK_RELATIVE);
}

- (NSUInteger)volume
{
  return [_sinkInput volume];
}
- (void)setVolume:(NSUInteger)volume
{
  [_sinkInput applyVolume:volume];
}
- (CGFloat)balance
{
  return _sinkInput.balance;
}
- (void)setBalance:(CGFloat)balance
{
  [_sinkInput applyBalance:balance];
}
- (void)setMute:(BOOL)isMute
{
  [_sinkInput applyMute:isMute];
}
- (BOOL)isMute
{
  return (BOOL)_sinkInput.mute;
}

- (NSString *)activePort
{
  SNDServer *server = [SNDServer sharedServer];
  PASink    *sink = [server sinkWithIndex:_sinkInput.sinkIndex];

  if (sink == nil) {
    sink = [server defaultOutput].sink;
  }

  return sink.activePort;
}
- (void)setActivePort:(NSString *)portName
{
  SNDServer *server = [SNDServer sharedServer];
  PASink    *sink = [server sinkWithIndex:_sinkInput.sinkIndex];

  if (sink == nil) {
    sink = [server defaultOutput].sink;
  }

  [sink applyActivePort:portName];
}

@end
