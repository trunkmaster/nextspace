/*
  Controller class for Expert preferences bundle

  Author:	Sergii Stoian <stoyan255@ukr.net>
  Date:		2018

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
#import <AppKit/AppKit.h>
#import <NXFoundation/NXFileManager.h>

#import "Expert.h"

@implementation Expert


- (id)init
{
  self = [super init];
  
  defaults = [NXDefaults globalUserDefaults];
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  NSString *imagePath = [bundle pathForResource:@"Expert" ofType:@"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile:imagePath];
      
  return self;
}

- (void)dealloc
{
  NSLog(@"Expert -dealloc");
  [image release];
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
    selectItemWithTag:[[NXFileManager sharedManager] sortFilesBy]];
  [showHiddenFilesBtn
    setState:[[NXFileManager sharedManager] isShowHiddenFiles]];
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
  [[NXFileManager sharedManager] setSortFilesBy:[[sender selectedItem] tag]];
}

- (void)setShowHiddenFiles:(id)sender
{
  [[NXFileManager sharedManager] setShowHiddenFiles:[sender state]];
}

@end

