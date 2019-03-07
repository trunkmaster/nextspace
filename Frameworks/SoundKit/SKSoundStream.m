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

#import "PASinkInput.h"
#import "PAStream.h"
#import "PAClient.h"

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
  _isRestored = NO;
  _isVirtual = NO;
  _isPlayStream = NO;
  _isRecordStream = NO;
  return self;
}

- (id)initWithRestoredStream:(PAStream *)stream
                      server:(SKSoundServer *)server
{
  if ((self = [super init]) == nil)
    return nil;

  _server = server;

  [self setStream:stream];
  
  return self;  
}

- (void)setStream:(PAStream *)stream
{
  _stream = stream;
  if (_stream == nil) {
    _isVirtual = YES;
    _name = @"Dummy Stream";
  }
  else if ([[_stream typeName] isEqualToString:@"sink-input-by-media-role"] != NO &&
           [[_stream clientName] isEqualToString:@"event"] != NO) {
    _isVirtual = YES;
    _isPlayStream = YES;
    _name = @"System Sounds";
  }
  else {
    [self setClient:[_server clientWithName:[_stream clientName]]];
    _name = _stream.clientName;
    fprintf(stderr, "[SoundKit] SoundStream: %s \t\tSinkInput:`%s` \t\tClient:`%s`\n",
            [_stream.name cString], [_sinkInput.name cString], [_client.name cString]);
  }
}
- (void)setClient:(PAClient *)client
{
  _client = client;
  if (_client != nil) {
    [self setSinkInput:[_server sinkInputWithClientIndex:_client.index]];
  }
}
// TODO: Must be overriden by SKSoundPlayStream
- (void)setSinkInput:(PASinkInput *)sinkInput
{
  _sinkInput = sinkInput;
  if (_sinkInput != nil) {
    _isVirtual = NO;
    _isPlayStream = YES;
  }
}

// - (id)initWithSinkInput:(PAStream *)sink;
// - (id)initWithClient:(PAStream *)client;

@end
