/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Copyright (C) 2014 Sergii Stoian
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

#import <SystemKit/OSEDefaults.h>
#import "AdvancedPrefs.h"
#import <Workspace+WM.h>
#import <dock.h>

@implementation AdvancedPrefs

- (void)dealloc
{
  TEST_RELEASE(box);
  [super dealloc];
}

- (void)awakeFromNib
{
  [box retain];
  [box removeFromSuperview];
  DESTROY(bogusWindow);

  [slideOnBadFop setRefusesFirstResponder:YES];
  [slideFromShelf setRefusesFirstResponder:YES];
  [slideWhenOpening setRefusesFirstResponder:YES];
}

// --- PrefsModule protocol

- (NSString *)moduleName
{
  return _(@"Advanced");
}

- (NSView *)view
{
  if (box == nil) {
    [NSBundle loadNibNamed:@"AdvancedPrefs" owner:self];
  }

  return box;
}

- (void)revert:(id)sender
{
  OSEDefaults *df = [OSEDefaults userDefaults];

  [slideFromShelf setState:![df boolForKey:@"DontSlideIconsFromShelf"]];
  [slideWhenOpening setState:![df boolForKey:@"DontSlideIconsWhenOpening"]];
  [slideOnBadFop setState:![df boolForKey:@"DontSlideIconBackOnBadFop"]];

  [dockLevelBtn selectItemWithTag:wDockLevel(wDefaultScreen()->dock)];
}

// --- Actions

- (void)setDockLevel:(id)sender
{
  wDockSetLevel(wDefaultScreen()->dock, [[sender selectedItem] tag]);
}

- (void)setSlidesWhenChangingPath:(id)sender
{
  [[OSEDefaults userDefaults] setBool:![slideFromShelf state] forKey:@"DontSlideIconsFromShelf"];
}

- (void)setSlidesBackOnBadOperation:(id)sender
{
  [[OSEDefaults userDefaults] setBool:![slideOnBadFop state] forKey:@"DontSlideIconBackOnBadFop"];
}

- (void)setSlidesWhenOpeningFile:(id)sender
{
  [[OSEDefaults userDefaults] setBool:![slideWhenOpening state]
                               forKey:@"DontSlideIconsWhenOpening"];
}

@end
