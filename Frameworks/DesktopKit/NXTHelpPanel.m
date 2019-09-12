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
#import "NXTListView.h"
#import "NXTHelpPanel.h"

static NXTHelpPanel *_sharedHelpPanel = nil;
static NSString     *_helpDirectory = nil;

@implementation NXTHelpPanel (PrivateMethods)

- (void)_loadTableOfContents:(NSString *)tocFilePath
{
  NSMutableArray     *titles, *attachments;
  NSAttributedString *attrString;
  NSString           *text, *t;
  NSRange            range;
  NSDictionary       *attrs;
  id                 attachment;

  // NSLog(@"Load TOC from: %@", tocFilePath);

  titles = [NSMutableArray new];
  attachments = [NSMutableArray new];
  attrString = [[NSAttributedString alloc]
                   initWithRTF:[NSData dataWithContentsOfFile:tocFilePath]
                 documentAttributes:NULL];
  text = [attrString string];
    
  for (int i = 0; i <= [text length]; i++) {
    attrs = [attrString attributesAtIndex:i effectiveRange:&range];
    // NSLog(@"[%d] %@ - (%@)", i, attrs, NSStringFromRange(range));
    // NSLog(@"Font for(%@): %@", [text substringWithRange:range],
    //       [attrs objectForKey:@"NSFont"]);
    if ((attachment = [attrs objectForKey:@"NSAttachment"]) != nil) {
      range = [text lineRangeForRange:range];
      // Skip attachment symbol
      range.location++;
      range.length--;
      // Exclude new line character if any
      if ([[text substringFromRange:range]
            characterAtIndex:range.length-1] == '\n') {
        range.length--;
      }
      [titles addObject:[attrString attributedSubstringFromRange:range]];
      [attachments addObject:[attachment fileName]];
    }
    else {
      if ([[text substringFromRange:range] length] > 0) {
        [titles addObject:[attrString attributedSubstringFromRange:range]];
        [attachments addObject:@""];
      }
    }
    i = range.location + range.length;
  }

  if (tocTitles != nil) [titles release];
  tocTitles = [[NSArray alloc] initWithArray:titles];
  [titles release];
  if (tocAttachments != nil) [titles release];
  tocAttachments = [[NSArray alloc] initWithArray:attachments];
  [attachments release];
  
  [attrString release];
}

- (void)_showArticle
{
  NSCell *cell = [tocList selectedCell];
  NSString *docPath;
  NSString *artPath;

  docPath = [cell representedObject];
  NSLog(@"[HelpPanel] showArticle doc path: %@", docPath);
  
  if (docPath && [docPath isEqualToString:@""] == NO) {
    artPath = [_helpDirectory stringByAppendingPathComponent:docPath];
    [articleView readRTFDFromFile:artPath];
  }
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
  return _sharedHelpPanel;
}

- (id)init
{
  self = [NXTHelpPanel sharedHelpPanel];
  return self;
}

- (void)awakeFromNib
{
  NSString *tocFilePath;
  
  tocFilePath = [_helpDirectory
                  stringByAppendingPathComponent:@"TableOfContents.rtf"];
  [self _loadTableOfContents:tocFilePath];

  // TOC list
  tocList = [[NXTListView alloc] initWithFrame:NSMakeRect(0,0,414,200)];
  [splitView addSubview:tocList];
  [tocList setTarget:self];
  [tocList setAction:@selector(_showArticle)];
  [tocList loadTitles:tocTitles andObjects:tocAttachments];
  [tocList release];

  // Article
  NSScrollView *scrollView;
  scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0,0,414,200)];
  [scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  [scrollView setHasVerticalScroller:YES];
  [scrollView setBorderType:NSBezelBorder];
  articleView = [[NSTextView alloc] initWithFrame:NSMakeRect(0,0,394,200)];
  [articleView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  [articleView setEditable:NO];
  [scrollView setDocumentView:articleView];
  [splitView addSubview:scrollView];
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
