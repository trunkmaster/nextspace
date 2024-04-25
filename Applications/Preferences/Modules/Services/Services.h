/* -*- mode: objc -*- */
//
// Project: Preferences
//
// Copyright (C) 2014-present Sergii Stoian
// Copyright (C) 2022-2023 Andres Morales
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

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSServicesManager.h>

#import <Preferences.h>

@interface Services: NSObject <PrefsModule>
{
  NSImage *image;
  id view;
  id window;
  id servicesList;
  id actionButton;

  GSServicesManager *serviceManager;
  NSDictionary *allServices;
  NSArray *disabledServices;
  NSMutableDictionary *services;
}

@end
