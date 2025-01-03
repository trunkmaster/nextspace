/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - Login application
//
// Description: Module for Preferences application.
//
// Copyright (C) 2011-2019 Sergii Stoian
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

#import <AppKit/NSNibDeclarations.h>
#import <AppKit/NSTextField.h>
#import <AppKit/NSImageView.h>

#import <SystemKit/OSEDefaults.h>

#import <Preferences.h>

@interface Login: NSObject <PrefsModule>
{
  NSImage		*image;
  IBOutlet NSWindow	*window;
  IBOutlet id		view;
  IBOutlet NSTextField	*screenSaverField;
  IBOutlet NSSlider	*screenSaverSlider;
  IBOutlet NSTextField	*loginHookField;
  IBOutlet NSTextField	*logoutHookField;
  IBOutlet NSTextField	*customSaverTitle;
  IBOutlet NSTextField	*customSaverField;
  IBOutlet NSButton	*customSaverButton;
  IBOutlet NSTextField	*customUITitle;
  IBOutlet NSTextField	*customUIField;
  IBOutlet NSButton	*customUIButton;
  IBOutlet NSButton	*displayHostname;
  IBOutlet NSButton	*saveLastLoggedIn;

  OSEDefaults           *defaults;
  OSEDefaults           *systemDefaults;
  BOOL                  isAdminUser;
}

@end
