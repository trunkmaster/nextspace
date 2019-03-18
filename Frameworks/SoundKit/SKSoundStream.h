/* -*- mode: objc -*- */
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

#import <Foundation/Foundation.h>

#import <SoundKit/SKSoundServer.h>
#import <SoundKit/SKSoundDevice.h>

@class PAStream;
@class PAClient;

@interface SKSoundStream : NSObject
{
  pa_stream *_pa_stream;
}
@property (assign) SKSoundServer *server;
@property (assign) PAClient      *client;
@property (assign) SKSoundDevice *device;
@property (assign) NSString      *name;
@property (assign) BOOL          isActive;

// Must be everriden in subclass: SoundPlayStream or SoundRecordStream
- (id)initOnDevice:(SKSoundDevice *)device
      samplingRate:(NSUInteger)rate
      channelCount:(NSUInteger)channels
            format:(NSUInteger)format;

// Subclass responsibilty
- (void)activate;
- (void)deactivate;

- (NSUInteger)volume;
- (void)setVolume:(NSUInteger)volume;
- (CGFloat)balance;
- (void)setBalance:(CGFloat)balance;
- (BOOL)isMute;
- (void)setMute:(BOOL)isMute;

@end
