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

#import <stdio.h>
#import <string.h>

#import <dispatch/dispatch.h>
#import <pulse/ext-stream-restore.h>
#import <pulse/ext-device-manager.h>

#import "PAClient.h"
#import "PASinkInput.h"
#import "PASink.h"
#import "PAStream.h"
#import "PulseAudio.h"

static int          n_outstanding = 0;
// static bool         retry = false;
static int          reconnect_timeout = 1;
static pa_context   *pa_ctx;
static pa_operation *pa_op;

static dispatch_queue_t pa_q;

static PulseAudio *pulseAudio;

@implementation PulseAudio (Callbacks)

void dec_outstanding(void)
{
  if (n_outstanding <= 0)
    return;

  n_outstanding--;
  // if (--n_outstanding <= 0) {
  //   pa_ready = 1;
  // }
}
// --- Card ---
void card_cb(pa_context *ctx, const pa_card_info *info, int eol, void *userdata)
{
  if (eol < 0) {
    if (pa_context_errno(ctx) == PA_ERR_NOENTITY) {
      return;
    }
    fprintf(stderr, "[Mixer] ERROR: Card callback failure\n");
    return;
  }
  else if (eol > 0) {
    dec_outstanding();
    return;
  }
  else {
    NSValue *value;
    fprintf(stderr, "[Mixer] Card: %s\n", info->name);
    value = [NSValue value:info withObjCType:@encode(const pa_card_info)];
    [pulseAudio performSelectorOnMainThread:@selector(updateCard:)
                                 withObject:value
                              waitUntilDone:YES];
  }
}

// --- Sink ---
void sink_cb(pa_context *ctx, const pa_sink_info *info, int eol, void *userdata)
{
  if (eol < 0) {
    if (pa_context_errno(ctx) == PA_ERR_NOENTITY) {
      return;
    }
    fprintf(stderr, "[Mixer] ERROR: Sink callback failure\n");
    return;
  }

  if (eol > 0) {
    dec_outstanding();
    return;
  }

  fprintf(stderr, "[Mixer] Sink: %s (%s)\n", info->name, info->description);
  
  [pulseAudio performSelectorOnMainThread:@selector(updateSink:)
                               withObject:[NSString stringWithCString:info->description]
                            waitUntilDone:YES];
}
void sink_input_cb(pa_context *ctx, const pa_sink_input_info *info,
                   int eol, void *userdata)
{
  NSValue *value;
  
  if (eol < 0) {
    if (pa_context_errno(ctx) == PA_ERR_NOENTITY) {
      return;
    }
    fprintf(stderr, "[Mixer] ERROR: Sink input callback failure\n");
    return;
  }

  if (eol > 0) {
    dec_outstanding();
    return;
  }

  fprintf(stderr, "[Mixer] Sink Input: %s "
          "(has_volume:%i client index:%i sink index:%i mute:%i corked:%i)\n",
          info->name, info->has_volume, info->client, info->sink,
          info->mute, info->corked);
  
  value = [NSValue value:info withObjCType:@encode(const pa_sink_input_info)];
  [pulseAudio performSelectorOnMainThread:@selector(updateSinkInput:)
                               withObject:value
                            waitUntilDone:YES];
}

// --- Source ---
void source_cb(pa_context *ctx, const pa_source_info *info,
               int eol, void *userdata)
{
  if (eol < 0) {
    if (pa_context_errno(ctx) == PA_ERR_NOENTITY) {
      return;
    }
    fprintf(stderr, "[Mixer] ERROR: Source callback failure\n");
    return;
  }

  if (eol > 0) {
    dec_outstanding();
    return;
  }

  fprintf(stderr, "[Mixer] Source: %s (%s)\n", info->name, info->description);
  
  NSValue *value = [NSValue value:info
                     withObjCType:@encode(const pa_source_info)];
  [pulseAudio performSelectorOnMainThread:@selector(updateSource:)
                               withObject:value
                            waitUntilDone:YES];
}

void source_output_cb(pa_context *ctx, const pa_source_output_info *info,
                      int eol, void *userdata)
{
  if (eol < 0) {
    if (pa_context_errno(ctx) == PA_ERR_NOENTITY) {
      return;
    }
    fprintf(stderr, "[Mixer] ERROR: Source output callback failure\n");
    return;
  }
  
  if (eol > 0) {
    dec_outstanding();
    return;
  }
  
  fprintf(stderr, "[Mixer] Source Output: %s\n", info->name);
  
  NSValue *value = [NSValue value:info
                     withObjCType:@encode(const pa_source_output_info)];
  [pulseAudio performSelectorOnMainThread:@selector(updateSourceOutput:)
                               withObject:value
                            waitUntilDone:YES];
}

// --- Client/server ---
void client_cb(pa_context *ctx, const pa_client_info *info,
               int eol, void *userdata)
{
  NSValue *value;
  
  if (eol < 0) {
    if (pa_context_errno(ctx) == PA_ERR_NOENTITY) {
      return;
    }
    fprintf(stderr, "[Mixer] ERROR: Client callback failure\n");
    return;
  }

  if (eol > 0) {
    dec_outstanding();
    return;
  }
  
  fprintf(stderr, "[Mixer] Client: %s (index:%i)\n", info->name, info->index);
  
  value = [NSValue value:info withObjCType:@encode(const pa_client_info)];
  [pulseAudio performSelectorOnMainThread:@selector(updateClient:)
                               withObject:value
                            waitUntilDone:YES];
}

void server_info_cb(pa_context *ctx, const pa_server_info *info, void *userdata)
{
  NSValue *value;
  
  if (!info) {
    fprintf(stderr, "[Mixer] Server info callback failure\n");
    return;
  }
  dec_outstanding();
  
  value = [NSValue value:info withObjCType:@encode(const pa_server_info)];
  [pulseAudio performSelectorOnMainThread:@selector(updateServer:)
                               withObject:value
                            waitUntilDone:YES];
}

// --- Stream ---
void ext_stream_restore_read_cb(pa_context *ctx,
                                const pa_ext_stream_restore_info *info,
                                int eol, void *userdata)
{
  NSValue *value;

  if (eol < 0) {
    fprintf(stderr, "[Mixer] Failed to initialize stream_restore extension: %s\n",
            pa_strerror(pa_context_errno(ctx)));
    return;
  }

  if (eol > 0) {
    dec_outstanding();
    return;
  }

  // fprintf(stderr, "[Mixer] Stream: %s\n", info->name);

  value = [NSValue value:info
            withObjCType:@encode(const pa_ext_stream_restore_info)];
  
  [pulseAudio performSelectorOnMainThread:@selector(updateStream:)
                               withObject:value
                            waitUntilDone:YES];
}

void ext_stream_restore_subscribe_cb(pa_context *ctx, void *userdata)
{
  pa_operation *o;

  if (!(o = pa_ext_stream_restore_read(ctx, ext_stream_restore_read_cb, NULL))) {
    fprintf(stderr, "[Mixer] pa_ext_stream_restore_read() failed\n");
    return;
  }

  pa_operation_unref(o);
}

// --- Device ---
#if HAVE_EXT_DEVICE_RESTORE_API
void ext_device_restore_read_cb(pa_context *ctx,
                                const pa_ext_device_restore_info *info,
                                int eol, void *userdata)
{
  if (eol < 0) {
    dec_outstanding();
    fpritnf(stderr, "[Mixer] Failed to initialize device restore extension: %s\n");
    return;
  }

  if (eol > 0) {
    dec_outstanding();
    break;
  }
}
void ext_device_restore_subscribe_cb(pa_context *ctx, pa_device_type_t type,
                                     uint32_t idx, void *userdata)
{
  pa_operation *o;

  if (type != PA_DEVICE_TYPE_SINK) {
    return;
  }
  
  o = pa_ext_device_restore_read_formats(c, type, idx,
                                         ext_device_restore_read_cb, NULL);
  if (!o) {
    fprintf(stderr, "[Mixer] pa_ext_device_restore_read_sink_formats() failed\n");
    return;
  }

  pa_operation_unref(o);
}
#endif

void ext_device_manager_read_cb(pa_context *ctx,
                                const pa_ext_device_manager_info *info,
                                int eol, void *userdata)
{

  if (eol < 0) {
    dec_outstanding();
    fprintf(stderr, "[Mixer] ERROR: Failed to initialize device manager extension: %s\n",
            pa_strerror(pa_context_errno(ctx)));
    return;
  }

  // w->canRenameDevices = true;

  if (eol > 0) {
    dec_outstanding();
    return;
  }

  /* Do something with a widget when this part is written */
}

void ext_device_manager_subscribe_cb(pa_context *ctx, void *userdata)
{
  pa_operation *o;

  if (!(o = pa_ext_device_manager_read(ctx, ext_device_manager_read_cb, NULL))) {
    fprintf(stderr, "[Mixer] ERROR: pa_ext_device_manager_read() failed\n");
    return;
  }

  pa_operation_unref(o);
}

// --- Context events subscription ---
void context_subscribe_cb(pa_context *ctx, pa_subscription_event_type_t event_type,
                          uint32_t index, void *userdata)
{
  pa_subscription_event_type_t event_type_masked;
  // pa_operation *o;

  event_type_masked = (event_type & PA_SUBSCRIPTION_EVENT_TYPE_MASK);
    
  switch (event_type & PA_SUBSCRIPTION_EVENT_FACILITY_MASK) {
  case PA_SUBSCRIPTION_EVENT_SINK:
    if (event_type_masked == PA_SUBSCRIPTION_EVENT_REMOVE) {
      [pulseAudio performSelectorOnMainThread:@selector(removeSinkWithIndex:)
                                   withObject:[NSNumber numberWithUnsignedInt:index]
                                waitUntilDone:YES];
    }
    else {
      if (!(pa_op = pa_context_get_sink_info_by_index(ctx, index, sink_cb, NULL))) {
        fprintf(stderr, "[Mixer] ERROR: pa_context_get_sink_info_by_index() failed\n");
        return;
      }
      pa_operation_unref(pa_op);
    }
    break;

  case PA_SUBSCRIPTION_EVENT_SOURCE:
    if (event_type_masked == PA_SUBSCRIPTION_EVENT_REMOVE) {
      [pulseAudio performSelectorOnMainThread:@selector(removeSourceWithIndex:)
                                   withObject:[NSNumber numberWithUnsignedInt:index]
                                waitUntilDone:YES];
    }
    else {
      if (!(pa_op = pa_context_get_source_info_by_index(ctx, index, source_cb, NULL))) {
        fprintf(stderr, "[Mixer] ERROR: pa_context_get_source_info_by_index() failed\n");
        return;
      }
      pa_operation_unref(pa_op);
    }
    break;

  case PA_SUBSCRIPTION_EVENT_SINK_INPUT:
    if (event_type_masked == PA_SUBSCRIPTION_EVENT_REMOVE) {
      [pulseAudio performSelectorOnMainThread:@selector(removeSinkInputWithIndex:)
                                   withObject:[NSNumber numberWithUnsignedInt:index]
                                waitUntilDone:YES];
    }
    else {
      if (!(pa_op = pa_context_get_sink_input_info(ctx, index, sink_input_cb, NULL))) {
        fprintf(stderr, "[Mixer] ERROR: pa_context_get_sink_input_info() failed\n");
        return;
      }
      pa_operation_unref(pa_op);
    }
    break;

  case PA_SUBSCRIPTION_EVENT_SOURCE_OUTPUT:
    if (event_type_masked == PA_SUBSCRIPTION_EVENT_REMOVE) {
      [pulseAudio performSelectorOnMainThread:@selector(removeSourceOutputWithIndex:)
                                   withObject:[NSNumber numberWithUnsignedInt:index]
                                waitUntilDone:YES];
    }
    else {
      pa_op = pa_context_get_source_output_info(ctx, index, source_output_cb, NULL);
      if (!pa_op) {
        fprintf(stderr, "[Mixer] ERROR: pa_context_get_sink_input_info() failed\n");
        return;
      }
      pa_operation_unref(pa_op);
    }
    break;

  case PA_SUBSCRIPTION_EVENT_CLIENT:
    if (event_type_masked == PA_SUBSCRIPTION_EVENT_REMOVE) {
      [pulseAudio performSelectorOnMainThread:@selector(removeClientWithIndex:)
                                   withObject:[NSNumber numberWithUnsignedInt:index]
                                waitUntilDone:YES];
    }
    else {
      if (!(pa_op = pa_context_get_client_info(ctx, index, client_cb, NULL))) {
        fprintf(stderr, "[Mixer] ERROR: pa_context_get_client_info() failed\n");
        return;
      }
      pa_operation_unref(pa_op);
    }
    break;

  case PA_SUBSCRIPTION_EVENT_SERVER:
    if (!(pa_op = pa_context_get_server_info(ctx, server_info_cb, NULL))) {
      fprintf(stderr, "[Mixer] ERROR: pa_context_get_server_info() failed\n");
      return;
    }
    pa_operation_unref(pa_op);
    break;

  case PA_SUBSCRIPTION_EVENT_CARD:
    if (event_type_masked == PA_SUBSCRIPTION_EVENT_REMOVE) {
      [pulseAudio performSelectorOnMainThread:@selector(removeCardWithIndex:)
                                   withObject:[NSNumber numberWithUnsignedInt:index]
                                waitUntilDone:YES];
    }
    else {
      if (!(pa_op = pa_context_get_card_info_by_index(ctx, index, card_cb, NULL))) {
        fprintf(stderr, "[Mixer] ERROR: pa_context_get_card_info_by_index() failed\n");
        return;
      }
      pa_operation_unref(pa_op);
    }
    break;
  }
}

void context_state_cb(pa_context *ctx, void *userdata)
{
  pa_context_state_t state = pa_context_get_state(ctx);
  // int                *pa_ready = userdata;
  
  fprintf(stderr, "State callback: %i\n", state);
  
  switch (state) {
  case PA_CONTEXT_UNCONNECTED:
    fprintf(stderr, "PulseAudio context state is UNCONNECTED.\n");
    break;
  case PA_CONTEXT_CONNECTING:
    fprintf(stderr, "PulseAudio context state is CONNECTING.\n");
    break;
  case PA_CONTEXT_AUTHORIZING:
    fprintf(stderr, "PulseAudio context state is AUTHORIZING.\n");
    break;
  case PA_CONTEXT_SETTING_NAME:
    fprintf(stderr, "PulseAudio context state is SETTING_NAME.\n");
    break;

  case PA_CONTEXT_READY:
    {
      pa_operation *o;

      fprintf(stderr, "PulseAudio context is ready.\n");
      
      reconnect_timeout = 1;

      pa_context_set_subscribe_callback(ctx, context_subscribe_cb, NULL);

      if (!(o = pa_context_subscribe(ctx, (pa_subscription_mask_t)
                                     (PA_SUBSCRIPTION_MASK_SINK|
                                      PA_SUBSCRIPTION_MASK_SOURCE|
                                      PA_SUBSCRIPTION_MASK_SINK_INPUT|
                                      PA_SUBSCRIPTION_MASK_SOURCE_OUTPUT|
                                      PA_SUBSCRIPTION_MASK_CLIENT|
                                      PA_SUBSCRIPTION_MASK_SERVER|
                                      PA_SUBSCRIPTION_MASK_CARD), NULL, NULL))) {
        fprintf(stderr, "[Mixer] pa_context_subscribe() failed\n");
        return;
      }
      pa_operation_unref(o);

      /* Keep track of the outstanding callbacks for UI tweaks */
      n_outstanding = 0;

      if (!(o = pa_context_get_server_info(ctx, server_info_cb, NULL))) {
        fprintf(stderr, "[Mixer] pa_context_get_server_info() failed\n");
        return;
      }
      pa_operation_unref(o);
      n_outstanding++;

      if (!(o = pa_context_get_client_info_list(ctx, client_cb, NULL))) {
        fprintf(stderr, "[Mixer] pa_context_client_info_list() failed\n");
        return;
      }
      pa_operation_unref(o);
      n_outstanding++;

      if (!(o = pa_context_get_card_info_list(ctx, card_cb, NULL))) {
        fprintf(stderr, "[Mixer] pa_context_get_card_info_list() failed");
        return;
      }
      pa_operation_unref(o);
      n_outstanding++;

      if (!(o = pa_context_get_sink_info_list(ctx, sink_cb, NULL))) {
        fprintf(stderr, "[Mixer] pa_context_get_sink_info_list() failed\n");
        return;
      }
      pa_operation_unref(o);
      n_outstanding++;

      if (!(o = pa_context_get_source_info_list(ctx, source_cb, NULL))) {
        fprintf(stderr, "[Mixer] pa_context_get_source_info_list() failed\n");
        return;
      }
      pa_operation_unref(o);
      n_outstanding++;

      if (!(o = pa_context_get_sink_input_info_list(ctx, sink_input_cb, NULL))) {
        fprintf(stderr, "[Mixer] pa_context_get_sink_input_info_list() failed\n");
        return;
      }
      pa_operation_unref(o);
      n_outstanding++;

      if (!(o = pa_context_get_source_output_info_list(ctx, source_output_cb, NULL))) {
        fprintf(stderr, "[Mixer] pa_context_get_source_output_info_list() failed\n");
        return;
      }
      pa_operation_unref(o);
      n_outstanding++;

      /* These calls are not always supported */
      if ((o = pa_ext_stream_restore_read(ctx, ext_stream_restore_read_cb, NULL))) {
        pa_operation_unref(o);
        n_outstanding++;

        pa_ext_stream_restore_set_subscribe_cb(ctx, ext_stream_restore_subscribe_cb, NULL);

        if ((o = pa_ext_stream_restore_subscribe(ctx, 1, NULL, NULL)))
          pa_operation_unref(o);

      }
      else {
        fprintf(stderr, "[Mixer] Failed to initialize stream_restore extension: %s",
                pa_strerror(pa_context_errno(ctx)));
      }

#if HAVE_EXT_DEVICE_RESTORE_API
      /* TODO Change this to just the test function */
      if ((o = pa_ext_device_restore_read_formats_all(ctx, ext_device_restore_read_cb, NULL))) {
        pa_operation_unref(o);
        n_outstanding++;

        pa_ext_device_restore_set_subscribe_cb(ctx, ext_device_restore_subscribe_cb, NULL);

        if ((o = pa_ext_device_restore_subscribe(ctx, 1, NULL, NULL)))
          pa_operation_unref(o);

      }
      else {
        fprintf(stderr, "[Mixer] Failed to initialize device restore extension: %s",
                pa_strerror(pa_context_errno(context)));
      }
#endif

      if ((o = pa_ext_device_manager_read(ctx, ext_device_manager_read_cb, NULL))) {
        pa_operation_unref(o);
        n_outstanding++;

        pa_ext_device_manager_set_subscribe_cb(ctx, ext_device_manager_subscribe_cb, NULL);

        if ((o = pa_ext_device_manager_subscribe(ctx, 1, NULL, NULL)))
          pa_operation_unref(o);

      }
      else {
        fprintf(stderr, "[Mixer] Failed to initialize device manager extension: %s",
                pa_strerror(pa_context_errno(ctx)));
      }
      // *pa_ready = 1;
      break;
    }

  case PA_CONTEXT_FAILED:
    {
      fprintf(stderr, "PulseAudio connection failed!\n");
      
      pa_context_unref(pa_ctx);
      pa_ctx = NULL;

      if (reconnect_timeout > 0) {
        fprintf(stderr, "[Mixer] DEBUG: Connection failed, attempting reconnect\n");
        // g_timeout_add_seconds(reconnect_timeout, connect_to_pulse, w);
      }
      return;
      // *pa_ready = 2;
      break;
    }

  case PA_CONTEXT_TERMINATED:
  default:
    fprintf(stderr, "PulseAudio connection terminated!\n");
    // *pa_ready = 2;
    return;
  }
}

@end

@implementation PulseAudio

- init
{
  pulseAudio = self = [super init];
  
  if (window == nil) {
    [NSBundle loadNibNamed:@"PulseAudio" owner:self];
  }
  [window makeKeyAndOrderFront:self];
  
  return self;
}

- (void)_initPAConnection
{
  // state = 0;
  // pa_ready = 0;
  
  // Initialize our device lists
  // input = malloc(sizeof(pa_devicelist_t) * 16);
  // output = malloc(sizeof(pa_devicelist_t) * 16);
  // memset(input, 0, sizeof(pa_devicelist_t) * 16);
  // memset(output, 0, sizeof(pa_devicelist_t) * 16);

  // Create a mainloop API and connection to the default server
  pa_loop = pa_mainloop_new();
  pa_api = pa_mainloop_get_api(pa_loop);
  // pa_ctx = pa_context_new(pa_api, "SoundMixer");

  pa_proplist *proplist = pa_proplist_new();
  pa_proplist_sets(proplist, PA_PROP_APPLICATION_NAME, "NextSpace Sound Mixer");
  pa_proplist_sets(proplist, PA_PROP_APPLICATION_ID, "org.nextspace.mixer");
  pa_proplist_sets(proplist, PA_PROP_APPLICATION_ICON_NAME, "audio-card");
  pa_proplist_sets(proplist, PA_PROP_APPLICATION_VERSION, "0.1");

  pa_ctx = pa_context_new_with_proplist(pa_api, NULL, proplist);

  pa_proplist_free(proplist);
  
  // pa_context_set_state_callback(pa_ctx, context_state_cb, &pa_ready);
  pa_context_set_state_callback(pa_ctx, context_state_cb, NULL);
  pa_context_connect(pa_ctx, NULL, 0, NULL);
}

- (void)awakeFromNib
{
  [streamsBrowser loadColumnZero];
  [devicesBrowser loadColumnZero];
  [streamsBrowser setTitle:@"Streams" ofColumn:0];
  [devicesBrowser setTitle:@"Devices (Sinks)" ofColumn:0];

  clientList = [[NSMutableArray alloc] init];
  sinkList = [[NSMutableArray alloc] init];
  sinkInputList = [[NSMutableArray alloc] init];
  sourceList = [[NSMutableArray alloc] init];
  streamList = [[NSMutableArray alloc] init];
  
  [self _initPAConnection];
  
  pa_q = dispatch_queue_create("org.nextspace.pamixer", NULL);
  dispatch_async(pa_q, ^{
      while (pa_mainloop_iterate(pa_loop, 1, NULL) >= 0) { ; }
      fprintf(stderr, "[Mixer] mainloop exited!\n");
    });
}

// --- These methods are called by PA callbacks ---

// client_sb(...)
- (void)updateClient:(NSValue *)value
{
  const pa_client_info *info;
  BOOL clientUpdated = NO;

  // Convert PA structure into NSDictionary
  info = malloc(sizeof(const pa_client_info));
  [value getValue:(void *)info];

  for (PAClient *c in clientList) {
    if ([c index] == info->index) {
      [c updateWithValue:value];
      clientUpdated = YES;
      break;
    }
  }

  if (clientUpdated == NO) {
    NSLog(@"Add Client: %s", info->name);
    PAClient *client = [[PAClient alloc] init];
    [client updateWithValue:value];
    [clientList addObject:client];
    [client release];
  }

  [self reloadBrowser:streamsBrowser];
  
  free((void *)info);
}
- (void)removeClientWithIndex:(NSNumber *)index
{
  PAClient *client;

  for (PAClient *c in clientList) {
    if ([c index] == [index unsignedIntegerValue]) {
      client = c;
      break;
    }
  }

  if (client != nil) {
    [clientList removeObject:client];
    [self reloadBrowser:streamsBrowser];
  }
}

// ext_stream_restore_read_cb(...)
- (void)updateStream:(NSValue *)value
{
  const pa_ext_stream_restore_info *info;
  BOOL isUpdated = NO;
  NSString *streamName;

  // Convert PA structure into NSDictionary
  info = malloc(sizeof(const pa_ext_stream_restore_info));
  [value getValue:(void *)info];

  streamName = [NSString stringWithCString:info->name];
  for (PAStream *s in streamList) {
    if ([[s name] isEqualToString:streamName]) {
      [s updateWithValue:value];
      isUpdated = YES;
      break;
    }
  }

  if (isUpdated == NO) {
    PAStream *s = [[PAStream alloc] init];
    [s updateWithValue:value];
    [streamList addObject:s];
    [s release];
  }
  free((void *)info);

  [self reloadBrowser:streamsBrowser];
}

// sink_cb(...)
- (void)updateSink:(NSString *)sink
{
  for (NSString *s in sinkList) {
    if ([s isEqualToString:sink]) {
      return;
    }
  }    
  [sinkList addObject:sink];
  [self reloadBrowser:devicesBrowser];
}
// TODO
- (void)removeSinkWithIndex:(NSNumber *)index
{
}

- (void)updateSinkInput:(NSValue *)value
{
  const pa_sink_input_info *info;
  BOOL  isUpdated = NO;

  // Convert PA structure into NSDictionary
  info = malloc(sizeof(const pa_sink_input_info));
  [value getValue:(void *)info];

  for (PASinkInput *si in sinkInputList) {
    if (si.index == info->index) {
      NSLog(@"Update Sink Input: %s", info->name);
      [si updateWithValue:value];
      isUpdated = YES;
      break;
    }
  }

  if (isUpdated == NO) {
    PASinkInput *si = [[PASinkInput alloc] init];
    NSLog(@"Add Sink Input: %s", info->name);
    [si updateWithValue:value];
    [sinkInputList addObject:si];
    [si release];
  }
  
  free((void *)info);
  [self reloadBrowser:streamsBrowser];
}
- (void)removeSinkInputWithIndex:(NSNumber *)index
{
  PASinkInput *sinkInput;
  NSUInteger  idx = [index unsignedIntegerValue];

  for (PASinkInput *si in sinkInputList) {
    if (si.index == idx) {
      sinkInput = si;
      break;
    }
  }

  if (sinkInput != nil) {
    [sinkInputList removeObject:sinkInput];
    [self reloadBrowser:streamsBrowser];
  }
}

- (void)updateSource:(NSValue *)value
{
}
- (void)removeSourceWithIndex:(NSNumber *)index
{
}
- (void)updateSourceOutput:(NSValue *)value
{
}
- (void)removeSourceOutputWithIndex:(NSNumber *)index
{
}

- (void)updateServer:(NSValue *)value
{
  const pa_server_info *info;
  NSString             *server;

  // Convert PA structure into NSDictionary
  info = malloc(sizeof(const pa_server_info));
  [value getValue:(void *)info];

  server = [NSString stringWithFormat:@"Server: %s %s",
                     info->server_name, info->server_version];
  [serverInfo setStringValue:server];
  
  free((void *)info);
}
- (void)updateCard:(NSValue *)value
{
  const pa_card_info *info;
  NSString           *card;

  // Convert PA structure into NSDictionary
  info = malloc(sizeof(const pa_card_info));
  [value getValue:(void *)info];

  card = [NSString stringWithFormat:@"Audio device: %s (%s %s)",
                   pa_proplist_gets(info->proplist, PA_PROP_DEVICE_DESCRIPTION),
                   pa_proplist_gets(info->proplist, PA_PROP_DEVICE_VENDOR_NAME),
                   pa_proplist_gets(info->proplist, PA_PROP_DEVICE_PRODUCT_NAME)];
  [cardInfo setStringValue:card];
  
  free((void *)info);
}
- (void)removeCardWithIndex:(NSNumber *)index
{
}

- (void)reloadBrowser:(NSBrowser *)browser
{
  [browser reloadColumn:0];
  
  if (browser == streamsBrowser) {
    [browser setTitle:@"Streams/Clients" ofColumn:0];
  }
  else if (browser == devicesBrowser) {
    [browser setTitle:@"Devices/Sinks" ofColumn:0];
  }
}

// --- Browser delegate ---
- (void)     browser:(NSBrowser *)sender
 createRowsForColumn:(NSInteger)column
            inMatrix:(NSMatrix *)matrix
{
  NSBrowserCell *cell;
  NSArray       *list = nil;
  NSString      *title;
  
  if (sender == streamsBrowser) {
    list = sinkInputList;
  }
  else if (sender == devicesBrowser) {
    list = sinkList;
  }

  if (sender == streamsBrowser) {
    // Streams first
    for (PAStream *st in streamList) {
      if ((title = [st visibleNameForClients:clientList]) != nil) {
        [matrix addRow];
        cell = [matrix cellAtRow:[matrix numberOfRows] - 1 column:column];
        [cell setLeaf:YES];
        [cell setRefusesFirstResponder:YES];
        [cell setTitle:title];
      }
    }
    for (PASinkInput *si in sinkInputList) {
      [matrix addRow];
      cell = [matrix cellAtRow:[matrix numberOfRows] - 1 column:column];
      [cell setLeaf:YES];
      [cell setRefusesFirstResponder:YES];
      // [cell setTitle:si.name];
      [cell setTitle:[si nameForClients:clientList sinks:sinkList]];
    }
  }
  else if (sender == devicesBrowser) {
    for (NSString *s in sinkList) {
      [matrix addRow];
      cell = [matrix cellAtRow:[matrix numberOfRows] - 1 column:column];
      [cell setTitle:s];
      [cell setLeaf:YES];
      [cell setRefusesFirstResponder:YES];
    }
  }
}

// --- Window delegate
- (BOOL)windowShouldClose:(id)sender
{
  int retval = 0;
  
  // if (sender != window)
  //   return NO;
  
  // NSLog(@"[PulseAudio] windowShouldClose. Waiting for operation to be done.");
  
  // while (pa_op && pa_operation_get_state(pa_op) != PA_OPERATION_DONE) {
  //   sleep(1);
    // pa_mainloop_iterate(pa_loop, 1, NULL);
  // }

  // if (pa_op)
  //   pa_operation_unref(pa_op);
  
  NSLog(@"[PulseAudio] windowShouldClose. Closing connection to server.");
  pa_mainloop_quit(pa_loop, retval);
  pa_context_disconnect(pa_ctx);
  pa_context_unref(pa_ctx);
  pa_mainloop_free(pa_loop);
  NSLog(@"[PulseAudio] windowShouldClose. Connection to server closed.");

  return YES;
}

// --- Actions
- (void)browserClick:(id)sender
{
  NSLog(@"Browser received click: %@, cell - %@",
        [sender className], [[sender selectedCellInColumn:0] title]);
}

@end
