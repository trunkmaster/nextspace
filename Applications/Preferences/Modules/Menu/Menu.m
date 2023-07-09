/* -*- mode: objc -*- */
//
// Project: Preferences
//
// Copyright (C) 2014-2019 Sergii Stoian
// // Copyright (C) 2022-2023 Andres Morales
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

#import <AppKit/NSApplication.h>
#import <AppKit/NSNibLoading.h>
#import <AppKit/NSView.h>
#import <AppKit/NSBox.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSButton.h>
#import <AppKit/NSTableView.h>
#import <AppKit/NSTableColumn.h>
#import <AppKit/NSBrowser.h>
#import <AppKit/NSMatrix.h>

#import "Menu.h"

@implementation Menu

static NSBundle                 *bundle = nil;
static NSUserDefaults           *defaults = nil;
static NSMutableDictionary      *domain = nil;

- (id)init
{
  self = [super init];
  
  defaults = [NSUserDefaults standardUserDefaults];
  domain = [[defaults persistentDomainForName:NSGlobalDomain] mutableCopy];

  bundle = [NSBundle bundleForClass:[self class]];
  NSString *imagePath = [bundle pathForResource:@"Menu" ofType:@"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile:imagePath];
      
  return self;
}

- (void)dealloc
{
  NSLog(@"Menu -dealloc");
  [image release];
  [super dealloc];
}

- (void)awakeFromNib
{
  [view retain];
  [window release];
}

- (NSView *)view
{
  if (view == nil)
    {
      if (![NSBundle loadNibNamed:@"Menu" owner:self])
        {
          NSLog (@"Menu.preferences: Could not load NIB, aborting.");
          return nil;
        }
    }
  
  return view;
}

- (NSString *)buttonCaption
{
  return @"Menu Preferences";
}

- (NSImage *)buttonImage
{
  return image;
}

//
// Action methods
//

@end

