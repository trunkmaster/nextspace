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

#import <Foundation/NSDebug.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSObjCRuntime.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSDistributedNotificationCenter.h>
#include <math.h>

#import <AppKit/NSApplication.h>
#import <AppKit/NSNibLoading.h>
#import <AppKit/NSScrollView.h>
#import <AppKit/NSScroller.h>
#import <AppKit/NSButton.h>

#import <SystemKit/OSEDefaults.h>
#import <DesktopKit/NXTBundle.h>

#import "PrefsController.h"

// Gorm resources contain fixed geometry and tiny explicit fonts. Grow the
// layout as well as the text; merely changing NSFont leaves clipped controls.
static void SizePreferencesView(NSView *view, CGFloat scale, NSFont *font)
{
  NSRect frame = [view frame];
  BOOL autoresizes = [view autoresizesSubviews];
  [view setAutoresizesSubviews:NO];
  frame.origin.x *= scale;
  frame.origin.y *= scale;
  frame.size.width *= scale;
  frame.size.height *= scale;
  [view setFrame:frame];

  if ([view isKindOfClass:[NSScrollView class]]) {
    NSScrollView *scroll = (NSScrollView *)view;
    NSView *document = [scroll documentView];
    if ([document isKindOfClass:[NSMatrix class]]) {
      NSMatrix *matrix = (NSMatrix *)document;
      CGFloat height = ceil([font ascender] - [font descender]) + 6;
      for (NSCell *cell in [matrix cells]) [cell setFont:font];
      [matrix setCellSize:NSMakeSize([scroll contentSize].width, height)];
      [matrix sizeToCells];
      [scroll setLineScroll:height];
    }
  } else {
    if ([view isKindOfClass:[NSControl class]]) [(NSControl *)view setFont:font];
    if ([view isKindOfClass:[NSBox class]]) [(NSBox *)view setTitleFont:font];
    for (NSView *child in [view subviews]) SizePreferencesView(child, scale, font);
  }
  [view setAutoresizesSubviews:autoresizes];
}

@implementation PrefsController

- (id)init
{
  self = [super init];
  prefsViews = [[NSMutableDictionary alloc] init];
  viewScales = [NSMutableDictionary new];
  [[NSDistributedNotificationCenter defaultCenter] addObserver:self
      selector:@selector(fontPreferencesDidChange:)
      name:@"NXTSystemFontPreferencesDidChangeNotification" object:nil];
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

  if (iconList)	{ // stop processing if we already have an icon list
    return;
  }

  iconList = [[NSMatrix alloc] initWithFrame:NSMakeRect(0,0,64*30,70)
                                        mode:NSRadioModeMatrix
                                   cellClass:[NSButtonCell class]
                                numberOfRows:1
                             numberOfColumns:0];
  [iconList setCellSize:NSMakeSize(70, 70)];
  [iconList setIntercellSpacing:NSZeroSize];
  [iconList setAllowsEmptySelection:NO];

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
  NSLog(@"PrefsController: dealloc");

  [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
  [prefsViews release];
  [viewScales release];
  [window close];
  [window release];

  [super dealloc];
}

- (id)currentModule
{
  return currentModule;
}

- (NSWindow *)window
{
  return window;
}

//
// Button matrix
//
- (void)fontPreferencesDidChange:(NSNotification *)notification
{
  [self buttonClicked:iconList];
}

- (void)buttonClicked:(id)sender
{
  NSString        *buttonCaption = [[sender selectedCell] title];
  id<PrefsModule> module;
  NSView          *view;
  NSRect          buttonRect;

  module = [prefsViews objectForKey:buttonCaption];
  view = [module view];

  buttonRect = [sender cellFrameAtRow:0 column:[sender selectedColumn]];
  [iconList scrollRectToVisible:buttonRect];
  
  NSSize old = [[prefsViewBox contentView] frame].size;
  {
    CGFloat points = [[NSUserDefaults standardUserDefaults] floatForKey:@"NSFontSize"];
    if (points <= 0) points = 12;
    CGFloat scale = MAX(1.0, points / 9.0);
    NSValue *key = [NSValue valueWithPointer:view];
    CGFloat previous = [[viewScales objectForKey:key] doubleValue];
    if (previous <= 0) previous = 1;
    NSFont *font = [NSFont fontWithName:[[NSUserDefaults standardUserDefaults]
        stringForKey:@"NSFont"] size:points];
    if (!font) font = [NSFont systemFontOfSize:points];
    SizePreferencesView(view, scale / previous, font);
    [viewScales setObject:[NSNumber numberWithDouble:scale] forKey:key];
  }

  // The box constrains its content view to its own size. Resize the window
  // first, preserving its top edge, then install the module at its natural size.
  NSSize wanted = [view frame].size;
  CGFloat dx = wanted.width - old.width;
  CGFloat dy = wanted.height - old.height;
  NSRect frame = [window frame];
  frame.origin.y -= dy;
  frame.size.width += dx;
  frame.size.height += dy;
  frame = [window constrainFrameRect:frame toScreen:[window screen]];
  NSRect boxFrame = [prefsViewBox frame];
  NSRect iconsFrame = [iconScrollView frame];
  boxFrame.size.width += dx;
  boxFrame.size.height += dy;
  iconsFrame.origin.y += dy;
  iconsFrame.size.width += dx;
  BOOL autoresizes = [[window contentView] autoresizesSubviews];
  [[window contentView] setAutoresizesSubviews:NO];
  [window setFrame:frame display:NO];
  [prefsViewBox setFrame:boxFrame];
  [iconScrollView setFrame:iconsFrame];
  [[window contentView] setAutoresizesSubviews:autoresizes];
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
  NSButtonCell	*button;
  NSString	*caption;

  caption = [aPrefsModule buttonCaption];
  if (!caption) {
    return NO;
  }
  
  if ([prefsViews objectForKey:caption] != aPrefsModule) {
    [prefsViews setObject:aPrefsModule forKey:caption];
  }

  button = [[NSButtonCell alloc] init];
  [button setTitle:caption];
  [button setFont:[NSFont systemFontOfSize:9]];
  [button setImage:[aPrefsModule buttonImage]];
  [button setImagePosition:NSImageOnly];
  [button setButtonType:NSOnOffButton];
  [button setRefusesFirstResponder:YES];

  [button setTarget:self];
  [button setAction:@selector(buttonClicked:)];

  [iconList addColumnWithCells:[NSArray arrayWithObject:button]];
  [iconList sizeToCells];
  [button release];

  return YES;
}

- (void)loadBundles
{
  NSDictionary *bRegistry;
  NSArray      *modules;

  bRegistry = [[NXTBundle shared] registerBundlesOfType:@"preferences"
                                                atPath:nil];
  modules = [[NXTBundle shared] loadRegisteredBundles:bRegistry
                                                type:@"Preferences"
                                            protocol:@protocol(PrefsModule)];
  for (id b in modules) {
    [self registerPrefsModule:b];
  }
}

@end
