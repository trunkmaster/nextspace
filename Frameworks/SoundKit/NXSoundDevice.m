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
                                      
#import <dispatch/dispatch.h>

#import "NXSoundDevice.h"
#import "NXSoundDeviceCallbacks.h"

static dispatch_queue_t _pa_q;

@implementation NXSoundDevice

- (void)dealloc
{
  int retval = 0;
  
  NSLog(@"[SoundKit] Closing connection to server.");
  pa_mainloop_quit(_pa_loop, retval);
  pa_context_disconnect(_pa_ctx);
  pa_context_unref(_pa_ctx);
  pa_mainloop_free(_pa_loop);
  NSLog(@"[SoundKit] Connection to server closed.");
  
  if (_host) {
    [_host release];
  }
  [super dealloc];
}

- (id)init
{
  return [self initOnHost:nil withName:@"SoundKit"];
}

- (id)initOnHost:(NSString *)hostName
        withName:(NSString *)appName
{
  pa_proplist *proplist;
  const char  *host = NULL;

  [super init];

  if (hostName != nil) {
    _host = [[NSString alloc] initWithString:hostName];
    host = [hostName cString];
  }
  
  _pa_loop = pa_mainloop_new();
  _pa_api = pa_mainloop_get_api(_pa_loop);

  proplist = pa_proplist_new();
  pa_proplist_sets(proplist, PA_PROP_APPLICATION_NAME, [appName cString]);
  pa_proplist_sets(proplist, PA_PROP_APPLICATION_ID, "org.nextspace.soundkit");
  pa_proplist_sets(proplist, PA_PROP_APPLICATION_ICON_NAME, "audio-card");
  // pa_proplist_sets(proplist, PA_PROP_APPLICATION_VERSION, "0.1");

  _pa_ctx = pa_context_new_with_proplist(_pa_api, [appName cString], proplist);
  
  pa_proplist_free(proplist);
  
  // pa_context_set_state_callback(pa_ctx, context_state_cb, &pa_ready);
  pa_context_set_state_callback(_pa_ctx, context_state_cb, NULL);
  pa_context_connect(_pa_ctx, host, 0, NULL);

  _pa_q = dispatch_queue_create("org.nextspace.soundkit", NULL);
  dispatch_async(_pa_q, ^{
      while (pa_mainloop_iterate(_pa_loop, 1, NULL) >= 0) { ; }
      fprintf(stderr, "[SoundKit] mainloop exited!\n");
    });
  
  return self;
}

- (NSString *)host
{
  return _host;
}

@end
