/*
   Preferences for advanced users of Workspace or WindowMaker.

   Copyright (C) 2018 Sergii Stoian

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import <NXFoundation/NXDefaults.h>
#import "AdvancedPrefs.h"
#import <Workspace+WM.h>

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
  NXDefaults *df = [NXDefaults userDefaults];

  [slideFromShelf setState:![df boolForKey:@"DontSlideIconsFromShelf"]];
  [slideWhenOpening setState:![df boolForKey:@"DontSlideIconsWhenOpening"]];
  [slideOnBadFop setState:![df boolForKey:@"DontSlideIconBackOnBadFop"]];

  [dockLevelBtn selectItemWithTag:WWMDockLevel()];
}

// --- Actions

- (void)setDockLevel:(id)sender
{
  WWMSetDockLevel([[sender selectedItem] tag]);
}

- (void)setSlidesWhenChangingPath:(id)sender
{
  [[NXDefaults userDefaults] setBool:![slideFromShelf state]
                              forKey:@"DontSlideIconsFromShelf"];
}

- (void)setSlidesBackOnBadOperation:(id)sender
{
  [[NXDefaults userDefaults] setBool:![slideOnBadFop state]
                              forKey:@"DontSlideIconBackOnBadFop"];
}

- (void)setSlidesWhenOpeningFile:(id)sender
{
  [[NXDefaults userDefaults] setBool:![slideWhenOpening state]
                              forKey:@"DontSlideIconsWhenOpening"];
}

@end
