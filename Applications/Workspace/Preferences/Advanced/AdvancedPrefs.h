/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Copyright (C) 2018 Sergii Stoian
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

//
// Preferences for advanced users of Workspace or WM.
//

#import <AppKit/AppKit.h>
#import <Preferences/PrefsModule.h>

@interface AdvancedPrefs : NSObject <PrefsModule>
{
  id bogusWindow;
  id box;
  id dockLevelBtn;
  id slideOnBadFop;
  id slideFromShelf;
  id slideWhenOpening;
}

- (void)setSlidesWhenChangingPath:(id)sender;
- (void)setSlidesBackOnBadOperation:(id)sender;
- (void)setSlidesWhenOpeningFile:(id)sender;

@end
