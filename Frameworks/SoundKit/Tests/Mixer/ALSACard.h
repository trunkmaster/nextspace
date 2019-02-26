/*
   Project: Mixer

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

#import <alsa/asoundlib.h>
#import <Foundation/Foundation.h>

#import <dispatch/dispatch.h>

@interface ALSACard : NSObject
{
  NSString       *cardName;
  NSString       *chipName;
  NSString       *deviceName;
  
  snd_mixer_t    *alsa_mixer;

  NSMutableArray *controls;

  NSTimer        *timer;
  
  dispatch_queue_t event_loop_q;
  __block BOOL   shouldHandleEvents;
  __block BOOL   isEventLoopActive;
  __block BOOL   isEventLoopDidQuit;
  BOOL           isEventLoopDispatched;
}

- initWithNumber:(int)number;
- (void)handleEvents:(BOOL)oneTime;
- (void)setShouldHandleEvents:(BOOL)yn;
- (void)enterEventLoop;
- (void)pauseEventLoop;
- (void)resumeEventLoop;
- (void)quitEventLoop;

// - (void)setShouldHandleEvents:(BOOL)yn;
  
- (NSString *)name;
- (NSString *)chipName;
- (NSArray *)controls;

- (snd_mixer_t *)mixer;
- (snd_mixer_t *)createMixer;
- (void)deleteMixer:(snd_mixer_t *)mixer;

@end

