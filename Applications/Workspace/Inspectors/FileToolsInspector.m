/*
   FileToolsInspector.m
   "Tools" section Workspace Manager inspector.

   Copyright (C) 2014 Sergii Stoian
   Copyright (C) 2005 Saso Kiselkov

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

#include <AppKit/AppKit.h>

#import <NXFoundation/NXDefaults.h>
#import "FileToolsInspector.h"

static inline void AddAppToMatrix(NSString *appName, NSMatrix *matrix)
{
  NSButtonCell *cell;
  NSWorkspace  *ws = [NSWorkspace sharedWorkspace];

  [matrix addColumn];
  cell = [matrix cellAtRow:0 column:[matrix numberOfColumns] - 1];
  [cell setTitle:appName];
  [cell setImage:[ws iconForFile:[ws fullPathForApplication:appName]]];
}

@interface FileToolsInspector (Private)

- (void)clearDisplay;

@end

@implementation FileToolsInspector (Private)

- (void)clearDisplay
{
  [appListView setDocumentView:nil];
  [appPathField setStringValue:nil];
  [defaultAppField setStringValue:nil];
}

@end

@implementation FileToolsInspector

static id toolsInspector = nil;

+ new
{
  if (toolsInspector == nil)
    {
      toolsInspector = [super new];
      if (![NSBundle loadNibNamed:@"FileToolsInspector"
                            owner:toolsInspector])
        {
          toolsInspector = nil;
        }
    }

  return toolsInspector;
}

- (void)dealloc
{
  NSDebugLLog(@"Inspector", @"FileToolsInspector: dealloc");

  TEST_RELEASE(view);
  TEST_RELEASE(path);
  
  RELEASE(defaultEditor);

  [super dealloc];
}

- (void)awakeFromNib
{
  NSLog(@"[FileToolsInspector] awakeFromNib");
  [[appListView horizontalScroller] setArrowsPosition:NSScrollerArrowsNone];

  ws = [NSWorkspace sharedWorkspace];
  
  defaultEditor = [[[[NXDefaults userDefaults] objectForKey:@"DefaultEditor"]
                     stringByDeletingPathExtension] retain];
}

// --- Actions ---

- (void)appSelected:sender
{
  NSString *appFullPath;
  NSString *appName = [[sender selectedCell] title];

  if ([appName isEqualToString:[defaultAppField stringValue]])
    {
      return;
    }
  
  appFullPath = [ws fullPathForApplication:appName];
  
  [appPathField setStringValue:appFullPath];
  [defaultAppField setStringValue:appName];

  [super touch:self];
}

- (void)openWithApp:sender
{
  NSEnumerator *e = [files objectEnumerator];
  NSString     *f, *fp;

  while ((f = [e nextObject]) != nil)
    {
      fp = [path stringByAppendingPathComponent:f];
      [[NSApp delegate] openFile:fp
                 withApplication:[[sender selectedCell] title]];
    }
}


// --- Overrides ---

// nodep
- (BOOL)hasToolsInspector
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *defaultAppName;
  NSString *wsFileType, *fmFileType;
  NSString *fp;
  NSString *selectedPath = nil;
  NSArray  *selectedFiles = nil;

  [self getSelectedPath:&selectedPath andFiles:&selectedFiles];

  // Multiple selection
  if ([selectedFiles count] > 1)
    {
      NSEnumerator *e = [selectedFiles objectEnumerator];
      NSString     *ext=nil, *file=nil;
      while ((file = [e nextObject]) != nil)
        {
          if (ext == nil)
            {
              ext = [file pathExtension];
            }
          if (![[file pathExtension] isEqualToString:ext] ||
              ![fm isReadableFileAtPath:[selectedPath stringByAppendingPathComponent:file]])
            {
              return NO;
            }
        }
    }
  
  fp = [selectedPath
         stringByAppendingPathComponent:[selectedFiles objectAtIndex:0]];
  if (![fm isReadableFileAtPath:fp])
    {
      return NO;
    }
  
  [[NSApp delegate] getInfoForFile:fp
                       application:&defaultAppName
                              type:&wsFileType];

  fmFileType = [[fm fileAttributesAtPath:fp traverseLink:NO]
                 objectForKey:@"NSFileType"];
  if ([wsFileType isEqualToString:NSDirectoryFileType] ||
      [fmFileType isEqualToString:NSFileTypeDirectory])
    {
      return NO;
    }

  return YES;
}

// Set default
- (void)ok:sender
{
  NSMatrix     *matrix = [appListView documentView];
  NSButtonCell *selected, *first;
  NSString     *title = nil, *fp = nil;

  if ([matrix numberOfColumns] == 0)
    return;

  selected = [matrix selectedCell];
  first = [matrix cellAtRow:0 column:0];

  // Save default application
  fp = [path stringByAppendingPathComponent:[files objectAtIndex:0]];
  [ws setBestApp:[selected title]
	  inRole:nil
    forExtension:[fp pathExtension]];

  // Exchange the icons in the matrix
  ASSIGN(title, [selected title]);
  [selected setTitle:[first title]];
  [first setTitle:title];
  DESTROY(title);

  [first setImage:[ws iconForFile:[ws fullPathForApplication:[first title]]]];
  [selected setImage:[ws iconForFile:[ws fullPathForApplication:
                                           [selected title]]]];
  [matrix selectCellAtRow:0 column:0];
  [self appSelected:matrix];
}

- revert:sender
{
  NSLog(@"File Tools Inspector: revert:");
  NSMatrix      *matrix;
  NSButtonCell  *cell;
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString      *defaultAppName;
  NSString      *fileType;
  
  NSString      *selectedPath = nil, *fp;
  NSArray       *selectedFiles = nil;

  [self getSelectedPath:&selectedPath andFiles:&selectedFiles];

  ASSIGN(path, selectedPath);
  ASSIGN(files, selectedFiles);

  {
    [ws setBestApp:@"TextEdit" inRole:nil forExtension:@""];
    [[NSApp delegate] getInfoForFile:@"/Users/me"
                         application:&defaultAppName
                                type:&fileType];
    NSLog(@"Default application for all files: %@", defaultAppName);
    defaultAppName = nil;
    fileType = nil;
  }
  
  fp = [path stringByAppendingPathComponent:[files objectAtIndex:0]];
  [[NSApp delegate] getInfoForFile:fp
                       application:&defaultAppName
                              type:&fileType];

  // Create button matrix
  cell = [[NSButtonCell new] autorelease];
  [cell setImagePosition:NSImageOnly];
  [cell setButtonType:NSOnOffButton];
  [cell setRefusesFirstResponder:YES];
  
  matrix = [[[NSMatrix alloc] initWithFrame:NSMakeRect(0,0,64,64)] autorelease];
  [matrix setPrototype:cell];
  [matrix setCellSize:NSMakeSize(64, 64)];
  [matrix setTarget:self];
  [matrix setDoubleAction:@selector(openWithApp:)];
  [matrix setAction:@selector(appSelected:)];
  [matrix setAutoscroll:YES];
  [matrix setIntercellSpacing:NSZeroSize];

  if (defaultAppName != nil ||
      (defaultEditor != nil &&
       ([fileType isEqualToString:NSPlainFileType] ||
        [fileType isEqualToString:NSShellCommandFileType])))
    {
      NSEnumerator *e;
      NSString     *appName;
      NSButtonCell *cell;
      NSDictionary *extInfo;
      BOOL         seenDefaultEditor = NO;

      if (defaultAppName == nil)
        {
          defaultAppName = defaultEditor;
          seenDefaultEditor = YES;
        }
      else
        {
          defaultAppName = [defaultAppName stringByDeletingPathExtension];
          if ([defaultAppName isEqualToString:defaultEditor])
            {
              seenDefaultEditor = YES;
            }
        }

      AddAppToMatrix(defaultAppName, matrix);

      if ((extInfo = [ws infoForExtension:[fp pathExtension]]))
        {
          e = [[[extInfo allKeys] sortedArrayUsingSelector:
                          @selector(caseInsensitiveCompare:)] objectEnumerator];
          while ((appName = [e nextObject]) != nil)
            {
              appName = [appName stringByDeletingPathExtension];

              if ([appName isEqualToString:defaultAppName])
                continue;
              if ([appName isEqualToString:defaultEditor])
                seenDefaultEditor = YES;

              AddAppToMatrix(appName, matrix);
            }
        }

      if (seenDefaultEditor == NO && defaultEditor != nil)
        {
          AddAppToMatrix(defaultEditor, matrix);
        }

      [self appSelected:matrix];
    }
  else
    {
      [defaultAppField setStringValue:nil];
      [appPathField setStringValue:nil];
    }

  [matrix sizeToCells];
  [appListView setDocumentView:matrix];

  [super revert:self];
  [[[self okButton] cell] setTitle:@"Set Default"];

  return self;
}

@end
