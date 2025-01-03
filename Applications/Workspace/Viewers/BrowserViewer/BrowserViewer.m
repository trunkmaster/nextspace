/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Description: Browser viewer.
//
// Copyright (C) 2005 Saso Kiselkov
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

#include <dispatch/dispatch.h>

#import <AppKit/AppKit.h>
#import <SystemKit/OSEDefaults.h>
#import <SystemKit/OSEFileManager.h>
#import <DesktopKit/Utilities.h>

#import <Workspace.h>
#import <Preferences/Browser/BrowserPrefs.h>

#import "BrowserViewer.h"

//=============================================================================
// BrowserMatrix: focus, selection and copy/pase operations
// BrowserMatrix links with BrowserViewer in awakeFromNib:
//=============================================================================
@interface BrowserMatrix : NSMatrix
@end

@implementation BrowserMatrix

// If matrix is not last selected column matrix do not accept first
// responder status to avoid focus stealing from column with selected cells
- (BOOL)acceptsFirstResponder
{
  NSBrowser *view = (NSBrowser *)[_delegate view];

  if (([view selectedColumn] < 0) || (self == [view matrixInColumn:[view selectedColumn]])) {
    return YES;
  }

  return NO;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event
{
  if ([event type] == NSLeftMouseDown) {
    return YES;
  }
  return NO;
}

- (id)validRequestorForSendType:(NSString *)st
                     returnType:(NSString *)rt
{
  NSString *currentPath = [[[self delegate] selectedPaths] firstObject];

  if (currentPath && [st isEqual:NSStringPboardType])
    return self;
  else
    return nil;
}

- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pb
                             types:(NSArray *)types
{
  NSString *currentPath = [[[self delegate] selectedPaths] firstObject];

  if (currentPath) {
    [pb declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    [pb setString:currentPath forType:NSStringPboardType];
    return YES;
  }
  else {
    return NO;
  }
}

- (void)selectAll:(id)sender
{
  //NSDebugLLog(@"Browser", @"BrowserMatrix: selectAll:");
  if (![sender isKindOfClass:[NSBrowser class]] &&
      [_delegate respondsToSelector:@selector(selectAll:)]) {
      [_delegate selectAll:sender];
    }
  else {
    [super selectAll:sender];
  }
}

- (void)keyDown:(NSEvent *)event
{
  NSInteger selectedRow;
  NSInteger selectedRowNew;
  unichar   c = [[event characters] characterAtIndex:0];

  if (([event modifierFlags] & NSShiftKeyMask) ||
      (c != NSDownArrowFunctionKey && c != NSUpArrowFunctionKey)) {
    [super keyDown:event];
    return;
  }
  
  while ([event type] != NSKeyUp) {
    event = [[self window] nextEventMatchingMask:NSAnyEventMask];
    selectedRow = [self selectedRow];
    selectedRowNew = [self selectedRow];

    if (c == NSDownArrowFunctionKey) {
      if (selectedRow < [self numberOfRows]-1)
        selectedRowNew++;
    }
    else if (c == NSUpArrowFunctionKey) {
      if (selectedRow > 0)
        selectedRowNew--;
    }

    if (selectedRow == selectedRowNew)
      continue;

    [self deselectAllCells];
    [self selectCellAtRow:selectedRowNew column:0];
    [self displayIfNeeded];
  }

  NSBrowser *browser = (NSBrowser *)[(BrowserViewer *)_delegate view];
  [browser selectRow:selectedRowNew inColumn:[browser selectedColumn]];
  [(BrowserViewer *)_delegate doClick:self];
}

/*- (void)copy:(id)senderPath
{
  // Shortcut-based Copy/Move file operaion
  NSDebugLLog(@"Browser", @"BrowserMatrix: copy:");
}*/

@end

//=============================================================================
// BrowserCell: do not draw first responder frame. 
// [NSBrowserCell setShowsFirstResponder:NO] doesn't work. GNUstep bug?
// BrowserCell links with BrowserViewer in awakeFromNib:
//=============================================================================

@interface BrowserCell : NSBrowserCell
{
  NSString *fullTitle;
}
@end

@implementation BrowserCell

- (void)setShowsFirstResponder:(BOOL)flag
{
  _cell.shows_first_responder = NO;
}

- (void)_drawAttributedText:(NSAttributedString*)aString 
                    inFrame:(NSRect)aRect
{
  NSSize             titleSize;
  NSAttributedString *saString;
  NSString           *sString;
  NSDictionary       *attrs;

  if (aString == nil)
    return;

  attrs = [aString attributesAtIndex:0 effectiveRange:NULL];
  sString = NXTShortenString([aString string], aRect.size.width, [self font],
                            NXSymbolElement, NXTDotsAtRight);
  saString = [[NSAttributedString alloc] initWithString:sString
                                             attributes:attrs];
  
  titleSize = [saString size];

  /** Important: text should always be vertically centered without
   * considering descender [as if descender did not exist].
   * This is particularly important for single line texts.
   * Please make sure the output remains always correct.
   */
  aRect.origin.y = NSMidY (aRect) - titleSize.height/2; 
  aRect.size.height = titleSize.height;

  [saString drawInRect:aRect];
  
  [saString release];
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event
{
  if ([event type] == NSLeftMouseDown) {
    return YES;
  }
  return NO;
}

@end

//=============================================================================
// BrowserViewer
//=============================================================================

@interface BrowserViewer (Private)

- (void)ensureBrowserHasEmptyColumn;

@end

@implementation BrowserViewer (Private)

- (void)ensureBrowserHasEmptyColumn
{
 // NSDebugLLog(@"Browser", @"[BrowserViewer] lastVC: %i selectedC: %i", 
 //        [view lastVisibleColumn], [view selectedColumn]);
  if ([view lastVisibleColumn] == [view selectedColumn]) {
    [view addColumn];
  }
}

// FIXME: is not used
- (void)ensureBrowserScrolledMaxLeft
{
  [view scrollColumnsLeftBy:[view lastVisibleColumn]-[view selectedColumn]-1];
}

// FIXME: is not used
- (void)ensureBrowserScrolledMaxRight
{
//  [view scrollColumnsLeftBy:[view lastVisibleColumn]-[view selectedColumn]-1];
  if ([view lastColumn] - [view firstVisibleColumn] == 1) {
    [view scrollColumnsRightBy:2];
  }
}

// FIXME: is not used
- (BOOL)isEmptyColumn:(NSInteger)column
{
  NSMatrix *columnMatrix = [view matrixInColumn:column];

  if ([columnMatrix numberOfRows] == 0)
    return YES;

  return NO;
}

@end

@implementation BrowserViewer

//=============================================================================
// Create and destroy
//=============================================================================

- (void)dealloc
{
  NSDebugLLog(@"Memory", @"[BrowserViewer] dealloc");
  [[NSNotificationCenter defaultCenter] removeObserver:self];
    
  TEST_RELEASE(currentPath);
  TEST_RELEASE(selection);

  TEST_RELEASE(fileViewer);
  TEST_RELEASE(rootPath);
  TEST_RELEASE(fileManager);

  TEST_RELEASE(view);

  [super dealloc];
}

- init
{
  [super init];

  if (![NSBundle loadNibNamed:@"BrowserViewer" owner:self]) {
    NSDebugLLog(@"BrowserViewer", @"Error: failed to load BrowserViewer interface file!");
    [self autorelease];
    return nil;
  }
  
  ASSIGN(fileManager, [NSFileManager defaultManager]);

  currentPath = nil;
  selection = nil;

  return self;
}

- (void)awakeFromNib
{
  [view retain];
  [view removeFromSuperview];
  DESTROY(bogusWindow);

  columnCount = 0;
  currentPath = nil;

  [self setColumnWidth:BROWSER_DEF_COLUMN_WIDTH];

  [view setMaxVisibleColumns:99];
  [view setTarget:self];
  [view setAction:@selector(doClick:)];
  [view setDoubleAction:@selector(doDoubleClick:)];
  [view setMatrixClass:[BrowserMatrix class]];
  [view setCellClass:[BrowserCell class]];
}

//=============================================================================
// <Viewer> protocol methods
//=============================================================================

+ (NSString *)viewerType
{
  return _(@"Browser");
}

+ (NSString *)viewerShortcut
{
  return _(@"B");
}

- (NSView *)view
{
  return view;
}

// Access to last selected column in browser (for example, focus tasks)
- (NSView *)keyView
{
  NSInteger selectedColumn = [view selectedColumn];
  return [view matrixInColumn:(selectedColumn > 0 ? selectedColumn : 0)];
}

- (void)setOwner:(FileViewer *)theFileViewer
{
  ASSIGN(fileViewer, theFileViewer);
}

- (void)setRootPath:(NSString *)fullPath
{
  ASSIGN(rootPath, fullPath);
}

- (NSString *)fullPath
{
  return [rootPath stringByAppendingPathComponent:[view path]];
}

- (CGFloat)columnWidth
{
  OSEDefaults *df = [OSEDefaults userDefaults];

  columnWidth = [df floatForKey:BrowserViewerColumnWidth];
  if (columnWidth <= BROWSER_MIN_COLUMN_WIDTH) {
    columnWidth = BROWSER_DEF_COLUMN_WIDTH;
  }

  return columnWidth;
}

- (void)setColumnWidth:(CGFloat)width
{
  columnWidth = width;
  [view setMinColumnWidth:columnWidth * 0.75];
}

- (NSUInteger)columnCount
{
  columnCount = [view numberOfVisibleColumns];

  return columnCount;
}

- (void)setColumnCount:(NSUInteger)num
{
  [view setMinColumnWidth:([view frame].size.width / num) * 0.75];
  columnCount = [view numberOfVisibleColumns];
}

- (NSInteger)numberOfEmptyColumns
{
  NSInteger     lastVC = [view lastVisibleColumn];
  NSInteger     firstVC = [view firstVisibleColumn];
  NSInteger     empty = 0;
  NSMatrix      *mtrx;
  NSBrowserCell *selectedCell;
  NSUInteger    rows;
  int           i;

//  NSDebugLLog(@"Browser", @"Matrix at column %i has %i rows", lastVC, [mtrx numberOfRows]);
  for (i = lastVC; i >= firstVC; i--) {
    mtrx = [view matrixInColumn:i];
    if ([mtrx numberOfRows] > 0) {
      // Check if directory selected
      selectedCell = [mtrx selectedCell];
      if (selectedCell && empty > 0 && ![selectedCell isLeaf]) {
        empty--;
      }
      break;
    }
    if (i == 0) {
      empty--;
      break;
    }
    empty++;
  }

  // NSDebugLLog(@"Browser", @"[BrowserViewer] numberOfEmptyColumns: %i, LVC:%i FVC:%i # of VC:%i", 
  //       empty, lastVC, firstVC, [view numberOfVisibleColumns]);

  return empty;
}

- (void)setNumberOfEmptyColumns:(NSInteger)num
{
  // NSDebugLLog(@"Browser", @"[BrowserViewer] setNumberOfEmptyColumns: %i", num);
  if ([self numberOfEmptyColumns] < num) {
    [view addColumn];
  }
}

- (NSArray *)selectedPaths
{
  NSMutableArray *pathList;
  NSString       *pathPrefix;
  
  if (!currentPath)
    return nil;

  pathList = [NSMutableArray new];
  pathPrefix = [rootPath stringByAppendingPathComponent:currentPath];
  
  if ([selection count] > 0) {
    for (NSString *path in selection) {
      path = [pathPrefix stringByAppendingPathComponent:path];
      [pathList addObject:path];
    }
    return pathList;
  }
  else {
    [pathList addObject:currentPath];
  }
  
  return pathList;
}


//-----------------------------------------------------------------------------
// Actions
//-----------------------------------------------------------------------------

- (void)_setSelection:(NSArray *)filenames
             inColumn:(NSInteger)column
{
  NSInteger selectionCount = [filenames count];
  NSMatrix  *mtrx;
  NSInteger rowsCount, i;
  NSCell    *cell;

  NSDebugLLog(@"Browser", @"[Browser:%@] setSelection:%@ in column:%li",
              [view path], filenames, column);

  mtrx = [view matrixInColumn:column];
  rowsCount = [mtrx numberOfRows];
  for (i = 0; i < rowsCount; i++) {
    cell = [mtrx cellAtRow:i column:0];
    if ([filenames containsObject:[cell stringValue]]) {
      [mtrx selectCellAtRow:i column:0];
      if (--selectionCount == 0) {
        break;
      }
    }
  }
}

- (void)displayPath:(NSString *)dirPath
          selection:(NSArray *)filenames
{
  int     length = [dirPath length];
  NSArray *pathComponents;

  if (dirPath == nil || [dirPath isEqualToString:@""]) {
    return;
  }

  [fileViewer setWindowEdited:YES];
  
  // remove a trailing "/" character
  if (length > 1 && [dirPath characterAtIndex:length-1] == '/') {
    dirPath = [dirPath substringToIndex:length-1];
  }

  // Initial
  if (currentPath == nil || [view lastColumn] < 0) {
    [view loadColumnZero];
  }

  // Make assignment here because NSBrowser delegate methods rely on
  // these ivars to proceed hidden directories correctly.
  ASSIGN(currentPath, dirPath);
  ASSIGN(selection, filenames);
  
  if (dirPath && (filenames == nil || [filenames count] == 0)) {
    // dir selected
    NSDebugLLog(@"Browser", @"<NSBrowser> set path to dir: %@", dirPath);
    [view reloadColumn:0];
    [view setPath:dirPath];
  }
  else if ([filenames count] == 1) {
    [view setPath:[dirPath stringByAppendingPathComponent:[filenames lastObject]]];
  }
  else if ([filenames count] > 1) {
    // Set path to last dir
    [view setPath:dirPath];
    // Set selection
    [self _setSelection:selection inColumn:[view selectedColumn]+1];
  }

  [self ensureBrowserHasEmptyColumn];
  
  [fileViewer setWindowEdited:NO];
}

- (void)scrollToRange:(NSRange)range
{
  [view scrollColumnToVisible:range.location];
  [view scrollColumnToVisible:range.location + range.length - 1];
}

//-----------------------------------------------------------------------------
// Events
//-----------------------------------------------------------------------------

- (void)reloadColumn:(NSUInteger)col
{
  NSMatrix  *mtrx;
  NSString  *path;
  NSRect    r;
  NSInteger rowsCount;
  id        cell;
  int       i;

  if (col == -1) {
    col = 0;
  }
  mtrx = [view matrixInColumn:col];

  // Save browser path
  path = [view path];
  // Save visible rect in last coloumn
  r = [mtrx visibleRect];

  // NSDebugLLog(@"Browser", @"[Browser:%@] reloadColumn #%li(%li) with path %@", 
  //       [view path], col, [view lastColumn], selectedNames);

  // Reload
  [view reloadColumn:col];
  
  // Restore path selection
  [view setPath:path];
  [self ensureBrowserHasEmptyColumn];

  // Restore scrolling position
  mtrx = [view matrixInColumn:col]; // it's new matrix after reload
  [mtrx scrollRectToVisible:r];

  // Restore selection in last loaded column
  [self _setSelection:selection inColumn:[view selectedColumn]];
}

- (void)reloadLastColumn
{
  [self reloadColumn:[view selectedColumn]];
  [[view window] makeFirstResponder:view];
}

// relativePath is unused here
- (void)reloadPathWithSelection:(NSString *)relativePath
{
  [self reloadLastColumn];
  [[view window] makeFirstResponder:view];
}

- (void)reloadPath:(NSString *)reloadPath
{
  NSString  *path;
  NSInteger i;

  NSDebugLLog(@"Browser", @"[Browser:%@] reloadPath:%@", [view path], reloadPath);

  for (i=[view lastColumn]; i>=0; i--) {
    path = [view pathToColumn:i];
    if ([path isEqualToString:reloadPath]) {
      [self reloadColumn:i];
      break;
    }
  }
  [[view window] makeFirstResponder:view];
}

- (void)currentSelectionRenamedTo:(NSString *)absolutePath
{
  NSString   *newName = [absolutePath lastPathComponent];
  NSUInteger column = [view selectedColumn];
  id         cell;

  // Rename selected cell in Browser
  cell = [view selectedCellInColumn:column];
  [cell setStringValue:newName];
  [self reloadLastColumn];
  [[view window] makeFirstResponder:view];
}

- (BOOL)becomeFirstResponder
{
  return [view becomeFirstResponder];
}

//=============================================================================
// NSBrowser delegate methods
//=============================================================================
- (void)     browser:(NSBrowser *)sender 
 createRowsForColumn:(NSInteger)column
	    inMatrix:(NSMatrix *)matrix
{
  NSString *path = [view pathToColumn:column];
  NSString *fullPath;
  NSArray  *dirContents;

  NSDebugLLog(@"Browser", @"<NSBrowser> load coumn:%@ for path:%@ %li/%li",
        path, [view path], [view selectedColumn], column);

  if ([[view selectedCell] isLeaf] ||     // Is not directory
      [[view selectedCells] count] > 1) { // Multiple directories selected
    if (![[view path] isEqualToString:@"/"]) {
      return;
    }
  }

  [fileViewer setWindowEdited:YES];
  
  [matrix setDelegate:self];

  // Get sorted directory contents
  fullPath = [rootPath stringByAppendingPathComponent:currentPath];
  dirContents = [fileViewer directoryContentsAtPath:path forPath:fullPath];
  fullPath = [self fullPath];

  int i = 0;
  if ([matrix numberOfRows] < [dirContents count]) {
    i = [matrix numberOfRows];
  }
  for (; i < [dirContents count]; i++) {
    [matrix addRow];
  }
  
  dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
      NSString *fPath = [NSString stringWithString:fullPath];
      NSArray  *dc = [dirContents copy];
    
      // Fill column
      // for (NSString *filename in dc) {
      for (int i = 0; i < [dc count]; i++) {
        NSString    *fileName;
        NSString    *filePath;
        NSString    *wmFileType = nil;
        NSString    *fmFileType = nil;
        NSString    *appName = nil;
        BrowserCell *bc;

        // [matrix addRow];
        bc = [matrix cellAtRow:i column:0];

        fileName = [dc objectAtIndex:i];
        filePath = [fPath stringByAppendingPathComponent:fileName];
        [(NSWorkspace *)[NSApp delegate] getInfoForFile:filePath
                                            application:&appName
                                                   type:&wmFileType];

        if (![wmFileType isEqualToString:NSDirectoryFileType] &&
            ![wmFileType isEqualToString:NSFilesystemFileType]) {
          [bc setLeaf:YES];
        }

        // Modify display attributes and set title of cell
        fmFileType = [[fileManager fileAttributesAtPath:filePath
                                           traverseLink:NO] fileType];
        if ([fmFileType isEqualToString:NSFileTypeSymbolicLink]) {
          [bc setFont:[NSFont fontWithName:@"Helvetica-Oblique" size:12.0]];
        }
      
        [bc setTitle:fileName];
        [bc setLoaded:YES];
        // [sender displayColumn:column];
      }
      [dc release];
      [fileViewer setWindowEdited:NO];
      [sender displayColumn:column];
    });
}

// FIXME: do nothing
- (void)browserDidScroll:(NSBrowser *)sender
{
  // [view becomeFirstResponder];
}

- (void)doClick:(id)sender
{
  NSString *dirPath = [view path];
  NSArray  *filenames = nil;
  NSArray  *selectedCells = [view selectedCells];
  unsigned length = [dirPath length];
  NSPasteboard *pb = [NSPasteboard pasteboardWithName:@"Selection"];

  NSDebugLLog(@"Browser",
              @"[BrowserViewer] doClick:%@ lastColumn(selected): %li(%li)", 
              dirPath, [view lastVisibleColumn], [view selectedColumn]);

  // remove a trailing "/" character
  if (length > 1 && [dirPath characterAtIndex:length-1] == '/') {
    dirPath = [dirPath substringToIndex:length-1];
  }

  if ([selectedCells count] == 0) { /* dir selected */
    [fileViewer displayPath:dirPath selection:nil sender:self];
  }
  else if ([selectedCells count] == 1) { /* 1 file selected */
    NSString *fileType, *appName;
      
    [(NSWorkspace *)[NSApp delegate] getInfoForFile:[self fullPath]
                                        application:&appName
                                               type:&fileType];
    
    if (fileType != nil
        && ([fileType isEqualToString:NSDirectoryFileType]
            || [fileType isEqualToString:NSFilesystemFileType])) {
      [fileViewer displayPath:dirPath selection:nil sender:self];
    }
    else {
      filenames = [NSArray arrayWithObject:[dirPath lastPathComponent]];
      dirPath = [dirPath stringByDeletingLastPathComponent];
      // FileViewer
      [fileViewer displayPath:dirPath selection:filenames sender:self];
    }
  }
  else { /* multiple files (dirs?) selected */
    NSMutableArray *array = [NSMutableArray array];
    NSEnumerator   *e = [selectedCells objectEnumerator];
    NSBrowserCell  *bc;

    while ((bc = [e nextObject]) != nil)
      {
        [array addObject:[bc title]];
      }

    filenames = array;
    dirPath = [dirPath stringByDeletingLastPathComponent];

    // FileViewer
    [fileViewer displayPath:dirPath selection:filenames sender:self];
  }

  [pb declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
  [pb setString:dirPath forType:NSStringPboardType];
  
  ASSIGN(currentPath, dirPath);
  ASSIGN(selection, filenames);
  
  [self ensureBrowserHasEmptyColumn];
}

- (void)doDoubleClick:(id)sender
{
  NSDebugLLog(@"Browser",
              @"[BrowserViewer] doDoubleClick: %@", [sender className]);
  [self doClick:sender];
  [fileViewer open:sender];
}

//=============================================================================
// NSFirst overridings
//=============================================================================

- (void)selectAll:(id)sender
{
  //NSDebugLLog(@"Browser", @"Browser: selectAll:");
  if ([(NSBrowserCell *)[view selectedCell] isLeaf]) {
    [[view matrixInColumn:[view selectedColumn]] selectAll:view];
  }
  else {
    [[view matrixInColumn:[view selectedColumn]+1] selectAll:view];
  }
  [self doClick:self];
}

@end
