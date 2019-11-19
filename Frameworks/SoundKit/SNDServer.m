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
                                      
#import <dispatch/dispatch.h>

#import "PACard.h"
#import "PASink.h"
#import "PASource.h"
#import "PASinkInput.h"
#import "PASourceOutput.h"
#import "PAClient.h"
#import "PAStream.h"

#import <SoundKit/SNDDevice.h>
#import <SoundKit/SNDOut.h>
#import <SoundKit/SNDIn.h>
#import <SoundKit/SNDPlayStream.h>
#import <SoundKit/SNDRecordStream.h>
#import <SoundKit/SNDVirtualStream.h>
#import <SoundKit/SNDServer.h>

#import "SNDServerCallbacks.h"

static dispatch_queue_t _pa_q = NULL;
static SNDServer        *_server = nil;
static BOOL             mainLoopRunning = NO;

NSString *SNDServerStateDidChangeNotification = @"SNDServerStateDidChangeNotification";
NSString *SNDDeviceDidAddNotification    = @"SNDDeviceDidAddNotification";
NSString *SNDDeviceDidChangeNotification = @"SNDDeviceDidChangeNotification";
NSString *SNDDeviceDidRemoveNotification = @"SNDDeviceDidRemoveNotification";

@implementation SNDServer

// + (void)initialize
// {
//   if ([SNDServer class] == self) {
//     _server = [SNDServer new];
//   }
// }
+ (id)sharedServer
{
  if (_server == nil) {
    [SNDServer new];
  }
  return _server;
}

- (void)dealloc
{
  NSDebugLLog(@"Memory", @"[SNDServer] dealloc");

  // pa_context_unref(_pa_ctx);
  // pa_mainloop_free(_pa_loop);
  
  [cardList release];
  [sinkList release];
  [sourceList release];
  [clientList release];
  [sinkInputList release];
  [sourceOutputList release];
  [savedStreamList release];
  
  [_userName release];
  [_hostName release];
  [_name release];
  [_version release];
  [_defaultSinkName release];
  [_defaultSourceName release];
  
  [super dealloc];
}
- (id)init
{
  return [self initOnHost:nil];
}
- (id)initOnHost:(NSString *)hostName
{
  [super init];

  _status = SNDServerNoConnnectionState;

  if (hostName != nil) {
    _hostName = [hostName copy];
  }
  else {
    _hostName = [[NSString alloc] initWithString:@"localhost"];
  }

  cardList = [NSMutableArray new];
  sinkList = [NSMutableArray new];
  sourceList = [NSMutableArray new];
  clientList = [NSMutableArray new];
  sinkInputList = [NSMutableArray new];
  sourceOutputList = [NSMutableArray new];
  savedStreamList = [NSMutableArray new];

  _pa_loop = NULL;
  _pa_api = NULL;
  _pa_ctx = NULL;
  
  _server = self;
  
  return self;
}
- (void)connect
{
  const char *host_name = NULL;
  
  if (mainLoopRunning != NO) {
    return;
  }

  if (_pa_ctx == NULL) {
    pa_proplist *proplist;
    const char  *app_name = NULL;

    _pa_loop = pa_mainloop_new();
    _pa_api = pa_mainloop_get_api(_pa_loop);

    app_name = [[[NSProcessInfo processInfo] processName] cString];
  
    proplist = pa_proplist_new();
    pa_proplist_sets(proplist, PA_PROP_APPLICATION_NAME, app_name);
    pa_proplist_sets(proplist, PA_PROP_APPLICATION_ID, "org.nextspace.soundkit");
    pa_proplist_sets(proplist, PA_PROP_APPLICATION_ICON_NAME, "audio-card");
    pa_proplist_sets(proplist, PA_PROP_APPLICATION_VERSION, "0.1");

    _pa_ctx = pa_context_new_with_proplist(_pa_api, app_name, proplist);
    pa_context_set_state_callback(_pa_ctx, context_state_cb, self);
    
    pa_proplist_free(proplist);
  }
  
  if (_hostName && [_hostName isEqualToString:@"localhost"] == NO) {
    host_name = [_hostName cString];
  }
  pa_context_connect(_pa_ctx, host_name, 0, NULL);
  
  _pa_q = dispatch_queue_create("org.nextspace.soundkit", NULL);
  dispatch_async(_pa_q, ^{
      NSDebugLLog(@"SoundKit", @"[SNDServer] >>> PulseAudio mainloop started.");
      while (pa_mainloop_iterate(_pa_loop, 1, NULL) >= 0) { ; }
      NSDebugLLog(@"SoundKit", @"[SNDServer] <<< PulseAudio mainloop exited.");
    });
  mainLoopRunning = YES;
}
- (void)disconnect
{
  int retval = 0;
  
  NSDebugLLog(@"SoundKit", @"[SNDServer] === disconnect === START");
  if (_pa_ctx) {
    NSDebugLLog(@"SoundKit", @"[SNDServer] disconnect: clear PA context...");
    pa_context_disconnect(_pa_ctx);
    pa_context_set_state_callback(_pa_ctx, NULL, NULL);
    pa_context_unref(_pa_ctx);
    _pa_ctx = NULL;
  }
  if (_pa_loop) {
    NSDebugLLog(@"SoundKit", @"[SNDServer] disconnect: stop PA mainloop...");
    pa_mainloop_quit(_pa_loop, retval);
    pa_mainloop_free(_pa_loop);
  }
  if (_pa_q) {
    NSDebugLLog(@"SoundKit", @"[SNDServer] disconnect: release GCD queue...");
    dispatch_release(_pa_q);
    _pa_q = NULL;
  }
  mainLoopRunning = NO;
  NSDebugLLog(@"SoundKit", @"[SNDServer] === disconnect === END");
}

- (SNDDevice *)defaultCard
{
  NSArray   *cards = [self cardList];
  PACard    *defOutCard = [self defaultOutput].card;
  SNDDevice *defCard;

  for (SNDDevice *device in cards) {
    if (device.card == defOutCard) {
      defCard = device;
      break;
    }
  }  
    
  return defCard;
}
- (NSArray *)cardList
{
  NSMutableArray *list = [NSMutableArray new];
  SNDDevice  *device;

  for (PACard *card in cardList) {
    device = [[SNDDevice alloc] initWithServer:self];
    device.card = card;
    [list addObject:device];
    [device release];
  }
  return [list autorelease];
}

- (SNDOut *)outputWithSink:(PASink *)sink
{
  SNDOut *output;

  output = [[SNDOut alloc] init];
  output.card = [self cardWithIndex:sink.cardIndex];
  output.sink = sink;

  return [output autorelease];
}
- (SNDOut *)defaultOutput
{
  if (_defaultSinkName == nil || [_defaultSinkName length] == 0) {
    return [[self outputList] objectAtIndex:0];
  }
  
  return [self outputWithSink:[self sinkWithName:_defaultSinkName]];
}
- (NSArray *)outputList
{
  NSMutableArray *list = [NSMutableArray new];

  for (PASink *sink in sinkList) {
    [list addObject:[self outputWithSink:sink]];
  }
  return [list autorelease];
}

- (SNDIn *)inputWithSource:(PASource *)source
{
  SNDIn *input;

  input = [[SNDIn alloc] init];
  input.card = [self cardWithIndex:source.cardIndex];
  input.source = source;

  return [input autorelease];
}
- (SNDIn *)defaultInput
{
  return [self inputWithSource:[self sourceWithName:_defaultSourceName]];
}
- (NSArray *)inputList
{
  NSMutableArray *list = [NSMutableArray new];

  for (PASource *source in sourceList) {
    [list addObject:[self inputWithSource:source]];
  }
  return [list autorelease];
}

- (SNDStream *)defaultPlayStream
{
  for (SNDVirtualStream *st in [self streamList]) {
    if ([st isKindOfClass:[SNDPlayStream class]] &&
        [st.stream.clientName isEqualToString:@"event"]) {
      return st;
    }
  }
  return nil;
}
- (NSArray *)streamList
{
  NSMutableArray   *list = [NSMutableArray new];
  SNDVirtualStream *virtualStream;
  SNDPlayStream    *playStream;
  SNDRecordStream  *recordStream;
  PASource         *source;
  PAClient         *client;

  // Pure virtual streams
  for (PAStream *stream in savedStreamList) {
    virtualStream = [[SNDVirtualStream alloc] initWithStream:stream];
    [list addObject:virtualStream];
    [virtualStream release];
  }
  // Streams with SinkInput and Client
  for (PASinkInput *sinkInput in sinkInputList) {
    client = [self clientWithIndex:sinkInput.clientIndex];
    if (client != nil &&
        (sinkInput.mediaRole == nil || [sinkInput.mediaRole isEqualToString:@""])) {
      playStream = [SNDPlayStream new];
      playStream.client = client;
      playStream.server = self;
      playStream.device = [self outputWithSink:[self sinkWithIndex:sinkInput.sinkIndex]];
      playStream.name = playStream.client.appName;
      playStream.sinkInput = sinkInput;
      [list addObject:playStream];
      NSDebugLLog(@"SoundKit", @"SNDPlayStream was added to list: %@ (%@)",
                  playStream.name, sinkInput.mediaRole);
      [playStream release];
    }
  }
  // Streams with SourceOuput and Client
  for (PASourceOutput *sourceOutput in sourceOutputList) {
    source = [self sourceWithIndex:sourceOutput.sourceIndex];
    if (source.isMonitor == NO) {
      recordStream = [SNDRecordStream new];
      recordStream.client = [self clientWithIndex:sourceOutput.clientIndex];
      if (recordStream.client != nil) {
        recordStream.server = self;
        recordStream.device = [self inputWithSource:source];
        recordStream.name = recordStream.client.appName;
        recordStream.sourceOutput = sourceOutput;
        [list addObject:recordStream];
        NSDebugLLog(@"SoundKit", @"SNDRecordStream was added to list: %@",
                    recordStream.name);
      }
      [recordStream release];
    }
  }

  return [list autorelease];
}

@end

@implementation SNDServer (PulseAudio)

// Server
- (void)updateConnectionState:(NSNumber *)state
{
  _status = [state intValue];
  if (_statusDescription != nil) {
    [_statusDescription release];
  }
  _statusDescription = [[NSString alloc]
                           initWithCString:pa_strerror(pa_context_errno(_pa_ctx))];
  NSDebugLLog(@"SoundKit", @"[SNDServer] connection state was updated - %li.",
              _status);
  [[NSNotificationCenter defaultCenter]
      postNotificationName:SNDServerStateDidChangeNotification
                    object:self];
}
- (void)updateServer:(NSValue *)value // server_info_cb(...)
{
  const pa_server_info *info;

  info = malloc(sizeof(const pa_server_info));
  [value getValue:(void *)info];

  _userName = [[NSString alloc] initWithCString:info->user_name];
  // if (_hostName == nil) {
  //   _hostName = [[NSString alloc] initWithCString:info->host_name];
  // }
  _name = [[NSString alloc] initWithCString:info->server_name];
  _version = [[NSString alloc] initWithCString:info->server_version];
  _defaultSinkName = [[NSString alloc] initWithCString:info->default_sink_name];
  _defaultSourceName = [[NSString alloc] initWithCString:info->default_source_name];

  free((void *)info);
}

// Card
- (void)updateCard:(NSValue *)value // card_sb(...)
{
  const pa_card_info *info;
  BOOL               isUpdated = NO;
  PACard             *card;

  // Convert PA structure into NSDictionary
  info = malloc(sizeof(const pa_card_info));
  [value getValue:(void *)info];

  for (card in cardList) {
    if (card.index == info->index) {
      NSDebugLLog(@"SoundKit", @"[SNDServer] Card Update: %s.", info->name);
      [card updateWithValue:value];
      isUpdated = YES;
      break;
    }
  }

  if (isUpdated == NO) {
    SNDDevice *soundDevice;
    card = [[PACard alloc] init];
    NSDebugLLog(@"SoundKit", @"[SNDServer] Card Add: %s.", info->name);
    card.context = _pa_ctx;
    [card updateWithValue:value];
    [cardList addObject:card];
    [card release];
  }
  
  free((void *)info);
}
- (PACard *)cardWithIndex:(NSUInteger)index
{
  for (PACard *card in cardList) {
    if (card.index == index) {
      return card;
    }
  }
  return nil;
}
- (void)removeCardWithIndex:(NSUInteger)index // context_subscribe_cb(...)
{
  PACard *card = [self cardWithIndex:index];

  if (card != nil) {
    [cardList removeObject:card];
  }
}

// Sink
- (void)updateSink:(NSValue *)value // sink_cb(...)
{
  const pa_sink_info *info;
  PASink             *sink;
  BOOL               isUpdated = NO;
  NSNotification     *aNotif;

  // Convert PA structure into NSDictionary
  info = malloc(sizeof(const pa_sink_info));
  [value getValue:(void *)info];

  for (sink in sinkList) {
    if (sink.index == info->index) {
      NSDebugLLog(@"SoundKit", @"[SNDServer] Sink Update: %s.", info->name);
      [sink updateWithValue:value];
      isUpdated = YES;
      aNotif = [NSNotification notificationWithName:SNDDeviceDidChangeNotification
                                             object:[self outputWithSink:sink]];
      break;
    }
  }

  if (isUpdated == NO) {
    // Create Sink
    sink = [[PASink alloc] init];
    NSDebugLLog(@"SoundKit", @"[SNDServer] Sink Add: %s.", info->name);
    [sink updateWithValue:value];
    sink.context = _pa_ctx;
    [sinkList addObject:sink];
    [sink release];
    aNotif = [NSNotification notificationWithName:SNDDeviceDidAddNotification
                                           object:[self outputWithSink:sink]];
  }
  [[NSNotificationCenter defaultCenter] postNotification:aNotif];
  
  free((void *)info);  
}
- (PASink *)sinkWithIndex:(NSUInteger)index
{
  for (PASink *sink in sinkList) {
    if (sink.index == index) {
      return sink;
    }
  }
  return nil;
}
- (PASink *)sinkWithName:(NSString *)name
{
  for (PASink *sink in sinkList) {
    if ([name isEqualToString:sink.name]) {
      return sink;
    }
  }
  return nil;
}
- (void)removeSinkWithIndex:(NSUInteger)index // context_subscribe_cb(...)
{
  PASink *sink = [self sinkWithIndex:index];

  if (sink != nil) {
    [sinkList removeObject:sink];
  }  
}

// Source
- (void)updateSource:(NSValue *)value // source_cb(...)
{
  const pa_source_info *info;
  PASource             *source;
  BOOL                 isUpdated = NO;
  NSNotification       *aNotif;

  // Convert PA structure into NSDictionary
  info = malloc(sizeof(const pa_source_info));
  [value getValue:(void *)info];

  for (source in sourceList) {
    if (source.index == info->index) {
      NSDebugLLog(@"SoundKit", @"[SNDServer] Source Update: %s.", info->name);
      [source updateWithValue:value];
      isUpdated = YES;
      aNotif = [NSNotification notificationWithName:SNDDeviceDidChangeNotification
                                             object:[self inputWithSource:source]];
      break;
    }
  }

  if (isUpdated == NO) {
    source = [[PASource alloc] init];
    NSDebugLLog(@"SoundKit", @"[SNDServer] Source Add: %s.", info->name);
    [source updateWithValue:value];
    source.context = _pa_ctx;
    [sourceList addObject:source];
    [source release];
    aNotif = [NSNotification notificationWithName:SNDDeviceDidAddNotification
                                           object:[self inputWithSource:source]];
  }
  
  [[NSNotificationCenter defaultCenter] postNotification:aNotif];
  
  free((void *)info);  
}
- (PASource *)sourceWithIndex:(NSUInteger)index
{
  for (PASource *source in sourceList) {
    if (source.index == index) {
      return source;
    }
  }
  return nil;
}
- (PASource *)sourceWithName:(NSString *)name
{
  for (PASource *source in sourceList) {
    if ([name isEqualToString:source.name]) {
      return source;
    }
  }
  return nil;
}
- (void)removeSourceWithIndex:(NSUInteger)index // context_subscribe_cb(...)
{
  PASource *source = [self sourceWithIndex:index];

  if (source != nil) {
    [sourceList removeObject:source];
  }  
}

// Sink Input
- (void)updateSinkInput:(NSValue *)value // sink_input_cb(...)
{
  const pa_sink_input_info *info;
  PASinkInput              *sinkInput;
  BOOL                     isUpdated = NO;
  NSNotification           *aNotif;

  // Convert PA structure into NSDictionary
  info = malloc(sizeof(const pa_sink_input_info));
  [value getValue:(void *)info];

  for (sinkInput in sinkInputList) {
    if (sinkInput.index == info->index) {
      NSDebugLLog(@"SoundKit", @"[SNDServer] Sink Input Update: %s.", info->name);
      [sinkInput updateWithValue:value];
      isUpdated = YES;
      aNotif = [NSNotification notificationWithName:SNDDeviceDidChangeNotification
                                             object:self];
      break;
    }
  }

  if (isUpdated == NO) {
    sinkInput = [[PASinkInput alloc] init];
    NSDebugLLog(@"SoundKit", @"[SNDServer] Sink Input Add: %s.", info->name);
    [sinkInput updateWithValue:value];
    sinkInput.context = _pa_ctx;
    [sinkInputList addObject:sinkInput];
    [sinkInput release];
    aNotif = [NSNotification notificationWithName:SNDDeviceDidAddNotification
                                           object:self];
  }
  [[NSNotificationCenter defaultCenter] postNotification:aNotif];
  
  free((void *)info);
}
- (PASinkInput *)sinkInputWithClientIndex:(NSUInteger)index
{
  for (PASinkInput *sinkInput in sinkInputList) {
    if (sinkInput.clientIndex == index) {
      return sinkInput;
    }
  }
  return nil;
}
- (PASinkInput *)sinkInputWithIndex:(NSUInteger)index
{
  for (PASinkInput *sinkInput in sinkInputList) {
    if (sinkInput.index == index) {
      return sinkInput;
    }
  }
  return nil;
}
- (void)removeSinkInputWithIndex:(NSUInteger)index // context_subscribe_cb(...)
{
  PASinkInput    *sinkInput = [self sinkInputWithIndex:index];
  NSNotification *aNotif;
  if (sinkInput != nil) {
    [sinkInputList removeObject:sinkInput];
    aNotif = [NSNotification notificationWithName:SNDDeviceDidRemoveNotification
                                           object:self];
    [[NSNotificationCenter defaultCenter] postNotification:aNotif];
  }
}

// TODO: Source Output
- (void)updateSourceOutput:(NSValue *)value // source_outout_cb(...)
{
  const pa_source_output_info *info;
  PASourceOutput              *sourceOutput;
  BOOL                        isUpdated = NO;
  NSNotification              *aNotif;

  // Convert PA structure into NSDictionary
  info = malloc(sizeof(const pa_source_output_info));
  [value getValue:(void *)info];

  for (sourceOutput in sourceOutputList) {
    if (sourceOutput.index == info->index) {
      NSDebugLLog(@"SoundKit", @"[SNDServer] Source Output Update: %s.", info->name);
      [sourceOutput updateWithValue:value];
      isUpdated = YES;
      aNotif = [NSNotification notificationWithName:SNDDeviceDidChangeNotification
                                             object:self];
      break;
    }
  }

  if (isUpdated == NO) {
    sourceOutput = [[PASourceOutput alloc] init];
    NSDebugLLog(@"SoundKit", @"[SNDServer] Source Output Add: %s.", info->name);
    [sourceOutput updateWithValue:value];
    sourceOutput.context = _pa_ctx;
    [sourceOutputList addObject:sourceOutput];
    [sourceOutput release];
    aNotif = [NSNotification notificationWithName:SNDDeviceDidAddNotification
                                           object:self];
  }
  [[NSNotificationCenter defaultCenter] postNotification:aNotif];
 
  free((void *)info);
}
- (PASourceOutput *)sourceOutputWithClientIndex:(NSUInteger)index
{
  for (PASourceOutput *sourceOutput in sourceOutputList) {
    if (sourceOutput.clientIndex == index) {
      return sourceOutput;
    }
  }
  return nil;
}
- (PASourceOutput *)sourceOutputWithIndex:(NSUInteger)index
{
  for (PASourceOutput *sourceOutput in sourceOutputList) {
    if (sourceOutput.index == index) {
      return sourceOutput;
    }
  }
  return nil;
}
- (void)removeSourceOutputWithIndex:(NSUInteger)index // context_subscribe_cb(...)
{
  PASourceOutput *sourceOutput = [self sourceOutputWithIndex:index];
  NSNotification *aNotif;
  if (sourceOutput != nil) {
    [sourceOutputList removeObject:sourceOutput];
    aNotif = [NSNotification notificationWithName:SNDDeviceDidRemoveNotification
                                           object:self];
    [[NSNotificationCenter defaultCenter] postNotification:aNotif];
  }
}

// Client
- (void)updateClient:(NSValue *)value // client_sb(...)
{
  const pa_client_info *info;
  BOOL                 isUpdated = NO;

  // Convert PA structure into NSDictionary
  info = malloc(sizeof(const pa_client_info));
  [value getValue:(void *)info];

  for (PAClient *c in clientList) {
    if ([c index] == info->index) {
      NSDebugLLog(@"SoundKit", @"[SNDServer] Client Update: %s (index: %i).",
              info->name, info->index);
      [c updateWithValue:value];
      isUpdated = YES;
      break;
    }
  }

  if (isUpdated == NO) {
    PAClient *client = [[PAClient alloc] init];
    NSDebugLLog(@"SoundKit", @"[SNDServer] Client Add: %s (index: %i).",
                info->name, info->index);
    [client updateWithValue:value];
    [clientList addObject:client];
    [client release];
  }
  
  free((void *)info);
}
- (PAClient *)clientWithIndex:(NSUInteger)index
{
  for (PAClient *client in clientList) {
    if ([client index] == index) {
      return client;
    }
  }
  return nil;
}
- (PAClient *)clientWithName:(NSString *)name
{
  for (PAClient *client in clientList) {
    if ([name isEqualToString:client.name]) {
      return client;
    }
  }
  return nil;
}
- (void)removeClientWithIndex:(NSUInteger)index // context_subscribe_cb(...)
{
  PAClient *client = [self clientWithIndex:index];

  if (client != nil) {
    [clientList removeObject:client];
  }
}

// Restored Stream
- (void)updateStream:(NSValue *)value // ext_stream_restore_read_cb(...)
{
  const pa_ext_stream_restore_info *info;
  BOOL                             isUpdated = NO;
  NSString                         *streamName;

  // Convert PA structure into NSDictionary
  info = malloc(sizeof(const pa_ext_stream_restore_info));
  [value getValue:(void *)info];
  
  streamName = [NSString stringWithCString:info->name];
  for (PAStream *s in savedStreamList) {
    if ([[s name] isEqualToString:streamName]) {
      NSDebugLLog(@"SoundKit", @"[SNDServer] Stream Update: %s.", info->name);
      [s updateWithValue:value];
      isUpdated = YES;
      break;
    }
  }

  if (isUpdated == NO) {
    PAStream *s = [[PAStream alloc] init];
    NSDebugLLog(@"SoundKit", @"[SNDServer] Stream Add: %s.", info->name);
    s.context = _pa_ctx;
    [s updateWithValue:value];
    [savedStreamList addObject:s];
    [s release];
  }
  
  free((void *)info);
}

@end
