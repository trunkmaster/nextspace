/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - SystemKit framework
//
// Description: Represents connection to specific D-Bus service.
//
// Copyright (C) 2025- Sergii Stoian
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

#import "OSEBusConnection.h"
#import "OSEBusService.h"

@implementation OSEBusService

/*
   `connection` property has `assign` attribute so retain count should be always 1.
   Because we're owning connection to a specific D-Bus service - initiate disconnection.
   Concrete class talks to a D-Bus service and must be the only instance (signleton).
*/
- (void)dealloc
{
  NSDebugLLog(@"dealloc",
              @"OSEBusService: -dealloc (retain count: %lu) (connection retain count: %lu)",
              [self retainCount], [self.connection retainCount]);

  [_objectPath release];
  [_serviceName release];
  [_connection release];
  [super dealloc];
}

- (instancetype)init
{
  [super init];

  _connection = [[OSEBusConnection defaultConnection] retain];

  return self;
}

@end