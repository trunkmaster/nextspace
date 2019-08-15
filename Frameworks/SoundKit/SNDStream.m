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

#import "SNDStream.h"

static BOOL isBufferEmpty = YES;

// PulseAudio callbacks.
// Stream is ready to receive sound bytes.
void _stream_buffer_ready(pa_stream *stream, size_t length, void *sndStream)
{
  id  delegate = [(SNDStream *)sndStream delegate];
  SEL action = @selector(soundStream:bufferReady:);

  isBufferEmpty = NO;
  
  if (delegate == nil) {
    NSLog(@"[SoundKit] delegate is not set for SNDStream.");
    return;
  }
  if ([delegate respondsToSelector:action]) {
    [delegate performSelector:action
                   withObject:sndStream
                   withObject:[NSNumber numberWithUnsignedInteger:length]];
  }
}
// Stream finished processing bytes in buffer.
void _stream_buffer_empty(pa_stream *stream, int success, void *sndStream)
{
  if (isBufferEmpty != NO)
    return;
  
  isBufferEmpty = YES;
  [(SNDStream *)sndStream
      performDelegateSelector:@selector(soundStreamBufferEmpty:)];
}
static void _stream_paused(pa_stream *stream, int success, void *sndStream)
{
  [(SNDStream *)sndStream performDelegateSelector:@selector(soundStreamDidPause:)];
}
static void _stream_resumed(pa_stream *stream, int success, void *sndStream)
{
  [(SNDStream *)sndStream performDelegateSelector:@selector(soundStreamDidResume:)];
}

@implementation SNDStream

- (void)dealloc
{
  NSDebugLLog(@"Memory", @"[SNDStream] dealloc");
  if (_pa_stream != NULL)
    pa_stream_unref(_pa_stream);

  [_server release];
  [_device release];
    
  [super dealloc];
}

- (id)initOnDevice:(SNDDevice *)device
{
  return [self initOnDevice:device
               samplingRate:44100
               channelCount:2
                     format:PA_SAMPLE_FLOAT32LE
                       type:SNDEventType];
}
- (id)initOnDevice:(SNDDevice *)device
      samplingRate:(NSUInteger)rate
      channelCount:(NSUInteger)channels
            format:(NSUInteger)format
              type:(SNDStreamType)streamType
{
  pa_sample_spec sample_spec;
  pa_proplist    *proplist;
  char           *stream_media_role;

  if ((self = [super init]) == nil)
    return nil;

  // NSLog(@"[SNDStream] init on server: %@", device.server.hostName);

  if (device == nil) {
    self.server = [SNDServer sharedServer];
    self.device = (SNDDevice *)[_server defaultOutput];
  }
  else {
    self.device = device;
    self.server = device.server;
  }

  sample_spec.rate = rate;
  sample_spec.channels = channels;
  sample_spec.format = format;

  // Create stream
  proplist = pa_proplist_new();
  if (streamType > SNDApplicationType) {
    switch (streamType) {
    case SNDEventType:
      stream_media_role = "event";
      break;
    case SNDMusicType:
      stream_media_role = "music";
      break;
    case SNDVideoType:
      stream_media_role = "video";
      break;
    case SNDGameType:
      stream_media_role = "game";
      break;
    case SNDPhoneType:
      stream_media_role = "phone";
      break;
    case SNDAnimationType:
      stream_media_role = "animation";
      break;
    case SNDProductionType:
      stream_media_role = "production";
      break;
    case SNDAccessibilityType:
      stream_media_role = "a11y";
      break;
    case SNDTestType:
      stream_media_role = "test";
      break;
    default:
      break;
    }  
    pa_proplist_sets(proplist, PA_PROP_MEDIA_ROLE, stream_media_role);
  }
  _name = [[NSProcessInfo processInfo] processName];
  
  _pa_stream = pa_stream_new_with_proplist(_server.pa_ctx, [_name cString],
                                           &sample_spec, NULL, proplist);
  pa_xfree(proplist);
  
  return self;
}

- (id)delegate
{
  return _delegate;
}
- (void)setDelegate:(id)aDelegate
{
  _delegate = aDelegate;
}
- (void)performDelegateSelector:(SEL)action
{
  if (_delegate != nil && [_delegate respondsToSelector:action]) {
    [_delegate performSelector:action withObject:self];
  }
}

- (void)activate
{
  NSLog(@"[SoundKit] `activate` was send to SNDStream."
        " SNDPlayStream or SNDRecordStream subclasses should be used instead.");
}
- (void)deactivate
{
  NSLog(@"[SoundKit] `deactivate` was send to SNDStream."
        " SNDPlayStream or SNDRecordStream subclasses should be used instead.");
}
- (void)empty:(BOOL)flush
{
  if (flush == NO) {
    pa_stream_drain(_pa_stream, _stream_buffer_empty, self);
  }
  else {
    [self abort:self];
  }
}

- (BOOL)isPaused
{
  NSLog(@"[SoundKit] `isPaused` was send to SNDStream."
        " SNDPlayStream or SNDRecordStream subclasses should be used instead.");
  return NO;
}
- (void)pause:(id)sender
{
  pa_stream_cork(_pa_stream, 1, _stream_paused, self);
}
- (void)resume:(id)sender
{
  pa_stream_cork(_pa_stream, 0, _stream_resumed, self);
}
- (void)abort:(id)sender
{
  pa_stream_flush(_pa_stream, _stream_buffer_empty, self);
}


- (NSNumber *)bufferLength
{
  const pa_buffer_attr *buffer_attr;
  buffer_attr = pa_stream_get_buffer_attr(_pa_stream);

  return [NSNumber numberWithUnsignedInteger:buffer_attr->tlength];
}
- (NSUInteger)volume
{
  NSLog(@"[SoundKit] `volume` was send to SNDStream."
        " SNDPlayStream or SNDRecordStream subclasses should be used instead.");
  return 0;
}
- (void)setVolume:(NSUInteger)volume
{
  NSLog(@"[SoundKit] `setVolume` was send to SNDStream."
        " SNDPlayStream or SNDRecordStream subclasses should be used instead.");
}
- (CGFloat)balance
{
  NSLog(@"[SoundKit] `balance` was send to SNDStream."
        " SNDPlayStream or SNDRecordStream subclasses should be used instead.");
  return 0.0;
}
- (void)setBalance:(CGFloat)balance
{
  NSLog(@"[SoundKit] setBalance was send to SNDStream."
        " SNDPlayStream or SNDRecordStream subclasses should be used instead.");
}
- (void)setMute:(BOOL)isMute
{
  NSLog(@"[SoundKit] `setMute` was send to SNDStream."
        " SNDPlayStream or SNDRecordStream subclasses should be used instead.");
}
- (BOOL)isMute
{
  NSLog(@"[SoundKit] `isMute` was send to SNDStream."
        " SNDPlayStream or SNDRecordStream subclasses should be used instead.");
  return YES;
}

- (NSString *)activePort
{
  NSLog(@"[SoundKit] `activePort` was send to SNDStream."
        " SNDPlayStream or SNDRecordStream subclasses should be used instead.");
  return nil;
}
- (void)setActivePort:(NSString *)portName
{
  NSLog(@"[SoundKit] `setActivePort` was send to SNDStream."
        " SNDPlayStream or SNDRecordStream subclasses should be used instead.");
}


// - (NXSoundDeviceError)pauseAtTime:(struct timeval *)time;
// - (NXSoundDeviceError)resumeAtTime:(struct timeval *)time;
// - (NXSoundDeviceError)abortAtTime:(struct timeval *)time;

// - (unsigned int)bytesProcessed;
// - (NXSoundDeviceError)lastError;

@end
