/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - DesktopKit framework
//
// Description: Standard panel for application help.
//
// Copyright (C) 2019 Sergii Stoian
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
#import <Foundation/Foundation.h>
#import <AppKit/NSAttributedString.h>
#import <AppKit/NSNibLoading.h>
#import <GNUstepGUI/GSHelpAttachment.h>

#import "NXTPanelLoader.h"
#import "NXTAlert.h"
#import "NXTHelpPanel.h"

static NXTHelpPanel *_sharedHelpPanel = nil;
static NSString     *_helpDirectory = nil;

// @interface TOCListCell : NSTextFieldCell
// {
//   BOOL _isSelected;
// }
// @end
// @implementation TOCListCell

// @end

// @interface TOCList : NXMatrix
// @end
// @implementation TOCList
// @end

@implementation NXTHelpPanel (PrivateMethods)

- (void)_loadTableOfContents:(NSString *)tocFilePath
{
  NSMutableDictionary *toc;
  NSAttributedString *attrString;
  NSString           *text;
  NSRange            range;
  NSDictionary       *attrs;
  id                 attachment;

  NSLog(@"Load TOC from: %@", tocFilePath);

  toc = [NSMutableDictionary new];
  attrString = [[NSAttributedString alloc]
                   initWithRTF:[NSData dataWithContentsOfFile:tocFilePath]
                 documentAttributes:NULL];
  text = [attrString string];
    
  for (int i = 0; i < [text length]; i++) {
    attrs = [attrString attributesAtIndex:i effectiveRange:&range];
    // NSLog(@"[%d] %@ - (%@)", i, attrs, NSStringFromRange(range));
    if ((attachment = [attrs objectForKey:@"NSAttachment"]) != nil) {
      range = [text lineRangeForRange:range];
      range.location++;
      range.length -= 2;
      NSLog(@"%@ -> %@", [text substringWithRange:range], [attachment fileName]);
      [toc setObject:[attachment fileName] forKey:[text substringWithRange:range]];
    }
    i = range.location + range.length;
  }

  if (tableOfContents != nil) {
    [tableOfContents release];
  }
  tableOfContents = [[NSDictionary alloc] initWithDictionary:toc];
  [attrString release];
  [toc release];
}

// Brower delegate methods
- (void)     browser:(NSBrowser *)sender
 createRowsForColumn:(NSInteger)column
            inMatrix:(NSMatrix *)matrix
{
  NSBrowserCell      *cell;
  NSAttributedString *attrString;
  NSString           *text;
  NSRange            range;
  NSDictionary       *attrs;
  id                 attachment;
  NSString           *tocFilePath;

  tocFilePath = [NSString stringWithFormat:@"%@/TableOfContents.rtf",
                          _helpDirectory];
  NSLog(@"Load TOC from: %@", tocFilePath);

  attrString = [[NSAttributedString alloc]
                   initWithRTF:[NSData dataWithContentsOfFile:tocFilePath]
                 documentAttributes:NULL];
  text = [attrString string];
    
  for (int i = 0; i < [text length]; i++) {
    attrs = [attrString attributesAtIndex:i effectiveRange:&range];
    if ((attachment = [attrs objectForKey:@"NSAttachment"]) != nil) {
      range = [text lineRangeForRange:range];
      range.location++;
      range.length -= 2;
      // NSLog(@"%@ -> %@", [text substringWithRange:range], [attachment fileName]);
      
      [matrix addRow];
      cell = [matrix cellAtRow:[matrix numberOfRows] - 1 column:column];
      [cell setLeaf:YES];
      [cell setRefusesFirstResponder:NO];
      [cell setTitle:[text substringWithRange:range]];
      [cell setRepresentedObject:[attachment fileName]];
    }
    i = range.location + range.length;
  }
}

- (void)showArticle
{
  NSLog(@"Will show document: %@",
        [[tocList selectedCellInColumn:0] representedObject]);
}

@end

@implementation NXTHelpPanel : NSPanel

+ (NXTHelpPanel *)sharedHelpPanel
{
  if (_sharedHelpPanel == nil) {
    [self sharedHelpPanelWithDirectory:_helpDirectory];
  }
  return _sharedHelpPanel;
}
+ (NXTHelpPanel *)sharedHelpPanelWithDirectory:(NSString *)helpDirectory
{
  NSString *tocFilePath;
  
  // Check if TableOfContents exists inside helpDirectory
  tocFilePath = [NSString stringWithFormat:@"%@/TableOfContents.rtf",
                          helpDirectory];
  if ([[NSFileManager defaultManager] fileExistsAtPath:tocFilePath] == NO) {
    NXTRunAlertPanel(@"Help", @"NEXTSPACE Help isn't available for %@",
                     @"OK", nil, nil,
                     [[NSProcessInfo processInfo] processName]);
    return nil;
  }

  // Create instance
  [self setHelpDirectory:helpDirectory];
  if (_sharedHelpPanel == nil) {
    _sharedHelpPanel = [[NXTPanelLoader alloc] loadPanelNamed:@"NXTHelpPanel"];
  }

  // Load model file
  // if (![NSBundle loadNibNamed:@"NXTHelpPanel" owner:self]) {
  //   NSLog(@"Cannot open HelpPanel model file!");
  // }

  return _sharedHelpPanel;
}

- (id)init
{
  self = [NXTHelpPanel sharedHelpPanel];
  return self;
}

- (void)awakeFromNib
{
  // TOC list
  tocList = [[NSBrowser alloc] initWithFrame:NSMakeRect(0,0,414,200)];
  [tocList setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
  [tocList setMaxVisibleColumns:1];
  [tocList setHasHorizontalScroller:NO];
  [tocList setSeparatesColumns:YES];
  [tocList setTitled:NO];
  [tocList setDelegate:self];
  [tocList setAction:@selector(showArticle)];
  [splitView addSubview:tocList];
  [tocList release];

  [tocList loadColumnZero];

  // Article
}

// --- Managing the Contents

+ (void)setHelpDirectory:(NSString *)helpDirectory
{
  if (_helpDirectory) {
    [_helpDirectory release];
  }
  _helpDirectory = [[NSString alloc] initWithString:helpDirectory];
}

- (void)addSupplement:(NSString *)helpDirectory
               inPath:(NSString *)supplementPath
{
  NSWarnFLog(@"Not implemented");
}

- (NSString *)helpDirectory
{
  return _helpDirectory;
}

- (NSString *)helpFile
{
  NSWarnFLog(@"Not implemented");
  return nil;
}


// --- Attaching Help to Objects

+ (void)attachHelpFile:(NSString *)filename
            markerName:(NSString *)markerName
                    to:(id)anObject
{
  NSWarnFLog(@"Not implemented");
}

+ (void)detachHelpFrom:(id)anObject
{
  NSWarnFLog(@"Not implemented");
}

// --- Showing Help

- (void)showFile:(NSString *)filename
        atMarker:(NSString *)markerName
{
  NSWarnFLog(@"Not implemented");
}

- (BOOL)showHelpAttachedTo:(id)anObject
{
  NSWarnFLog(@"Not implemented");
  return NO;
}

// --- Printing 
- (void)print:(id)sender
{
  NSLog(@"Not implemented");
}

@end
