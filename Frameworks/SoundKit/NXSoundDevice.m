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
                                      
#import "NXSoundServer.h"
#import "NXSoundDevice.h"
#import "NXSoundDeviceCallbacks.h"

@implementation NXSoundDevice

- (void)dealloc
{
  [_server release];
  [super dealloc];
}

- (id)init
{
  return [self initOnHost:nil withName:@"SoundKit"];
}

- (id)initOnHost:(NSString *)hostName
        withName:(NSString *)appName
{
  [super init];
  _server = [[NXSoundServer alloc] initOnHost:hostName withName:appName];
  return self;
}

/*--- Accesorries ---*/
- (NSString *)host
{
  return [(NXSoundServer *)_server host];
}

/*--- Sink ---*/
- (NSString *)name
{
  return _name;
}
- (NSString *)description
{
  return _description;
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
- (NSArray *)availablePorts
{
  return nil;
}
- (NSDictionary *)activePort
{
  return nil;
}
- (void)setActivePort:(NSString *)name
{} // subclass responsibility

/*--- Card ---*/
- (NSArray *)availableProfiles
{
  return nil;
}
- (NSDictionary *)activeProfile
{
  return nil;
}
- (void)setActiveProfile:(NSString *)name
{} // subclass responsibility

// - samples
// {}
// - latency
// {}

@end
