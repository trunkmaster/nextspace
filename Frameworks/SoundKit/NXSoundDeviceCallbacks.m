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

#import "NXSoundDevice.h"
#import "NXSoundDeviceCallbacks.h"

static int n_outstanding = 0;

// @implementation NXSoundDevice (Callbacks)

void dec_outstanding(void)
{
  if (n_outstanding <= 0)
    return;

  n_outstanding--;
}

// --- NXSoundDevice ---
// --- Card and Server ---
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
    [(NXSoundDevice *)userdata performSelectorOnMainThread:@selector(updateCard:)
                                                withObject:value
                                             waitUntilDone:YES];
  }
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
  [(NXSoundDevice *)userdata performSelectorOnMainThread:@selector(updateServer:)
                                              withObject:value
                                           waitUntilDone:YES];
}

// --- NXSoundOut: Sink (Card, Server) ---
// --- Sink ---
void sink_cb(pa_context *ctx, const pa_sink_info *info, int eol, void *userdata)
{
  NSValue *value;
  
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
  
  value = [NSValue value:info withObjCType:@encode(const pa_sink_info)];
  [(NXSoundDevice *)userdata  performSelectorOnMainThread:@selector(updateSink:)
                                               withObject:value
                                            waitUntilDone:YES];
}

// --- NXSoundIn: Source (Card, Server) ---
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
  [(NXSoundDevice *)userdata performSelectorOnMainThread:@selector(updateSource:)
                                              withObject:value
                                           waitUntilDone:YES];
}

// --- NXSoundStream: SinkInput | SourceOutput, Client, Stream ---
// --- SinkInput
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
  [(NXSoundDevice *)userdata performSelectorOnMainThread:@selector(updateSinkInput:)
                                              withObject:value
                                           waitUntilDone:YES];
}
// --- SourceOutput
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
  [(NXSoundDevice *)userdata performSelectorOnMainThread:@selector(updateSourceOutput:)
                                              withObject:value
                                           waitUntilDone:YES];
}
// --- Client
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
  [(NXSoundDevice *)userdata performSelectorOnMainThread:@selector(updateClient:)
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

  // fprintf(stderr, "[Mixer] Stream: %s for device %s\n", info->name);

  value = [NSValue value:info
            withObjCType:@encode(const pa_ext_stream_restore_info)];
  
  [(NXSoundDevice *)userdata performSelectorOnMainThread:@selector(updateStream:)
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

// --- Context events subscription ---
void context_subscribe_cb(pa_context *ctx, pa_subscription_event_type_t event_type,
                          uint32_t index, void *userdata)
{
  NXSoundDevice                *soundDevice = userdata;
  pa_subscription_event_type_t event_type_masked;
  pa_operation *o;

  event_type_masked = (event_type & PA_SUBSCRIPTION_EVENT_TYPE_MASK);
    
  switch (event_type & PA_SUBSCRIPTION_EVENT_FACILITY_MASK) {
  case PA_SUBSCRIPTION_EVENT_SINK:
    if (event_type_masked == PA_SUBSCRIPTION_EVENT_REMOVE) {
      [soundDevice performSelectorOnMainThread:@selector(removeSinkWithIndex:)
                                   withObject:[NSNumber numberWithUnsignedInt:index]
                                waitUntilDone:YES];
    }
    else {
      if (!(o = pa_context_get_sink_info_by_index(ctx, index, sink_cb, NULL))) {
        fprintf(stderr, "[Mixer] ERROR: pa_context_get_sink_info_by_index() failed\n");
        return;
      }
      pa_operation_unref(o);
    }
    break;

  case PA_SUBSCRIPTION_EVENT_SOURCE:
    if (event_type_masked == PA_SUBSCRIPTION_EVENT_REMOVE) {
      [soundDevice performSelectorOnMainThread:@selector(removeSourceWithIndex:)
                                   withObject:[NSNumber numberWithUnsignedInt:index]
                                waitUntilDone:YES];
    }
    else {
      if (!(o = pa_context_get_source_info_by_index(ctx, index, source_cb, NULL))) {
        fprintf(stderr, "[Mixer] ERROR: pa_context_get_source_info_by_index() failed\n");
        return;
      }
      pa_operation_unref(o);
    }
    break;

  case PA_SUBSCRIPTION_EVENT_SINK_INPUT:
    if (event_type_masked == PA_SUBSCRIPTION_EVENT_REMOVE) {
      [soundDevice performSelectorOnMainThread:@selector(removeSinkInputWithIndex:)
                                   withObject:[NSNumber numberWithUnsignedInt:index]
                                waitUntilDone:YES];
    }
    else {
      if (!(o = pa_context_get_sink_input_info(ctx, index, sink_input_cb, NULL))) {
        fprintf(stderr, "[Mixer] ERROR: pa_context_get_sink_input_info() failed\n");
        return;
      }
      pa_operation_unref(o);
    }
    break;

  case PA_SUBSCRIPTION_EVENT_SOURCE_OUTPUT:
    if (event_type_masked == PA_SUBSCRIPTION_EVENT_REMOVE) {
      [soundDevice performSelectorOnMainThread:@selector(removeSourceOutputWithIndex:)
                                   withObject:[NSNumber numberWithUnsignedInt:index]
                                waitUntilDone:YES];
    }
    else {
      o = pa_context_get_source_output_info(ctx, index, source_output_cb, NULL);
      if (!o) {
        fprintf(stderr, "[Mixer] ERROR: pa_context_get_sink_input_info() failed\n");
        return;
      }
      pa_operation_unref(o);
    }
    break;

  case PA_SUBSCRIPTION_EVENT_CLIENT:
    if (event_type_masked == PA_SUBSCRIPTION_EVENT_REMOVE) {
      [soundDevice performSelectorOnMainThread:@selector(removeClientWithIndex:)
                                   withObject:[NSNumber numberWithUnsignedInt:index]
                                waitUntilDone:YES];
    }
    else {
      if (!(o = pa_context_get_client_info(ctx, index, client_cb, NULL))) {
        fprintf(stderr, "[Mixer] ERROR: pa_context_get_client_info() failed\n");
        return;
      }
      pa_operation_unref(o);
    }
    break;

  case PA_SUBSCRIPTION_EVENT_SERVER:
    if (!(o = pa_context_get_server_info(ctx, server_info_cb, NULL))) {
      fprintf(stderr, "[Mixer] ERROR: pa_context_get_server_info() failed\n");
      return;
    }
    pa_operation_unref(o);
    break;

  case PA_SUBSCRIPTION_EVENT_CARD:
    if (event_type_masked == PA_SUBSCRIPTION_EVENT_REMOVE) {
      [soundDevice performSelectorOnMainThread:@selector(removeCardWithIndex:)
                                   withObject:[NSNumber numberWithUnsignedInt:index]
                                waitUntilDone:YES];
    }
    else {
      if (!(o = pa_context_get_card_info_by_index(ctx, index, card_cb, NULL))) {
        fprintf(stderr, "[Mixer] ERROR: pa_context_get_card_info_by_index() failed\n");
        return;
      }
      pa_operation_unref(o);
    }
    break;
  }
}

void context_state_cb(pa_context *ctx, void *userdata)
{
  pa_context_state_t state = pa_context_get_state(ctx);
  
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
      
      // reconnect_timeout = 1;

      pa_context_set_subscribe_callback(ctx, context_subscribe_cb, userdata);

      if (!(o = pa_context_subscribe(ctx, (pa_subscription_mask_t)
                                     (PA_SUBSCRIPTION_MASK_SINK|
                                      PA_SUBSCRIPTION_MASK_SOURCE|
                                      PA_SUBSCRIPTION_MASK_SINK_INPUT|
                                      PA_SUBSCRIPTION_MASK_SOURCE_OUTPUT|
                                      PA_SUBSCRIPTION_MASK_CLIENT|
                                      PA_SUBSCRIPTION_MASK_SERVER|
                                      PA_SUBSCRIPTION_MASK_CARD), NULL, userdata))) {
        fprintf(stderr, "[Mixer] pa_context_subscribe() failed\n");
        return;
      }
      pa_operation_unref(o);

      /* Keep track of the outstanding callbacks for UI tweaks */
      n_outstanding = 0;

      if (!(o = pa_context_get_server_info(ctx, server_info_cb, userdata))) {
        fprintf(stderr, "[Mixer] pa_context_get_server_info() failed\n");
        return;
      }
      pa_operation_unref(o);
      n_outstanding++;

      if (!(o = pa_context_get_client_info_list(ctx, client_cb, userdata))) {
        fprintf(stderr, "[Mixer] pa_context_client_info_list() failed\n");
        return;
      }
      pa_operation_unref(o);
      n_outstanding++;

      if (!(o = pa_context_get_card_info_list(ctx, card_cb, userdata))) {
        fprintf(stderr, "[Mixer] pa_context_get_card_info_list() failed");
        return;
      }
      pa_operation_unref(o);
      n_outstanding++;

      if (!(o = pa_context_get_sink_info_list(ctx, sink_cb, userdata))) {
        fprintf(stderr, "[Mixer] pa_context_get_sink_info_list() failed\n");
        return;
      }
      pa_operation_unref(o);
      n_outstanding++;

      if (!(o = pa_context_get_source_info_list(ctx, source_cb, userdata))) {
        fprintf(stderr, "[Mixer] pa_context_get_source_info_list() failed\n");
        return;
      }
      pa_operation_unref(o);
      n_outstanding++;

      if (!(o = pa_context_get_sink_input_info_list(ctx, sink_input_cb, userdata))) {
        fprintf(stderr, "[Mixer] pa_context_get_sink_input_info_list() failed\n");
        return;
      }
      pa_operation_unref(o);
      n_outstanding++;

      if (!(o = pa_context_get_source_output_info_list(ctx, source_output_cb, userdata))) {
        fprintf(stderr, "[Mixer] pa_context_get_source_output_info_list() failed\n");
        return;
      }
      pa_operation_unref(o);
      n_outstanding++;

      /* These calls are not always supported */
      if ((o = pa_ext_stream_restore_read(ctx, ext_stream_restore_read_cb, userdata))) {
        pa_operation_unref(o);
        n_outstanding++;

        pa_ext_stream_restore_set_subscribe_cb(ctx, ext_stream_restore_subscribe_cb, userdata);

        if ((o = pa_ext_stream_restore_subscribe(ctx, 1, NULL, userdata)))
          pa_operation_unref(o);

      }
      else {
        fprintf(stderr, "[Mixer] Failed to initialize stream_restore extension: %s",
                pa_strerror(pa_context_errno(ctx)));
      }

      break;
    }

  case PA_CONTEXT_FAILED:
    {
      fprintf(stderr, "PulseAudio connection failed!\n");
      
      pa_context_unref(ctx);
      ctx = NULL;

      // if (reconnect_timeout > 0) {
      //   fprintf(stderr, "[Mixer] DEBUG: Connection failed, attempting reconnect\n");
      //   // g_timeout_add_seconds(reconnect_timeout, connect_to_pulse, w);
      // }
    }
    break;

  case PA_CONTEXT_TERMINATED:
  default:
    fprintf(stderr, "PulseAudio connection terminated!\n");
    return;
  }
}

// @end
