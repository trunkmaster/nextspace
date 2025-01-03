/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Copyright (C) 2015-2019 Sergii Stoian
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

//
// The default file contents inspector: shows file description returned
// by OSEFileManager (libmagic functionality).
// Contents inspectors manager: finds, loads .inspector bundles and returns
// particular inspector for specified file extension.
//

#import <DesktopKit/NXTBundle.h>
#import <SystemKit/OSEFileManager.h>

#import <dispatch/dispatch.h>

#import "FileInspector.h"

NSUInteger numberOfLinesInString(NSString *string)
{
  NSUInteger numberOfLines, index, stringLength = [string length];

  for (index = 0, numberOfLines = 0; index < stringLength; numberOfLines++) {
    index = NSMaxRange([string lineRangeForRange:NSMakeRange(index, 0)]);
  }

  return numberOfLines;
}

@interface FileInspector (Private)

- (void)_showTextFields:(BOOL)show;
- (void)_initTextView;
- (void)_showFileContentsAtPath:(NSString *)path;
- (void)_showFileSelection:(NSArray *)files;

@end

@implementation FileInspector (Private)

- (void)_showTextFields:(BOOL)show
{
  if (show) {
    [linesLabel setTextColor:[NSColor controlTextColor]];
    [linesField setTextColor:[NSColor controlTextColor]];
    [encodingLabel setTextColor:[NSColor controlTextColor]];
    [encodingField setTextColor:[NSColor controlTextColor]];
  } else {
    [linesLabel setTextColor:[NSColor controlBackgroundColor]];
    [linesField setTextColor:[NSColor controlBackgroundColor]];
    [encodingLabel setTextColor:[NSColor controlBackgroundColor]];
    [encodingField setTextColor:[NSColor controlBackgroundColor]];
  }
}

- (void)_initTextView
{
  NSDictionary *selTextAttrs;

  [fileInfoText setAlignment:NSCenterTextAlignment];
  [fileInfoText setFont:[NSFont systemFontOfSize:0.0]];
  [fileInfoText setBackgroundColor:[NSColor controlBackgroundColor]];

  selTextAttrs = @{
    NSBackgroundColorAttributeName : [NSColor whiteColor],
    NSForegroundColorAttributeName : [NSColor blackColor]
  };
  [fileInfoText setSelectedTextAttributes:selTextAttrs];

  [[fileInfoText enclosingScrollView] setBorderType:NSNoBorder];
  [[fileInfoText enclosingScrollView] setHasVerticalScroller:NO];
}

- (void)_showFileContentsAtPath:(NSString *)path
{
  NSDictionary *selTextAttrs;
  NSFileHandle *handle;
  NSData *data;
  NSString *string;
  unsigned showedLines, allLines;

  // Prepare text view
  [fileInfoText setAlignment:NSLeftTextAlignment];
  [fileInfoText setFont:[NSFont toolTipsFontOfSize:0.0]];
  [fileInfoText setBackgroundColor:[NSColor whiteColor]];
  selTextAttrs = @{
    NSBackgroundColorAttributeName : [NSColor lightGrayColor],
    NSForegroundColorAttributeName : [NSColor blackColor]
  };
  [fileInfoText setSelectedTextAttributes:selTextAttrs];

  [[fileInfoText enclosingScrollView] setBorderType:NSBezelBorder];
  [[fileInfoText enclosingScrollView] setHasVerticalScroller:YES];
  [fileInfoText setAutoresizingMask:NSViewHeightSizable];
  // [[fileInfoText enclosingScrollView] setHasHorizontalScroller:YES];
  // [[fileInfoText textContainer] setWidthTracksTextView:NO];

  // Load 1KB of text from file
  handle = [NSFileHandle fileHandleForReadingAtPath:path];
  data = [handle readDataOfLength:1024];
  string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

  showedLines = numberOfLinesInString(string);
  allLines = numberOfLinesInString([NSString stringWithContentsOfFile:path]);

  if (showedLines == allLines) {
    [fileInfoText setText:string];
  } else {
    [fileInfoText setText:[NSString stringWithFormat:@"%@\n...", string]];
  }

  [string release];

  // Meta information
  [encodingField setStringValue:[[OSEFileManager defaultManager] mimeEncodingForFile:path]];

  [linesField setStringValue:[NSString stringWithFormat:@"%i/%i", showedLines, allLines]];

  [[[self okButton] cell] setTitle:@"Edit"];
  [[self okButton] setEnabled:YES];
}

- (void)_showFileSelection:(NSArray *)files
{
  NSDictionary *selTextAttrs;
  NSEnumerator *e = [files objectEnumerator];
  NSString *file;
  NSMutableString *filesString = [NSMutableString new];

  [fileInfoText setAlignment:NSLeftTextAlignment];
  [[fileInfoText enclosingScrollView] setBorderType:NSBezelBorder];
  [[fileInfoText enclosingScrollView] setHasVerticalScroller:YES];

  while ((file = [e nextObject]) != nil) {
    [filesString appendFormat:@"%@\n", file];
  }

  [fileInfoText setText:filesString];
}

@end

static id contentsInspector = nil;

@implementation FileInspector

// Class Methods

+ new
{
  if (contentsInspector == nil) {
    contentsInspector = [super new];
    if (![NSBundle loadNibNamed:@"FileInspector" owner:contentsInspector]) {
      contentsInspector = nil;
    }
  }

  return contentsInspector;
}

- (void)dealloc
{
  NSDebugLLog(@"Inspector", @"FileContentsInspector: dealloc");

  TEST_RELEASE(view);

  [super dealloc];
}

- (void)awakeFromNib
{
  [fileInfoText setSelectable:YES];
}

// Public Methods

- ok:sender
{
  NSString *fp;

  fp = [selectedPath stringByAppendingPathComponent:[selectedFiles objectAtIndex:0]];

  [[NSApp delegate] openFile:fp];

  return self;
}

- revert:sender
{
  NSString *file;
  NSString *filePath;
  OSEFileManager *fm = [OSEFileManager defaultManager];
  NSDictionary *fattrs;
  NSString *mimeType;

  [self getSelectedPath:&selectedPath andFiles:&selectedFiles];

  // Buttons state and title, window edited state
  [super revert:self];

  [self _initTextView];
  [self _showTextFields:NO];

  [fileInfoText setText:@"Loading..."];

  if ([selectedFiles count] > 1) {
    [self _showFileSelection:selectedFiles];
  } else {
    file = [selectedFiles objectAtIndex:0];
    filePath = [selectedPath stringByAppendingPathComponent:file];
    mimeType = [fm mimeTypeForFile:filePath];
    if ([[[mimeType pathComponents] objectAtIndex:0] isEqualToString:@"text"]) {
      [self _showTextFields:YES];
      // dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
      [self _showFileContentsAtPath:filePath];
      // });
    } else if ([[file pathExtension] isEqualToString:@"gorm"]) {
      [fileInfoText setText:@"GNUstep Object Relationship Modeller file"];
    } else {
      // dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
      [fileInfoText setText:[fm descriptionForFile:filePath]];
      //                });
    }
  }

  return self;
}

@end
