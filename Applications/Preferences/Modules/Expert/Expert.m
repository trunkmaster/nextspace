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

#import <AppKit/AppKit.h>
#import <SystemKit/OSEFileManager.h>

#import "Expert.h"

@implementation Expert

- (id)init
{
  self = [super init];
  
  defaults = [OSEDefaults globalUserDefaults];
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  NSString *imagePath = [bundle pathForResource:@"Expert" ofType:@"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile:imagePath];
      
  return self;
}

- (void)dealloc
{
  NSLog(@"Expert -dealloc");
  [image release];
  if (view) {
    [view release];
  }
  [super dealloc];
}

- (void)awakeFromNib
{
  [view retain];
  [window release];

  [sortByBtn setRefusesFirstResponder:YES];
  [showHiddenFilesBtn setRefusesFirstResponder:YES];
  [privateWindowServerBtn setRefusesFirstResponder:YES];
  [privateSoundServerBtn setRefusesFirstResponder:YES];

  [sortByBtn
    selectItemWithTag:[[OSEFileManager defaultManager] sortFilesBy]];
  [showHiddenFilesBtn
    setState:[[OSEFileManager defaultManager] isShowHiddenFiles]];
}

- (NSView *)view
{
  if (view == nil)
    {
      if (![NSBundle loadNibNamed:@"Expert" owner:self])
        {
          NSLog (@"Expert.preferences: Could not load NIB, aborting.");
          return nil;
        }
    }
  
  return view;
}

- (NSString *)buttonCaption
{
  return @"Expert Preferences";
}

- (NSImage *)buttonImage
{
  return image;
}

//
// Action methods
//

- (void)setSortBy:(id)sender
{
  [[OSEFileManager defaultManager] setSortFilesBy:[[sender selectedItem] tag]];
}

- (void)setShowHiddenFiles:(id)sender
{
  [[OSEFileManager defaultManager] setShowHiddenFiles:[sender state]];
}

@end

