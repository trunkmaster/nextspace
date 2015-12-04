/*
   Preferences.m
   The preferences panel controller.

   Copyright (C) 2005 Saso Kiselkov

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import <AppKit/AppKit.h>

#import "Preferences.h"
#import "ModuleLoader.h"

@implementation Preferences

static Preferences * shared = nil;

+ shared
{
  if (shared == nil)
    {
      shared = [self new];
    }
  return shared;
}

- (void)activate
{
  if (panel == nil)
    {
      [NSBundle loadNibNamed:@"Preferences" owner:self];
    }

  [panel makeKeyAndOrderFront:nil];
}

- (void)dealloc
{
  TEST_RELEASE(prefs);

  [super dealloc];
}

- (void)awakeFromNib
{
  [panel setFrameAutosaveName:@"Preferences"];

  ASSIGN(prefs, [[ModuleLoader shared] preferencesModules]);

  [popup removeAllItems];
  [popup addItemsWithTitles:[[prefs allKeys] sortedArrayUsingSelector:
	  @selector(caseInsensitiveCompare:)]];

  if ([prefs count] > 0)
    {
      [popup selectItemAtIndex:0];
      [self switchModule:popup];
    }
}

- (void)switchModule:(id)sender
{
  id <PrefsModule> module;

  module = [prefs objectForKey:[sender titleOfSelectedItem]];
  [(NSBox *)box setContentView:[module view]];
//  [panel setTitle:[NSString stringWithFormat:_(@"%@ Preferences"), 
//    [module moduleName]]];
}

@end
