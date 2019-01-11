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

#import "PulseAudio.h"

void pa_state_cb(pa_context *c, void *userdata);
void pa_sinklist_cb(pa_context *c, const pa_sink_info *l,
                    int eol, void *userdata);
void pa_sourcelist_cb(pa_context *c, const pa_source_info *l,
                      int eol, void *userdata);
int pa_get_devicelist(pa_devicelist_t *input, pa_devicelist_t *output);

@implementation PulseAudio

// This callback gets called when our context changes state.
// We really only care about when it's ready or if it has failed
void pa_state_cb(pa_context *c, void *userdata)
{
  pa_context_state_t state;
  int                *pa_ready = userdata;

  state = pa_context_get_state(c);
  
  fprintf(stderr, "State callback: %i\n", state);
  
  switch (state) {
    // There are just here for reference
  case PA_CONTEXT_UNCONNECTED:
  case PA_CONTEXT_CONNECTING:
  case PA_CONTEXT_AUTHORIZING:
  case PA_CONTEXT_SETTING_NAME:
  default:
    break;
  case PA_CONTEXT_FAILED:
  case PA_CONTEXT_TERMINATED:
    *pa_ready = 2;
    break;
  case PA_CONTEXT_READY:
    *pa_ready = 1;
    break;
  }
}

// pa_mainloop will call this function when it's ready to tell us about a sink.
// Since we're not threading, there's no need for mutexes on the devicelist
// structure
void pa_sinklist_cb(pa_context *c, const pa_sink_info *l,
                    int eol, void *userdata)
{
  pa_devicelist_t *pa_devicelist = userdata;
  int ctr = 0;

  // If eol is set to a positive number, you're at the end of the list
  if (eol > 0) {
    return;
  }

  fprintf(stderr, "Sink List callback.\n");
  // We know we've allocated 16 slots to hold devices.  Loop through our
  // structure and find the first one that's "uninitialized."  Copy the
  // contents into it and we're done.  If we receive more than 16 devices,
  // they're going to get dropped.  You could make this dynamically allocate
  // space for the device list, but this is a simple example.
  for (ctr = 0; ctr < 16; ctr++) {
    if (! pa_devicelist[ctr].initialized) {
      fprintf(stderr, "\t%s (%s)\n", l->name, l->description);
      strncpy(pa_devicelist[ctr].name, l->name, 511);
      strncpy(pa_devicelist[ctr].description, l->description, 255);
      pa_devicelist[ctr].index = l->index;
      pa_devicelist[ctr].initialized = 1;
      break;
    }
  }
  fprintf(stderr, "Sink List callback: done.\n");
}

// See above.  This callback is pretty much identical to the previous
void pa_sourcelist_cb(pa_context *c, const pa_source_info *l,
                      int eol, void *userdata)
{
  pa_devicelist_t *pa_devicelist = userdata;
  int ctr = 0;

  if (eol > 0) {
    return;
  }

  fprintf(stderr, "Source List callback:\n");
  for (ctr = 0; ctr < 16; ctr++) {
    if (!pa_devicelist[ctr].initialized) {
      fprintf(stderr, "\t%s (%s)\n", l->name, l->description);
      strncpy(pa_devicelist[ctr].name, l->name, 511);
      strncpy(pa_devicelist[ctr].description, l->description, 255);
      pa_devicelist[ctr].index = l->index;
      pa_devicelist[ctr].initialized = 1;
      break;
    }
  }
  fprintf(stderr, "Source List callback: done.\n");

}

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
  input = malloc(sizeof(pa_devicelist_t) * 16);
  output = malloc(sizeof(pa_devicelist_t) * 16);
  memset(input, 0, sizeof(pa_devicelist_t) * 16);
  memset(output, 0, sizeof(pa_devicelist_t) * 16);

  // Create a mainloop API and connection to the default server
  pa_loop = pa_mainloop_new();
  pa_api = pa_mainloop_get_api(pa_loop);
  pa_ctx = pa_context_new(pa_api, "SoundMixer");

  // This function connects to the pulse server
  pa_context_connect(pa_ctx, NULL, 0, NULL);

  // This function defines a callback so the server will tell us it's state.
  // Our callback will wait for the state to be ready.  The callback will
  // modify the variable to 1 so we know when we have a connection and it's
  // ready.
  // If there's an error, the callback will set pa_ready to 2
  pa_context_set_state_callback(pa_ctx, pa_state_cb, &pa_ready);  
}
- (int)_iterate
{
  for (;;) {
    if (pa_ready == 0) {
      pa_mainloop_iterate(pa_loop, 1, NULL);
      continue;
    }
    // We couldn't get a connection to the server, so exit out
    if (pa_ready == 2) {
      NSLog(@"[PulseAudio] couldn't get a connection to the server. Exit PA runloop.");
      pa_context_disconnect(pa_ctx);
      pa_context_unref(pa_ctx);
      pa_mainloop_free(pa_loop);
      return -1;
    }
    // At this point, we're connected to the server and ready to make
    // requests
    switch (state) {
      // State 0: we haven't done anything yet
    case 0:
      pa_op = pa_context_get_sink_info_list(pa_ctx, pa_sinklist_cb, output);
      state++;
      break;
    case 1:
      if (pa_operation_get_state(pa_op) == PA_OPERATION_DONE) {
        pa_operation_unref(pa_op);
        pa_op = pa_context_get_source_info_list(pa_ctx, pa_sourcelist_cb, input);
        state++;
      }
      break;
    case 2:
      return 0;
      break;
    default:
      // We should never see this state
      fprintf(stderr, "in state %d\n", state);
      // return -1;
    }
    pa_mainloop_iterate(pa_loop, 1, NULL);
  }
}

- (void)awakeFromNib
{
  [streamsBrowser loadColumnZero];
  [devicesBrowser loadColumnZero];
  [streamsBrowser setTitle:@"Streams" ofColumn:0];
  [devicesBrowser setTitle:@"Devices" ofColumn:0];
  
  [self _initPAConnection];
  dispatch_queue_t pa_q = dispatch_queue_create("ns.mixer.pulseaudio", NULL);
  dispatch_async(pa_q, ^{[self _iterate];});
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
