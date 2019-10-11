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
#import "NXTSplitView.h"

// Singleton
static NXTHelpPanel *_sharedHelpPanel = nil;
static NSRange      selectedRange;
static NSUInteger   selectedItemIndex;

@implementation NSApplication (NSApplicationHelpExtension)
- (void)orderFrontHelpPanel:(id)sender
{
  [[NXTHelpPanel sharedHelpPanel] makeKeyAndOrderFront:self];
}
@end

@implementation NSString (NSStringTextFinding)

- (NSRange)findString:(NSString *)string
        selectedRange:(NSRange)selectedRange
              options:(unsigned)options
                 wrap:(BOOL)wrap
{
  BOOL         forwards = (options & NSBackwardsSearch) == 0;
  unsigned int length = [self length];
  NSRange      searchRange, range;

  if (forwards) {
    searchRange.location = NSMaxRange(selectedRange);
    searchRange.length = length - searchRange.location;
    range = [self rangeOfString:string options:options range:searchRange];

    if ((range.length == 0) && wrap) {
      /* If not found look at the first part of the string */
      searchRange.location = 0;
      searchRange.length = selectedRange.location;
      range = [self rangeOfString:string options:options range:searchRange];
    }
  }
  else {
    searchRange.location = 0;
    searchRange.length = selectedRange.location;
    range = [self rangeOfString:string options:options range:searchRange];
    
    if ((range.length == 0) && wrap) {
      searchRange.location = NSMaxRange(selectedRange);
      searchRange.length = length - searchRange.location;
      range = [self rangeOfString:string options:options range:searchRange];
    }
  }
  return range;
}

@end

@interface NXTHelpArticle : NSTextView
@end
@implementation NXTHelpArticle
- (void)resetCursorRects
{
  NSSize   aSize;
  NSRange  gRange = [_layoutManager glyphRangeForBoundingRect:[self bounds]
                                              inTextContainer:_textContainer];
  NSRect   gRect;

  // Set pointing hand cursor to links
  // TODO: It's assumed that links cell size is 11x11. Check if glyph really
  // represents NeXTHelpLink RTF keyword (not just image).
  for (NSUInteger index = 0; index < gRange.length; index++) {
    aSize = [_layoutManager attachmentSizeForGlyphAtIndex:index];
    if (aSize.width == 12 && aSize.height == 12) {
      gRect = [_layoutManager boundingRectForGlyphRange:NSMakeRange(index,1)
                                        inTextContainer:_textContainer];
      gRect.origin.x += (gRect.size.width-12)/2;
      gRect.origin.y += (gRect.size.height-12)/2;
      gRect.size = aSize;
      [self addCursorRect:gRect cursor:[NSCursor pointingHandCursor]];
    }
  }
  // NSLog(@"resetCursorRects");
}
@end

@implementation NXTHelpPanel (PrivateMethods)

// --- History
- (void)_updateHistoryWithIndex:(NSUInteger)index
                   documentPath:(NSString *)path
{
  if (historyPosition < historyLength) {
    if (historyPosition >= 0) {
      history[historyPosition].rect = [articleView visibleRect];
    }
    historyPosition++;
    history[historyPosition].index = index;
    history[historyPosition].documentPath = [path copy];
    [backtrackBtn setEnabled:(historyPosition > 0)];
    // NSLog(@"Update history[%i] with index: %lu", historyPosition, index);
  }
}

- (void)_setHelpDirectory:(NSString *)helpDirectory
{
  if (_helpDirectory == helpDirectory) {
    return;
  }
  
  if (_helpDirectory) {
    [_helpDirectory release];
  }
  _helpDirectory = [[NSString alloc] initWithString:helpDirectory];
}

- (void)_loadTableOfContents:(NSString *)tocFilePath
{
  NSMutableArray     *titles, *attachments;
  NSAttributedString *attrString;
  NSString           *text, *t;
  NSRange            range;
  NSDictionary       *attrs;
  id                 attachment;
  NSString           *fileName;

  NSLog(@"Load TOC from: %@", tocFilePath);

  titles = [NSMutableArray new];
  attachments = [NSMutableArray new];
  attrString = [[NSAttributedString alloc]
                   initWithRTF:[NSData dataWithContentsOfFile:tocFilePath]
                 documentAttributes:NULL];
  text = [attrString string];
    
  for (int i = 0; i < [text length]; i++) {
    attrs = [attrString attributesAtIndex:i effectiveRange:&range];
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
      
      fileName = [attachment fileName];
      if ([fileName rangeOfString:@"Objects"].location == 0) {
        objectsPrologIndex = [attachments count];
      }
      [attachments addObject:fileName];
    }
    else {
      if ([[text substringFromRange:range] length] > 0) {
        // Exclude new line character if any
        if ([[text substringFromRange:range] characterAtIndex:range.length-1] == '\n') {
          range.length--;
        }
        [titles addObject:[attrString attributedSubstringFromRange:range]];
        [attachments addObject:@""];
      }
    }
    i = range.location + range.length;
  }

  if (tocTitles != nil) [tocTitles release];
  tocTitles = [[NSArray alloc] initWithArray:titles];
  [titles release];
  if (tocAttachments != nil) [tocAttachments release];
  tocAttachments = [[NSArray alloc] initWithArray:attachments];
  [attachments release];
  
  [attrString release];
}

// Returns full path to file with article document
- (NSString *)_filePathForAttachment:(NSString *)attachment
{
  NSString *artPath = nil;

  if (!attachment && [attachment isEqualToString:@""] != NO) {
    return nil;
  }
  
  // Convert `attachment` path into full path
  if ([attachment characterAtIndex:0] != '/') {
    artPath = [_helpDirectory stringByAppendingPathComponent:attachment];
  }
  else {
    artPath = attachment;
  }

  // Check if document exists
  if ([[NSFileManager defaultManager] fileExistsAtPath:artPath] == NO) {
    artPath = nil;
  }
  
  return artPath;
}

- (void)_scrollArticle
{
  NSRange        range = selectedRange;
  NSCharacterSet *letters = [NSCharacterSet alphanumericCharacterSet];
  NSString       *text = [[articleView textStorage] string];
  int            i;
  
  while ([letters characterIsMember:[text characterAtIndex:range.location]] == NO) {
    range.location++;
    range.length--;
  }
  [articleView setSelectedRange:range];

  // Scroll to the +2 lines after selected
  range = [text lineRangeForRange:NSMakeRange(range.location+range.length+1,1)];
  range = [text lineRangeForRange:NSMakeRange(range.location+range.length+1,1)];
  [articleView scrollRangeToVisible:range];
}

// `path` must be a relative path e.g. `Tasks/Basics/Intro.rtfd`
- (BOOL)_showArticleWithPath:(NSString *)path
{
  BOOL      isSuccess = NO;
  NSCell    *cell = nil;
  NSString  *absPath;
  NSInteger index;

  // If `path` is `nil` get article path from selected TOC item
  if (path == nil) {
    cell = [tocList selectedItem];
    if ([tocList indexOfItem:cell] != selectedItemIndex) {
      [tocList selectItemAtIndex:selectedItemIndex];
      cell = [tocList selectedItem];
    }
    path = [cell representedObject];
  }
  else {
    if ((index = [tocList indexOfItemWithStringRep:path]) != NSNotFound) {
      cell = [tocList itemAtIndex:index];
    }
    else {
      cell = [tocList selectedItem];
    }
  }
  
  absPath = [self _filePathForAttachment:path];
  // NSLog(@"[HelpPanel] showArticle doc path: %@ absPath: %@ cell:%@",
  //       path, absPath, cell);
  
  if (absPath != nil && cell != nil) {
    [self _updateHistoryWithIndex:[tocList indexOfItem:cell]
                     documentPath:path];
    [articleView readRTFDFromFile:absPath];
    [articleView scrollRangeToVisible:NSMakeRange(0,0)];
    if ([scrollView superview] == nil) {
      [splitView replaceSubview:indexList with:scrollView];
      [splitView adjustSubviews];
      [splitView setPosition:145.0 ofDividerAtIndex:0];
    }
    isSuccess = YES;
  }
  else {
    NXTRunAlertPanel(@"Help", @"Help file `%@` doesn't exist",
                     @"OK", nil, nil, path);
    selectedItemIndex = history[historyPosition].index;
    [tocList selectItemAtIndex:selectedItemIndex];
  }
  [self makeFirstResponder:findField];

  return isSuccess;
}

- (void)_showMarkerWithName:(NSString *)markerName
{
  NSString           *filePath;
  NSAttributedString *attrString;
  NSString           *artText;
  NSUInteger         artLength;
  NSRange            lineRange, range;
  NSDictionary       *attrs;
  id                 attachment;

  // NSLog(@"Will show marker: %@", markerName);

  if (markerName == nil) {
    return;
  }
  
  filePath = [self _filePathForAttachment:[self helpFile]];
  attrString = [[NSAttributedString alloc] initWithPath:filePath
                                     documentAttributes:NULL];
  artText = [attrString string];
  artLength = [artText length];
  
  for (int i = 0; i < artLength; i++) {
    lineRange = [artText lineRangeForRange:NSMakeRange(i,1)];
    attrs = [attrString attributesAtIndex:i effectiveRange:&range];
    attachment = [attrs objectForKey:@"NSAttachment"];
    if (attachment &&
        [attachment respondsToSelector:@selector(markerName)] &&
        [[attachment markerName] isEqualToString:markerName]) {
      // Select text after marker
      selectedRange = [artText lineRangeForRange:NSMakeRange(i,1)];
      [self _scrollArticle];
      break;
    }
    i = range.location + (range.length - 1);
  }
  [attrString release];
}

- (NSRange)_findInArticleAtPath:(NSString *)path
{
  NSText       *reader = [NSText new];
  NSString     *text = nil;
  NSRange      range = NSMakeRange(0,0);
  NSRange      selectedRange = NSMakeRange(0,0);
  unsigned int options = NSCaseInsensitiveSearch;
  BOOL         lastFindWasSuccessful = NO;

  if ([reader readRTFDFromFile:path] != NO) {
    text = [reader string];
  }
  if (text && [text length]) {
    range = [text findString:[findField stringValue]
               selectedRange:selectedRange
                     options:options
                        wrap:NO];
  }
  [reader release];

  return range;
}

- (void)_enableButtons:(BOOL)isEnabled
{
  NSString *artPath = nil;

  if (isEnabled != NO) {
    // Find
    [findBtn setEnabled:YES];
    // Index
    artPath = [_helpDirectory stringByAppendingPathComponent:@"Index.rtfd"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:artPath] != NO) {
      [indexBtn setEnabled:YES];
    }
    else {
      [indexBtn setEnabled:NO];
    }
    // Backtrack
    [backtrackBtn setEnabled:(historyPosition > 0) ? YES : NO];
  }
  else {
    [findBtn setEnabled:NO];
    [indexBtn setEnabled:NO];
    [backtrackBtn setEnabled:NO];
  }  
}

- (void)_enableFindField
{
  [findField setTextColor:[NSColor blackColor]];
  [findField setSelectable:YES];
  [findField setEditable:YES];
  [findField drawCell:[findField cell]];
  [self makeFirstResponder:findField];
  [self _enableButtons:YES];
  [statusField setStringValue:@""];
}

- (void)_tocItemClicked:(id)sender
{
  NSCell   *item = [tocList selectedItem];
  NSString *artPath = [item representedObject];

  if (selectedItemIndex == [tocList indexOfItem:item]) {
    return;
  }
  selectedItemIndex = [tocList indexOfItem:item];
  
  if (artPath && [artPath isKindOfClass:[NSString class]] &&
      [artPath isEqualToString:@"Index.rtfd"]) {
    [self _showIndex:indexBtn];
  }
  else {
    [self _showArticleWithPath:nil];
  }
}

- (void)_performFind:(id)sender
{
  dispatch_queue_t find_q;
  
  if ([[findField stringValue] length] == 0) {
    return;
  }

  [findField setTextColor:[NSColor grayColor]];
  [findField setEditable:NO];
  [findField setSelectable:NO];
  [findField drawCell:[findField cell]];
  [self makeFirstResponder:articleView];
  [self _enableButtons:NO];
  [statusField setStringValue:@"Searching..."];
  
  find_q = dispatch_queue_create("ns.desktopkit.helppanel", NULL);
  dispatch_async(find_q, ^{
      NSString     *text = [[articleView textStorage] string];
      NSRange      range;
      unsigned int options = NSCaseInsensitiveSearch;
      BOOL         lastFindWasSuccessful = NO;
      
      // Search opened article
      selectedRange = [articleView selectedRange];
      if (text && [text length]) {
        if (selectedRange.length != 0) {
          selectedRange.location = selectedRange.location + selectedRange.length;
          selectedRange.length = 0;
        }
        else {
          selectedRange.location = 0;
        }
        range = [text findString:[findField stringValue]
                   selectedRange:selectedRange
                         options:options
                            wrap:NO];
        if (range.length) {
          selectedRange.location = range.location;
          selectedRange.length = range.length;
          [self performSelectorOnMainThread:@selector(_scrollArticle)
                                 withObject:nil
                              waitUntilDone:YES];
          lastFindWasSuccessful = YES;
        }
      }
  
      // Search through the articles, skips Index.rtfd
      if (!lastFindWasSuccessful) {
        NSUInteger index = [tocList indexOfItem:[tocList selectedItem]] + 1;
        NSString   *artPath, *attachment;
        for (NSUInteger i = index; i < [tocAttachments count]; i++) {
          attachment = [tocAttachments objectAtIndex:i];
          if (attachment &&
              [attachment isEqualToString:@""] == NO &&
              [attachment isEqualToString:@"Index.rtfd"] == NO) {
            artPath = [self _filePathForAttachment:attachment];
            range = [self _findInArticleAtPath:artPath];
            if (range.length > 0) {
              selectedItemIndex = i;
              [self performSelectorOnMainThread:@selector(_showArticleWithPath:)
                                     withObject:nil
                                  waitUntilDone:YES];
              selectedRange.location = range.location;
              selectedRange.length = range.length;
              [self performSelectorOnMainThread:@selector(_scrollArticle)
                                     withObject:nil
                                  waitUntilDone:YES];
              break;
            }
          }
        }
      }
    
      [self performSelectorOnMainThread:@selector(_enableFindField)
                             withObject:nil
                          waitUntilDone:YES];
    });
}

// --- Index

- (void)_loadIndex:(NSString *)indexFilePath
{
  NSAttributedString  *attrString;
  NSString            *text;
  NSRange             range, lineRange;
  NSUInteger          diff;
  NSDictionary        *attrs;
  NSAttributedString  *title;
  NSMutableDictionary *object = [NSMutableDictionary new];
  id                  attachment;

  // NSLog(@"Loading Index: start");
  attrString = [[NSAttributedString alloc] initWithPath:indexFilePath
                                     documentAttributes:NULL];
  text = [attrString string];
  // NSLog(@"Index loading done. Length == %lu", [text length]);

  NSLog(@"Index.rtfd: loading items into list view: START");
  for (int i = 0; i < [text length]; i++) {
    lineRange = [text lineRangeForRange:NSMakeRange(i,1)];
    attrs = [attrString attributesAtIndex:i effectiveRange:&range];
    if ((attachment = [attrs objectForKey:@"NSAttachment"]) != nil) {
      if ([attachment isKindOfClass:[GSHelpLinkAttachment class]] != NO) {
        // Skip attachment symbol
        lineRange.length -= range.length;
        lineRange.location = range.location + range.length;
      }
      title = [attrString attributedSubstringFromRange:lineRange];
      if ([attachment respondsToSelector:@selector(fileName)]) {
        [object setObject:[attachment fileName] forKey:@"Link"];
        if ([attachment respondsToSelector:@selector(markerName)] &&
            [attachment markerName]) {
          [object setObject:[attachment markerName] forKey:@"Marker"];
        }
      }
    }
    else {
      title = [attrString attributedSubstringFromRange:lineRange];
    }
    
    i = lineRange.location + (lineRange.length - 1);
    
    if ([[object allKeys] count] > 0) {
      [indexList addItemWithTitle:title
                representedObject:[NSDictionary dictionaryWithDictionary:object]];
      [object removeAllObjects];
    }
    else {
      [indexList addItemWithTitle:title representedObject:nil];
    }
  }
  NSLog(@"Index.rtfd: loading items into list view: END");
  [attrString release];
}

- (void)_indexItemClicked:(id)sender
{
  NSDictionary *attrs;
  NSString     *artPath;
  NSInteger    tocIndex;

  if (sender == nil) {
    return;
  }
  attrs = [[sender selectedCell] representedObject];
  artPath = [attrs objectForKey:@"Link"];
  
  // NSLog(@"[%@] Index item %@ clicked with link: %@ (%@)",
  //       [sender className], [sender selectedCell], artPath, attrs);

  tocIndex = [tocList indexOfItemWithStringRep:artPath];
  if (tocIndex == NSNotFound) {
    tocIndex = objectsPrologIndex;
  }
  [tocList selectItemAtIndex:tocIndex];
  selectedItemIndex = tocIndex;
  [self _showArticleWithPath:artPath];
  [self _showMarkerWithName:[attrs objectForKey:@"Marker"]];
}

- (void)_showIndex:(id)sender
{
  NSInteger idx;
  BOOL      justCreated = NO;
   
  [statusField setStringValue:@"Loading Index..."];
  [statusField display];
  
  // Find item with `Index.rtfd` represented object
  idx = [tocList indexOfItemWithStringRep:@"Index.rtfd"];
  if (idx != NSNotFound) {
    if (indexList == nil) {
      indexList = [[NXTListView alloc] initWithFrame:NSMakeRect(0,0,414,200)];
      [indexList setBackgroundColor:[NSColor whiteColor]];
      [indexList setSelectionBackgroundColor:[NSColor controlBackgroundColor]];
      [indexList setTarget:self];
      [indexList setAction:@selector(_indexItemClicked:)];
      [indexList setNextKeyView:findField];
      justCreated = YES;
    }
    [splitView replaceSubview:scrollView with:indexList];
    [splitView adjustSubviews];
    [splitView setPosition:145.0 ofDividerAtIndex:0];
    // [splitView display];
    [tocList selectItemAtIndex:idx];
    [tocList display];
    selectedItemIndex = idx;
    [self _updateHistoryWithIndex:idx documentPath:@"Index.rtfd"];
    
    if (justCreated) {
      [self _loadIndex:[_helpDirectory
                             stringByAppendingPathComponent:@"Index.rtfd"]];
      [indexList display];
    }
  }
  else {
    // Item was not found
    NXTRunAlertPanel(@"Help", @"No Index file found for this help.",
                     @"OK", nil, nil);
  }
  
  [statusField setStringValue:@""];
  [statusField display];
}

// --- Backtrack

- (void)_goHistoryBack:(id)sender
{
  NSString *filePath;
  
  // NSLog(@"Backtrack at %d with %lu",
  //       historyPosition, history[historyPosition].index);
  if (historyPosition > 0) {
    /* We need to release NSString because it was copied earlier
       in _updateHistoryWithIndex method */
    [history[historyPosition].documentPath release];
    
    historyPosition--;
    if (selectedItemIndex != history[historyPosition].index) {
      [tocList selectItemAtIndex:history[historyPosition].index];
    }
    
    filePath = history[historyPosition].documentPath;
    if ([filePath isEqualToString:@"Index.rtfd"] != NO) {
      [self _showIndex:self];
    }
    else {
      [self _showArticleWithPath:filePath];
    }
    
    // _show... methods increment history position so we return it back once more
    historyPosition--;
    [articleView scrollRectToVisible:history[historyPosition].rect];
    [backtrackBtn setEnabled:(historyPosition != 0)];
  }
}

@end

@implementation NXTHelpPanel : NSPanel

+ (NXTHelpPanel *)sharedHelpPanel
{
  if (_sharedHelpPanel == nil) {
    [self sharedHelpPanelWithDirectory:nil];
  }
    
  return _sharedHelpPanel;
}

+ (NXTHelpPanel *)sharedHelpPanelWithDirectory:(NSString *)helpDirectory
{
  NSString     *tocFilePath;
  NXTHelpPanel *panel;
  
  // Setup help directory if needed
  if (helpDirectory == nil) {
    helpDirectory = [[NSBundle mainBundle] pathForResource:@"Help"
                                                    ofType:@""
                                               inDirectory:@""];
  }
  
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
  if (_sharedHelpPanel == nil) {
    _sharedHelpPanel = [[NXTPanelLoader alloc] loadPanelNamed:@"NXTHelpPanel"];
    [_sharedHelpPanel _setHelpDirectory:helpDirectory];
    [_sharedHelpPanel _enableButtons:YES];
    panel = _sharedHelpPanel;
  }
  else if ([helpDirectory isEqualToString:[_sharedHelpPanel helpDirectory]] == NO) {
    panel = [[NXTPanelLoader alloc] loadPanelNamed:@"NXTHelpPanel"];
    [panel _setHelpDirectory:helpDirectory];
  }
  else {
    panel = _sharedHelpPanel;
  }

  return panel;
}

- (id)init
{
  self = [NXTHelpPanel sharedHelpPanel];
  return self;
}

- (void)awakeFromNib
{
  [statusField setStringValue:@""];
  [[findBtn cell] setImageDimsWhenDisabled:YES];
  [[indexBtn cell] setImageDimsWhenDisabled:YES];
  [[backtrackBtn cell] setImageDimsWhenDisabled:YES];
  [splitView setResizableState:NSOnState];

  // TOC list
  tocList = [[NXTListView alloc] initWithFrame:NSMakeRect(0,0,414,200)];
  [splitView addSubview:tocList];
  [tocList setTarget:self];
  [tocList setAction:@selector(_tocItemClicked:)];
  [tocList setNextKeyView:findField];
  [tocList release];

  // Article
  scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0,0,414,200)];
  [scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  [scrollView setHasVerticalScroller:YES];
  [scrollView setBorderType:NSBezelBorder];
  articleView = [[NXTHelpArticle alloc] initWithFrame:NSMakeRect(0,0,394,200)];
  [articleView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  [articleView setEditable:NO];
  [articleView setDelegate:self];
  [scrollView setDocumentView:articleView];
  [splitView addSubview:scrollView];
  // Don't release scrollView - it can be replaced with Index view
  // [scrollView release];

  // History (for Backtrack)
  historyLength = 20;
  historyPosition = -1;
  history = malloc(sizeof(NXTHelpHistory) * 20);
  
  [splitView setPosition:145.0 ofDividerAtIndex:0];

  [self setTitle:[NSString stringWithFormat:@"%@ Help Panel",
                           [[NSProcessInfo processInfo] processName]]];
}

// --- Overrides

- (void)orderWindow:(NSWindowOrderingMode)place relativeTo:(NSInteger)otherWin
{
  NSString *toc;

  if (place != NSWindowOut && !tocTitles) {
    toc = [_helpDirectory stringByAppendingPathComponent:@"TableOfContents.rtf"];
    [self _loadTableOfContents:toc];
    [tocList loadTitles:tocTitles andObjects:tocAttachments];
    [tocList selectItemAtIndex:0];
    selectedItemIndex = 0;
    [self _showArticleWithPath:nil];
  }
  
  [super orderWindow:place relativeTo:otherWin];
}

- (void)sendEvent:(NSEvent *)theEvent
{
  NSEventType type = [theEvent type];
  unichar c;

  if (type == NSKeyDown || type == NSKeyUp) {
    c = [[theEvent characters] characterAtIndex:0];
  }
  
  if (type == NSKeyDown &&
      (c == NSUpArrowFunctionKey || c == NSDownArrowFunctionKey)) {
    [tocList keyDown:theEvent];
  }
  else if (type == NSKeyUp &&
           (c == NSUpArrowFunctionKey || c == NSDownArrowFunctionKey)) {
    [tocList keyUp:theEvent];
  }
  else {
    [super sendEvent:theEvent];
  }
}

// --- NSTextView delegate

- (void)textView:(NSTextView *)textView
   clickedOnCell:(id <NSTextAttachmentCell>)cell
          inRect:(NSRect)cellFrame
{
  GSHelpLinkAttachment *attachment;
  NSString             *currDir;
  NSArray              *pathComps;
  NSString             *repObject;

  attachment = (GSHelpLinkAttachment *)[cell attachment];
  
  if ([attachment isKindOfClass:[GSHelpLinkAttachment class]]) {
    currDir = [[[tocList selectedItem] representedObject]
                stringByDeletingLastPathComponent];
    pathComps = [[attachment fileName] pathComponents];
    
    // Convert to path relative to _helpDirectory
    if ([pathComps[0] isEqualToString:@".."]) {
      // points to _helpDirectory (e.g `../Basics/Intro.rtfd`)
      for (NSString *comp in pathComps) {
        if ([comp isEqualToString:@".."]) {
          currDir = [currDir stringByDeletingLastPathComponent];
          continue;
        }
        currDir = [currDir stringByAppendingPathComponent:comp];
      }
      repObject = currDir;
    }
    else {
      repObject = [currDir
                    stringByAppendingPathComponent:[attachment fileName]];
    }

    // Find and select TOC item with `repObject`
    NSString *object;
    BOOL      isFound = NO;
    for (int i = 0; i < [tocAttachments count]; i++) {
      object = [tocAttachments objectAtIndex:i];
      if ([object isEqualToString:repObject]) {
        [tocList selectItemAtIndex:i];
        selectedItemIndex = i;
        isFound = YES;
        break;
      }
    }
    if (isFound == NO) { // it's a hidden file
      [tocList selectItemAtIndex:objectsPrologIndex];
      selectedItemIndex = objectsPrologIndex;
    }

    // Show article
    [self _showArticleWithPath:repObject];
  }
}

// --- Managing the Contents

+ (void)setHelpDirectory:(NSString *)helpDirectory
{
  if (_sharedHelpPanel != nil) {
    [_sharedHelpPanel _setHelpDirectory:helpDirectory];
  }
}

// TODO
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
  return [[tocList selectedItem] representedObject];
}


// --- Attaching Help to Objects

// TODO
+ (void)attachHelpFile:(NSString *)filename
            markerName:(NSString *)markerName
                    to:(id)anObject
{
  NSWarnFLog(@"Not implemented");
}

// TODO
+ (void)detachHelpFrom:(id)anObject
{
  NSWarnFLog(@"Not implemented");
}

// --- Showing Help

- (void)showFile:(NSString *)filename
        atMarker:(NSString *)markerName
{
  if ([self _showArticleWithPath:filename] != NO && markerName != nil) {
    [self _showMarkerWithName:markerName];
  }
}

// TODO
- (BOOL)showHelpAttachedTo:(id)anObject
{
  NSWarnFLog(@"Not implemented");
  return NO;
}

// --- Printing 
// TODO
- (void)print:(id)sender
{
  NSLog(@"Not implemented");
}

@end
