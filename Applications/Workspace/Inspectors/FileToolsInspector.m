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

#import <DesktopKit/NXTDefaults.h>
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

  RELEASE(defaultEditor);

  [super dealloc];
}

- (void)awakeFromNib
{
  NSButtonCell *cell;

  NSDebugLLog(@"Inspector", @"[FileToolsInspector] awakeFromNib");
  ws = [NSApp delegate];

  defaultEditor =
      [[[NXTDefaults userDefaults] objectForKey:@"DefaultEditor"] stringByDeletingPathExtension];
  [defaultEditor retain];

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
  NSString *appFullPath;
  NSString *appName = [[sender selectedCell] title];

  if ([appName isEqualToString:[defaultAppField stringValue]]) {
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
  if ([wsFileType isEqualToString:NSDirectoryFileType] ||
      [fmFileType isEqualToString:NSFileTypeDirectory]) {
    return NO;
  }

  return YES;
}

// Set default
- (void)ok:sender
{
  NSMatrix *matrix = [appListView documentView];
  NSButtonCell *selected, *first;
  NSString *title = nil, *fp = nil;

  if ([matrix numberOfColumns] == 0)
    return;

  selected = [matrix selectedCell];
  first = [matrix cellAtRow:0 column:0];

  // Save default application
  fp = [path stringByAppendingPathComponent:[files objectAtIndex:0]];
  [ws setBestApp:[selected title] inRole:nil forExtension:[fp pathExtension]];

  // Exchange the icons in the matrix
  ASSIGN(title, [selected title]);
  [selected setTitle:[first title]];
  [first setTitle:title];
  DESTROY(title);

  [first setImage:[ws iconForFile:[ws fullPathForApplication:[first title]]]];
  [selected setImage:[ws iconForFile:[ws fullPathForApplication:[selected title]]]];
  [matrix selectCellAtRow:0 column:0];
  [self appSelected:matrix];
}

- revert:sender
{
  // NSDebugLLog(@"Inspector", @"File Tools Inspector: revert:");
  NSLog(@"File Tools Inspector: revert:");
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *defaultAppName;
  NSString *fileType;
  NSString *selectedPath;
  NSString *filePath;
  NSArray *selectedFiles;

  [self getSelectedPath:&selectedPath andFiles:&selectedFiles];

  ASSIGN(path, selectedPath);
  ASSIGN(files, selectedFiles);

  filePath = [path stringByAppendingPathComponent:[files objectAtIndex:0]];
  [[NSApp delegate] getInfoForFile:filePath application:&defaultAppName type:&fileType];

  if ([appMatrix numberOfRows] > 0) {
    [appMatrix removeRow:0];
  }

  if (defaultAppName != nil ||
      (defaultEditor != nil && ([fileType isEqualToString:NSPlainFileType] ||
                                [fileType isEqualToString:NSShellCommandFileType]))) {
    NSString *appName;
    NSDictionary *extInfo;
    BOOL seenDefaultEditor = NO;

    if (defaultAppName == nil) {
      defaultAppName = defaultEditor;
      seenDefaultEditor = YES;
    } else {
      defaultAppName = [defaultAppName stringByDeletingPathExtension];
      if ([defaultAppName isEqualToString:defaultEditor]) {
        seenDefaultEditor = YES;
      }
    }

    AddAppToMatrix(defaultAppName, appMatrix);

    if ((extInfo = [ws _infoForExtension:[filePath pathExtension]])) {
      NSLog(@"Inspector: extension info: %@", extInfo);
      for (appName in [extInfo allKeys]) {
        appName = [appName stringByDeletingPathExtension];

        if ([appName isEqualToString:defaultAppName])
          continue;
        if ([appName isEqualToString:defaultEditor])
          seenDefaultEditor = YES;

        AddAppToMatrix(appName, appMatrix);
      }
    }

    if (seenDefaultEditor == NO && defaultEditor != nil) {
      AddAppToMatrix(defaultEditor, appMatrix);
    }
    [self appSelected:appMatrix];
  } else {
    [defaultAppField setStringValue:nil];
    [appPathField setStringValue:nil];
  }

  [appMatrix sizeToCells];

  [super revert:self];
  [[[self okButton] cell] setTitle:@"Set Default"];

  return self;
}

@end
