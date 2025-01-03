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

#import <dispatch/dispatch.h>

#import "RTFInspector.h"

static inline NSUInteger numberOfLinesInString(NSString *string)
{
  NSUInteger numberOfLines, index, stringLength = [string length];

  for (index = 0, numberOfLines = 0; index < stringLength; numberOfLines++) {
    index = NSMaxRange([string lineRangeForRange:NSMakeRange(index, 0)]);
  }

  return numberOfLines;
}

@interface RTFInspector (Private)

- (void)_showFileContentsAtPath:(NSString *)path;

@end

@implementation RTFInspector (Private)

- (void)_showFileContentsAtPath:(NSString *)path
{
  NSDictionary *selTextAttrs;
  NSFileHandle *handle;
  NSData *data;
  NSString *string;
  NSUInteger showedLines, allLines;

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

  [linesField setStringValue:[NSString stringWithFormat:@"%lu/%lu", showedLines, allLines]];

  [[[self okButton] cell] setTitle:@"Edit"];
  [[self okButton] setEnabled:YES];
}

@end

static id contentsInspector = nil;

@implementation RTFInspector

// Class Methods

+ new
{
  if (contentsInspector == nil) {
    contentsInspector = [super new];
    if (![NSBundle loadNibNamed:@"RTFInspector" owner:contentsInspector]) {
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
  NSString *filePath;
  NSData *fileContentsAsData;
  NSDictionary *docAttrs;
  NSSize size = NSZeroSize;
  CGFloat factor = 0.0;
  NSTextStorage *newTextStorage = nil;
  OSEFileManager *fm = [OSEFileManager defaultManager];

  [self getSelectedPath:&selectedPath andFiles:&selectedFiles];
  filePath = [selectedPath stringByAppendingPathComponent:[selectedFiles objectAtIndex:0]];

  // Buttons state and title, window edited state
  [super revert:self];

  fileContentsAsData = [[NSData alloc] initWithContentsOfFile:filePath];
  newTextStorage = [[NSTextStorage alloc] initWithRTF:fileContentsAsData
                                   documentAttributes:&docAttrs];
  if (newTextStorage) {
    // [[fileInfoText layoutManager]
    //    setHyphenationFactor:
    //     [[docAttrs objectForKey:@"HyphenationFactor"] floatValue]];
    [[fileInfoText layoutManager] replaceTextStorage:newTextStorage];

    // Meta information
    [encodingField setStringValue:[fm mimeEncodingForFile:filePath]];

    [linesField setStringValue:[NSString stringWithFormat:@"%lu", numberOfLinesInString(
                                                                      [newTextStorage string])]];
    [newTextStorage release];

    [[[self okButton] cell] setTitle:@"Edit"];
    [[self okButton] setEnabled:YES];
  }

  [fileContentsAsData release];

  return self;
}

@end
