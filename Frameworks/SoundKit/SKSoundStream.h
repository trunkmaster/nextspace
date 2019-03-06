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

#import "SKSoundServer.h"
#import "SKSoundDevice.h"

@class PASinkInput;
@class PAStream;
@class PAClient;

@interface SKSoundStream : NSObject
{
}
@property (readonly) SKSoundServer *server;

@property (nonatomic, assign) PASinkInput   *sinkInput;
@property (nonatomic, assign) PAStream      *stream;
@property (nonatomic, assign) PAClient      *client;
@property (nonatomic, assign) SKSoundDevice *device;

@property (readonly) NSString    *name;
@property (readonly) BOOL        isRestored;
@property (readonly) BOOL        isVirtual;
@property (readonly) BOOL        isPlayStream;
@property (readonly) BOOL        isRecordStream;

- (id)initWithRestoredStream:(PAStream *)stream
                      server:(SKSoundServer *)server;

// - (id)initOnDevice:(SKSoundDevice *)device;
// - initOnDevice:withParameters:
// - parameters;

// - (void)activate;
// - (void)deactivate;

// - abort:
// - abortAtTime:
// - pause:
// - pauseAtTime:
// - resume:
// - resumeAtTime:

// - bytesProcessed
// - isActive
// - isPaused
// - streamPort
// - lastError

// - setDelegate:
// - delegate
@end
