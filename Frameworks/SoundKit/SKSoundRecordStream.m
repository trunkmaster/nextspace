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

#import "SKSoundIn.h"
#import "SKSoundRecordStream.h"

@implementation SKSoundRecordStream

- (void)dealloc
{
  [super dealloc];
}

// TODO
static void stream_read_callback(pa_stream *stream, size_t length, void *userdata)
{
  /*  sf_count_t frames, frames_read;
      float      *data; */
  // pa_assert(s && length && snd_file);

  fprintf(stderr, "[SKSoundStream] stream_write_callback\n");
  
  /*
  data = pa_xmalloc(length);

  // pa_assert(sample_length >= length);
  frames = (sf_count_t) (length/pa_frame_size(&sample_spec));
  frames_read = sf_readf_float(snd_file, data, frames);
  fprintf(stderr, "length == %li frames == %li frames_read == %li\n",
          length, frames, frames_read);
  
  if (frames_read <= 0) {
    pa_xfree(data);
    fprintf(stderr, "End of file\n");
    pa_stream_set_write_callback(stream, NULL, NULL);
    pa_stream_disconnect(stream);
    pa_stream_unref(stream);
    return;
  }

  pa_stream_write(s, d, length, pa_xfree, 0, PA_SEEK_RELATIVE);
  */
}

- (void)activate
{
  SKSoundIn *input;
  
  if (super.device == nil) {
    super.device = [super.server defaultInput];
  }
  input = (SKSoundIn *)super.device;

  pa_stream_connect_record(_pa_stream, [input.source.name cString], NULL, 0);
  pa_stream_set_read_callback(_pa_stream, stream_read_callback, NULL);
  super.isActive = YES;
}
- (void)deactivate
{
  pa_stream_set_write_callback(_pa_stream, NULL, NULL);
  pa_stream_disconnect(_pa_stream);
  // pa_stream_unref(paStream);
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

@end
