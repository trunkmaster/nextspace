/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - DesktopKit framework
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

#import <AppKit/AppKitDefines.h>
#import <AppKit/NSSound.h>
#import <SoundKit/SNDServer.h>
#import <SoundKit/SNDPlayStream.h>

typedef NS_ENUM (NSUInteger, NXTSoundState) {
  NXTSoundInitial  = 0,
  NXTSoundPlay     = 1,
  NXTSoundPause    = 2,
  NXTSoundFinished = 3
};

@interface NXTSound : NSSound
{
  NSSound       *_sound;
  SNDPlayStream *_stream;
  NXTSoundState _state;
  SNDStreamType _streamType;
  BOOL          _isShort;
  NSTimer       *releaseTimer;
}

- (id)initWithContentsOfFile:(NSString *)path
                 byReference:(BOOL)byRef
                  streamType:(SNDStreamType)sType;

@end

