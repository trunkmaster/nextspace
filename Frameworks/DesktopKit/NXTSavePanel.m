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
#import "NXTSavePanel.h"

static NXTSavePanel *savePanel = nil;

@implementation NXTSavePanel

// --- Overridings
- (id)init
{
  self = [super initWithContentRect:NSMakeRect (100, 100, 308, 317)
                          styleMask:(NSTitledWindowMask | NSResizableWindowMask) 
                            backing:2
                              defer:YES];

  if ([NSBundle loadNibNamed:@"NXTSavePanel" owner:self] == NO) {
    NSLog(@"[NXTSavePanel] can't load model file.");
  }
  
  if (nil == self)
    return nil;
  
  return self;
}

- (void)awakeFromNib
{
  [[self contentView] addSubview:_topView];
  [[self contentView] addSubview:_bottomView];

  NSLog(@"[NXTSavePanel] awakeFromNib");

  [_browser setTag:NSFileHandlingPanelBrowser];
  [_browser setDoubleAction:@selector(performClick:)];
  [_browser setTarget:_okButton];
  // [_browser setDelegate:self];
  // [_browser setMinColumnWidth:140];
  // Browser rght-click menu
  // _showsHiddenFilesMenu = [[NSMenu alloc] initWithTitle: @""];
  // [_showsHiddenFilesMenu insertItemWithTitle:_(@"Show Hidden Files")
  //                                     action:@selector(_toggleShowsHiddenFiles:)
  //                              keyEquivalent:@""
  //                                    atIndex:0];
  // [[_showsHiddenFilesMenu itemAtIndex:0] setTarget:self];
  // [[_showsHiddenFilesMenu itemAtIndex:0] setState:[self showsHiddenFiles]];
  // [_browser setMenu:_showsHiddenFilesMenu];
  // [_showsHiddenFilesMenu release];

  [_form setTag:NSFileHandlingPanelForm];
  [_homeButton setTag:NSFileHandlingPanelHomeButton];
  [_homeButton setToolTip:_(@"Home")];
  [_diskButton setTag:NSFileHandlingPanelDiskButton];
  [_diskButton setToolTip:_(@"Mount")];
  [_ejectButton setTag:NSFileHandlingPanelDiskEjectButton];
  [_ejectButton setToolTip:_(@"Unmount")];
  [_cancelButton setTag:NSFileHandlingPanelCancelButton];
  [_okButton setTag:NSFileHandlingPanelOKButton];

  /* Used in setMinSize: */
  // _originalMinSize = [self minSize];
  /* Used in setContentSize: */
  // _originalSize = [[self contentView] frame].size;
}

static NSComparisonResult compareFilenames(id elem1, id elem2, void *context)
{
  /* TODO - use IMP optimization here.  */
  NSSavePanel *s = context;
  NSSavePanel *self = (NSSavePanel *)context;

  return (NSComparisonResult)[s->_delegate panel:self
                                 compareFilename:elem1
                                            with:elem2
                                   caseSensitive:YES];
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
  NSString              *progressString = nil;
  NSWorkspace		*ws;
  NSFileManager         *fm;
  /* We create lot of objects in this method, so we use a pool */
  NSAutoreleasePool     *pool;

  NSLog(@"browser:createRowsForColumn:inMatrix");

  pool = [NSAutoreleasePool new];
  ws = [NSWorkspace sharedWorkspace];
  fm = [NSFileManager defaultManager];
  path = [_browser pathToColumn:column];
  files = [fm directoryContentsAtPath: path];

  /* Remove hidden files.  */
  {
    NSString *h;
    NSArray *hiddenFiles = nil;
    
    // FIXME: Use NSFileManager to tell us what files are hidden/non-hidden
    // rather than having it hardcoded here

    if ([files containsObject: @".hidden"] == YES) {
      /* We need to remove files listed in the xxx/.hidden file.  */
      h = [path stringByAppendingPathComponent: @".hidden"];
      h = [NSString stringWithContentsOfFile: h];
      hiddenFiles = [h componentsSeparatedByString: @"\n"];
    }

    /* Alse remove files starting with `.' (dot) */

    /* Now copy the files array into a mutable array - but only if
       strictly needed.  */
    if (!_showsHiddenFiles) {
      int j;
      /* We must make a mutable copy of the array because the API
         says that NSFileManager -directoryContentsAtPath: return a
         NSArray, not a NSMutableArray, so we shouldn't expect it to
         be mutable.  */
      NSMutableArray *mutableFiles = AUTORELEASE ([files mutableCopy]);
	
      /* Ok - now modify the mutable array removing unwanted files.  */
      if (hiddenFiles != nil) {
        [mutableFiles removeObjectsInArray: hiddenFiles];
      }
	
	
      /* Don't use i which is unsigned.  */
      j = [mutableFiles count] - 1;
	
      while (j >= 0) {
        NSString *file = (NSString *)[mutableFiles objectAtIndex: j];
	    
        if ([file hasPrefix: @"."]) {
          /* NSLog (@"Removing dot file %@", file); */
          [mutableFiles removeObjectAtIndex: j];
        }
        j--;
      }
	
      files = mutableFiles;
    }
  }

  count = [files count];

  /* If array is empty, just return (nothing to display).  */
  if (count == 0) {
    RELEASE (pool);
    return;
  }

  [self setTitle:_(@"Save")];

  // TODO: Sort after creation of matrix so we do not sort 
  // files we are not going to show.  Use NSMatrix sorting cells method
  // Sort list of files to display
  if (_delegateHasCompareFilter == YES) {
    files = [files sortedArrayUsingFunction:compareFilenames 
                                    context:self];
  }
  else {
    files = [files sortedArrayUsingSelector:@selector(_gsSavePanelCompare:)];
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

// --- Extentions

@end
