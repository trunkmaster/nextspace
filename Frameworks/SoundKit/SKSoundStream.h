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
#import <SoundKit/SKSoundDevice.h>

@class PASinkInput;
@class PAStream;
@class PAClient;

@interface SKSoundStream : NSObject
{
  pa_stream *paStream;
}
@property (assign) SKSoundServer *server;

@property (nonatomic, assign) PASinkInput   *sinkInput;
@property (nonatomic, assign) PAClient      *client;
@property (nonatomic, assign) SKSoundDevice *device;

@property (assign)   NSString    *name;
@property (assign)   BOOL        isVirtual;
@property (assign)   BOOL        isPlayStream;
@property (assign)   BOOL        isRecordStream;

// Must be everriden in subclass: SoundPlayStream or SoundRecordStream
- (id)initOnDevice:(SKSoundDevice *)device
      samplingRate:(NSUInteger)rate
      channelCount:(NSUInteger)channels
            format:(NSUInteger)format;
- (void)activate;
- (void)deactivate;

- (NSUInteger)volume;
- (void)setVolume:(NSUInteger)volume;
- (CGFloat)balance;
- (void)setBalance:(CGFloat)balance;
- (BOOL)isMute;
- (void)setMute:(BOOL)isMute;

@end
