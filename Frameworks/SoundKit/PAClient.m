/* -*- mode: objc -*- */
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

#import <pulse/pulseaudio.h>
#import "PAClient.h"

/*
typedef struct pa_client_info {
  uint32_t    index;        // Index of this client
  const char  *name;        // Name of this client
  uint32_t    owner_module; // Index of the owning module, or PA_INVALID_INDEX.
  const char  *driver;      // Driver name
  pa_proplist *proplist;    // Property list
} pa_client_info;
*/

@implementation PAClient

- (void)dealloc
{
  if (_name) [_name release];
  [super dealloc];
}

- (id)updateWithValue:(NSValue *)value
{
  const pa_client_info *info;
  
  info = malloc(sizeof(const pa_client_info));
  [value getValue:(void *)info];

  if (_name)
    [_name release];
  _name = [[NSString alloc] initWithCString:info->name];
  _index = info->index;

  return self;
}

@end
