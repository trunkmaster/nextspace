/* -*- mode: objc -*- */
//
// Project: Preferences
//
// Copyright (C) 2014-2019 Sergii Stoian
// Copyright (C) 2022-2023 Andres Morales
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

#import "Services.h"
#include "Foundation/NSDictionary.h"
#include "Foundation/NSObjCRuntime.h"
#include "GNUstepGUI/GSServicesManager.h"

@implementation Services

static NSBundle *bundle = nil;

- (id)init
{
  self = [super init];
  
  bundle = [NSBundle bundleForClass:[self class]];
  NSString *imagePath = [bundle pathForResource:@"Services" ofType:@"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile:imagePath];
      
  return self;
}

- (void)dealloc
{
  [image release];
  [super dealloc];
}

- (void)awakeFromNib
{
  [view retain];
  [window release];

  serviceManager = [GSServicesManager manager];
  [serviceManager rebuildServices];
  NSLog(@"Services: %@", [[serviceManager menuServices] allKeys]);
  [servicesList loadColumnZero];
}

- (NSView *)view
{
  if (view == nil) {
    if (![NSBundle loadNibNamed:@"Services" owner:self]) {
      NSLog(@"Services.preferences: Could not load NIB, aborting.");
      return nil;
    }
  }

  return view;
}

- (NSString *)buttonCaption
{
  return @"Services Preferences";
}

- (NSImage *)buttonImage
{
  return image;
}

//
// Action methods
//
- (void)setServiceState:(id)sender
{
}

- (void)browser:(NSBrowser *)brow
    willDisplayCell:(NSBrowserCell *)cell
              atRow:(NSInteger)row
             column:(NSInteger)col
{
  NSDictionary *services = [serviceManager menuServices];

  if (col == 0) {
    NSArray *apps = [services allKeys];
    NSString *app = [apps objectAtIndex:row];

    // [cell setRepresentedObject:app];
    [cell setLeaf:NO];
    [cell setStringValue:app];
  } else {
    // NSArray *ls = [[brow selectedCellInColumn:0] representedObject];
    // id it = [ls objectAtIndex:row];
    // NSString *name = [it valueForKeyPath:@"NSMenuItem.default"];
    // [cell setLeaf:YES];
    // [cell setStringValue:niceName(name)];
    // [cell setRepresentedObject:name];
  }
}

- (NSInteger)browser:(NSBrowser *)brow numberOfRowsInColumn:(NSInteger)col
{
  if (col == 0) {
    return [[[serviceManager menuServices] allKeys] count];
  } else {
    // NSArray *ls = [[brow selectedCellInColumn:0] representedObject];
    // return [ls count];
    return 0;
  }
}

@end

