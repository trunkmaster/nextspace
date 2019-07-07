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

// #import <Foundation/NSNotification.h>
#import "NXTSound.h"
#import <GNUstepGUI/GSSoundSource.h>

@implementation NXTSound

// --- Overridings
- (id)initWithContentsOfFile:(NSString *)path
                 byReference:(BOOL)byRef
{
  self = [super initWithContentsOfFile:path byReference:byRef];
  if (self == nil) {
    return nil;
  }

  NSLog(@"[NXTSound] channels: %lu rate: %lu format: %i",
        [_source channelCount], [_source sampleRate], [_source byteOrder]);

  _stream = [[SNDPlayStream alloc] initOnDevice:nil
                                   samplingRate:[_source sampleRate]
                                   channelCount:[_source channelCount]
                                         format:3 // PA
                                           type:SNDEventType];
  [_stream setDelegate:self];
  
  return self;
}

- (BOOL)play
{
  [_stream activate];  
}
- (BOOL)stop
{
  [_stream empty:NO];
}

- (BOOL)pause;
- (BOOL)resume;

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
  [_stream deactivate];
}

@end
