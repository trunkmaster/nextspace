/*
   FileViewer.h
   The workspace manager's file viewer.

   Copyright (C) 2005 Saso Kiselkov

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPXSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import <AppKit/AppKit.h>

#import "Protocols/FileViewer.h"
#import "Protocols/Viewer.h"

#import <NXSystem/NXFileSystem.h>
#import <NXSystem/NXFileSystemMonitor.h>
#import <NXSystem/NXMediaManager.h>

#import "PathIcon.h"
#import "ShelfView.h"
#import "PathView.h"
#import "PathViewScroller.h"

@class NXIconView, NXIcon, NXIconLabel;

@interface FileViewer : NSObject <FileViewer>
{
  NSString *rootPath;
  NSString *displayedPath;
  NSArray  *dirContents;
  NSArray  *selection;
  BOOL     isRootViewer;
  BOOL     isFolderViewer;

  NSFileHandle *dirHandle;

  id<MediaManager> mediaManager;

  NXFileSystemMonitor *fileSystemMonitor;     // File system events
  NSNumber            *monitorPathDescriptor; // file descriptor for path

  NSWindow *window;
  id       box;
  id       scrollView;
  id       pathView;
  id       containerBox;
  id       shelf;
  id       bogusWindow;
  id       splitView;
  id       diskInfo;
  id       operationInfo;

  int setEditedStateCount;

//  PathViewScroller *scroller;
  id <Viewer> viewer;
  NSLock      *lock;
  CGFloat     viewerColumnWidth;
  NSUInteger  viewerColumnCount;

  NSTimer *checkTimer;

  // Preferences
  BOOL      showHiddenFiles;
  NSInteger sortFilesBy;

  // Dragging
  NXIconView *draggedSource;
  PathIcon   *draggedIcon;
  unsigned   draggingSourceMask;
}

- initRootedAtPath:(NSString *)aRootPath
	  asFolder:(BOOL)isFolder
	    isRoot:(BOOL)isRoot;


- (BOOL)isRootViewer;
- (BOOL)isFolderViewer;
- (NSWindow *)window;
- (NSDictionary *)shelfRepresentation;
- (id<Viewer>)viewer;
- (PathView *)pathView;

- (NSString *)rootPath;
- (NSString *)displayedPath;
- (NSString *)absolutePath; // rootPath + displayedPath for FolderViewers
- (NSArray *)selection;
- (void)setPathFromAbsolutePath:(NSString *)absolutePath;
- (NSString *)absolutePathFromPath:(NSString *)relPath;
- (NSString *)pathFromAbsolutePath:(NSString *)absolutePath;
- (NSArray *)absolutePathsForPaths:(NSArray *)relPaths;

- (NSArray *)checkSelection:(NSArray *)filenames
		     atPath:(NSString *)relativePath;
- (void)validatePath:(NSString **)relativePath
           selection:(NSArray **)filenames;
- (void)displayPath:(NSString *)relativePath
	  selection:(NSArray *)filenames
	     sender:(id)sender;

- (void)setViewerType:(id)sender;

- (void)updateWindowWidth:(id)sender;

//=============================================================================
- (void)scrollDisplayToRange:(NSRange)aRange;
- (void)slideToPathFromShelfIcon:(NXIcon *)shelfIcon;

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
// Path View
//=============================================================================

- (void)configurePathView;

- (void)setPathViewPath:(NSString *)relativePath
	      selection:(NSArray *)filenames;

- (void)pathViewIconDragged:sender event:(NSEvent *)ev;

- (NSImage *)pathView:(PathView *)aPathView
   imageForIconAtPath:(NSString *)aPath;

- (NSString *)pathView:(PathView *)aPathView
    labelForIconAtPath:(NSString *)aPath;

- (void)pathView:(PathView *)aPathView
 didChangePathTo:(NSString *)newPath;

- (void)pathViewSyncEmptyColumns;

// --- Scroller delegate
- (void)constrainScroller:(NSScroller *)aScroller;

- (void)trackScroller:(NSScroller *)aScroller;

//=============================================================================
// Splitview
//=============================================================================
- (void)         splitView:(NSSplitView *)sender
 resizeSubviewsWithOldSize:(NSSize)oldSize;

- (CGFloat)     splitView:(NSSplitView *)sender
 constrainSplitPosition:(CGFloat)proposedPosition
	    ofSubviewAt:(NSInteger)offset;

//=============================================================================
// NXIconLabel delegate
//=============================================================================
- (void)   iconLabel:(NXIconLabel *)anIconLabel
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
// - (void)shelfIconSlotWidthChanged:(NSNotification *)notif;
- (void)shelfResizableStateChanged:(NSNotification *)notif;
- (void)updateDiskInfo;
- (void)updateInfoLabels:(NSNotification *)notif;
- (void)volumeDidMount:(NSNotification *)notif;
- (void)volumeDidUnmount:(NSNotification *)notif;

//=============================================================================
// Dragging
//=============================================================================

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
                                              iconView:(NXIconView *)sender;

// - Dragging source helper
- (unsigned int)draggingSourceOperationMaskForPaths:(NSArray *)filenames;
// - Dragging destination helper
- (unsigned int)draggingDestinationMaskForPaths:(NSArray *)paths
				       intoPath:(NSString *)destPath;

/*- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
	       		   icon:(PathIcon *)icon;

- (void)draggingExited:(id <NSDraggingInfo>)sender
		  icon:(PathIcon *)icon;

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
			icon:(PathIcon *)icon;*/

@end
