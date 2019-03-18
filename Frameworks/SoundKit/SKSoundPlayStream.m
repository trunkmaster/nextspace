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

#import "SKSoundOut.h"
#import "SKSoundPlayStream.h"

@implementation SKSoundPlayStream

- (void)dealloc
{
  [super dealloc];
}

static void _pa_write_callback(pa_stream *stream, size_t length, void *userdata)
{
  [(SKSoundPlayStream *)userdata writeStreamLength:length];
}

// when PA stream is ready to receive bytes `_delegate` will be messaged with `action`
- (void)setDelegate:(id)aDelegate
{
  _delegate = aDelegate;
}
- (void)setAction:(SEL)aSel
{
  _action = aSel;
}
- (void)writeStreamLength:(size_t)length
{
  if (_delegate == nil) {
    NSLog(@"[SoundKit] delegate is not set for SKSoundPlayStream.");
    return;
  }
  if ([_delegate respondsToSelector:_action]) {
    [_delegate performSelector:_action
                    withObject:[NSNumber numberWithUnsignedInteger:length]];
  }
  else {
    NSLog(@"[SoundKit] delegate does not respond to action write action"
          " of SKSoundPlayStream");
  }
}

- (void)activate
{
  SKSoundOut *output;
  
  if (super.device == nil) {
    super.device = [super.server defaultOutput];
  }
  output = (SKSoundOut *)super.device;
  
  pa_stream_connect_playback(_pa_stream, [output.sink.name cString], NULL, 0, NULL, NULL);
  pa_stream_set_write_callback(_pa_stream, _pa_write_callback, self);
  
  super.isActive = YES;
}
- (void)deactivate
{
  pa_stream_set_write_callback(_pa_stream, NULL, NULL);
  pa_stream_disconnect(_pa_stream);
  // pa_stream_unref(paStream);
  super.isActive = NO;
}

- (void)playBuffer:(void *)data
              size:(NSUInteger)bytes
               tag:(NSUInteger)anUInt
{
  pa_stream_write(_pa_stream, data, bytes, pa_xfree, 0, PA_SEEK_RELATIVE);
 
  NSLog(@"[SoundKit, SKSoundPlayStream] playBuffer:size:tag: is not implemented yes.");  
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

@end
