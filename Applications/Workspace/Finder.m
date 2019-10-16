/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Copyright (C) 2014-2019 Sergii Stoian
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

#import <AppKit/AppKit.h>
#import <DesktopKit/NXTDefaults.h>
#import <DesktopKit/NXTAlert.h>
#import <DesktopKit/NXTIconView.h>
#import <DesktopKit/NXTFileManager.h>

#import <Viewers/FileViewer.h>
#import <Viewers/PathIcon.h>
#import <Preferences/Shelf/ShelfPrefs.h>

#import "Finder.h"

//=============================================================================
// Custom text field
//=============================================================================
@interface WMFindField : NSTextField
- (void)findFieldKeyUp:(NSEvent *)theEvent;
- (void)deselectText;
@end
@implementation WMFindField
- (void)keyUp:(NSEvent *)theEvent
{
  if (_delegate && [_delegate respondsToSelector:@selector(findFieldKeyUp:)]) {
    [_delegate findFieldKeyUp:theEvent];
  }
}
- (void)findFieldKeyUp:(NSEvent *)theEvent
{
  // Should be implemented by delegate
}
- (void)deselectText
{
  NSString *fieldString = [self stringValue];
  NSText   *fieldEditor = [_window fieldEditor:NO forObject:self];
  
  [fieldEditor setSelectedRange:NSMakeRange([fieldString length], 0)];
}
@end

//=============================================================================
// Custom NSBrowser elements
//=============================================================================
@interface FinderCell : NSBrowserCell
@end
@implementation FinderCell
- (BOOL)acceptsFirstResponder
{
  return NO;
}
@end
@interface FinderMatrix : NSMatrix
@end
@implementation FinderMatrix
- (BOOL)acceptsFirstResponder
{
  return NO;
}
@end

//=============================================================================
// NSOperation to perform search asynchronously
//=============================================================================
@interface FindWorker : NSOperation
{
  Finder *finder;
  NSArray *searchPaths;
  NSRegularExpression *expression;
  BOOL isContentSearch;
}
- (id)initWithFinder:(Finder *)onwer
               paths:(NSArray *)paths
          expression:(NSRegularExpression *)regexp
      searchContents:(BOOL)isContent;
@end
@implementation FindWorker

- (void)dealloc
{
  NSLog(@"[FindWorker] -dealloc");
  [searchPaths release];
  [expression release];
  [super dealloc];
}

- (id)initWithFinder:(Finder *)owner
               paths:(NSArray *)paths
          expression:(NSRegularExpression *)regexp
      searchContents:(BOOL)isContent
{
  [super init];
  
  if (self != nil) {
    finder = owner;
    searchPaths = [[NSArray alloc] initWithArray:paths];
    expression = regexp;
    [expression retain];
    isContentSearch = isContent;
  }

  return self;
}

- (BOOL)isTextMatched:(NSString *)text
{
  NSUInteger matches;
  
  matches = [expression numberOfMatchesInString:text
                                        options:0
                                          range:NSMakeRange(0, [text length])];
  if (matches > 0) {
    return YES;
  }

  return NO;
}

- (BOOL)isFileMatched:(NSString *)filePath
{
  BOOL         isMatched = NO;
  NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:filePath];
  NSData       *dataChunk;
  NSString     *text;
  // NSUInteger   patternLength = [[expression pattern] length];
  NSUInteger   offset;

  // NSLog(@"Search for contents in file:%@", filePath);

  dataChunk = [handle readDataOfLength:1024*1024];
  while ([dataChunk length] > 0) {
    text = [[NSString alloc] initWithData:dataChunk
                                 encoding:NSUTF8StringEncoding];
    [text autorelease];
    if ([self isTextMatched:text]) {
      isMatched = YES;
      break;
    }
    // Step down on the pattern length to omit cases when search string
    // is located across the chunks of data read.
    // offset = [handle offsetInFile];
    // if (offset )
    // [handle seekToFileOffset:offset-patternLength];
    
    dataChunk = [handle readDataOfLength:1024*1024];
  }

  [handle closeFile];
  return isMatched;
}

- (void)findInDirectory:(NSString *)dirPath
{
  NXTFileManager *fm = [NXTFileManager defaultManager];
  BOOL           isDir;
  NSArray        *dirContents;
  NSString       *itemPath;
  NSDictionary   *attrs;
  NSString       *itemFormat;

  // NSLog(@"Processing directory %@...", dirPath);

  dirContents = [fm directoryContentsAtPath:dirPath
                                    forPath:nil
                                 showHidden:[fm isShowHiddenFiles]];
  itemFormat = ([dirPath isEqualToString:@"/"] == NO) ? @"%@/%@" : @"%@%@";
  
  for (NSString *item in dirContents) {
    if ([self isCancelled]) {
      break;
    }
    itemPath = [NSString stringWithFormat:itemFormat, dirPath, item];
    [fm fileExistsAtPath:itemPath isDirectory:&isDir];
    attrs = [fm fileAttributesAtPath:itemPath traverseLink:NO];

    if ([[attrs fileType] isEqualToString:NSFileTypeSymbolicLink] == NO) {
      if ([[attrs fileType] isEqualToString:NSFileTypeDirectory] != NO) {
        [self findInDirectory:itemPath];
      }
      else if (isContentSearch != NO) {
        if ([self isFileMatched:itemPath]) {
          [finder performSelectorOnMainThread:@selector(addResult:)
                                   withObject:itemPath
                                waitUntilDone:NO];
        }
      }
      if (isContentSearch == NO && [self isTextMatched:item]) {
        [finder performSelectorOnMainThread:@selector(addResult:)
                                 withObject:itemPath
                              waitUntilDone:NO];
      }
    }
  }
}

- (void)main
{
  NSLog(@"[Finder] will search contents: %@", isContentSearch ? @"Yes" : @"No");
  
  for (NSString *path in searchPaths) {
    [self findInDirectory:path];
  }  
}

- (BOOL)isReady
{
  return YES;
}

@end

@implementation Finder (Worker)

- (void)runWorkerWithPaths:(NSArray *)searchPaths
                expression:(NSRegularExpression *)regexp
{
  NSOperation *worker;
  
  if (operationQ == nil) {
    operationQ = [[NSOperationQueue alloc] init];
  }

  worker = [[FindWorker alloc] initWithFinder:self
                                        paths:searchPaths
                                   expression:regexp
                               searchContents:[[findScopeButton selectedItem] tag]];
  [worker addObserver:self
           forKeyPath:@"isFinished"
              options:0
              context:self];
  [operationQ addOperation:worker];
  [worker release];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
  NSLog(@"Finder operation was finished.");
  [self performSelectorOnMainThread:@selector(finishFind)
                         withObject:nil
                      waitUntilDone:YES];
}

@end

//=============================================================================
// Finder class
//=============================================================================
@implementation Finder

- (void)dealloc
{
  NSLog(@"Finder: dealloc");

  [variantList release];
  [resultIcon release];
  [findButtonImage release];
  [window release];
  
  [super dealloc];
}

- (id)initWithFileViewer:(FileViewer *)fv
{
  NXTDefaults *df = [NXTDefaults userDefaults];
  NSSize     slotSize;
    
  if ((self = [super init]) == nil) {
    return nil;
  }

  if ([df objectForKey:ShelfIconSlotWidth]) {
    slotSize = NSMakeSize([df floatForKey:ShelfIconSlotWidth], 76);
  }
  else {
    slotSize = NSMakeSize(76, 76);
  }
  [NXTIconView setDefaultSlotSize:slotSize];
  [NSBundle loadNibNamed:@"Finder" owner:self];

  fileViewer = fv;
  resultIndex = -1;
  variantList = [[NSMutableArray alloc] init]; 

  return self;
}

- (void)setFileViewer:(FileViewer *)fv
{
  fileViewer = fv;
}

- (void)awakeFromNib
{
  [window setFrameAutosaveName:@"Finder"];
  // Shelf
  [shelf setAllowsMultipleSelection:YES];
  [shelf setAllowsEmptySelection:NO];
  [shelf setDelegate:self];
  [self restoreShelf];

  // Status fields
  [resultsFound setStringValue:@""];
  [statusField setStringValue:@""];

  // Find button
  [findButton setButtonType:NSMomentaryPushInButton];
  findButtonImage = [findButton image];
  [findButtonImage retain];

  // Text field
  [findField setStringValue:@""];
  [findField setNextKeyView:findField];

  // Browser list
  [resultList setCellClass:[FinderCell class]];
  [resultList setMatrixClass:[FinderMatrix class]];
  [resultList loadColumnZero];
  [resultList setTakesTitleFromPreviousColumn:NO];
  [resultList scrollColumnToVisible:0];
  [resultList setAllowsMultipleSelection:NO];
  [resultList setTarget:self];
  [resultList setAction:@selector(listItemClicked:)];

  // Icon at the right of text field
  [iconPlace setBorderType:NSNoBorder];
  resultIcon = [[PathIcon alloc] init];
  [resultIcon setIconSize:NSMakeSize(66, 55)];
  [resultIcon setEditable:NO];
  [resultIcon setSelected:YES];
  [resultIcon setPaths:@[@"me"]];
  [resultIcon setSelectable:YES];
  [resultIcon setDoubleClickPassesClick:NO];
  [resultIcon setTarget:self];
  [resultIcon setDoubleAction:@selector(resultIconDoubleClicked:)];
  [resultIcon setMaximumCollapsedLabelWidth:80];
  [resultIcon setShowsExpandedLabelWhenSelected:YES];
}

- (void)activateWithString:(NSString *)searchString
{
  [resultList reloadColumn:0];

  if ([searchString length] > 0) {
    [findField setStringValue:searchString];
  }
  else {
    [findField setStringValue:@""];
  }
  
  [window makeFirstResponder:findField];
  
  if (![searchString isEqualToString:@""]) {
    [[window fieldEditor:NO forObject:findField]
      setSelectedRange:NSMakeRange([searchString length], 0)];
  }
  if ([window isVisible] == NO) {
    [window center];
    [window makeKeyAndOrderFront:nil];
  }
}

- (void)deactivate
{
  [window close];
}

- (void)windowWillClose:(NSNotification *)notif
{
  NXTDefaults *df = [NXTDefaults userDefaults];

  [df setObject:[shelf storableRepresentation] forKey:@"FinderShelfContents"];
  [df setObject:[self storableShelfSelection] forKey:@"FinderShelfSelection"];
  [df synchronize];
  
  [variantList removeAllObjects];
}

- (NSWindow *)window
{
  return window;
}

- (void)reset
{
  [variantList removeAllObjects];
  [resultList reloadColumn:0];
  resultIndex = -1;
  [resultsFound setStringValue:@""];
  [resultIcon removeFromSuperview];
}

// --- Find button actions

- (void)performFind:(id)sender
{
  NSError             *error = NULL;
  NSRegularExpression *regex;
  NSMutableArray      *searchPaths;
  NSString            *enteredText;

  if ([operationQ operationCount] > 0) {
    NSLog(@"[Finder] stopping search operation.");
    [operationQ cancelAllOperations];
  }
  else {
    enteredText = [findField stringValue];
    if ([enteredText isEqualToString:@""] ||
        [enteredText characterAtIndex:0] == ' ') {
      [self finishFind];
      return;
    }

    [self reset];
    
    [findButton setImagePosition:NSImageOnly];
    [findButton setImage:[findButton alternateImage]];
    [statusField setStringValue:@"Searching..."];

    searchPaths = [NSMutableArray array];

    for (PathIcon *icon in [shelf selectedIcons]) {
      [searchPaths addObjectsFromArray:[icon paths]];
    }
  
    regex = [NSRegularExpression
              regularExpressionWithPattern:enteredText
                                   options:NSRegularExpressionCaseInsensitive
                                     error:&error];

    [self runWorkerWithPaths:searchPaths expression:regex];
  }
}

- (void)addResult:(NSString *)resultString
{
  [variantList addObject:resultString];
  [resultsFound setStringValue:[NSString stringWithFormat:@"%lu found",
                                         [variantList count]]];
  if ([variantList count] == 1) {
    [resultList reloadColumn:0];
  }
  else {
    NSBrowserCell *cell;
    NSMatrix      *matrix = [resultList matrixInColumn:0];
    
    [matrix addRow];
    cell = [matrix cellAtRow:[matrix numberOfRows] - 1 column:0];
    [cell setLeaf:YES];
    [cell setRefusesFirstResponder:YES];
    [cell setTitle:resultString];
    [cell setLoaded:YES];
    [resultList displayColumn:0];
  }
}

- (void)finishFind
{
  [findButton setImagePosition:NSImageAbove];
  [findButton setImage:findButtonImage];
  [findButton setState:NSOnState];
  [statusField setStringValue:@""];  
}

// --- TextField Actions

- (NSArray *)completionFor:(NSString *)path
{
  NSMutableArray *variants = [[NSMutableArray alloc] init];
  NSFileManager  *fm = [NSFileManager defaultManager];
  NSArray        *dirContents;
  const char     *c_t;
  BOOL           isAbsolute = NO;
  NSString       *absPath;
  BOOL           isDir;

  if (!path || [path length] == 0 || [path isEqualToString:@""]) {
    return variants;
  }

  c_t = [path cString];
  if (c_t[0] == '/') {
    isAbsolute = YES;
  }
  else if (c_t[0] == '~') {
    path = [path stringByReplacingCharactersInRange:NSMakeRange(0,1)
                                         withString:NSHomeDirectory()];
    isAbsolute = YES;
  }
  else if (([path length] > 1) && (c_t[0] == '.' && c_t[1] == '/')) {
    path = [path stringByReplacingCharactersInRange:NSMakeRange(0,2)
                                         withString:NSHomeDirectory()];
    isAbsolute = YES;
  }

  if (isAbsolute) {
    NSString *pathBase = [NSString stringWithString:path];
    
    // Do filesystem scan
    while ([fm fileExistsAtPath:pathBase isDirectory:&isDir] == NO) {
      pathBase = [pathBase stringByDeletingLastPathComponent];
    }
    dirContents = [fileViewer directoryContentsAtPath:pathBase forPath:nil];
    for (NSString *file in dirContents) {
      absPath = [pathBase stringByAppendingPathComponent:file];
      if ([absPath rangeOfString:path].location == 0) {
        [variants addObject:[absPath lastPathComponent]];
      }
    }
  }

  return variants;
}

- (void)makeCompletion
{
  NSString *enteredText = [findField stringValue];
  NSString *variant;

  [variantList removeAllObjects];
  
  if ([enteredText length] == 0) {
    NSSet *selectedIcons = [shelf selectedIcons];
    
    if ([selectedIcons count] > 1) {
      for (PathIcon *icon in selectedIcons) {
        [variantList addObjectsFromArray:[icon paths]];
      }
    }
    else {
      enteredText = [[[selectedIcons anyObject] paths] objectAtIndex:0];
      [variantList addObjectsFromArray:[self completionFor:enteredText]];
    }
  }
  else {
    [variantList addObjectsFromArray:[self completionFor:enteredText]];
  }

  [resultsFound setStringValue:[NSString stringWithFormat:@"%lu found",
                                         [variantList count]]];
  
  if ([variantList count] > 0) {
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL          isDir;
    NSString      *path = [findField stringValue];
    NSString      *newPath;
    NSRange       subRange;
    
    [resultList reloadColumn:0];

    // Append '/' to dir name or shrink enetered path to existing dir
    if ([path length] > 0 && [path characterAtIndex:[path length]-1] != '/') {
      if ([fm fileExistsAtPath:path isDirectory:&isDir]) {
        if (isDir != NO) {
          path = [path stringByAppendingString:@"/"];
        }
      }
    }
    
    // Set field value to first variant
    if ([variantList count] == 1) {
      variant = [variantList objectAtIndex:0];
      newPath = [[path stringByDeletingLastPathComponent]
                  stringByAppendingPathComponent:variant];
      
      if ([fm fileExistsAtPath:newPath isDirectory:&isDir] && isDir != NO) {
        newPath = [newPath stringByAppendingString:@"/"];
      }
      
      [findField setStringValue:newPath];
      
      subRange = [newPath rangeOfString:path];
      subRange.location = subRange.location + subRange.length;
      subRange.length = [newPath length] - subRange.location;
      [[window fieldEditor:NO forObject:findField] setSelectedRange:subRange];
    }
    else {
      [findField setStringValue:path];
      [findField deselectText];
    }
  }
  else {
    [resultList reloadColumn:0];
    resultIndex = -1;
  }
}

// --- Search text field delegate

- (void)controlTextDidChange:(NSNotification *)aNotification
{
  NSTextField *field = [aNotification object];
  NSString    *text;

  if (field != findField ||![field isKindOfClass:[NSTextField class]]) {
    return;
  }

  if ([operationQ operationCount] == 0) {
    [self reset];
    [self restoreShelfSelection];
  }
  
  text = [field stringValue];
  if ([text length] > 0 && [text characterAtIndex:[text length]-1] == '/') {
    [self makeCompletion];
  }
  else {
    [variantList removeAllObjects];
    [resultList reloadColumn:0];
  }
}

- (void)findFieldKeyUp:(NSEvent *)theEvent
{
  unichar c = [[theEvent characters] characterAtIndex:0];

  switch(c) {
  case NSTabCharacter:
    if (resultIndex >= 0 && resultIndex >= [variantList count]-1) {
      [resultList reloadColumn:0];
      resultIndex = -1;
      [resultIcon removeFromSuperview];
      [self restoreShelfSelection];
      [window makeFirstResponder:findField];
      [findField deselectText];
    }
    else if ([variantList count] > 0){
      resultIndex++;
      [resultList selectRow:resultIndex inColumn:0];
      [self listItemClicked:resultList];
    }
    break;
  case NSBackTabCharacter:
    if (resultIndex > 0) {
      resultIndex--;
      [resultList selectRow:resultIndex inColumn:0];
      [self listItemClicked:resultList];
    }
    else {
      [resultList reloadColumn:0];
      resultIndex = -1;
      [resultIcon removeFromSuperview];
      [self restoreShelfSelection];
      [window makeFirstResponder:findField];
      [findField deselectText];
    }
    break;
  case 27: // Escape
    if ([operationQ operationCount] > 0) {
      break;
    }
    [self makeCompletion];
    if ([resultIcon superview]) {
      resultIndex = -1;
      [resultIcon removeFromSuperview];
      [self restoreShelfSelection];
      [window makeFirstResponder:findField];
      [findField deselectText];
    }
    break;
  case NSCarriageReturnCharacter:
  case NSEnterCharacter:
    {
      NSString *enteredText = [findField stringValue];
      if ([enteredText characterAtIndex:0] == '/' ||
          [enteredText characterAtIndex:0] == '~' ) {
        [fileViewer displayPath:[enteredText stringByExpandingTildeInPath]
                      selection:nil
                         sender:self];
        [self deactivate]; 
      }
      else {
        [findButton performClick:self];
      }        
   }
  default:
    break;
  }
}

// --- Results browser delegate

- (void)     browser:(NSBrowser *)sender
 createRowsForColumn:(NSInteger)column
	    inMatrix:(NSMatrix *)matrix
{
  NSBrowserCell *cell;
  
  if (sender != resultList)
    return;

  for (NSString *variant in variantList) {
    [matrix addRow];
    cell = [matrix cellAtRow:[matrix numberOfRows] - 1 column:column];
    [cell setLeaf:YES];
    [cell setTitle:variant];
    [cell setRefusesFirstResponder:YES];
  }
}

- (void)listItemClicked:(id)sender
{
  NSInteger selRow;
  NSString  *item, *path, *fieldText;
  NSSet     *shelfIcons;
  NXTIcon   *sIcon;

  if (sender != resultList)
    return;

  // UGLY: Prevent deselection of selected item in NSBrowser's column
  if (resultIndex == [resultList selectedRowInColumn:0]) {
    [resultList selectRow:resultIndex inColumn:0];
  }

  resultIndex = [resultList selectedRowInColumn:0];
  item = [variantList objectAtIndex:resultIndex];

  shelfIcons = [shelf selectedIcons];
  fieldText = [findField stringValue];
  if ([fieldText length] > 1) {
    // if ([fieldText characterAtIndex:[fieldText length]-1] != '/') {
    //   path = [fieldText stringByDeletingLastPathComponent];
    // }
    // else {
      path = [NSString stringWithString:fieldText];
    // }
    NSLog(@"2.1 - %@", path);
  }
  else { // text field empty
    if ([shelfIcons count] == 1) {
      path = [[[shelfIcons anyObject] paths] objectAtIndex:0];
    }
    NSLog(@"3 - %@", path);
  }
  NSLog(@"[Finder] - result list clicked:%@ - %@", path, item);
  path = [path stringByAppendingPathComponent:item];
  NSLog(@"[Finder] + result list clicked:%@", path);
  
  [resultIcon setIconImage:[[NSApp delegate] iconForFile:path]];
  [resultIcon setPaths:@[path]];
  if (![resultIcon superview]) {
    [resultIcon putIntoView:iconPlace atPoint:NSMakePoint(33,48)];
    if ([shelfIcons count] > 0) {
      [self resignShelfSelection];
    }
  }
}

// --- Result icon action
- (void)resultIconDoubleClicked:(id)sender
{
  NSLog(@"Result icon double action: %@", [sender className]);
  [fileViewer open:sender];
}

@end

@implementation Finder (Shelf)

- (void)restoreShelf
{
  NSDictionary *aDict;
  NSArray      *shelfSelection;
  PathIcon     *icon;

  aDict = [[NXTDefaults userDefaults] objectForKey:@"FinderShelfContents"];
  if (!aDict || ![aDict isKindOfClass:[NSDictionary class]]) {
    // Home
    icon = [shelf createIconForPaths:@[NSHomeDirectory()]];
    if (icon) {
      [icon setDelegate:self];
      [icon setEditable:NO];
      [icon registerForDraggedTypes:@[NSFilenamesPboardType]];
      [[icon label] setNextKeyView:findField];
      [shelf putIcon:icon intoSlot:NXTMakeIconSlot(0,0)];
      [shelf selectIcons:[NSSet setWithObject:icon]];
    }
  }
  else {
    [shelf reconstructFromRepresentation:aDict];
    for (NXTIcon *icon in [shelf icons]) {
      [[icon label] setNextKeyView:findField];
    }
  }

  shelfSelection = [[NXTDefaults userDefaults] objectForKey:@"FinderShelfSelection"];
  [self reconstructShelfSelection:shelfSelection];
}

- (NSArray *)storableShelfSelection
{
  NSMutableArray *selectedSlots = [[NSMutableArray alloc] init];
  NXTIconSlot     slot;
  
  for (PathIcon *icon in [shelf selectedIcons]) {
    if ([icon isKindOfClass:[NSNull class]]) {
      continue;
    }
    slot = [shelf slotForIcon:icon];
    [selectedSlots addObject:@[[NSNumber numberWithInt:slot.x],
                               [NSNumber numberWithInt:slot.y]]];
  }

  return [selectedSlots autorelease];
}

- (void)reconstructShelfSelection:(NSArray *)selectedSlots
{
  NXTIconSlot   slot;
  NSMutableSet *selection = [[NSMutableSet alloc] init];

  for (NSArray *slotRep in selectedSlots) {
    slot = NXTMakeIconSlot([[slotRep objectAtIndex:0] intValue],
                          [[slotRep objectAtIndex:1] intValue]);
    [selection addObject:[shelf iconInSlot:slot]];
  }

  if (!selectedSlots || [selectedSlots count] == 0) {
    [selection addObject:[shelf iconInSlot:NXTMakeIconSlot(0,0)]];
  }
  [shelf selectIcons:selection];
  [selection release];
}

// This method manipulates icon selected state directly.
// NXTIconView -selectedIcons method returns selected set of icons.
- (void)resignShelfSelection
{
  NSSet *selectedIcons = [shelf selectedIcons];
  
  ASSIGN(savedSelection, [NSSet setWithSet:selectedIcons]);

  for (PathIcon *icon in selectedIcons) {
    [icon setSelected:NO];
    [[icon label] setTextColor:[NSColor whiteColor]];
    [[icon shortLabel] setTextColor:[NSColor whiteColor]];
  }
}

- (void)restoreShelfSelection
{
  if (!savedSelection || [savedSelection count] <= 0)
    return;

  for (PathIcon *icon in savedSelection) {
    [icon setSelected:YES];
    [[icon label] setTextColor:[NSColor blackColor]];
    [[icon shortLabel] setTextColor:[NSColor blackColor]];
  }
}

@end
