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

@class NXSoundOut;
@class NXSoundIn;

@class PACard;
@class PASink;

typedef enum NSInteger {
  SKServerNoConnnectionState,	// PA_CONTEXT_UNCONNECTED
  SKServerConnectingState,	// PA_CONTEXT_CONNECTING
  SKServerAuthorizingState,	// PA_CONTEXT_AUTHORIZING
  SKServerSettingNameState,	// PA_CONTEXT_SETTING_NAME
  SKServerReadyState,		// PA_CONTEXT_READY
  SKServerFailedState,		// PA_CONTEXT_FAILED
  SKServerTerminatedState,	// PA_CONTEXT_TERMINATED
  SKServerInventoryState
} SKConnectionState;

extern NSString *SKServerStateDidChangeNotification;
extern NSString *SKDeviceDidAddNotification;
extern NSString *SKDeviceDidChangeNotification;
extern NSString *SKDeviceDidRemoveNotification;

@interface NXSoundServer : NSObject
{
  // Define our pulse audio loop and connection variables
  pa_mainloop		*_pa_loop;
  pa_mainloop_api	*_pa_api;
  // pa_context		*_pa_ctx;
  pa_operation		*_pa_op;

  // SoundKit objects
  NSMutableArray        *outputList; // array of NXSoundOut objects
  NSMutableArray        *inputList;  // array of NXSoundIn objects
  NSMutableArray        *streamList; // array of NXSoundStream objects

  // NXSoundOut
  NSMutableArray        *cardList;
  NSMutableArray        *sinkList;
  NSMutableArray        *sourceList;
  // 
  NSMutableArray        *clientList;
  NSMutableArray        *sinkInputList;
  NSMutableArray        *sourceOutputList;
  NSMutableArray        *savedStreamList; // sink-input* or source-output*
}

@property (readonly) pa_context *pa_ctx;
@property (readonly) SKConnectionState state;
@property (readonly) NSString *userName;  // User name of the daemon process
@property (readonly) NSString *hostName;  // Host name the daemon is running on
@property (readonly) NSString *name;      // Server package name (usually "pulseaudio")
@property (readonly) NSString *version;   // Version string of the daemon
@property (readonly) NSString *defaultSinkName;
@property (readonly) NSString *defaultSourceName;

+ (id)defaultServer;

- (id)initOnHost:(NSString *)hostName;

@end

@interface NXSoundServer (PulseAudio)

- (PACard *)cardForSink:(PASink *)sink;
- (PASink *)sinkWithName:(NSString *)name;
// - (PASink *)sinkForSinkInput:(PASinkInput *)sinkInput;

@end
