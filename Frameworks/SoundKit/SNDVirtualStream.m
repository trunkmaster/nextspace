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

#import <SoundKit/SNDServer.h>
#import <SoundKit/SNDVirtualStream.h>

#import "PAStream.h"
#import "PAClient.h"

#import "PASink.h"
#import "SNDOut.h"

@implementation SNDVirtualStream

- (void)dealloc
{
  NSDebugLLog(@"Memory", @"[SNDVirtualStream] dealloc");
  [super dealloc];
}

- (id)initWithStream:(PAStream *)stream
{
  if ((self = [super init]) == nil)
    return nil;

  _stream = stream;
  
  if (_stream == nil) {
    super.name = @"Dummy Virtual Stream";
  }
  else if ([[_stream typeName] isEqualToString:@"sink-input-by-media-role"] != NO) {
    if ([[_stream clientName] isEqualToString:@"event"] != NO) {
      super.name = @"System Sounds";
      super.isActive = YES;
      super.isPlayback = YES;
    }
  }
  else {
    super.name = _stream.clientName;
  }

  // fprintf(stderr, "[SoundKit] SoundStream: %s \t\tDevice: %s\n",
  //         [_stream.name cString], [_stream.deviceName cString]);
  
  return self;  
}

- (NSString *)appName
{
  return super.client.appName;
}

- (NSUInteger)volume
{
  return [_stream volume];
}
- (void)setVolume:(NSUInteger)volume
{
  [_stream applyVolume:volume];
}
- (CGFloat)balance
{
  return _stream.balance;
}
- (void)setBalance:(CGFloat)balance
{
  [_stream applyBalance:balance];
}
- (void)setMute:(BOOL)isMute
{
  [_stream applyMute:isMute];
}
- (BOOL)isMute
{
  return (BOOL)_stream.mute;
}

- (NSString *)activePort
{
  SNDServer *server = [SNDServer sharedServer];

  return [server defaultOutput].sink.activePort;
}

- (void)setActivePort:(NSString *)portName
{
  SNDServer *server = [SNDServer sharedServer];

  [[server defaultOutput].sink applyActivePort:portName];
}

@end
