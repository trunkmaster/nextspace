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
  NSString     *p;
  NSArray      *s;

  while ((c = [e nextObject]) != nil)
    {
      [c setRefusesFirstResponder:YES];
    }

  wsDefaults = [NXDefaults userDefaults];
}

- (BOOL)isLocalFile
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *fp;
  NSString *selectedPath = nil;
  NSArray  *selectedFiles = nil;

  [self getSelectedPath:&selectedPath andFiles:&selectedFiles];
  
  fp = [selectedPath
         stringByAppendingPathComponent:[selectedFiles objectAtIndex:0]];
  if (![fm isReadableFileAtPath:fp])
    {
      return NO;
    }
  
  return YES;
}

// Control actions
- (void)setSortBy:sender
{
  if ([[sortByMatrix selectedCell] tag] !=
      [[folderDefaults objectForKey:@"SortBy"] intValue])
    {
      [self touch:self];
    }
}

// Public Methods - overrides of superclass

- touch:sender
{
  [folderDefaults
    setObject:[NSNumber numberWithInt:[[sortByMatrix selectedCell] tag]]
       forKey:@"SortBy"];
  
  return [super touch:sender];
}

- ok:sender
{
  [wsDefaults setObject:folderDefaults forKey:folderPath];

  [[NSNotificationCenter defaultCenter]
    postNotificationName:WMFolderSortMethodDidChangeNotification
                  object:folderPath];
  
  [self revert:self];
  
  return self;
}

- revert:sender
{
  NSString   *path = nil;
  NSArray    *files = nil;
  NXSortType sortType;

  ASSIGN(folderDefaults, nil);
  
  [self getSelectedPath:&path andFiles:&files];
  
  ASSIGN(folderPath,
         [path stringByAppendingPathComponent:[files objectAtIndex:0]]);

  if ([wsDefaults objectForKey:folderPath] != nil)
    {
      folderDefaults = [[wsDefaults objectForKey:folderPath] mutableCopy];
    }

  if (folderDefaults == nil)
    {
      ASSIGN(folderDefaults, [[NSMutableDictionary new] autorelease]);
      sortType = [[NXFileManager sharedManager] sortFilesBy];
      [folderDefaults setObject:[NSNumber numberWithInt:sortType]
                         forKey:@"SortBy"];
    }
  else
    {
      sortType = [[folderDefaults objectForKey:@"SortBy"] intValue];
    }

  [sortByMatrix selectCellWithTag:sortType];

  // Buttons state and title, window edited state
  return [super revert:self];
}

@end
