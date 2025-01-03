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

#include <AppKit/AppKit.h>

#import <SystemKit/OSEDefaults.h>
#import <DesktopKit/Utilities.h>
#import "FileToolsInspector.h"

static inline void AddAppToMatrix(NSString *appName, NSMatrix *matrix)
{
  NSButtonCell *cell;
  NSImage *icon;
  NSString *appPath;

  [matrix addColumn];
  cell = [matrix cellAtRow:0 column:[matrix numberOfColumns] - 1];
  [cell setTitle:appName];
  appPath = [[NSApp delegate] fullPathForApplication:appName];
  if (appPath) {
    icon = [[NSApp delegate] iconForFile:appPath];
    if (icon) {
      [cell setImage:icon];
    }
  }
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
  if (toolsInspector == nil) {
    toolsInspector = [super new];
    if (![NSBundle loadNibNamed:@"FileToolsInspector" owner:toolsInspector]) {
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

  [super dealloc];
}

- (void)awakeFromNib
{
  NSButtonCell *cell;

  NSDebugLLog(@"Inspector", @"[FileToolsInspector] awakeFromNib");
  workspace = [NSApp delegate];

  // App matrix scrollview
  [appListView setBorderType:NSBezelBorder];
  [appListView setHasHorizontalScroller:YES];
  [[appListView horizontalScroller] setArrowsPosition:NSScrollerArrowsNone];

  // App matrix
  cell = [[NSButtonCell new] autorelease];
  [cell setImagePosition:NSImageOnly];
  [cell setButtonType:NSOnOffButton];
  [cell setRefusesFirstResponder:YES];

  appMatrix = [[[NSMatrix alloc] initWithFrame:NSMakeRect(0, 0, 64, 64)] autorelease];
  [appMatrix setPrototype:cell];
  [appMatrix setCellSize:NSMakeSize(64, 64)];
  [appMatrix setTarget:self];
  [appMatrix setDoubleAction:@selector(openWithApp:)];
  [appMatrix setAction:@selector(appSelected:)];
  [appMatrix setAutoscroll:YES];
  [appMatrix setIntercellSpacing:NSZeroSize];

  [appListView setDocumentView:appMatrix];
}

// --- Actions ---

- (void)appSelected:sender
{
  NSString *appName = [[sender selectedCell] title];
  NSString *appFullPath;

  if (appName == nil) {
    return;
  }

  // Default:
  if ([sender selectedCell] == [sender cellAtRow:0 column:0]) {
    [defaultAppField setStringValue:appName];
  }

  // Path:
  appFullPath = [workspace fullPathForApplication:appName];
  if (appFullPath != nil) {
    appFullPath = NXTShortenString(appFullPath, [appPathField frame].size.width,
                                   [appPathField font], NXPathElement, NXTDotsAtLeft);
    [appPathField setStringValue:appFullPath];
  }

  [super touch:self];
}

- (void)openWithApp:sender
{
  NSEnumerator *e = [files objectEnumerator];
  NSString *f, *fp;

  while ((f = [e nextObject]) != nil) {
    fp = [path stringByAppendingPathComponent:f];
    [[NSApp delegate] openFile:fp withApplication:[[sender selectedCell] title]];
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
  NSArray *selectedFiles = nil;

  [self getSelectedPath:&selectedPath andFiles:&selectedFiles];

  // Multiple selection
  if ([selectedFiles count] > 1) {
    NSEnumerator *e = [selectedFiles objectEnumerator];
    NSString *ext = nil, *file = nil;
    while ((file = [e nextObject]) != nil) {
      if (ext == nil) {
        ext = [file pathExtension];
      }
      if (![[file pathExtension] isEqualToString:ext] ||
          ![fm isReadableFileAtPath:[selectedPath stringByAppendingPathComponent:file]]) {
        return NO;
      }
    }
  }

  fp = [selectedPath stringByAppendingPathComponent:[selectedFiles objectAtIndex:0]];
  if (![fm isReadableFileAtPath:fp]) {
    return NO;
  }

  [[NSApp delegate] getInfoForFile:fp application:&defaultAppName type:&wsFileType];

  fmFileType = [[fm fileAttributesAtPath:fp traverseLink:NO] objectForKey:@"NSFileType"];
  if (([wsFileType isEqualToString:NSDirectoryFileType] ||
       [fmFileType isEqualToString:NSFileTypeDirectory]) && defaultAppName == nil) {
    return NO;
  }

  return YES;
}

// Set default
- (void)ok:sender
{
  NSButtonCell *selected, *first;
  NSString *title = nil, *fp = nil;

  if ([appMatrix numberOfColumns] == 0)
    return;

  selected = [appMatrix selectedCell];
  first = [appMatrix cellAtRow:0 column:0];

  // Save default application
  fp = [path stringByAppendingPathComponent:[files firstObject]];
  [workspace setBestApp:[selected title] inRole:nil forExtension:[fp pathExtension]];

  // Exchange the icons in the matrix
  ASSIGN(title, [selected title]);
  [selected setTitle:[first title]];
  [first setTitle:title];
  DESTROY(title);

  [first setImage:[workspace iconForFile:[workspace fullPathForApplication:[first title]]]];
  [selected setImage:[workspace iconForFile:[workspace fullPathForApplication:[selected title]]]];

  [appMatrix selectCellAtRow:0 column:0];
  [self appSelected:appMatrix];
  [super revert:self];
}

- revert:sender
{
  NSDebugLLog(@"Inspector", @"File Tools Inspector: revert:");
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *defaultAppName;
  NSString *fileType;
  NSString *selectedPath;
  NSString *filePath;
  NSArray *selectedFiles;
  NSDictionary *appList;

  [self getSelectedPath:&selectedPath andFiles:&selectedFiles];

  ASSIGN(path, selectedPath);
  ASSIGN(files, selectedFiles);

  filePath = [path stringByAppendingPathComponent:[files firstObject]];
  [[NSApp delegate] getInfoForFile:filePath application:&defaultAppName type:&fileType];

  if ([appMatrix numberOfRows] > 0) {
    [appMatrix removeRow:0];
  }
  defaultAppName = [defaultAppName stringByDeletingPathExtension];
  AddAppToMatrix(defaultAppName, appMatrix);

  if ((appList = [[NSApp delegate] applicationsForExtension:[filePath pathExtension]])) {
    for (NSString *appName in [appList allKeys]) {
      appName = [appName stringByDeletingPathExtension];
      if ([appName isEqualToString:defaultAppName]) {
        continue;
      }
      AddAppToMatrix(appName, appMatrix);
    }
  }

  [self appSelected:appMatrix];
  [appMatrix sizeToCells];
  [super revert:self];
  [[[self okButton] cell] setTitle:@"Set Default"];

  return self;
}

@end
