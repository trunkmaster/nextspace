/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Copyright (C) 2015 Sergii Stoian
// Copyright (C) 2015-2018 Sergii Stoian
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

#import "Viewers/Viewer.h"

#import <SystemKit/OSEFileSystem.h>
#import <SystemKit/OSEFileSystemMonitor.h>
#import <SystemKit/OSEMediaManager.h>

#import "PathIcon.h"
#import "ShelfView.h"
#import "PathView.h"
#import "PathViewScroller.h"

@class NXTIconView, NXTIcon, NXTIconLabel, ProcessManager;

@interface FileViewer : NSObject
{
  NSString *rootPath;
  NSString *displayedPath;
  NSArray *dirContents;
  NSArray *selection;
  BOOL isRootViewer;

  NSFileHandle *dirHandle;

  id<MediaManager> mediaManager;

  OSEFileSystemMonitor *fileSystemMonitor;  // File system events
  NSNumber *monitorPathDescriptor;          // file descriptor for path

  ProcessManager *processManager;

  NSWindow *window;
  id box;
  id scrollView;
  id pathView;
  id containerBox;
  id shelf;
  id bogusWindow;
  id splitView;
  id diskInfo;
  id operationInfo;

  int setEditedStateCount;

  //  PathViewScroller *scroller;
  id<Viewer> viewer;
  NSLock *lock;

  NSTimer *checkTimer;

  // Preferences
  BOOL showHiddenFiles;
  NSInteger sortFilesBy;

  // Dragging
  NXTIconView *draggedSource;
  PathIcon *draggedIcon;
}

- initRootedAtPath:(NSString *)aRootPath viewer:(NSString *)viewerType isRoot:(BOOL)isRoot;

- (BOOL)isRootViewer;
- (BOOL)isRootViewerCopy;
- (NSWindow *)window;
- (NSDictionary *)shelfRepresentation;
- (id<Viewer>)viewer;
- (PathView *)pathView;

//=============================================================================
// Path manipulations
//=============================================================================
- (NSString *)rootPath;
- (NSString *)displayedPath;
- (NSString *)absolutePath;  // rootPath + displayedPath for FolderViewers
- (NSArray *)selection;
- (void)setPathFromAbsolutePath:(NSString *)absolutePath;
- (NSString *)absolutePathFromPath:(NSString *)relPath;
- (NSString *)pathFromAbsolutePath:(NSString *)absolutePath;
- (NSArray *)absolutePathsForPaths:(NSArray *)relPaths;
- (NSArray *)directoryContentsAtPath:(NSString *)relPath forPath:(NSString *)targetPath;

//=============================================================================
// Actions
//=============================================================================
- (NSArray *)checkSelection:(NSArray *)filenames atPath:(NSString *)relativePath;
- (void)validatePath:(NSString **)relativePath selection:(NSArray **)filenames;
- (void)displayPath:(NSString *)relativePath selection:(NSArray *)filenames sender:(id)sender;

- (void)setViewerType:(id)sender;

- (void)updateWindowWidth:(id)sender;

//=============================================================================
- (void)scrollDisplayToRange:(NSRange)aRange;
- (void)slideToPathFromShelfIcon:(NXTIcon *)shelfIcon;

//=============================================================================
// Menu
//=============================================================================

// Menu items -> File
- (void)open:(id)sender;
- (void)openAsFolder:(id)sender;
- (void)newFolder:(id)sender;
// TODO
- (void)duplicate:(id)sender;
- (void)compress:(id)sender;
- (void)destroy:(id)sender;

// Menu items -> Disk
- (void)unmount:(id)sender;
- (void)eject:(id)sender;

//=============================================================================
// Shelf
//=============================================================================
- (void)restoreShelf;

//=============================================================================
// Splitview
//=============================================================================
- (void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize;

- (CGFloat)splitView:(NSSplitView *)sender
    constrainSplitPosition:(CGFloat)proposedPosition
               ofSubviewAt:(NSInteger)offset;

//=============================================================================
// NXTIconLabel delegate
//=============================================================================
- (void)iconLabel:(NXTIconLabel *)anIconLabel
    didChangeStringFrom:(NSString *)oldLabelString
                     to:(NSString *)newLabelString;

//=============================================================================
// Viewer delegate
//=============================================================================
- (BOOL)viewerRenamedCurrentFileTo:(NSString *)newName;

//=============================================================================
// Window
//=============================================================================
- (void)setWindowEdited:(BOOL)onState;

//=============================================================================
// Notifications
//=============================================================================
- (void)shelfResizableStateChanged:(NSNotification *)notif;
- (void)updateDiskInfo;
- (void)updateInfoLabels:(NSNotification *)notif;
- (void)volumeDidMount:(NSNotification *)notif;
- (void)volumeDidUnmount:(NSNotification *)notif;

//=============================================================================
// Dragging
//=============================================================================
// - Dragging source helper
- (NSDragOperation)draggingSourceOperationMaskForPaths:(NSArray *)paths;

@end
