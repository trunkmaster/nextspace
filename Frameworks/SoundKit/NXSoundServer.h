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

#import <pulse/pulseaudio.h>
#import <Foundation/Foundation.h>

@interface NXSoundServer : NSObject
{
  NSString 		*_host;
  // Define our pulse audio loop and connection variables
  pa_mainloop		*_pa_loop;
  pa_mainloop_api	*_pa_api;
  pa_context		*_pa_ctx;
  pa_operation		*_pa_op;

  // SoundKit objects
  NSMutableArray        *outputList; // array of NXSoundOut objects
  NSMutableArray        *inputList;  // array of NXSoundIn objects
  NSMutableArray        *streamList; // array of NXSoundStream objects

  // PulseAudio objects
  NSString              *defaultSinkName;
  NSString              *defaultSourceName;
  // NXSoundOut
  NSMutableArray        *cardList;
  NSMutableArray        *sinkList;
  NSMutableArray        *sourceList;
  NSMutableArray        *clientList;
  NSMutableArray        *sinkInputList;
  NSMutableArray        *sourceOutputList;
  NSMutableArray        *savedStreamList; // sink-input* or source-output*
}
+ (id)defaultServer;

- (id)init;
- (id)initOnHost:(NSString *)hostName
        withName:(NSString *)appName;
- (NSString *)host;

@end
