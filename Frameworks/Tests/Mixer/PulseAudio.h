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

#import <AppKit/AppKit.h>

#import <pulse/pulseaudio.h>

typedef struct pa_devicelist {
  uint8_t  initialized;
  char     name[512];
  uint32_t index;
  char     description[256];
} pa_devicelist_t;

@interface PulseAudio : NSObject
{
  id window;
  id streamsBrowser;
  id devicesBrowser;

  NSMutableArray *clientList;
  NSMutableArray *sinkList;
  NSMutableArray *sinkInputList;
  NSMutableArray *sourceList;
  NSMutableArray *streamList; // sink-input* or source-output*
  
  // Define our pulse audio loop and connection variables
  pa_mainloop     *pa_loop;
  pa_mainloop_api *pa_api;
  pa_operation    *pa_op;
  // We'll need these state variables to keep track of our requests
  int             state;

  // pa_devicelist_t *input;
  // pa_devicelist_t *output;
}

- (void)addStream:(NSValue *)value;
- (void)addSink:(NSString *)sink;
- (void)removeClientWithIndex:(NSUInteger)index;

@end
