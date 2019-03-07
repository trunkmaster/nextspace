/* -*- mode: objc -*- */
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

#import <Foundation/Foundation.h>
#import <SoundKit/SKSoundServer.h>

@class PACard;

@interface SKSoundDevice : NSObject // <SKSoundParameters>
{
  // SKSoundServer *_server;
}
@property (retain)   PACard        *card;
@property (readonly) SKSoundServer *server;

- (id)init;
- (id)initWithServer:(SKSoundServer *)server;
- (NSString *)host;
- (NSString *)name;
- (NSString *)cardDescription;
- (NSString *)description;
- (void)printDescription;

- (NSArray *)availableProfiles;
- (NSString *)activeProfile;
- (void)setActiveProfile:(NSString *)profileName;

// Subclass responsiblity
- (NSArray *)availablePorts;
- (NSString *)activePort;
- (void)setActivePort:(NSString *)portName;

- (NSUInteger)volumeSteps;
- (NSUInteger)volume;
- (void)setVolume:(NSUInteger)volume;

- (CGFloat)balance;
- (void)setBalance:(CGFloat)balance;

- (BOOL)isMute;
- (void)setMute:(BOOL)isMute;

@end
