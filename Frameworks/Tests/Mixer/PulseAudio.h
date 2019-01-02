/*
   Project: Mixer

   Copyright (C) 2019 Free Software Foundation

   Author: me

   Created: 2019-01-02 02:25:00 +0200 by me

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

#import <Foundation/Foundation.h>

#import <pulse/pulseaudio.h>

typedef struct pa_devicelist {
  uint8_t  initialized;
  char     name[512];
  uint32_t index;
  char     description[256];
} pa_devicelist_t;

@interface PulseAudio : NSObject
{
  // Define our pulse audio loop and connection variables
  pa_mainloop     *pa_loop;
  pa_mainloop_api *pa_api;
  pa_operation    *pa_op;
  pa_context      *pa_ctx;
  // We'll need these state variables to keep track of our requests
  int             state;
  int             pa_ready;

  pa_devicelist_t *input;
  pa_devicelist_t *output;
}

- (int)iterate;

@end
