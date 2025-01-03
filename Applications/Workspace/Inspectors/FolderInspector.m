/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Copyright (C) 2014 Sergii Stoian
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

#import <DesktopKit/NXTBundle.h>
#import <SystemKit/OSEFileManager.h>

#import "FolderInspector.h"

static id dirInspector = nil;

@implementation FolderInspector

// Class Methods

+ new
{
  if (dirInspector == nil) {
    dirInspector = [super new];
    if (![NSBundle loadNibNamed:@"FolderInspector" owner:dirInspector]) {
      dirInspector = nil;
    }
  }

  return dirInspector;
}

- (void)dealloc
{
  NSDebugLLog(@"Inspector", @"FolderInspector: dealloc");

  // release controls here
  TEST_RELEASE(sortByMatrix);
  TEST_RELEASE(folderPath);
  TEST_RELEASE(folderDefaults);

  [super dealloc];
}

- (void)awakeFromNib
{
  NSEnumerator *e = [[sortByMatrix cells] objectEnumerator];
  NSButtonCell *c;
  NSString *p;
  NSArray *s;

  while ((c = [e nextObject]) != nil) {
    [c setRefusesFirstResponder:YES];
  }

  wsDefaults = [OSEDefaults userDefaults];
}

- (BOOL)isLocalFile
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *fp;
  NSString *selectedPath = nil;
  NSArray *selectedFiles = nil;

  [self getSelectedPath:&selectedPath andFiles:&selectedFiles];

  fp = [selectedPath stringByAppendingPathComponent:[selectedFiles objectAtIndex:0]];
  if (![fm isReadableFileAtPath:fp]) {
    return NO;
  }

  return YES;
}

// Control actions
- (void)setSortBy:sender
{
  if ([[sortByMatrix selectedCell] tag] != [[folderDefaults objectForKey:@"SortBy"] intValue]) {
    [self touch:self];
  }
}

// Public Methods - overrides of superclass

- touch:sender
{
  [folderDefaults setObject:[NSNumber numberWithInt:[[sortByMatrix selectedCell] tag]]
                     forKey:@"SortBy"];

  return [super touch:sender];
}

- ok:sender
{
  [wsDefaults setObject:folderDefaults forKey:folderPath];

  [[NSNotificationCenter defaultCenter] postNotificationName:WMFolderSortMethodDidChangeNotification
                                                      object:folderPath];

  [self revert:self];

  return self;
}

- revert:sender
{
  NSString *path = nil;
  NSArray *files = nil;
  NXTSortType sortType;

  ASSIGN(folderDefaults, nil);

  [self getSelectedPath:&path andFiles:&files];

  ASSIGN(folderPath, [path stringByAppendingPathComponent:[files objectAtIndex:0]]);

  if ([wsDefaults objectForKey:folderPath] != nil) {
    folderDefaults = [[wsDefaults objectForKey:folderPath] mutableCopy];
  }

  if (folderDefaults == nil) {
    ASSIGN(folderDefaults, [[NSMutableDictionary new] autorelease]);
    sortType = [[OSEFileManager defaultManager] sortFilesBy];
    [folderDefaults setObject:[NSNumber numberWithInt:sortType] forKey:@"SortBy"];
  } else {
    sortType = [[folderDefaults objectForKey:@"SortBy"] intValue];
  }

  [sortByMatrix selectCellWithTag:sortType];

  // Buttons state and title, window edited state
  return [super revert:self];
}

@end
