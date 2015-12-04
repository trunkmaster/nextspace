/*
  PrefsController.m

  Preferences window controller class

  Copyright (C) 2001 Dusk to Dawn Computing, Inc.

  Author:	Jeff Teunissen <deek@d2dc.net>
  Date:		11 Nov 2001

  This program is free software; you can redistribute it and/or
  modify it under the terms of the GNU General Public License as
  published by the Free Software Foundation; either version 2 of
  the License, or (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public
  License along with this program; if not, write to:

  Free Software Foundation, Inc.
  59 Temple Place - Suite 330
  Boston, MA  02111-1307, USA
*/
#import <Foundation/NSDebug.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSObjCRuntime.h>
#import <Foundation/NSDictionary.h>

#import <AppKit/NSApplication.h>
#import <AppKit/NSNibLoading.h>
#import <AppKit/NSScrollView.h>
#import <AppKit/NSScroller.h>
#import <AppKit/NSButton.h>

#import <NXFoundation/NXBundle.h>

#import "PrefsController.h"

@implementation PrefsController

- (id)init
{
  self = [super init];
  
  prefsViews = [[NSMutableDictionary alloc] init];
  loadedBundles = [[NSMutableDictionary alloc] init];
  
  return self;
}

//
// Initialize stuff that can't be set in the nib/gorm file.
// 
- (void)awakeFromNib
{
  // Let the system keep track of where it belongs
  [window setFrameAutosaveName:@"PreferencesMainWindow"];
  [window setFrameUsingName:@"PreferencesMainWindow"];

  if (iconList)	// stop processing if we already have an icon list
    {
      return;
    }

  iconList = [[NSMatrix alloc] initWithFrame: NSMakeRect (0, 0, 64*30, 70)];
  [iconList setCellClass:[NSButtonCell class]];
  [iconList setCellSize:NSMakeSize (70, 70)];
  [iconList setMode:NSRadioModeMatrix];
  [iconList setIntercellSpacing:NSZeroSize];
  [iconList setAllowsEmptySelection:YES];

  [iconScrollView setDocumentView:iconList];
  [iconScrollView setHasHorizontalScroller:YES];
  [iconScrollView setHasVerticalScroller:NO];
  [iconScrollView setBorderType:NSBezelBorder];
  [[iconScrollView horizontalScroller] setArrowsPosition:NSScrollerArrowsNone];

  [self loadBundles];

  [iconList selectCellAtRow:0 column:0];
  [iconList sendAction];
  [window makeKeyAndOrderFront:self];
}

- (void)dealloc
{
  [loadedBundles release];
  [prefsViews release];
  currentModule = nil;
  
  [super dealloc];
}

- (id)currentModule
{
  return currentModule;
}

- (NSWindow*)window
{
  return window;
}

//
// Button matrix
//
- (void)buttonClicked:(id)sender
{
  NSString        *buttonCaption = [[sender selectedCell] title];
  id<PrefsModule> module;
  NSView          *view;

  module = [prefsViews objectForKey:buttonCaption];
  view = [module view];
  
  [prefsViewBox setContentView:view];
  [view setNeedsDisplay:YES];
  [window setTitle:buttonCaption];
       
  currentModule = module;
}

//
// Modules
//

- (BOOL)registerPrefsModule:(id)aPrefsModule
{
  NSButtonCell	*button = [[NSButtonCell alloc] init];
  NSString	*caption = [aPrefsModule buttonCaption];

  if (!caption)
    return NO;
  
  if ([prefsViews objectForKey:caption] != aPrefsModule)
    {
      [prefsViews setObject:aPrefsModule forKey:caption];
    }

  [button setTitle:caption];
  [button setFont:[NSFont systemFontOfSize:9]];
  [button setImage:[aPrefsModule buttonImage]];
  [button setImagePosition:NSImageOnly];
  [button setHighlightsBy:NSChangeBackgroundCellMask];
  [button setShowsStateBy:NSChangeBackgroundCellMask];
  [button setRefusesFirstResponder:YES];

  [button setTarget:self];
  [button setAction:@selector(buttonClicked:)];

  [iconList addColumnWithCells:[NSArray arrayWithObject:button]];
  [iconList sizeToCells];

  return YES;
}

- (void)loadBundles
{
  NSDictionary	*bRegistry;
  NSBundle	*bundle;
  NSString	*bExecutable;
  Class		bClass;

  bRegistry = [[NXBundle shared] registerBundlesOfType:@"preferences"
                                                atPath:nil];

  for (NSString *bPath in [bRegistry allKeys])
    {
      // Check type
      if (![[[bRegistry objectForKey:bPath] objectForKey:@"type"]
             isEqualToString:@"Preferences"])
        {
          NSLog(@"Module \"%@\" according to bundle.registry"
                " is not Preferences module! Bundle loading was stopped.",
                bPath);
          continue;
        }

      // Load module
      if ((bundle = [NSBundle bundleWithPath:bPath]))
      {
        bExecutable = [[bundle infoDictionary] objectForKey:@"NSExecutable"];
        if (!bExecutable)
          {
            NSLog (@"Bundle `%@' has no executable!", bPath);
            continue;
          }

        // Check if already loaded
        if ([loadedBundles objectForKey:bExecutable])
          {
            NSLog(@"Module \"%@\" is already loaded, skipping.", bPath);
            continue;
          }
      }

      // Conforming to protocol check
      bClass = [bundle principalClass];
      if (![bClass conformsToProtocol:@protocol(PrefsModule)])
        {
          NSLog (@"Principal class of '%@' bundle does not conform to the "
                 "PrefsModule protocol.", bPath);
          return;
        }

      if ([self registerPrefsModule:[[bClass alloc] init]] == YES)
        {
          [loadedBundles setObject:bundle forKey:bExecutable];
        }
    }
}

- (NSDictionary *)loadedBundles
{
  return loadedBundles;
}


@end
