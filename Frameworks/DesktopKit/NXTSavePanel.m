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

#import "NXTPanelLoader.h"
#import "NXTFileManager.h"
#import "NXTDefaults.h"
#import "NXTAlert.h"

#import "NXTSavePanel.h"

static NXTSavePanel *_savePanel = nil;
#define _SAVE_PANEL_X_PAD	5
#define _SAVE_PANEL_Y_PAD	4

@interface NSSavePanel (GSPrivateMethods)
- (BOOL)_shouldShowExtension:(NSString *)extension;
- (void)_setupForDirectory:(NSString *)path file:(NSString *)name;
// Local additions
- (void)_saveDefaultDirectory:(NSString*)path;
- (void)_setDefaultDirectory;
@end

@implementation NXTSavePanel

+ (void)initialize
{
  if (self == [NXTSavePanel class]) {
    [self setVersion:1];
  }
}

+ (NXTSavePanel *)savePanel
{
  if (_savePanel == nil) {
    _savePanel = [[NXTPanelLoader alloc] loadPanelNamed:@"NXTSavePanel"];
  }
  
  return _savePanel;
}

- (void)dealloc
{
  NSLog(@"[NXTSavePanel] -dealloc: %lu", [_savePanel retainCount]);
  [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  _savePanel = nil;
  [super dealloc];
}

// --- NSSavePanel Overridings
- (id)init
{
  // Save panel pattern is singleton, so no matter how it's created
  // (+savePanel, +new or alloc-init) it must always return single object
  // per application.
  self = [NXTSavePanel savePanel];
  NSLog(@"[NXTSavePanel] -init: %lu", [self retainCount]);
  return self;
}

- (void)awakeFromNib
{
  NSLog(@"awakeFromNib");
  [[NSDistributedNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(_globalDefaultsChanged:)
           name:NXUserDefaultsDidChangeNotification
         object:@"NXGlobalDomain"];
  _showsHiddenFiles = [[NXTFileManager defaultManager] isShowHiddenFiles];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(_windowResized:)
                                               name:NSWindowDidResizeNotification
                                             object:self];

  [self setTitle:@"Save"];
  
  [_icon setImage:[[NSApplication sharedApplication] applicationIconImage]];
  [_icon setRefusesFirstResponder:YES];

  [_browser setRefusesFirstResponder:YES];
  [_browser setTag:NSFileHandlingPanelBrowser];
  [_browser setDoubleAction:@selector(performClick:)];
  [_browser setTarget:_okButton];
  [_browser loadColumnZero];

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
  _originalMinSize = [self minSize];
  /* Used in setContentSize: */
  _originalSize = [[self contentView] frame].size;

  [self _setDefaultDirectory];
}

// --- NSBrowser replacements
- (void)browserMoveLeft:(id)sender
{
  NSInteger selectedColumn = [_browser selectedColumn];
  NSMatrix  *matrix = [_browser matrixInColumn:selectedColumn];

  if (selectedColumn == -1) {
    matrix = [_browser matrixInColumn:0];
    if ([[matrix cells] count]) {
      [matrix selectCellAtRow:0 column:0];
    }
  }

  if (selectedColumn > 0) {
    [matrix deselectAllCells];
    [_browser setLastColumn:selectedColumn];

    selectedColumn--;
    matrix = [_browser matrixInColumn:selectedColumn];
    [matrix scrollCellToVisibleAtRow:[matrix selectedRow]
                              column:selectedColumn];
    [_browser scrollColumnToVisible:selectedColumn];
  }
  [self _saveDefaultDirectory:[_browser path]];
}

- (void)browserMoveRight:(id)sender
{
  NSInteger selectedColumn = [_browser selectedColumn];
  NSMatrix  *matrix = [_browser matrixInColumn:selectedColumn];
  id        selectedCell = [matrix selectedCell];

  if (selectedColumn == -1) {
    matrix = [_browser matrixInColumn:0];
    if ([[matrix cells] count]) {
      [matrix selectCellAtRow:0 column:0];
    }
    selectedCell = [matrix selectedCell];
  }
  else {
    // if there is one selected cell and it is a leaf, move right
    // (column is already loaded)
    if (![selectedCell isLeaf] && [[matrix selectedCells] count] == 1) {
      selectedColumn++;
      matrix = [_browser matrixInColumn:selectedColumn];
      if ([[matrix cells] count] && [matrix selectedCell] == nil) {
        [matrix selectCellAtRow:0 column:0];
      }
      // if selected cell is a leaf, we need to add a column
      selectedCell = [matrix selectedCell];
      if (selectedCell && [selectedCell isLeaf] != NO) {
        [_browser addColumn];
      }
    }
  }
  [_browser setPath:[_browser path]];
  if (selectedCell && [selectedCell isLeaf] != NO) {
    [self _selectTextInColumn:selectedColumn];
  }
  [self _saveDefaultDirectory:[_browser path]];
}


// --- NSWindow Overriding
// Catches the mouse clicks on various panel controls to hold focus on "Name:"
// text field.
- (void)sendEvent:(NSEvent*)theEvent
{
  NSView *v;

  if (!self.isVisible && [theEvent type] != NSAppKitDefined) {
    NSDebugLLog(@"NSEvent", @"Discard (window not visible) %@", theEvent);
    return;
  }

  if ([theEvent type] == NSLeftMouseDown) {
    v = [_wv hitTest:[theEvent locationInWindow]];
    // NSLog(@"[NXTSavePanel] mouse down on %@", [v className]);
    if ([v isKindOfClass:[NSClipView class]] ||
        [v isKindOfClass:[NSBrowser class]]) {
      return;
    }
    else if ([v isKindOfClass:[NSMatrix class]]) {
      [v mouseDown:theEvent];
      [_browser resignFirstResponder];
      [_form becomeFirstResponder];
      return;
    }
  }
  else if ([theEvent type] == NSKeyDown) {
    NSString  *chars = [theEvent characters];
    unichar   character;
    NSMatrix  *matrix;
    NSInteger selectedRow, cellsCount;

    if ([chars isEqualToString:@"\e"]) {
      [[_form cellAtIndex:0] setStringValue:[_browser path]];
      return;
    }
    else if ([chars isEqualToString:@"\r"] && [_okButton isEnabled] == NO) {
      [[_form cellAtIndex:0] setStringValue:@""];
      [_browser setPath:[_browser path]];
      [self _saveDefaultDirectory:[_browser path]];
      return;
    }

    character = [chars characterAtIndex:0];
    if (character >= 0xF700) {
      matrix = [_browser matrixInColumn:[_browser selectedColumn]];
      selectedRow = [matrix selectedRow];
      if (character == NSUpArrowFunctionKey) {
        if (selectedRow > 0) {
          [matrix deselectAllCells];
          [matrix selectCellAtRow:selectedRow-1 column:0];
        }
        return;
      }
      else if (character == NSDownArrowFunctionKey) {
        if (selectedRow < [[matrix cells] count]-1) {
          [matrix deselectAllCells];
          [matrix selectCellAtRow:selectedRow+1 column:0];
        }
        return;
      }
      else if (character == NSLeftArrowFunctionKey) {
        if ([[[_form cellAtIndex:0] stringValue] length] == 0) {
          [self browserMoveLeft:_browser];
          return;
        }
      }
      else if (character == NSRightArrowFunctionKey) {
        if ([[[_form cellAtIndex:0] stringValue] length] == 0) {
          [self browserMoveRight:_browser];
          return;
        }
      }
    }
  }
  else if ([theEvent type] == NSKeyUp) {
    unichar  character = [[theEvent characters] characterAtIndex:0];
    NSMatrix *matrix;

    if (character >= 0xF700) {
      matrix = [_browser matrixInColumn:[_browser selectedColumn]];
      if (character == NSUpArrowFunctionKey) {
        [matrix performClick:self];
        return;
      }
      else if (character == NSDownArrowFunctionKey) {
        [matrix performClick:self];
        return;
      }
    }
  }

  [super sendEvent:theEvent];
}
// ---

- (void)setAccessoryView:(NSView*)aView
{
  NSRect accessoryViewFrame, bottomFrame;
  NSRect tmpRect;
  NSSize contentSize, contentMinSize;
  float  addedHeight, accessoryWidth;

  if (aView == _accessoryView)
    return;
  
  // Remove old accessory view if any
  if (_accessoryView != nil) {
    // Remove accessory view
    accessoryViewFrame = [_accessoryView frame];
    [_accessoryView removeFromSuperview];

    // Change the min size before doing the resizing otherwise it
    // could be a problem.
    [self setMinSize:_originalMinSize];

    // Resize the panel to the height without the accessory view. 
    // This must be done with the special care of not resizing 
    // the heights of the other views.
    addedHeight = accessoryViewFrame.size.height + (_SAVE_PANEL_Y_PAD * 2);
    contentSize = [[self contentView] frame].size;
    contentSize.height -= addedHeight;
    // Resize without modifying topView and bottomView height.
    [_browser setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
    [self setContentSize:contentSize];
    [_browser setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  }
  
  // Resize the panel to its original size.  This resizes freely the
  // heights of the views. NB: minSize *must* come first
  [self setMinSize:_originalMinSize];
  [self setContentSize:_originalSize];
  
  // Set the new accessory view
  _accessoryView = aView;
  
  // If there is a new accessory view, plug it in
  if (_accessoryView != nil) {
    // Make sure the new accessory view behaves  - its height must be fixed
    // and its position relative to the bottom of the superview must not
    // change	- so its position rlative to the top must be changable.
    [_accessoryView setAutoresizingMask:NSViewMaxYMargin
                    | ([_accessoryView autoresizingMask] 
                       & ~(NSViewHeightSizable | NSViewMinYMargin))];  
      
    /* Compute size taken by the new accessory view */
    accessoryViewFrame = [_accessoryView frame];
    addedHeight = accessoryViewFrame.size.height + (_SAVE_PANEL_Y_PAD * 2);
    accessoryWidth = accessoryViewFrame.size.width + (_SAVE_PANEL_X_PAD * 2);

    /* Resize content size accordingly */
    contentSize = _originalSize;
    contentSize.height += addedHeight;
    if (accessoryWidth > contentSize.width) {
      contentSize.width = accessoryWidth;
    }
      
    // Set new content size without resizing heights of topView, bottomView
    // Our views should resize horizontally if needed, but not vertically
    [_browser setAutoresizingMask:NSViewWidthSizable|NSViewMinYMargin];
    [self setContentSize: contentSize];
    // Restore the original autoresizing masks
    [_browser setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];

    /* Compute new min size */
    contentMinSize = _originalMinSize;
    contentMinSize.height += addedHeight;
    // width is more delicate
    tmpRect = NSMakeRect (0, 0, contentMinSize.width, contentMinSize.height);
    tmpRect = [NSWindow contentRectForFrameRect:tmpRect 
                                      styleMask:[self styleMask]];
    if (accessoryWidth > tmpRect.size.width) {
      contentMinSize.width += accessoryWidth - tmpRect.size.width;
    }
    // Set new min size
    [self setMinSize:contentMinSize];

    /*
     * Pack the Views
     */

    /* BottomView is ready */
    bottomFrame = [_bottomView frame];

    /* AccessoryView */
    accessoryViewFrame.origin.x 
      = (contentSize.width - accessoryViewFrame.size.width) / 2;
    accessoryViewFrame.origin.y = NSMaxY (bottomFrame) + _SAVE_PANEL_Y_PAD;
    [_accessoryView setFrameOrigin:accessoryViewFrame.origin];

    /* Add the accessory view */
    [[self contentView] addSubview:_accessoryView];
  }
  [self setFrameUsingName:@"NXTSavePanel"];
}

- (void)_selectCellName:(NSString *)title
{
  NSString           *cellString;
  NSMatrix           *matrix;
  NSComparisonResult  result;
  int                 i, titleLength, cellLength, numberOfCells;

  matrix = [_browser matrixInColumn:[_browser lastColumn]];
  if ([matrix selectedCell]) {
    return;
  }

  titleLength = [title length];
  if (!titleLength) {
    return;
  }

  numberOfCells = [[matrix cells] count];

  for (i = 0; i < numberOfCells; i++) {
    cellString = [[matrix cellAtRow:i column:0] stringValue];
    cellLength = [cellString length];
    if (cellLength != titleLength) {
      continue;
    }
    if ([cellString isEqualToString:title] != NO) {
      [matrix selectCellAtRow:i column:0];
      [matrix scrollCellToVisibleAtRow:i column:0];
      [_okButton setEnabled:YES];
      return;
    }
  }
}

- (void)_selectTextInColumn:(int)column
{
  NSMatrix      *matrix;
  NSBrowserCell *selectedCell;
  BOOL           isLeaf;

  // NSLog(@"_selectTextInColumn:%d", column);

  if (column == -1)
    return;

  matrix = [_browser matrixInColumn:column];
  selectedCell = [matrix selectedCell];
  isLeaf = [selectedCell isLeaf];

  if (_delegateHasSelectionDidChange) {
    [self.delegate panelSelectionDidChange:self];
  }

  if (isLeaf) {
    [[_form cellAtIndex:0] setStringValue:[selectedCell stringValue]];
    [_form selectTextAtIndex:0];
    [_okButton setEnabled:YES];
  }
  else {
    if (_delegateHasDirectoryDidChange) {
      [self.delegate panel:self directoryDidChange:[_browser pathToColumn:column]];
    }

    if ([[[_form cellAtIndex:0] stringValue] length] > 0) {
      [_okButton setEnabled:YES];
      [self _selectCellName:[[_form cellAtIndex:0] stringValue]];
    }
    else {
      [_okButton setEnabled:NO];
    }
  }

  [self _saveDefaultDirectory:[_browser path]];
  [matrix selectCell:selectedCell];
}

- (void)_selectText:(id)sender
{
  [self _selectTextInColumn:[_browser selectedColumn]];
}

- (void)     browser:(NSBrowser*)sender
 createRowsForColumn:(NSInteger)column
            inMatrix:(NSMatrix*)matrix
{
  NSString         *path, *file, *pathAndFile, *extension; 
  NSArray          *files;
  unsigned         i, count, addedRows; 
  BOOL             exists, isDir;
  NSBrowserCell    *cell;
  NSWorkspace      *ws;
  NXTFileManager   *fm;
  NSString         *fileType;
  /* We create lot of objects in this method, so we use a pool */
  NSAutoreleasePool *pool;

  // NSLog(@"browser:createRowsForColumn:inMatrix, NXTSavePanel RC: %lu",
  //       [self retainCount]);

  pool = [NSAutoreleasePool new];
  ws = [NSWorkspace sharedWorkspace];
  fm = [NXTFileManager defaultManager];
  path = [_browser pathToColumn:column];
  files = [fm directoryContentsAtPath:path
                              forPath:nil
                             sortedBy:[fm sortFilesBy]
                           showHidden:[fm isShowHiddenFiles]];

  count = [files count];

  /* If array is empty, just return (nothing to display).  */
  if (count == 0) {
    RELEASE (pool);
    return;
  }

  addedRows = 0;
  for (i = 0; i < count; i++) {
    // Now the real code
    file = [files objectAtIndex:i];
    extension = [file pathExtension];
      
    pathAndFile = [path stringByAppendingPathComponent:file];
    exists = [fm fileExistsAtPath:pathAndFile isDirectory:&isDir];

    /* Note: The initial directory and its parents are always shown, even if
     * it they are file packages or would be rejected by the validator. */
#define HAS_PATH_PREFIX(aPath, otherPath)                               \
    ([aPath isEqualToString:otherPath] ||                               \
     [aPath hasPrefix:[otherPath stringByAppendingString:@"/"]])

    if (exists && (!isDir || !HAS_PATH_PREFIX(_directory, pathAndFile))) {
      if (isDir && !_treatsFilePackagesAsDirectories
          && ([ws isFilePackageAtPath:pathAndFile]
              || [_allowedFileTypes containsObject:extension])) {
        isDir = NO;
      }

      if (_delegateHasShowFilenameFilter) {
        exists = [self.delegate panel:self shouldShowFilename:pathAndFile];
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

      // Modify display attributes and set title of cell
      NSString *fileType = [[fm fileAttributesAtPath:pathAndFile
                                        traverseLink:NO] fileType];
      if ([fileType isEqualToString:NSFileTypeSymbolicLink]) {
        [cell setFont:[NSFont fontWithName:@"Helvetica-Oblique" size:12.0]];
      }

      if (isDir)
        [cell setLeaf:NO];
      else
        [cell setLeaf:YES];

      addedRows++;
    }
  }

  RELEASE(pool);
}

// --- NSForm delegate
- (void)controlTextDidChange:(NSNotification *)aNotification
{
  NSString           *enteredString, *selectedString;
  NSArray            *cells;
  NSMatrix           *matrix;
  NSCell             *selectedCell;
  NSInteger          selectedRow, selectedColumn;
  NSUInteger         numberOfCells;
  NSComparisonResult result;
  NSRange            range;

  enteredString = [[[aNotification userInfo] objectForKey:@"NSFieldEditor"] string];

  // NSLog(@"controlTextDidChange: %@", enteredString);

  if ([enteredString length] == 0) {
    [[_browser matrixInColumn:[_browser lastColumn]] deselectAllCells];
    [_okButton setEnabled:NO];
    NSLog(@"Path set by user: %@", _directory);
    if ([[NSWorkspace sharedWorkspace] isFilePackageAtPath:_directory]) {
      [self _saveDefaultDirectory:[_directory stringByDeletingLastPathComponent]];
    }
    [_browser setPath:_directory];
    return;
  }

  // If the user typed in an absolute path, display it.
  if ([enteredString isAbsolutePath] == YES) {
    [self setDirectory:enteredString];
  }

  selectedColumn = [_browser lastColumn];
  matrix = [_browser matrixInColumn:selectedColumn];
  selectedCell = [matrix selectedCell];
  selectedRow = ([matrix selectedRow] == -1) ? 0 : [matrix selectedRow];
  cells = [matrix cells];

  // NSLog(@"Enetered: `%@`", enteredString);
    
  range.location = 0;
  range.length = [enteredString length];
  numberOfCells = [cells count];
  for (int i = 0; i < numberOfCells; i++) {
    selectedString = [[matrix cellAtRow:i column:0] stringValue];
    // NSLog(@"\tSelected %d: `%@`", i, selectedString);
    if ([selectedString length] < range.length) {
      continue;
    }

    result = [selectedString compare:enteredString options:0 range:range];
    if (result == NSOrderedSame) {
      // NSLog(@"Enetered text `%@` is OrderedDescending -> OrdereSame",
      //       enteredString);
      [matrix deselectAllCells];
      if ([[matrix cellAtRow:i column:0] isLeaf]) {
        [matrix selectCellAtRow:i column:0];
        [matrix scrollCellToVisibleAtRow:i column:0];
        [_okButton setEnabled:YES];
      }
      else {
        [matrix selectCellAtRow:i column:0];
        [matrix scrollCellToVisibleAtRow:i column:0];
        [_browser setLastColumn:selectedColumn];
        [_okButton setEnabled:NO];
      }
      // [_form selectTextAtIndex:0];
      return;
    }
  }

  // Set path to last set by user (click or Enter button press)
  [_browser setPath:_directory];
  [_okButton setEnabled:YES];
}

//
// Methods invoked by button press
//
- (void)_setHomeDirectory:(id)sender
{
  [self setDirectory:NSHomeDirectory()];
}

- (void)_mountMedia:(id)sender
{
  [[OSEMediaManager defaultManager] mountNewRemovableMedia];
}

- (void)_unmountMedia:(id)sender
{
  [[OSEMediaManager defaultManager] unmountAndEjectDeviceAtPath:[self directory]];
}

- (void) _setFileName: (NSString *)filename
{
  [self _selectCellName:filename];
  [[_form cellAtIndex:0] setStringValue:filename];
  [_form selectTextAtIndex:0];
  [_form setNeedsDisplay:YES];
}

- (void)ok:(id)sender
{
  NSMatrix      *matrix;
  NSBrowserCell *selectedCell;
  NSString      *filename;
  BOOL		isDir = NO;
  NSFileManager *_fm = [NSFileManager defaultManager];

  matrix = [_browser matrixInColumn:[_browser lastColumn]];
  selectedCell = [matrix selectedCell];

  if (selectedCell && [selectedCell isLeaf] == NO) {
    [[_form cellAtIndex:0] setStringValue: @""];
    [_browser doClick:matrix];
    [_form selectTextAtIndex:0];
    [_form setNeedsDisplay:YES];
    return;
  }

  ASSIGN (_directory, [_browser pathToColumn:[_browser lastColumn]]);
  filename = [[_form cellAtIndex:0] stringValue];
  if ([filename isAbsolutePath] == NO) {
    filename = [_directory stringByAppendingPathComponent:filename];
  }
  ASSIGN (_fullFileName, [filename stringByStandardizingPath]);

  if (_delegateHasUserEnteredFilename) {
    filename = [self.delegate panel:self userEnteredFilename:_fullFileName
                      confirmed:YES];
    if (!filename) {
      return;
    }
    else if (![_fullFileName isEqual: filename]) {
      ASSIGN (_directory, [filename stringByDeletingLastPathComponent]);
      ASSIGN (_fullFileName, filename);
      [_browser setPath:_fullFileName];
      [self _setFileName:[_fullFileName lastPathComponent]];
    }
  }

  /* Warn user if a wrong extension was entered */
  if (_allowedFileTypes != nil &&
      [_allowedFileTypes indexOfObject:@""] == NSNotFound) {
      NSString *fileType = [_fullFileName pathExtension];
      if ([fileType length] != 0 &&
	  [_allowedFileTypes indexOfObject:fileType] == NSNotFound) {
	  int result;
	  NSString *msgFormat, *butFormat;
	  NSString *altType, *requiredType;

	  requiredType = [self requiredFileType];
	  if ([self allowsOtherFileTypes]) {
            msgFormat = _(@"You have used the extension '.%@'.\n"
                          @"The standard extension is '.%@'.'");
            butFormat = _(@"Use .%@");
            altType = fileType;
          }
	  else {
            msgFormat = _(@"You cannot save this document with extension '.%@'.\n"
                          @"The required extension is '.%@'.");
            butFormat = _(@"Use .%@");
            altType = [fileType stringByAppendingPathExtension:requiredType];
          }

	  result = NXTRunAlertPanel(_(@"Save"),
                                   msgFormat,
                                   [NSString stringWithFormat:butFormat,requiredType],
                                   _(@"Cancel"),
                                   [NSString stringWithFormat:butFormat,altType],
                                   fileType, requiredType);
	  switch (result) {
          case NSAlertDefaultReturn:
            filename = [_fullFileName stringByDeletingPathExtension];
            filename = [filename stringByAppendingPathExtension:requiredType];

            ASSIGN (_fullFileName, filename);
            [_browser setPath:_fullFileName];
            [self _setFileName:[_fullFileName lastPathComponent]];
            break;
          case NSAlertOtherReturn:
            if (altType != fileType) {
              filename = [_fullFileName stringByAppendingPathExtension: requiredType];

              ASSIGN (_fullFileName, filename);
              [_browser setPath:_fullFileName];
              [self _setFileName:[_fullFileName lastPathComponent]];
            }
            break;
          default:
            return;
          }
      }
  }

  filename = [_fullFileName stringByDeletingLastPathComponent];
  if ([_fm fileExistsAtPath:filename isDirectory:&isDir] == NO) {
    int result;

    result = NXTRunAlertPanel(_(@"Save"),
                              _(@"The directory '%@' does not exist."
                                " do you want to create it?"),
                              _(@"Yes"), _(@"No"), nil, filename);

    if (result == NSAlertDefaultReturn) {
      if ([_fm createDirectoryAtPath: filename
               withIntermediateDirectories: YES
                          attributes: nil
                               error: NULL] == NO) {
        NXTRunAlertPanel(_(@"Save"),
                         _(@"The directory '%@' could not be created."),
                         _(@"Dismiss"), nil, nil, filename);
        return;
      }
    }
  }
  else if (isDir == NO) {
    NXTRunAlertPanel(_(@"Save"),
                     _(@"The path '%@' is not a directory."),
                     _(@"Dismiss"), nil, nil, filename);
    return;
  }
  
  if ([_fm fileExistsAtPath:[self filename] isDirectory:NULL]) {
    int result;

    result = NXTRunAlertPanel(_(@"Save"),
                              _(@"The file '%@' in '%@' exists. Replace it?"),
                              _(@"Replace"), _(@"Cancel"), nil,
                              [[self filename] lastPathComponent], _directory);

    if (result != NSAlertDefaultReturn)
      return;
  }

  if (_delegateHasValidNameFilter) {
    if (![self.delegate panel:self isValidFilename:[self filename]]) {
      return;
    }
  }

  [self _saveDefaultDirectory:_directory];

  if (self->_completionHandler == NULL) {
    [NSApp stopModalWithCode:NSOKButton];
  }
  else {
    CALL_BLOCK(self->_completionHandler, NSOKButton);
    Block_release(self->_completionHandler);
    self->_completionHandler = NULL;
  }

  [_okButton setEnabled:NO];
  [self close];
}


- (void)setTitle:(NSString*)title
{
  [super setTitle:@""];
  [_titleField setStringValue:title];
  [_titleField setAutoresizingMask:NSViewMinYMargin];
  [_titleField sizeToFit];
}

- (NSInteger)runModalForDirectory:(NSString*)path
                             file:(NSString*)filename
{
  [self _setupForDirectory:path file:filename];
  if ([filename length] > 0) {
    [_okButton setEnabled:YES];
  }
  if ([self setFrameUsingName:@"NXTSavePanel"] == NO) {
    [self center];
  }
  [self setFrameAutosaveName:@"NXTSavePanel"];
  [self orderFrontRegardless];
  return [NSApp runModalForWindow:self];
}

- (NSInteger)runModalForDirectory:(NSString *)path
                             file:(NSString *)filename
                 relativeToWindow:(NSWindow*)window
{
  [self _setupForDirectory:path file:filename];
  if ([filename length] > 0) {
    [_okButton setEnabled:YES];
  }
  [self setFrameAutosaveName:@"NXTSavePanel"];
  [self orderFrontRegardless];
  return [NSApp runModalForWindow:self
                 relativeToWindow:window];
}

- (void) _windowResized: (NSNotification*)n
{
  [_browser setMaxVisibleColumns:[_browser frame].size.width / [_browser minColumnWidth]];
}


// --- Extentions

- (void)_globalDefaultsChanged:(NSNotification *)aNotif
{
  [_browser loadColumnZero];
  [_browser setPath:_directory];
}

- (void)_saveDefaultDirectory:(NSString*)path
{
  NSString      *standardPath = [path stringByStandardizingPath];
  NSFileManager *fm = [NSFileManager defaultManager];
  BOOL	        isDir;

  if (standardPath &&
      [fm fileExistsAtPath:standardPath isDirectory:&isDir] && isDir) {
    [[NSUserDefaults standardUserDefaults] setObject:standardPath
                                              forKey:@"NSDefaultOpenDirectory"];
    ASSIGN(_directory, standardPath);
  }
}

- (void)_setDefaultDirectory
{
  NSString *path = [[NSUserDefaults standardUserDefaults] 
                     objectForKey:@"NSDefaultOpenDirectory"];

  if (path == nil) {
    ASSIGN(_directory, NSHomeDirectory());
  }
  else {
    ASSIGN(_directory, path);
  }
  // [_browser setPath:_directory];
  // [_browser scrollColumnToVisible:[_browser lastColumn]-1];
}

@end
