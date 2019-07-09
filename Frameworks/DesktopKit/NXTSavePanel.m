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

#import <Foundation/NSNotification.h>
#import <AppKit/AppKit.h>
#import <SystemKit/OSEMediaManager.h>
#import "NXTSavePanel.h"
#import "NXTFileManager.h"

@interface NXTPanelLoader : NSObject
{
  id IBOutlet panel;
}
- (id)loadPanelNamed:(NSString *)nibName;
@end
@implementation NXTPanelLoader

- (id)loadPanelNamed:(NSString *)nibName
{
  if ([NSBundle loadNibNamed:nibName owner:self] == NO) {
    NSLog(@"[NXTPanelLoader] can't load model file `%@`.", nibName);
  }

  while (panel == nil) {
    [[NSRunLoop currentRunLoop]
        runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
  }

  return panel;
}

@end

static NXTSavePanel *savePanel = nil;

@implementation NXTSavePanel

+ (NXTSavePanel *)savePanel
{
  if (savePanel == nil) {
    savePanel = [[NXTPanelLoader alloc] loadPanelNamed:@"NXTSavePanel"];
  }
  
  return savePanel;
}

- (void)dealloc
{
  NSLog(@"[NXTSavePanel] -dealloc: %lu", [savePanel retainCount]);
  savePanel = nil;
  [super dealloc];
}

// --- Overridings
- (id)init
{
  NSLog(@"[NXTSavePanel] -init");
  self = [NXTSavePanel savePanel];  
  return self;
}

- (void)awakeFromNib
{
  NSLog(@"awakeFromNib");
  [self setTitle:@"Save"];
  
  [_topView setBounds:[_topView frame]];
  [_topView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
  [_topView setAutoresizesSubviews:YES];
  
  [_bottomView setBounds:[_bottomView frame]];
  [_bottomView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
  [_bottomView setAutoresizesSubviews:YES];

  [_icon setImage:[[NSApplication sharedApplication] applicationIconImage]];

  [_browser setTag:NSFileHandlingPanelBrowser];
  [_browser setDoubleAction:@selector(performClick:)];
  // Browser rght-click menu
  _showsHiddenFilesMenu = [[NSMenu alloc] initWithTitle: @""];
  [_showsHiddenFilesMenu insertItemWithTitle:_(@"Show Hidden Files")
                                      action:@selector(_toggleShowsHiddenFiles:)
                               keyEquivalent:@""
                                     atIndex:0];
  [[_showsHiddenFilesMenu itemAtIndex:0] setTarget:self];
  [[_showsHiddenFilesMenu itemAtIndex:0] setState:[self showsHiddenFiles]];
  [_browser setMenu:_showsHiddenFilesMenu];
  [_showsHiddenFilesMenu release];

  [_form setTag:NSFileHandlingPanelForm];
  [_homeButton setTag:NSFileHandlingPanelHomeButton];
  [_homeButton setToolTip:_(@"Home")];
  [_diskButton setTag:NSFileHandlingPanelDiskButton];
  [_diskButton setToolTip:_(@"Mount")];
  [_ejectButton setTag:NSFileHandlingPanelDiskEjectButton];
  [_ejectButton setToolTip:_(@"Unmount")];
  [_cancelButton setTag:NSFileHandlingPanelCancelButton];
  [_okButton setTag:NSFileHandlingPanelOKButton];

  [self setFrameAutosaveName:@"NXTSavePanel"];
  
  /* Used in setMinSize: */
  _originalMinSize = [self minSize];
  /* Used in setContentSize: */
  _originalSize = [[self contentView] frame].size;

  [self setDirectory:NSHomeDirectory()];
}

- (BOOL)_shouldShowExtension:(NSString *)extension
{
  if (_allowedFileTypes != nil
      && [_allowedFileTypes indexOfObject:extension] == NSNotFound
      && [_allowedFileTypes indexOfObject:@""] == NSNotFound) {
    return NO;
  }

  return YES;
}

- (void)_selectTextInColumn:(int)column
{
  NSMatrix      *matrix;
  NSBrowserCell *selectedCell;
  BOOL           isLeaf;

  NSLog(@"_selectTextInColumn");

  if (column == -1)
    return;

  matrix = [_browser matrixInColumn:column];
  selectedCell = [matrix selectedCell];
  isLeaf = [selectedCell isLeaf];

  if (_delegateHasSelectionDidChange) {
    [_delegate panelSelectionDidChange:self];
  }

  if (isLeaf) {
    [[_form cellAtIndex:0] setStringValue:[selectedCell stringValue]];
    [_okButton setEnabled:YES];
  }
  else {
    if (_delegateHasDirectoryDidChange) {
      [_delegate panel:self directoryDidChange:[_browser pathToColumn:column]];
    }

    if ([[[_form cellAtIndex:0] stringValue] length] > 0) {
      [_okButton setEnabled:YES];
      // [self _selectCellName:[[_form cellAtIndex:0] stringValue]];
    }
    else {
      [_okButton setEnabled:NO];
    }
  }
  [super makeFirstResponder:[_form cellAtIndex:0]];
}

- (void)_selectText:(id)sender
{
  [self _selectTextInColumn:[_browser selectedColumn]];
}

- (void)     browser:(NSBrowser*)sender
 createRowsForColumn:(NSInteger)column
            inMatrix:(NSMatrix*)matrix
{
  NSString              *path, *file, *pathAndFile, *extension; 
  NSArray               *files;
  unsigned              i, count, addedRows; 
  BOOL                  exists, isDir;
  NSBrowserCell         *cell;
  NSWorkspace		*ws;
  NSFileManager         *fm;
  NXTFileManager        *nxfm;
  /* We create lot of objects in this method, so we use a pool */
  NSAutoreleasePool     *pool;

  NSLog(@"browser:createRowsForColumn:inMatrix");

  pool = [NSAutoreleasePool new];
  ws = [NSWorkspace sharedWorkspace];
  fm = [NSFileManager defaultManager];
  path = [_browser pathToColumn:column];
  nxfm = [NXTFileManager sharedManager];
  files = [nxfm directoryContentsAtPath:path
                                forPath:nil
                               sortedBy:NXTSortByKind
                             showHidden:_showsHiddenFiles];

  count = [files count];

  /* If array is empty, just return (nothing to display).  */
  if (count == 0) {
    RELEASE (pool);
    return;
  }

  addedRows = 0;
  [matrix setRefusesFirstResponder:YES];
  for (i = 0; i < count; i++) {
    // Now the real code
    file = [files objectAtIndex:i];
    extension = [file pathExtension];
      
    pathAndFile = [path stringByAppendingPathComponent:file];
    exists = [fm fileExistsAtPath:pathAndFile 
                       isDirectory:&isDir];

    /* Note: The initial directory and its parents are always shown, even if
     * it they are file packages or would be rejected by the validator. */
#define HAS_PATH_PREFIX(aPath, otherPath)                               \
    ([aPath isEqualToString:otherPath] ||                               \
     [aPath hasPrefix:[otherPath stringByAppendingString:@"/"]])

    if (exists && (!isDir || !HAS_PATH_PREFIX(_directory, pathAndFile))) {
      if (isDir && !_treatsFilePackagesAsDirectories
          && ([ws isFilePackageAtPath: pathAndFile]
              || [_allowedFileTypes containsObject: extension])) {
        isDir = NO;
      }

      if (_delegateHasShowFilenameFilter) {
        exists = [_delegate panel:self shouldShowFilename:pathAndFile];
      }

      if (exists && !isDir) {
        exists = [self _shouldShowExtension:extension];
      }
    } 

    if (exists) {
      if (addedRows == 0) {
        [matrix addColumn];
      }
      else {
        [matrix insertRow:addedRows withCells:nil];
      }

      cell = [matrix cellAtRow:addedRows column:0];
      [cell setStringValue:file];
      [cell setRefusesFirstResponder:YES];

      if (isDir)
        [cell setLeaf:NO];
      else
        [cell setLeaf:YES];

      addedRows++;
    }
  }

  RELEASE(pool);
}

//
// Methods invoked by button press
//
- (void)_setHomeDirectory:(id)sender
{
  [super setDirectory:NSHomeDirectory()];
}

- (void)_mountMedia:(id)sender
{
  [[OSEMediaManager defaultManager] mountNewRemovableMedia];
}

- (void)_unmountMedia:(id)sender
{
  [[OSEMediaManager defaultManager] unmountAndEjectDeviceAtPath:[self directory]];
}

- (void)setTitle:(NSString*)title
{
  [super setTitle: @""];
  [_titleField setStringValue:title];
  [_titleField sizeToFit];
}

// --- Extentions

@end
