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

#import "SKSoundServer.h"
#import "SKSoundServerCallbacks.h"

static int n_outstanding = 0;

NSString *SKServerStateDidChangeNotification = @"SKServerStateDidChange";

@implementation SKSoundServer (Callbacks)

// --- SKSoundServer: Server and Card---
void card_cb(pa_context *ctx, const pa_card_info *info, int eol, void *userdata)
{
  if (eol < 0) {
    if (pa_context_errno(ctx) == PA_ERR_NOENTITY) {
      return;
    }
    fprintf(stderr, "[SoundKit] ERROR: Card callback failure\n");
    return;
  }
  else if (eol > 0) {
    inventory_decrement_requests(ctx, userdata);
    return;
  }
  else {
    NSValue *value;
    
    fprintf(stderr, "[SoundKit] Card: %s\n", info->name);
    value = [NSValue value:info withObjCType:@encode(const pa_card_info)];
    [(SKSoundServer *)userdata updateCard:value];
  }
}
void server_info_cb(pa_context *ctx, const pa_server_info *info, void *userdata)
{
  NSValue *value;
     
  if (!info) {
    fprintf(stderr, "[SoundKit] Server info callback failure\n");
    return;
  }
  inventory_decrement_requests(ctx, userdata);
  
  value = [NSValue value:info withObjCType:@encode(const pa_server_info)];
  [(SKSoundServer *)userdata updateServer:value];
}

// --- SKSoundOut: Sink --> [Card, Server] ---
void sink_cb(pa_context *ctx, const pa_sink_info *info, int eol, void *userdata)
{
  NSValue *value;
  
  if (eol < 0) {
    if (pa_context_errno(ctx) == PA_ERR_NOENTITY) {
      return;
    }
    fprintf(stderr, "[SoundKit] ERROR: Sink callback failure\n");
    return;
  }

  if (eol > 0) {
    inventory_decrement_requests(ctx, userdata);
    return;
  }

  fprintf(stderr, "[SoundKit] Sink: %s (%s)\n", info->name, info->description);
  value = [NSValue value:info withObjCType:@encode(const pa_sink_info)];
  [(SKSoundServer *)userdata updateSink:value];
}

// --- SKSoundIn: Source --> [Card, Server] ---
void source_cb(pa_context *ctx, const pa_source_info *info,
               int eol, void *userdata)
{
  if (eol < 0) {
    if (pa_context_errno(ctx) == PA_ERR_NOENTITY) {
      return;
    }
    fprintf(stderr, "[SoundKit] ERROR: Source callback failure\n");
    return;
  }

  if (eol > 0) {
    inventory_decrement_requests(ctx, userdata);
    return;
  }

  fprintf(stderr, "[SoundKit] Source: %s (%s)\n", info->name, info->description);
  NSValue *value = [NSValue value:info
                     withObjCType:@encode(const pa_source_info)];
  [(SKSoundServer *)userdata updateSource:value];
}

// --- SKSoundStream: SinkInput | SourceOutput, Client, Saved Stream(?) ---
// SinkInput
void sink_input_cb(pa_context *ctx, const pa_sink_input_info *info,
                   int eol, void *userdata)
{
  NSValue *value;
  
  if (eol < 0) {
    if (pa_context_errno(ctx) == PA_ERR_NOENTITY) {
      return;
    }
    fprintf(stderr, "[SoundKit] ERROR: Sink input callback failure\n");
    return;
  }

  if (eol > 0) {
    inventory_decrement_requests(ctx, userdata);
    return;
  }

  fprintf(stderr, "[SoundKit] Sink Input: %s "
          "(has_volume:%i client index:%i sink index:%i mute:%i corked:%i)\n",
          info->name, info->has_volume, info->client, info->sink,
          info->mute, info->corked);
  
  value = [NSValue value:info withObjCType:@encode(const pa_sink_input_info)];
  [(SKSoundServer *)userdata updateSinkInput:value];
}
// SourceOutput
void source_output_cb(pa_context *ctx, const pa_source_output_info *info,
                      int eol, void *userdata)
{
  if (eol < 0) {
    if (pa_context_errno(ctx) == PA_ERR_NOENTITY) {
      return;
    }
    fprintf(stderr, "[SoundKit] ERROR: Source output callback failure\n");
    return;
  }
  
  if (eol > 0) {
    inventory_decrement_requests(ctx, userdata);
    return;
  }
  
  fprintf(stderr, "[SoundKit] Source Output: %s\n", info->name);
  NSValue *value = [NSValue value:info
                     withObjCType:@encode(const pa_source_output_info)];
  [(SKSoundServer *)userdata updateSourceOutput:value];
}
// Client
void client_cb(pa_context *ctx, const pa_client_info *info,
               int eol, void *userdata)
{
  NSValue *value;
  
  if (eol < 0) {
    if (pa_context_errno(ctx) == PA_ERR_NOENTITY) {
      return;
    }
    fprintf(stderr, "[SoundKit] ERROR: Client callback failure\n");
    return;
  }

  if (eol > 0) {
    inventory_decrement_requests(ctx, userdata);
    return;
  }
  
  fprintf(stderr, "[SoundKit] Client: %s (index:%i)\n", info->name, info->index);
  value = [NSValue value:info withObjCType:@encode(const pa_client_info)];
  [(SKSoundServer *)userdata updateClient:value];
}
// Saved Stream
void ext_stream_restore_read_cb(pa_context *ctx,
                                const pa_ext_stream_restore_info *info,
                                int eol, void *userdata)
{
  NSValue *value;

  if (eol < 0) {
    fprintf(stderr, "[SoundKit] Failed to initialize stream_restore extension: %s\n",
            pa_strerror(pa_context_errno(ctx)));
    return;
  }

  if (eol > 0) {
    inventory_decrement_requests(ctx, userdata);
    return;
  }

  fprintf(stderr, "[SoundKit] Stream: %s for device %s\n", info->name);
  
  value = [NSValue value:info
            withObjCType:@encode(const pa_ext_stream_restore_info)];
  [(SKSoundServer *)userdata updateStream:value];
}

// --- Context events subscription ---
void context_subscribe_cb(pa_context *ctx, pa_subscription_event_type_t event_type,
                          uint32_t index, void *userdata)
{
  SKSoundServer                *_server = userdata;
  pa_subscription_event_type_t event_type_masked;
  pa_operation *o;

  event_type_masked = (event_type & PA_SUBSCRIPTION_EVENT_TYPE_MASK);
    
  switch (event_type & PA_SUBSCRIPTION_EVENT_FACILITY_MASK) {
  case PA_SUBSCRIPTION_EVENT_SINK:
    {
      if (event_type_masked == PA_SUBSCRIPTION_EVENT_REMOVE) {
        [_server removeSinkWithIndex:index];
      }
      else {
        if (!(o = pa_context_get_sink_info_by_index(ctx, index, sink_cb, userdata))) {
          fprintf(stderr, "[SoundKit] ERROR: pa_context_get_sink_info_by_index() failed\n");
          return;
        }
        pa_operation_unref(o);
      }
    }
    break;

  case PA_SUBSCRIPTION_EVENT_SOURCE:
    {
      if (event_type_masked == PA_SUBSCRIPTION_EVENT_REMOVE) {
        [_server removeSourceWithIndex:index];
      }
      else {
        if (!(o = pa_context_get_source_info_by_index(ctx, index, source_cb, userdata))) {
          fprintf(stderr, "[SoundKit] ERROR: pa_context_get_source_info_by_index() failed\n");
          return;
        }
        pa_operation_unref(o);
      }
    }
    break;

  case PA_SUBSCRIPTION_EVENT_SINK_INPUT:
    {
      if (event_type_masked == PA_SUBSCRIPTION_EVENT_REMOVE) {
        [_server removeSinkInputWithIndex:index];
      }
      else {
        if (!(o = pa_context_get_sink_input_info(ctx, index, sink_input_cb, userdata))) {
          fprintf(stderr, "[SoundKit] ERROR: pa_context_get_sink_input_info() failed\n");
          return;
        }
        pa_operation_unref(o);
      }
    }
    break;

  case PA_SUBSCRIPTION_EVENT_SOURCE_OUTPUT:
    {
      if (event_type_masked == PA_SUBSCRIPTION_EVENT_REMOVE) {
        [_server removeSourceOutputWithIndex:index];
      }
      else {
        o = pa_context_get_source_output_info(ctx, index, source_output_cb, userdata);
        if (!o) {
          fprintf(stderr, "[SoundKit] ERROR: pa_context_get_sink_input_info() failed\n");
          return;
        }
        pa_operation_unref(o);
      }
    }
    break;

  case PA_SUBSCRIPTION_EVENT_CLIENT:
    {
      if (event_type_masked == PA_SUBSCRIPTION_EVENT_REMOVE) {
        [_server removeClientWithIndex:index];
      }
      else {
        if (!(o = pa_context_get_client_info(ctx, index, client_cb, userdata))) {
          fprintf(stderr, "[SoundKit] ERROR: pa_context_get_client_info() failed\n");
          return;
        }
        pa_operation_unref(o);
      }
    }
    break;

  case PA_SUBSCRIPTION_EVENT_SERVER:
    {
      if (!(o = pa_context_get_server_info(ctx, server_info_cb, userdata))) {
        fprintf(stderr, "[SoundKit] ERROR: pa_context_get_server_info() failed\n");
        return;
      }
      pa_operation_unref(o);
    }
    break;

  case PA_SUBSCRIPTION_EVENT_CARD:
    {
      if (event_type_masked == PA_SUBSCRIPTION_EVENT_REMOVE) {
        [_server removeCardWithIndex:index];
      }
      else {
        if (!(o = pa_context_get_card_info_by_index(ctx, index, card_cb, userdata))) {
          fprintf(stderr, "[SoundKit] ERROR: pa_context_get_card_info_by_index() failed\n");
          return;
        }
        pa_operation_unref(o);
      }
    }
    break;
  }
}
void context_state_cb(pa_context *ctx, void *userdata)
{
  pa_context_state_t state = pa_context_get_state(ctx);
  
  // fprintf(stderr, "State callback: %i\n", state);
  
  switch (state) {
  case PA_CONTEXT_UNCONNECTED:
    // fprintf(stderr, "[SoundKit] PulseAudio connection state == UNCONNECTED.\n");
    break;
  case PA_CONTEXT_CONNECTING:
    // fprintf(stderr, "[SoundKit] PulseAudio connection state == CONNECTING.\n");
    break;
  case PA_CONTEXT_AUTHORIZING:
    // fprintf(stderr, "[SoundKit] PulseAudio connection state == AUTHORIZING.\n");
    break;
  case PA_CONTEXT_SETTING_NAME:
    // fprintf(stderr, "[SoundKit] PulseAudio connection state == SETTING_NAME.\n");
    break;
  case PA_CONTEXT_READY:
    // fprintf(stderr, "[SoundKit] PulseAudio connection state == READY.\n");
    inventory_start(ctx, userdata);
    // Ready state will be announced in inventory_end()
    return;
  case PA_CONTEXT_FAILED:
    {
      // fprintf(stderr, "[SoundKit] PulseAudio connection state == FAILED!\n");
      pa_context_unref(ctx);
      ctx = NULL;
      // if (reconnect_timeout > 0) {
      //   fprintf(stderr, "[SoundKit] DEBUG: Connection failed, attempting reconnect\n");
      //   // g_timeout_add_seconds(reconnect_timeout, connect_to_pulse, w);
      // }
    }
    break;
  case PA_CONTEXT_TERMINATED:
    // fprintf(stderr, "[SoundKit] PulseAudio connection state == TERMINATED.\n");
    break;
  default:
    // fprintf(stderr, "[SoundKit] PulseAudio connection state == UNKNOWN.\n");
    return;
  }

  // fprintf(stderr, "[SoundKit] send notification.\n");
  // [(SKSoundServer *)userdata performSelectorOnMainThread:@selector(updateConnectionState:)
  //                                             withObject:[NSNumber numberWithInt:state]
  //                                          waitUntilDone:YES];
  [(SKSoundServer *)userdata updateConnectionState:[NSNumber numberWithInt:state]];
}

// --- Initial inventory of PulseAudio objects ---

/* Calls number of PA functions to gather information about various PA objects.
   Every called function is asynchronous and return info via callbacks. 
   `n_outstanding` counter is used to track processed requests. */
void inventory_start(pa_context *ctx, void *userdata)
{
  pa_operation *o;
  SKSoundServer *server = (SKSoundServer *)userdata;

  fprintf(stderr, "[SoundKit] --- Inventory of PulseAudio objects: BEGIN\n");
      
  // [server performSelectorOnMainThread:@selector(updateConnectionState:)
  //                          withObject:[NSNumber numberWithInt:SKServerInventoryState]
  //                       waitUntilDone:YES];
  [server updateConnectionState:[NSNumber numberWithInt:SKServerInventoryState]];
  /* Keep track of the outstanding requests */
  n_outstanding = 0;

  if (!(o = pa_context_get_server_info(ctx, server_info_cb, userdata))) {
    fprintf(stderr, "[SoundKit] pa_context_get_server_info() failed\n");
    return;
  }
  pa_operation_unref(o);
  n_outstanding++;

  if (!(o = pa_context_get_card_info_list(ctx, card_cb, userdata))) {
    fprintf(stderr, "[SoundKit] pa_context_get_card_info_list() failed");
    return;
  }
  pa_operation_unref(o);
  n_outstanding++;

  if (!(o = pa_context_get_sink_info_list(ctx, sink_cb, userdata))) {
    fprintf(stderr, "[SoundKit] pa_context_get_sink_info_list() failed\n");
    return;
  }
  pa_operation_unref(o);
  n_outstanding++;

  // At this point we can create SKSoundOut objects

  if (!(o = pa_context_get_source_info_list(ctx, source_cb, userdata))) {
    fprintf(stderr, "[SoundKit] pa_context_get_source_info_list() failed\n");
    return;
  }
  pa_operation_unref(o);
  n_outstanding++;
  
  // At this point we can create SKSoundIn objects
  
  if (!(o = pa_context_get_client_info_list(ctx, client_cb, userdata))) {
    fprintf(stderr, "[SoundKit] pa_context_client_info_list() failed\n");
    return;
  }
  pa_operation_unref(o);
  n_outstanding++;

  if (!(o = pa_context_get_sink_input_info_list(ctx, sink_input_cb, userdata))) {
    fprintf(stderr, "[SoundKit] pa_context_get_sink_input_info_list() failed\n");
    return;
  }
  pa_operation_unref(o);
  n_outstanding++;

  if (!(o = pa_context_get_source_output_info_list(ctx, source_output_cb, userdata))) {
    fprintf(stderr, "[SoundKit] pa_context_get_source_output_info_list() failed\n");
    return;
  }
  pa_operation_unref(o);
  n_outstanding++;

  // At this point we can create SKSoundStream objects

  /* This call is not always supported. 
     This intial call has no complementary subscribe for events call.
     We need it only to get `sink-input-by-media-role:event` stream - special stream
     for short-living clients. Thus, there's no accompanying client and sink input 
     most of the time. However, user should be able to adjust volume level for such 
     short-living sound events. */
  if (!(o = pa_ext_stream_restore_read(ctx, ext_stream_restore_read_cb, userdata))) {
    fprintf(stderr, "[SoundKit] Failed to initialize stream_restore extension: %s\n",
            pa_strerror(pa_context_errno(ctx)));
  }
  pa_operation_unref(o);
  n_outstanding++;
}
/* Decrements `n_outstanding`. If it equals to 0 - start tracking PA events (call
   inventory_end). */
void inventory_decrement_requests(pa_context *ctx, void *userdata)
{
  // fprintf(stderr, "[SoundKit] invetory_decrement_requests: %i\n", n_outstanding);
  if (n_outstanding <= 0)
    return;

  if (n_outstanding > 0) {
    if (--n_outstanding == 0) {
      fprintf(stderr, "[SoundKit] --- Inventory of PulseAudio objects: END\n");
      inventory_end(ctx, userdata);
    }
  }
}
void inventory_end(pa_context *ctx, void *userdata)
{
  pa_operation  *o;
  SKSoundServer *server = (SKSoundServer *)userdata;
  
  fprintf(stderr, "[SoundKit] --- Start tracking of PulseAudio events...\n");
  
  pa_context_set_subscribe_callback(ctx, context_subscribe_cb, userdata);
  if (!(o = pa_context_subscribe(ctx, (pa_subscription_mask_t)
                                 (PA_SUBSCRIPTION_MASK_SINK|
                                  PA_SUBSCRIPTION_MASK_SOURCE|
                                  PA_SUBSCRIPTION_MASK_SINK_INPUT|
                                  PA_SUBSCRIPTION_MASK_SOURCE_OUTPUT|
                                  PA_SUBSCRIPTION_MASK_CLIENT|
                                  PA_SUBSCRIPTION_MASK_SERVER|
                                  PA_SUBSCRIPTION_MASK_CARD), NULL, userdata))) {
    fprintf(stderr, "[SoundKit] ERROR: failed to start tracking event!\n");
    return;
  }
  pa_operation_unref(o);

  [server updateConnectionState:[NSNumber numberWithInt:SKServerReadyState]];
}

@end
