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

#import <pulse/pulseaudio.h>
#import <Foundation/Foundation.h>

@class SNDDevice;
@class SNDOut;
@class SNDIn;
@class SNDStream;

@class PACard;
@class PASink;
@class PASource;
@class PASinkInput;
@class PASourceOutput;
@class PAClient;

typedef NS_ENUM(NSInteger, SNDConnectionState) {
  SNDServerNoConnnectionState	= 0,	// PA_CONTEXT_UNCONNECTED
  SNDServerConnectingState	= 1,	// PA_CONTEXT_CONNECTING
  SNDServerAuthorizingState	= 2,	// PA_CONTEXT_AUTHORIZING
  SNDServerSettingNameState	= 3,	// PA_CONTEXT_SETTING_NAME
  SNDServerReadyState		= 4,	// PA_CONTEXT_READY
  SNDServerFailedState		= 5,	// PA_CONTEXT_FAILED
  SNDServerTerminatedState	= 6,	// PA_CONTEXT_TERMINATED
  SNDServerInventoryState	= 7
};

extern NSString *SNDServerStateDidChangeNotification;
extern NSString *SNDDeviceDidAddNotification;
extern NSString *SNDDeviceDidChangeNotification;
extern NSString *SNDDeviceDidRemoveNotification;

@interface SNDServer : NSObject
{
  // Define our pulse audio loop and connection variables
  pa_mainloop		*_pa_loop;
  pa_mainloop_api	*_pa_api;
  pa_operation		*_pa_op;

  // SNDDevice
  NSMutableArray        *cardList;
  // SNDOut
  NSMutableArray        *sinkList;
  // SNDIn
  NSMutableArray        *sourceList;
  // SNDStream
  NSMutableArray        *clientList;
  NSMutableArray        *sinkInputList;
  NSMutableArray        *sourceOutputList;
  NSMutableArray        *savedStreamList; // sink-input* or source-output*
}

@property (readonly) pa_context         *pa_ctx;
@property (readonly) SNDConnectionState status;
@property (readonly) NSString           *statusDescription;

@property (readonly) NSString *userName;  // User name of the daemon process
@property (readonly) NSString *hostName;  // Host name the daemon is running on
@property (readonly) NSString *name;      // Server package name (usually "pulseaudio")
@property (readonly) NSString *version;   // Version string of the daemon
@property (readonly) NSString *defaultSinkName;
@property (readonly) NSString *defaultSourceName;

+ (id)sharedServer;

- (id)initOnHost:(NSString *)hostName;
- (void)connect;
- (void)disconnect;

- (SNDDevice *)defaultCard;
- (NSArray *)cardList;

- (SNDOut *)outputWithSink:(PASink *)sink;
- (SNDOut *)defaultOutput;
- (NSArray *)outputList;

- (SNDIn *)defaultInput;
- (NSArray *)inputList;

- (SNDStream *)defaultPlayStream;
- (NSArray *)streamList;

@end

@interface SNDServer (PulseAudio)

// Server
- (void)updateConnectionState:(NSNumber *)state;
- (void)updateServer:(NSValue *)value;
// Card
- (void)updateCard:(NSValue *)value;
- (PACard *)cardWithIndex:(NSUInteger)index;
- (void)removeCardWithIndex:(NSUInteger)index;
// Sink
- (void)updateSink:(NSValue *)value;
- (PASink *)sinkWithIndex:(NSUInteger)index;
- (PASink *)sinkWithName:(NSString *)name;
- (void)removeSinkWithIndex:(NSUInteger)index;
// Source
- (void)updateSource:(NSValue *)value;
- (PASource *)sourceWithIndex:(NSUInteger)index;
- (PASource *)sourceWithName:(NSString *)name;
- (void)removeSourceWithIndex:(NSUInteger)index;
// Sink Input
- (void)updateSinkInput:(NSValue *)value;
- (PASinkInput *)sinkInputWithIndex:(NSUInteger)index;
- (PASinkInput *)sinkInputWithClientIndex:(NSUInteger)index;
- (void)removeSinkInputWithIndex:(NSUInteger)index;
// Source Output
- (void)updateSourceOutput:(NSValue *)value;
- (PASourceOutput *)sourceOutputWithClientIndex:(NSUInteger)index;
- (PASourceOutput *)sourceOutputWithIndex:(NSUInteger)index;
- (void)removeSourceOutputWithIndex:(NSUInteger)index;
// Client
- (void)updateClient:(NSValue *)value;
- (PAClient *)clientWithIndex:(NSUInteger)index;
- (PAClient *)clientWithName:(NSString *)name;
- (void)removeClientWithIndex:(NSUInteger)index;
// Restored Stream
- (void)updateStream:(NSValue *)value;

@end
