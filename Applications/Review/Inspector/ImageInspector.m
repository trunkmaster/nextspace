/*
  FolderInspector.m

  The folder contents inspector. 

  Copyright (C) 2014 Sergii Stoian

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

#import <NXFoundation/NXBundle.h>
#import <NXFoundation/NXFileManager.h>

#import "FolderInspector.h"

static id dirInspector = nil;

@implementation FolderInspector

// Class Methods

+ new
{
  if (dirInspector == nil)
    {
      dirInspector = [super new];
      if (![NSBundle loadNibNamed:@"FolderInspector"
                            owner:dirInspector])
        {
          dirInspector = nil;
        }
    }

  return dirInspector;
}

- (void)dealloc
{
  NSDebugLLog(@"FolderInspector", @"FolderInspector: dealloc");

  // release controls here
  TEST_RELEASE(foldersFirstBtn);
  TEST_RELEASE(sortByMatrix);

  [super dealloc];
}

- (void)awakeFromNib
{
  // init controls here
  // [[sortByMatrix cells]
  //   makeObjectsPerform:@selector(setRefusesFirstResponder:YES)];
}

// Control actions
- (void)setSortBy:sender
{
  NSLog(@"Sort by %@ clicked", [sender className]);
  [self touch:self];
}

- (void)setFoldersFirst:sender
{
  NSLog(@"Folders first %@ clicked", [sender className]);  
  [self touch:self];
}

// Public Methods

- (NSDictionary *)bundleRegistry
{
  return [NSDictionary dictionaryWithObjectsAndKeys:
                       @"InspectorCommand",    @"type",
                       @"contents",            @"mode",
                       @"FolderInspector",@"class",
                       @"selectionOneOnly",    @"selp",
                       @"isLocalFile",         @"nodep",
                       @"-1",                  @"priority",
                       nil];
}

- ok:sender
{
  return self;
}

- revert:sender
{
  NSString      *selectedPath = nil;
  NSArray       *selectedFiles = nil;
  
  [self getSelectedPath:&selectedPath andFiles:&selectedFiles];

  // load values for inspector controls here
  
  // Buttons state and title, window edited state
  return [super revert:self];
}

@end
