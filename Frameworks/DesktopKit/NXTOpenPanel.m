/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - DesktopKit framework
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

#import <Foundation/NSBundle.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSFileManager.h>
#import <AppKit/NSApplication.h>
#import <AppKit/NSBrowser.h>
#import <AppKit/NSBrowserCell.h>
#import <AppKit/NSForm.h>
#import <AppKit/NSImageView.h>

#import "NXTPanelLoader.h"
#import "NXTOpenPanel.h"

static NXTOpenPanel *_openPanel = nil;

// Pacify the compiler
@interface NSSavePanel (GSPrivateMethods)
- (void)awakeFromNib;
- (void)_updateDefaultDirectory;
- (void)_reloadBrowser;
- (void)_setupForDirectory:(NSString *)path file:(NSString *)filename;
@end

@implementation NXTOpenPanel (GSPrivateMethods)

- (BOOL)_shouldShowExtension:(NSString *)extension
{
  if (_canChooseFiles == NO ||
      (_allowedFileTypes != nil &&
       [_allowedFileTypes containsObject:extension] == NO)) {
    return NO;
  }

  return YES;
}

- (void)_selectTextInColumn:(int)column
{
  NSMatrix *matrix;
  BOOL     selectionValid = YES;
  NSArray  *selectedCells;

  if (column == -1)
    return;

  if (_delegateHasSelectionDidChange) {
    [self.delegate panelSelectionDidChange:self];
  }

  matrix = [_browser matrixInColumn:column];

  // Validate selection
  selectedCells = [matrix selectedCells];
  for (id cell in selectedCells) {
    if ((![cell isLeaf] && !_canChooseDirectories) ||
        ([cell isLeaf] && !_canChooseFiles)) {
      selectionValid = NO;
    }
  }
  
  // Set form label
  if ([selectedCells count] > 1) {
    [[_form cellAtIndex:0] setStringValue:@""];
  }
  else if (selectionValid != NO) {
    [[_form cellAtIndex:0] setStringValue:[[matrix selectedCell] stringValue]];
    [_form selectTextAtIndex:0];
  }
  
  if ([[matrix selectedCell] isLeaf] == NO) {
    ASSIGN(_directory, [[_browser path] copy]);
  }
  
  [_okButton setEnabled:selectionValid];
  [matrix selectCell:[matrix selectedCell]];
}

- (void)_setupForDirectory:(NSString *)path file:(NSString *)filename
{
  // FIXME: Not sure if this is needed
  if ((filename == nil) || ([filename isEqual:@""] != NO)) {
    [_okButton setEnabled:NO];
  }

  if (_canChooseDirectories == NO) {
    if ([_browser allowsMultipleSelection] == YES) {
      [_browser setAllowsBranchSelection:NO];
    }
  }
  
  [super _setupForDirectory:path file:filename];
}

@end

@implementation NXTOpenPanel

+ (void)initialize
{
  if (self == [NXTOpenPanel class]) {
    [self setVersion:1];
  }
}

+ (NXTOpenPanel *)openPanel
{
  if (_openPanel == nil) {
    _openPanel = [[NXTPanelLoader alloc] loadPanelNamed:@"NXTOpenPanel"];
  }

  return _openPanel;
}

- (void)dealloc
{
  NSLog(@"[NXTOpenPanel] -dealloc: %lu", [_openPanel retainCount]);
  _openPanel = nil;
  [super dealloc];
}

- (id)init
{
  self = [NXTOpenPanel openPanel];
  return self;
}

- (void)awakeFromNib
{
  [super awakeFromNib];
  
  _canChooseDirectories = NO;
  _canChooseFiles = YES;
  [self setTitle:_(@"Open")];
  [self setAllowsMultipleSelection:NO];
}

//
//--- Filtering Files
//

- (void)setAllowsMultipleSelection:(BOOL)flag
{
  [_browser setAllowsMultipleSelection:flag];
}

- (BOOL)allowsMultipleSelection
{
  return [_browser allowsMultipleSelection];
}

- (void)setCanChooseDirectories:(BOOL)flag
{
  if (flag != _canChooseDirectories) {
    _canChooseDirectories = flag;
    [_browser setAllowsBranchSelection:flag];
    if (!flag) {
      /* FIXME If the user disables directory selection we should deselect
         any directories that are currently selected. This is achieved by
         calling _reloadBrowser, but this may be considered overkill, since
         the displayed files are the same whether canChooseDirectories is
         enabled or not. */
      [self _reloadBrowser];
    }
  }
}

- (BOOL)canChooseDirectories
{
  return _canChooseDirectories;
}

- (void)setCanChooseFiles:(BOOL)flag
{
  if (flag != _canChooseFiles) {
    _canChooseFiles = flag;
    [self _reloadBrowser];
  }
}

- (BOOL)canChooseFiles
{
  return _canChooseFiles;
}

- (NSString *)filename
{
  NSArray *ret;

  ret = [self filenames];

  if ([ret count] == 1)
    return [ret objectAtIndex:0];
  else 
    return nil;
}

- (NSArray *)filenames
{
  if ([_browser allowsMultipleSelection]) {
    NSMutableArray *ret = [NSMutableArray array];
    NSString       *dir = [self directory];
      
    if ([_browser selectedColumn] != [_browser lastColumn]) {
      // The last column doesn't have anything selected - so we must
      // have selected a directory.
      if (_canChooseDirectories == YES) {
        [ret addObject:dir];
      }
    }
    else {
      for (NSBrowserCell *currCell in [_browser selectedCells]) {
        [ret addObject:[dir stringByAppendingPathComponent:[currCell stringValue]]];
      }
    }
    return ret;
  }
  else {
    if (_canChooseDirectories == YES) {
      if ([_browser selectedColumn] != [_browser lastColumn]) {
        return [NSArray arrayWithObject:[self directory]];
      }
    }

    return [NSArray arrayWithObject:[super filename]];
  }
}

- (NSArray *)URLs
{
  NSMutableArray *ret = [NSMutableArray new];

  for (NSString *filename in [self filenames]) {
    [ret addObject:[NSURL fileURLWithPath:filename]];
  } 

  return AUTORELEASE(ret);
}

//
//--- Running the NXTOpenPanel
//

- (NSInteger)runModal
{
  return [self runModalForTypes:[self allowedFileTypes]];
}

- (NSInteger)runModalForTypes:(NSArray *)fileTypes
{
  return [self runModalForDirectory:[self directory]
			       file:@""
			      types:fileTypes];
}

- (NSInteger)runModalForDirectory:(NSString *)path
                             file:(NSString *)name
                            types:(NSArray *)fileTypes
{
  [self setAllowedFileTypes:fileTypes];
  return [self runModalForDirectory:path 
			       file:name];  
}

- (NSInteger)runModalForDirectory:(NSString *)path
                             file:(NSString *)name
                            types:(NSArray *)fileTypes
                 relativeToWindow:(NSWindow*)window
{
  [self setAllowedFileTypes:fileTypes];
  return [self runModalForDirectory:path 
			       file:name
		   relativeToWindow:window];
}

- (void)beginSheetForDirectory:(NSString *)path
                          file:(NSString *)name
                         types:(NSArray *)fileTypes
                modalForWindow:(NSWindow *)docWindow
                 modalDelegate:(id)delegate
                didEndSelector: (SEL)didEndSelector
                   contextInfo:(void *)contextInfo
{
  [self setAllowedFileTypes:fileTypes];
  [self beginSheetForDirectory:path
			  file:name
		modalForWindow:docWindow
		 modalDelegate:delegate
		didEndSelector:didEndSelector
		   contextInfo:contextInfo];
}

- (void)beginForDirectory:(NSString *)path
                     file:(NSString *)filename
                    types:(NSArray *)fileTypes
         modelessDelegate:(id)modelessDelegate
           didEndSelector:(SEL)didEndSelector
              contextInfo:(void *)contextInfo
{
  // FIXME: This should be modeless
  [self setAllowedFileTypes:fileTypes];
  [self _setupForDirectory:path file:filename];
  if ([filename length] > 0) {
    [_okButton setEnabled: YES];
  }
  [NSApp beginSheet:self
     modalForWindow:nil
      modalDelegate:modelessDelegate
     didEndSelector:didEndSelector
        contextInfo:contextInfo];
}

- (void)ok:(id)sender
{
  NSMatrix      *matrix = nil;
  NSBrowserCell *selectedCell = nil;
  NSArray       *selectedCells = nil;
  int            selectedColumn, lastColumn;
  NSString	*tmp;

  selectedColumn = [_browser selectedColumn];
  lastColumn = [_browser lastColumn];
  if (selectedColumn >= 0) {
    matrix = [_browser matrixInColumn:selectedColumn];

    if ([_browser allowsMultipleSelection] == YES) {
      selectedCells = [matrix selectedCells];

      if (selectedColumn == lastColumn && [selectedCells count] == 1) {
        selectedCell = [selectedCells objectAtIndex:0];
      }
    }
    else {
      if (selectedColumn == lastColumn)
        selectedCell = [matrix selectedCell];
    }
  }

  if (selectedCell) {
    if ([selectedCell isLeaf] == NO) {
      [[_form cellAtIndex:0] setStringValue:@""];
      [_browser doClick:matrix];
      [_form selectTextAtIndex:0];
      [_form setNeedsDisplay:YES];

      return;
    }
  }
  else if (_canChooseDirectories == NO
           && (selectedColumn != lastColumn || ![selectedCells count])) {
    [_form selectTextAtIndex: 0];
    [_form setNeedsDisplay: YES];
    return;
  }

  ASSIGN (_directory, [_browser pathToColumn:[_browser lastColumn]]);

  if (selectedCell) {
    tmp = [selectedCell stringValue];
  }
  else {
    tmp = [[_form cellAtIndex:0] stringValue];
  }

  if ([tmp isAbsolutePath] == YES) {
    ASSIGN (_fullFileName, tmp);
  }
  else {
    ASSIGN (_fullFileName, [_directory stringByAppendingPathComponent:tmp]);
  }

  if (_delegateHasValidNameFilter) {
    for (NSString *filename in [self filenames]) {
      if ([self.delegate panel:self isValidFilename:filename] == NO) {
        return;
      }
    }
  }

  [self _updateDefaultDirectory];
  [NSApp stopModalWithCode:NSOKButton];
  [_okButton setEnabled:NO];
  [self close];
}

- (BOOL)resolvesAliases
{
  // FIXME
  return YES;
}

- (void)setResolvesAliases:(BOOL)flag
{
  // FIXME
}

//
//--- NSForm delegate
//
- (void)controlTextDidChange:(NSNotification *)aNotification
{
  NSString      *enteredString;
  NSFileManager *fm = [NSFileManager defaultManager];
  BOOL          isDir;

  enteredString = [[[aNotification userInfo] objectForKey:@"NSFieldEditor"] string];

  if ([enteredString length] == 0) {
    [[_browser matrixInColumn:[_browser lastColumn]] deselectAllCells];
    [_okButton setEnabled:_canChooseDirectories];
    return;
  }

  [super controlTextDidChange:aNotification];

  [fm fileExistsAtPath:[_browser path] isDirectory:&isDir];
  if (isDir != NO) {
    [_okButton setEnabled:_canChooseDirectories];
  }
}

/*
 * NSCoding protocol
 */
// - (void)encodeWithCoder:(NSCoder*)aCoder
// {
//   [super encodeWithCoder:aCoder];

//   [aCoder encodeValueOfObjCType:@encode(BOOL) at:&_canChooseDirectories];
//   [aCoder encodeValueOfObjCType:@encode(BOOL) at:&_canChooseFiles];
// }

// - (id)initWithCoder:(NSCoder*)aDecoder
// {
//   self = [super initWithCoder:aDecoder];
//   if (nil == self)
//     return nil;

//   [aDecoder decodeValueOfObjCType: @encode(BOOL) at: &_canChooseDirectories];
//   [aDecoder decodeValueOfObjCType: @encode(BOOL) at: &_canChooseFiles];

//   return self;
// }

@end
