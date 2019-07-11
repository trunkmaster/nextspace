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
#import "NXTDefaults.h"

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
#define _SAVE_PANEL_X_PAD	5
#define _SAVE_PANEL_Y_PAD	4

@implementation NXTSavePanel

+ (NXTSavePanel *)savePanel
{
  if (savePanel == nil) {
    savePanel = [[NXTPanelLoader alloc] loadPanelNamed:@"NXTSavePanel"];
  }
  
  return savePanel;
}

// --- NSWindow Overriding
// Catches the mouse clicks on various panel controls to hold focus on "Name:"
// text field.
- (void)sendEvent:(NSEvent*)theEvent
{
  NSView *v;

  if (!_f.visible && [theEvent type] != NSAppKitDefined) {
    NSDebugLLog(@"NSEvent", @"Discard (window not visible) %@", theEvent);
    return;
  }

  if (!_f.cursor_rects_valid) {
    [self resetCursorRects];
  }

  if ([theEvent type] == NSLeftMouseDown) {
    v = [_wv hitTest:[theEvent locationInWindow]];
    NSLog(@"[NXTSavePanel] mouse down on %@", [v className]);
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
    NSString *characters = [theEvent characters];
    unichar   character = 0;

    if ([characters length] > 0) {
      character = [characters characterAtIndex: 0];
    }

    switch (character)
      {
      case NSUpArrowFunctionKey:
        NSLog(@"Selected column: %lu", [_browser selectedColumn]);
        [[_browser matrixInColumn:[_browser selectedColumn]] keyDown:theEvent];
        return;
        break;
      case NSDownArrowFunctionKey:
        // [_form abortEditing];
        // [_form resignFirstResponder];
        // [_browser becomeFirstResponder];
        [[_browser matrixInColumn:[_browser selectedColumn]] keyDown:theEvent];
        // [_browser resignFirstResponder];
        // [_form becomeFirstResponder];
        return;
        break;
      case NSLeftArrowFunctionKey:
      case NSRightArrowFunctionKey:
        // [_form abortEditing];
        if ([[[_form cellAtIndex:0] stringValue] length] > 0) {
          break;
        }
        else {
          [_browser keyDown:theEvent];
          [_browser resignFirstResponder];
          [_form becomeFirstResponder];
        }
        return;
      }
  }

  [super sendEvent:theEvent];
}
// ---

- (void)dealloc
{
  NSLog(@"[NXTSavePanel] -dealloc: %lu", [savePanel retainCount]);
  [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
  // savePanel = nil;
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

  [self setTitle:@"Save"];
  
  [_icon setImage:[[NSApplication sharedApplication] applicationIconImage]];
  [_icon setRefusesFirstResponder:YES];

  [_browser setRefusesFirstResponder:YES];
  [_browser setTag:NSFileHandlingPanelBrowser];
  [_browser setDoubleAction:@selector(performClick:)];
  [_browser setTarget:_okButton];
  [_browser loadColumnZero];

  _showsHiddenFiles = [[NXTFileManager sharedManager] isShowHiddenFiles];
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

  [self setFrameAutosaveName:@"NXTSavePanel"];
  
  /* Used in setMinSize: */
  _originalMinSize = [self minSize];
  /* Used in setContentSize: */
  _originalSize = [[self contentView] frame].size;

  [self setDirectory:NSHomeDirectory()];
}

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
    [_browser setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];
    [self setContentSize: contentSize];
    // Restore the original autoresizing masks
    [_browser setAutoresizingMask: NSViewWidthSizable|NSViewHeightSizable];

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

  NSLog(@"_selectTextInColumn:");

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
    [_form selectTextAtIndex:0];
    [_okButton setEnabled:YES];
  }
  else {
    if (_delegateHasDirectoryDidChange) {
      [_delegate panel:self directoryDidChange:[_browser pathToColumn:column]];
    }

    if ([[[_form cellAtIndex:0] stringValue] length] > 0) {
      [_okButton setEnabled:YES];
      [self _selectCellName:[[_form cellAtIndex:0] stringValue]];
    }
    else {
      [_okButton setEnabled:NO];
    }
  }
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

  NSLog(@"browser:createRowsForColumn:inMatrix, NXTSavePanel RC: %lu", [self retainCount]);

  pool = [NSAutoreleasePool new];
  ws = [NSWorkspace sharedWorkspace];
  fm = [NSFileManager defaultManager];
  path = [_browser pathToColumn:column];
  nxfm = [NXTFileManager sharedManager];
  files = [nxfm directoryContentsAtPath:path
                                forPath:nil
                               sortedBy:[nxfm sortFilesBy]
                             showHidden:[nxfm isShowHiddenFiles]];

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

- (void)setTitle:(NSString*)title
{
  [super setTitle: @""];
  [_titleField setStringValue:title];
  [_titleField sizeToFit];
}

// --- Extentions

- (void)_globalDefaultsChanged:(NSNotification *)aNotif
{
  [_browser loadColumnZero];
  [_browser setPath:_directory];
}

@end
