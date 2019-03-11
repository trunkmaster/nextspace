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

#import "PASink.h"
#import "PASource.h"
#import "PASinkInput.h"
#import "PAStream.h"
#import "PAClient.h"

#import "SKSoundOut.h"
#import "SKSoundIn.h"
#import "SKSoundStream.h"

@implementation SKSoundStream

- (void)dealloc
{
  [super dealloc];
}

- (id)init
{
  if ((self = [super init]) == nil)
    return nil;
  _isVirtual = NO;
  _isPlayStream = NO;
  _isRecordStream = NO;
  return self;
}

- (id)initWithSinkInput:(PASinkInput *)sinkInput
                 server:(SKSoundServer *)server
{
  if ((self = [super init]) == nil)
    return nil;
  
  _server = server;
  _sinkInput = sinkInput;
  _client = [server clientWithIndex:_sinkInput.clientIndex];
  
  _name = _client.appName;
  _device = [server outputWithSink:[server sinkWithIndex:_sinkInput.sinkIndex]];
  _isVirtual = NO;
  _isPlayStream = YES;
  _isRecordStream = NO;

  return self;
}

static void stream_write_callback(pa_stream *stream, size_t length, void *userdata)
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

  _server = [SKSoundServer sharedServer];

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
  // Connect default stream
  // pa_stream_connect_playback(_stream, [device.sink.name cString],
  //                            NULL, 0, NULL, NULL);
  // pa_stream_set_write_callback(_stream, stream_write_callback, NULL);

  return self;
}
- (void)setDevice:(SKSoundDevice *)device
{
  if (device != nil) {
    _device = device;
    _isVirtual = NO;
    if ([device isKindOfClass:[SKSoundOut class]]) {
      _isPlayStream = YES;
    }
    else if ([device isKindOfClass:[SKSoundIn class]]) {
      _isRecordStream = YES;
    }
  }
}
- (void)playBuffer:(void *)data
              size:(NSUInteger)bytes
               tag:(NSUInteger)anUInt
{
}

- (BOOL)isActive
{
  return NO;
}
- (void)activate
{
  if (_isPlayStream) {
    pa_stream_connect_playback(paStream, [((SKSoundOut *)_device).sink.name cString],
                               NULL, 0, NULL, NULL);
  }
  else if (_isRecordStream) {
    pa_stream_connect_playback(paStream, [((SKSoundIn *)_device).source.name cString],
                               NULL, 0, NULL, NULL);
  }
  pa_stream_set_write_callback(paStream, stream_write_callback, NULL);
}
- (void)deactivate
{
  pa_stream_set_write_callback(paStream, NULL, NULL);
  pa_stream_disconnect(paStream);
  // pa_stream_unref(paStream);
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
