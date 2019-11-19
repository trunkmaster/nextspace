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

#import <SoundKit/SNDServer.h>
#import <SoundKit/SNDDevice.h>

@class PAStream;
@class PAClient;

typedef NS_ENUM(NSUInteger, SNDStreamType) {
  SNDApplicationType = 0,
  SNDEventType,
  SNDMusicType,
  SNDVideoType,
  SNDGameType,
  SNDPhoneType,
  SNDAnimationType,
  SNDProductionType,
  SNDAccessibilityType,
  SNDTestType
};

@interface SNDStream : NSObject
{
  pa_stream *_pa_stream;
  id        _delegate;
}
@property (retain) SNDServer *server;
@property (assign) PAClient  *client;
@property (retain) SNDDevice *device;
@property (assign) NSString  *name;
@property (assign) BOOL      isActive;
@property (assign) BOOL      isPlayback;

// Must be everriden in subclass: SoundPlayStream or SoundRecordStream
- (id)initOnDevice:(SNDDevice *)device
      samplingRate:(NSUInteger)rate
      channelCount:(NSUInteger)channels
            format:(NSUInteger)format
              type:(SNDStreamType)streamType;

- (id)delegate;
- (void)setDelegate:(id)aDelegate;
- (void)performDelegateSelector:(SEL)action;

// Subclass responsibilty
- (BOOL)isActive;
- (void)activate;
- (void)deactivate;
- (void)empty:(BOOL)flush;

- (BOOL)isPaused;
- (void)pause:(id)sender;
- (void)resume:(id)sender;
- (void)abort:(id)sender;

- (NSNumber *)bufferLength;
- (NSUInteger)volume;
- (void)setVolume:(NSUInteger)volume;
- (CGFloat)balance;
- (void)setBalance:(CGFloat)balance;
- (BOOL)isMute;
- (void)setMute:(BOOL)isMute;

- (NSString *)activePort;
- (void)setActivePort:(NSString *)portName;

// - (NXSoundDeviceError)pauseAtTime:(struct timeval *)time;
// - (NXSoundDeviceError)resumeAtTime:(struct timeval *)time;
// - (NXSoundDeviceError)abortAtTime:(struct timeval *)time;

// - (unsigned int)bytesProcessed;
// - (NXSoundDeviceError)lastError;
// - (id)delegate;
// - (void)setDelegate:(id)anObject;

@end
