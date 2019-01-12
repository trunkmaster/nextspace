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

#import "PulseAudio.h"

static int        n_outstanding = 0;
static bool       retry = false;
static int        reconnect_timeout = 1;
static int        pa_ready = 0;
static pa_context *pa_ctx;

@implementation PulseAudio (Callbacks)

void dec_outstanding(void)
{
  if (n_outstanding <= 0)
    return;

  if (--n_outstanding <= 0) {
    pa_ready = 1;
  }
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

  if (eol > 0) {
    dec_outstanding();
    return;
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
}
void sink_input_cb(pa_context *ctx, const pa_sink_input_info *info,
                   int eol, void *userdata)
{
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

  fprintf(stderr, "[Mixer] Sink Input: %s\n", info->name);
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
}

// --- Client/server ---
void client_cb(pa_context *ctx, const pa_client_info *info,
               int eol, void *userdata)
{
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
  
  fprintf(stderr, "[Mixer] Client: %s\n", info->name);
}

void server_info_cb(pa_context *ctx, const pa_server_info *info, void *userdata)
{
  if (!info) {
    fprintf(stderr, "[Mixer] Server info callback failure\n");
    return;
  }
  dec_outstanding();
}

// --- Stream ---
void ext_stream_restore_read_cb(pa_context *ctx,
                                const pa_ext_stream_restore_info *info,
                                int eol, void *userdata)
{
  if (eol < 0) {
    // dec_outstanding(w);
    fprintf(stderr, "[Mixer] Failed to initialize stream_restore extension: %s\n",
            pa_strerror(pa_context_errno(ctx)));
    // w->deleteEventRoleWidget();
    return;
  }

  if (eol > 0) {
    dec_outstanding();
    return;
  }

  // w->updateRole(*i);
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
  pa_operation *o;

  event_type_masked = (event_type & PA_SUBSCRIPTION_EVENT_TYPE_MASK);
    
  switch (event_type & PA_SUBSCRIPTION_EVENT_FACILITY_MASK) {
  case PA_SUBSCRIPTION_EVENT_SINK:
    if (event_type_masked == PA_SUBSCRIPTION_EVENT_REMOVE) {
      // w->removeSink(index);
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
      // w->removeSource(index);
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
      // w->removeSinkInput(index);
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
      // w->removeSourceOutput(index);
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
      // w->removeClient(index);
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
      // w->removeCard(index);
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
  int                *pa_ready = userdata;
  
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
      *pa_ready = 1;
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
      *pa_ready = 2;
      break;
    }

  case PA_CONTEXT_TERMINATED:
  default:
    fprintf(stderr, "PulseAudio connection terminated!\n");
    *pa_ready = 2;
    return;
  }
}

@end

@implementation PulseAudio

- init
{
  [super init];
  
  if (window == nil) {
    [NSBundle loadNibNamed:@"PulseAudio" owner:self];
  }
  [window makeKeyAndOrderFront:self];
  
  return self;
}

- (void)_initPAConnection
{
  state = 0;
  pa_ready = 0;
  
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
  
  pa_context_set_state_callback(pa_ctx, context_state_cb, &pa_ready);  
  pa_context_connect(pa_ctx, NULL, 0, NULL);
}

- (void)awakeFromNib
{
  [streamsBrowser loadColumnZero];
  [devicesBrowser loadColumnZero];
  [streamsBrowser setTitle:@"Streams" ofColumn:0];
  [devicesBrowser setTitle:@"Devices" ofColumn:0];
  
  [self _initPAConnection];
  
  dispatch_queue_t pa_q = dispatch_queue_create("org.nextspace.mixer", NULL);
  dispatch_async(pa_q, ^{ for (;;) { pa_mainloop_iterate(pa_loop, 1, NULL); } });
}

// --- Window delegate
- (BOOL)windowShouldClose:(id)sender
{
  int retval = 0;
  if (sender != window)
    return NO;
  
  NSLog(@"[PulseAudio] windowShouldClose. Waiting for operation to be done.");
  
  while (pa_operation_get_state(pa_op) != PA_OPERATION_DONE) {
    pa_mainloop_iterate(pa_loop, 1, NULL);
  }

  NSLog(@"[PulseAudio] windowShouldClose. Closing connection to server.");
  // Now we're done, clean up and disconnect and return
  state = 2;
  pa_mainloop_quit(pa_loop, retval);
  pa_operation_unref(pa_op);
  pa_context_disconnect(pa_ctx);
  pa_context_unref(pa_ctx);
  pa_mainloop_free(pa_loop);
  NSLog(@"[PulseAudio] windowShouldClose. Connection to server closed.");

  return YES;
}

@end
