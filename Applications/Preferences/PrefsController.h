/* -*- mode: objc -*- */
//
// Project: Preferences
//
// Copyright (C) 2014-2019 Sergii Stoian
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
#import <AppKit/NSWindowController.h>
#import <AppKit/NSBox.h>
#import <AppKit/NSMatrix.h>
#import <AppKit/NSScrollView.h>
#import <AppKit/NSWindow.h>

#import "Preferences.h"

@interface PrefsController: NSObject
{
  IBOutlet NSBox	*prefsViewBox;
  IBOutlet NSScrollView	*iconScrollView;
  IBOutlet NSWindow	*window;

  NSMatrix		*iconList;

  id			currentModule;
  NSMutableDictionary	*prefsViews;
  NSMutableDictionary   *loadedBundles;
}

- (NSWindow *)window;

- (void)loadBundles;

@end
