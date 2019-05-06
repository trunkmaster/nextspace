/* -*- mode: objc -*- */
//
// Project: Workspace
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

#import <AppKit/AppKit.h>
#import <DesktopKit/NXTBundle.h>

#import "Preferences.h"

NSString *ShelfIconSlotWidth = @"ShelfIconSlotWidth";
NSString *ShelfIsResizable = @"ShelfIsResizable";
NSString *ShelfIconSlotWidthDidChangeNotification = @"ShelfIconSlotWidthDidChangeNotification";
NSString *ShelfResizableStateDidChangeNotification = @"ShelfResizableStateDidChangeNotification";

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

- (void)dealloc
{
  NSLog(@"Preferences: dealloc");
  TEST_RELEASE(panel);
  TEST_RELEASE(prefs);

  [super dealloc];
}

- (void)awakeFromNib
{
  [panel setFrameAutosaveName:@"Preferences"];

  // ASSIGN(prefs, [[ModuleLoader shared] preferencesModules]);

  [popup removeAllItems];
  [self loadModules];

  if ([popup numberOfItems] > 0)
    {
      [popup selectItemAtIndex:0];
      [self switchModule:popup];
    }
}

- (void)loadModules
{
  NSDictionary *mRegistry;
  NSArray      *modules;
  NSString     *title;

  mRegistry = [[NXTBundle shared]
                registerBundlesOfType:@"wsprefs"
                               atPath:[[NSBundle mainBundle] bundlePath]];
  modules = [[NXTBundle shared] loadRegisteredBundles:mRegistry
                                                type:@"WSPreferences"
                                            protocol:@protocol(PrefsModule)];
  for (id<PrefsModule> b in modules)
    {
      title = [b moduleName];
      [popup addItemWithTitle:title];
      [[popup itemWithTitle:title] setRepresentedObject:b];
    }
}

- (void)activate
{
  if (panel == nil)
    {
      [NSBundle loadNibNamed:@"Preferences" owner:self];
    }

  [panel makeKeyAndOrderFront:nil];
}

- (void)switchModule:(id)sender
{
  id <PrefsModule> module;

  module = [[sender selectedItem] representedObject];
  [(NSBox *)box setContentView:[module view]];
  [module revert:self];
}

@end
