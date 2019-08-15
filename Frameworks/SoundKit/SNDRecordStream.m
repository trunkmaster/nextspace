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

#import "PASource.h"
#import "PASourceOutput.h"

#import "SNDIn.h"
#import "SNDRecordStream.h"

extern void _stream_buffer_ready(pa_stream *stream, size_t length, void *sndStream);
extern void _stream_buffer_empty(pa_stream *stream, int success, void *sndStream);

@implementation SNDRecordStream

- (void)dealloc
{
  NSDebugLLog(@"Memory", @"[SNDRecordStream] dealloc");
  if (super.isActive != NO) {
    [self setDelegate:nil];
    [self deactivate];
  }
  [super dealloc];
}

- (void)activate
{
  SNDIn *input;
  
  if (super.device == nil) {
    super.device = [super.server defaultInput];
  }
  input = (SNDIn *)super.device;

  pa_stream_connect_record(_pa_stream, [input.source.name cString], NULL, 0);
  pa_stream_set_read_callback(_pa_stream, _stream_buffer_ready, NULL);
  
  super.isActive = YES;
}
- (void)deactivate
{
  pa_stream_set_read_callback(_pa_stream, NULL, NULL);
  pa_stream_disconnect(_pa_stream);
  super.isActive = NO;
}

- (NSUInteger)volume
{
  return [_sourceOutput volume];
}
- (void)setVolume:(NSUInteger)volume
{
  [_sourceOutput applyVolume:volume];
}
- (CGFloat)balance
{
  return _sourceOutput.balance;
}
- (void)setBalance:(CGFloat)balance
{
  [_sourceOutput applyBalance:balance];
}
- (void)setMute:(BOOL)isMute
{
  [_sourceOutput applyMute:isMute];
}
- (BOOL)isMute
{
  return (BOOL)_sourceOutput.mute;
}

- (NSString *)activePort
{
  PASource *source = [super.server sourceWithIndex:_sourceOutput.sourceIndex];

  if (source == nil) {
    source = [super.server defaultInput].source;
  }

  return source.activePort;
}
- (void)setActivePort:(NSString *)portName
{
  PASource *source = [super.server sourceWithIndex:_sourceOutput.sourceIndex];

  if (source == nil) {
    source = [super.server defaultInput].source;
  }

  [source applyActivePort:portName];
}

@end
