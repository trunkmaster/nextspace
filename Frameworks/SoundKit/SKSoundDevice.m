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

#import "PACard.h"
#import "PASink.h"
#import "SKSoundDevice.h"

@implementation SKSoundDevice

- (void)dealloc
{
  NSLog(@"[SKSoundDevice] dealloc");
  [_card release];
  [super dealloc];
}

- (id)init
{
  return [self initWithServer:[SKSoundServer sharedServer]];
}

- (id)initWithServer:(SKSoundServer *)server
{
  if ((self = [super init]) == nil)
    return nil;
  
  _server = server;
  
  return self;
}

// --- Accesorries --- //
- (NSString *)host
{
  return _server.hostName;
}
- (NSString *)description
{
  return [NSString stringWithFormat:@"PulseAudio Card `%@`", _card.name];
}
- (void)printDescription
{
  // Print header only if it's not subclass `super` call
  if ([self class] == [SKSoundDevice class] ) {
    fprintf(stderr, "+++ SKSoundDevice: %s +++\n", [[self description] cString]);
  }
  fprintf(stderr, "\t           Index : %lu\n", _card.index);
  fprintf(stderr, "\t            Name : %s\n", [_card.name cString]);
  fprintf(stderr, "\t    Retain Count : %lu\n", [self retainCount]);

  fprintf(stderr, "\t Output Profiles : \n");
  for (NSString *prof in _card.outProfiles) {
    NSString *profString;
    if ([prof isEqualToString:_card.activeProfile])
      profString = [NSString stringWithFormat:@"%s%@%s", "\e[1m- ", prof, "\e[0m"];
    else
      profString = [NSString stringWithFormat:@"%s%@%s", "- ", prof, ""];
    fprintf(stderr, "\t                 %s\n", [profString cString]);
  }
  
  fprintf(stderr, "\t  Input Profiles : \n");
  for (NSString *prof in _card.inProfiles) {
    NSString *profString;
    if ([prof isEqualToString:_card.activeProfile])
      profString = [NSString stringWithFormat:@"%s%@%s", "\e[1m- ", prof, "\e[0m"];
    else
      profString = [NSString stringWithFormat:@"%s%@%s", "- ", prof, ""];
    fprintf(stderr, "\t                 %s\n", [profString cString]);
  }
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
