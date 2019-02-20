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

#import "NXSoundDevice.h"

@implementation NXSoundDevice

- (void)dealloc
{
  // [_server release];
  [super dealloc];
}

- (id)init
{
  return [self initOnHost:nil];
}

- (id)initOnHost:(NSString *)hostName
{
  self = [super init];
  
  _server = [NXSoundServer defaultServer];
  // [_server retain];
  
  // Wait for server to become ready
  // while (_server.state != SKServerReadyState) {
  //   [[NSRunLoop currentRunLoop]
  //     runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
  //   fprintf(stderr, "[SoundKit] SoundDevice: waiting for server to be ready...\n");
  // }
  return self;
}

// --- Accesorries --- //
- (NSString *)host
{
  return _server.hostName;
}
- (NSString *)description
{
  return [NSString stringWithFormat:@"Card `%@` on server `%@`",
                   _card.name, _server.hostName];
}

// --- Card proxy --- //
- (NSArray *)availableProfiles
{
  if (_card == nil) {
    NSLog(@"SoundDevice: avaliablePorts was called without Sink was being set.");
    return nil;
  }
  return _card.outProfiles;
}
- (NSString *)activeProfile:(NSString *)profileName
{
  return _card.activeProfile;
}
- (void)setActiveProfile:(NSString *)profile
{
  pa_context_set_card_profile_by_name(_server.pa_ctx,
                                      [_card.name cString],
                                      [profile cString],
                                      NULL, // pa_context_success_cb_t cb,
                                      self);
}

- (id)volume
{
  return nil;
}
- (NSUInteger)volumeSteps
{
  return 0;
}
- (void)setVolume:(id)volumes
{} // subclass responsibility
// - samples
// {}
// - latency
// {}

@end
