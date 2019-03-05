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
- (NSString *)name
{
  return _card.description;
}
- (NSString *)description
{
  return _card.description;
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

  fprintf(stderr, "\t        Profiles : \n");
  for (NSDictionary *prof in _card.profiles) {
    NSString *profDesc, *profString;
    profDesc = prof[@"Description"];
    if ([profDesc isEqualToString:_card.activeProfile])
      profString = [NSString stringWithFormat:@"%s%@%s", "\e[1m- ", profDesc, "\e[0m"];
    else
      profString = [NSString stringWithFormat:@"%s%@%s", "- ", profDesc, ""];
    fprintf(stderr, "\t                 %s\n", [profString cString]);
  }
}

// --- Card proxy --- //
- (NSArray *)availableProfiles
{
  if (_card == nil) {
    NSLog(@"SoundDevice: avaliableProfiles was called without Card was being set.");
    return nil;
  }
  return _card.profiles;
}
- (NSString *)activeProfile
{
  return _card.activeProfile;
}
- (void)setActiveProfile:(NSString *)profileName
{
  if (_card == nil) {
    NSLog(@"SoundDevice: setActiveProfile was called without Card was being set.");
    return;
  }
  [_card applyActiveProfile:profileName];
}

// Subclass responsiblity
- (NSArray *)availableCardPorts
{
  return nil;
}
- (NSArray *)availablePorts
{
  return [_card.outPorts arrayByAddingObjectsFromArray:_card.inPorts];
}
- (NSString *)activePort
{
  return nil;
}
- (void)setActivePort:(NSString *)portName
{
  NSLog(@"[SoundKit] setActivePort: was send to SKSoundDevice."
        " SKSoundOut or SKSoundIn subclasses should be used instead.");
}

- (NSUInteger)volumeSteps
{
  return 0;
}
- (NSUInteger)volume
{
  return 0;
}
- (void)setVolume:(NSUInteger)volume
{
  NSLog(@"[SoundKit] setVolume: was send to SKSoundDevice."
        " SKSoundOut or SKSoundIn subclasses should be used instead.");
}

- (CGFloat)balance
{
  return 0.0;
}
- (void)setBalance:(CGFloat)balance
{
}

- (BOOL)isMute
{
  return NO;
}
- (void)setMute:(BOOL)isMute
{
  NSLog(@"[SoundKit] setMute: was send to SKSoundDevice. "
        "SKSoundOut or SKSoundIn subclasses should be used instead.");
}

@end
