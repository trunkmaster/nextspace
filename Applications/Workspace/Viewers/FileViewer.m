/*
   FileViewer.m
   The workspace manager's file viewer.

   Copyright (C) 2006-2018 Sergii Stoian
   Copyright (C) 2005 Saso Kiselkov

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

//=============================================================================
// All path manipulations are based on following rules:
//   1. Subviews operate with relative path.
//   2. FileViewer operate with absolute path only on init.
//   3. Only FileViewer holds and returns root absolute path (displayedPath,
//      pathsForIcon).
//   4. Absolute paths hold PathIcon ('paths' ivar) and FileViewer 
//      ('rootPath' ivar)
//=============================================================================

#import <NXAppKit/NXAppKit.h>
#import <NXFoundation/NXDefaults.h>
#import <NXFoundation/NXFileManager.h>

#import <Workspace.h>

#import <stdio.h>
#import "math.h"

#import "Controller.h"
#import "FileViewer.h"
#import "ModuleLoader.h"
#import "Inspectors/Inspector.h"
#import "PathIcon.h"

#import <Operations/ProcessManager.h>
#import <Operations/FileMover.h>
#import <Operations/Sizer.h>

#import <Preferences/Shelf/ShelfPrefs.h>
#import <Preferences/Browser/BrowserPrefs.h>

#define NOTIFICATION_CENTER [NSNotificationCenter defaultCenter]
#define WIN_MIN_HEIGHT 380
#define WIN_DEF_WIDTH 560
#define SPLIT_DEF_WIDTH WIN_DEF_WIDTH-16
#define PATH_VIEW_HEIGHT 76.0

@interface FileViewer (Private)

- (id)dotDirObjectForKey:(NSString *)key;
- (void)useViewer:(id <Viewer>)aViewer;

@end

@implementation FileViewer (Private)

- (id)dotDirObjectForKey:(NSString *)key
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString      *dotDir = [NSString stringWithFormat:@"%@/.dir", rootPath];
  NSDictionary  *dotDirDict;

  if ([fm fileExistsAtPath:dotDir])
    {
      dotDirDict = [NSDictionary dictionaryWithContentsOfFile:dotDir];
      
      return [dotDirDict objectForKey:key];
    }

  return nil;
}

- (void)useViewer:(id <Viewer>)aViewer
{
  if (aViewer)
    {
      ASSIGN(viewer, aViewer);

      [viewer setOwner:self];
      [viewer setRootPath:rootPath];
//      [viewer setVerticalSize:windowVerticalSize];
//      [viewer setColumnWidth:windowVerticalSize];

      [(NSBox *)box setContentView:[viewer view]];
    }
  else
    {
      // Use this for case when aViewer set to 'nil'
      // to decrease retain count on FileViwer.
      // Example [self windowWillClose:]
      [viewer autorelease];
    }
}

@end

@implementation FileViewer

//=============================================================================
// Create and destroy
//=============================================================================

- initRootedAtPath:(NSString *)aRootPath
	  asFolder:(BOOL)isFolder
	    isRoot:(BOOL)isRoot
{
  NXDefaults           *df = [NXDefaults userDefaults];
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  NSString             *relativePath = nil;
  NSSize               iconSize;

  [super init];

  isRootViewer = isRoot;
  isFolderViewer = isFolder;

  setEditedStateCount = 0;

  ASSIGN(rootPath, aRootPath);
  ASSIGN(displayedPath, @"");

  // Initalize NXIconView frame. 
  // NXIconView is a parent class for ShelfView and PathView
  iconSize = NSMakeSize(66, 52); // Size of hilite.tiff 66x52
  [NXIcon setDefaultIconSize:iconSize];
  // Set NXIconView slot size
  if ([df objectForKey:@"IconLabelWidth"])
    {
      [NXIconView setDefaultSlotSize:
                    NSMakeSize([df floatForKey:@"IconLabelWidth"],
                               PATH_VIEW_HEIGHT)];
    }
  else
    {
      [NXIconView setDefaultSlotSize:NSMakeSize(168, PATH_VIEW_HEIGHT)];
    }
  
  // [NSBundle loadNibNamed:@"FileViewer" owner:self];
  // Just to avoid .gorm loading ineterference manually construct 
  // File Viewer window.
  [self awakeFromNib];
  [self configurePathView];

  // Load the viewer
  [self useViewer:[[ModuleLoader shared] preferredViewer]];

  if (isRootViewer || !isFolderViewer)
    {
      [window setTitle:@"File Viewer"];
      if (isRootViewer)
        {
          [window setFrameAutosaveName:@"RootViewer"];
          // try the saved path, then the home directory and as last
          // resort "/"
          (relativePath = [df objectForKey:@"RootViewerPath"]) != nil ||
            (relativePath = NSHomeDirectory()) != nil ||
            (relativePath = @"/");
        }
      else // copy of RootViewer
        {
          NSRect rootFrame = [[[[NSApp delegate] rootViewer] window] frame];
          rootFrame.origin.x += 20;
          rootFrame.origin.y -= 20;
          [window setFrame:rootFrame display:NO];
          relativePath = rootPath;
        }
    }
  else if (isFolderViewer)
    {
      NSString *viewerWindow = [self dotDirObjectForKey:@"ViewerWindow"];

      [window setTitle:
        [NSString stringWithFormat:_(@"File Viewer  \u2014  %@"), rootPath]];
      if (viewerWindow)
	{
	  [window setFrame:NSRectFromString(viewerWindow) display:NO];
	}
      else
	{
	  [window center];
	}
      if ((relativePath = [self dotDirObjectForKey:@"ViewerPath"]) == nil)
        {
          relativePath = @"/";
        }
    }

  // Resize window to just loaded viewer columns and
  // defined window frame (setFrameAutosaveName, setFrame)
  lock = [NSLock new];
  [self updateWindowWidth:nil];

  // Window content adjustments
  [nc addObserver:self
	 selector:@selector(shelfIconSlotWidthChanged:)
	     name:ShelfIconSlotWidthDidChangeNotification
	   object:nil];
  [nc addObserver:self
	 selector:@selector(shelfResizableStateChanged:)
	     name:ShelfResizableStateDidChangeNotification
	   object:nil];
  
  [nc addObserver:self
	 selector:@selector(browserColumnWidthChanged:)
	     name:BrowserViewerColumnWidthDidChangeNotification
	   object:nil];

  // If devider was moved we need to update info labels
  [nc addObserver:self
	 selector:@selector(updateInfoLabels:)
	     name:NXSplitViewDividerDidDraw
	   object:splitView];

  // Media manager and mount, unmount, eject events
  // Full Shelf is not supported in folder viewer
  mediaManager = [[NSApp delegate] mediaManager];
  if (isRootViewer || !isFolderViewer)
    {
      // For updating views (Shelf, PathView, Viewer)
      [nc addObserver:self
             selector:@selector(volumeDidMount:)
        	 name:NXVolumeMounted
               object:mediaManager];
      [nc addObserver:self
             selector:@selector(volumeDidUnmount:)
        	 name:NXVolumeUnmounted
               object:mediaManager];
    }

  // Inspector notifications
  [nc addObserver:self
         selector:@selector(directorySortMethodChanged:)
             name:WMFolderSortMethodDidChangeNotification
           object:nil];
  
  // Start filesystem event monitor
  fileSystemMonitor = [[NSApp delegate] fileSystemMonitor];

  NSLog(@"[FileViewer -init] %@", relativePath);

  // finally display the path
  if (!isRootViewer && !isFolderViewer)
    {
      [self displayPath:[[[NSApp delegate] rootViewer] displayedPath]
              selection:nil
                 sender:self];
    }
  else
    {
      [self displayPath:relativePath selection:nil sender:self];
    }

  // Configure Shelf later after viewer loaded path to make 
  // setNextKeyView working correctly
  [self configureShelf];

  // Make initial placement of disk and operation info labels
  [self updateInfoLabels:nil];

  [window makeKeyAndOrderFront:nil];

  // NXFileSystem notifications
  [nc addObserver:self
         selector:@selector(fileSystemChangedAtPath:)
             name:NXFileSystemChangedAtPath
           object:nil];

  // Global user preferences changes
  [[NSDistributedNotificationCenter notificationCenterForType:NSLocalNotificationCenterType]
    addObserver:self
       selector:@selector(globalUserPreferencesDidChange:)
           name:NXUserDefaultsDidChangeNotification
         object:nil];
  
  // Notifications from BGOperation
 [nc addObserver:self
        selector:@selector(fileOperationDidStart:)
            name:WMOperationDidCreateNotification
          object:nil];
  [nc addObserver:self
	 selector:@selector(fileOperationDidEnd:)
	     name:WMOperationWillDestroyNotification
	   object:nil];
  [nc addObserver:self
	 selector:@selector(fileOperationProcessingFile:)
	     name:WMOperationProcessingFileNotification
	   object:nil];

  return self;
}

- (void)awakeFromNib
{
  unsigned int styleMask;
  //  NSRect       contentRect = NSMakeRect(100, 500, 522, 390);
  NSRect       contentRect = NSMakeRect(100, 500, WIN_DEF_WIDTH, 390);
  NSSize       wSize, sSize;
  NXDefaults   *df = [NXDefaults userDefaults];

  // Create window
  if (isRootViewer)
    {
      styleMask = 
	NSTitledWindowMask | NSMiniaturizableWindowMask 
	| NSResizableWindowMask;
    }
  else
    {
      styleMask = 
	NSTitledWindowMask | NSMiniaturizableWindowMask 
	| NSResizableWindowMask | NSClosableWindowMask;
    }

  window = [[NSWindow alloc] initWithContentRect:contentRect
		     		       styleMask:styleMask
			     		 backing:NSBackingStoreRetained
					   defer:YES];
  [window setReleasedWhenClosed:NO];
  [window setMinSize:NSMakeSize(353, 320)];
  [window setMaxSize:NSMakeSize(10000, 10000)];
  [window setDelegate:self];

  // Spliview
  splitView = [[NXSplitView alloc]
                initWithFrame:NSMakeRect(8,-2,SPLIT_DEF_WIDTH,392)];
  [splitView setAutoresizingMask:(NSViewWidthSizable|NSViewHeightSizable)];
  [self shelfResizableStateChanged:nil];
  //[splitView retain];
  //[splitView removeFromSuperview];

  // Disk info label
  // Frame of info labels will be adjusted in 'updateInfoLabels:' later.
  diskInfo = [[NSTextField alloc] initWithFrame:NSMakeRect(8,312,231,12)];
  [diskInfo setAutoresizingMask:(NSViewMaxXMargin | NSViewMinYMargin
				 | NSViewWidthSizable)];
  [diskInfo setEnabled:NO]; // not editable, not selectable
  [diskInfo setBezeled:NO];
  [diskInfo setBordered:NO];
  [diskInfo setDrawsBackground:NO];
  [diskInfo setRefusesFirstResponder:YES];
  [diskInfo setFont:[NSFont toolTipsFontOfSize:0.0]];
  // [diskInfo retain];
  // [diskInfo removeFromSuperview];
  [[window contentView] addSubview:diskInfo];
  [diskInfo release];

  // Just add label to viewer window. Proccesses will update it.
  operationInfo = [[ProcessManager shared] backInfoLabel];
  [operationInfo setEditable:NO];
  [operationInfo setSelectable:NO];
  [operationInfo setRefusesFirstResponder:YES];
  [[window contentView] addSubview:operationInfo];

  // [bogusWindow release];

  // Shelf
  shelf = [[ShelfView alloc] initWithFrame:NSMakeRect(0,0,SPLIT_DEF_WIDTH,76)];
  [shelf setAutoresizingMask:NSViewWidthSizable];
  [splitView addSubview:shelf];
  // [self configureShelf];

  // Bottom part of split view
  containerBox = [[NSBox alloc] 
                   initWithFrame:NSMakeRect(0,0,SPLIT_DEF_WIDTH,310)];
  [containerBox setContentViewMargins:NSMakeSize(0,0)];
  [containerBox setAutoresizingMask:(NSViewWidthSizable|NSViewHeightSizable)];
  [containerBox setTitlePosition:NSNoTitle];
  [containerBox setBorderType:NSNoBorder];
  [splitView addSubview:containerBox];
  [containerBox release];

  // Path view enclosed into scroll view
  scrollView = [[NSScrollView alloc] 
                 initWithFrame:NSMakeRect(0,212,SPLIT_DEF_WIDTH,98)];
  [scrollView setBorderType:NSBezelBorder];
  [scrollView setAutoresizingMask:(NSViewWidthSizable 
				   |NSViewMaxXMargin|NSViewMinYMargin)];

  pathView = [[PathView alloc] 
               initWithFrame:NSMakeRect(0,0,SPLIT_DEF_WIDTH-4,98)];
  [pathView setAutoresizingMask:0];
  [scrollView setDocumentView:pathView];
  [pathView release];
  [containerBox addSubview:scrollView];
  [scrollView release];
  // [self configurePathView];

  // Box to place viewers
  box = [[NSBox alloc] initWithFrame:NSMakeRect(0,0,SPLIT_DEF_WIDTH,206)];
  [box setContentViewMargins:NSMakeSize(0,0)];
  [box setAutoresizingMask:(NSViewWidthSizable|NSViewHeightSizable)];
  [box setBorderType:NSNoBorder];
  [box setTitlePosition:NSNoTitle];
  [containerBox addSubview:box];
  [box release];

  [[window contentView] addSubview:splitView];
  [splitView release];
  [splitView setDelegate:self];

  {
    NXDefaults *df = [NXDefaults userDefaults];
    NSRect     shelfFrame = [shelf frame];
    NSRect     pathFrame = [[pathView enclosingScrollView] frame];
    NSSize     windowMinSize = [window minSize];
    CGFloat    shelfHeight = 0.0;
    
    if (isFolderViewer)
      {
        shelfHeight = [[self dotDirObjectForKey:@"ShelfSize"] floatValue];
      }
    else
      {
        shelfHeight = [df floatForKey:@"RootViewerShelfSize"];
      }
    
    if (shelfHeight > 0.0)
      {
        shelfFrame.size.height = shelfHeight;
        [shelf setFrame:shelfFrame];
      }

    windowMinSize.height =
      shelfFrame.size.height + pathFrame.size.height + 200;
    [window setMinSize:windowMinSize];
  }
}

- (void)dealloc
{
  NXDefaults    *df = [NXDefaults userDefaults];
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString      *file = [selection objectAtIndex:0];

  NSLog(@"FileViewer %@: dealloc", rootPath);

  [[NSNotificationCenter defaultCenter] removeObserver:self];

  if (isRootViewer)
    {
      [df setObject:[displayedPath stringByAppendingPathComponent:file]
	     forKey:@"RootViewerPath"];
      [df setObject:[shelf storableRepresentation]
	     forKey:@"RootShelfContents"];
      [df setFloat:[shelf frame].size.height 
	    forKey:@"RootViewerShelfSize"];
      [df synchronize];
    }
  else if (isFolderViewer && [fm isWritableFileAtPath:rootPath])
    {
      NSMutableDictionary *fvdf = [NSMutableDictionary new];

      [fvdf setObject:[displayedPath stringByAppendingPathComponent:file]
               forKey:@"ViewerPath"];
      [fvdf setObject:NSStringFromRect([window frame])
	       forKey:@"ViewerWindow"];
      [fvdf setObject:[shelf storableRepresentation] 
	       forKey:@"ShelfContents"];
      [fvdf setObject:[NSNumber numberWithInt:[shelf frame].size.height]
	       forKey:@"ShelfSize"];
      [fvdf writeToFile:[rootPath stringByAppendingPathComponent:@".dir"] 
	     atomically:YES];
    }

  TEST_RELEASE(window);
  TEST_RELEASE(rootPath);
  TEST_RELEASE(displayedPath);
  TEST_RELEASE(dirContents);
  TEST_RELEASE(selection);

  // Processes holds list of labels for FileViewers.
  // This message removes local copy of label from Processes' list
  [[ProcessManager shared] releaseBackInfoLabel:operationInfo];
  TEST_RELEASE(lock);

  NSLog(@"FileViewer %@: dealloc END", rootPath);
  
  [super dealloc];
}

//=============================================================================
// Accessories
//=============================================================================

- (BOOL)isRootViewer
{
  return isRootViewer;
}

- (BOOL)isFolderViewer
{
  return isFolderViewer;
}

- (NSWindow *)window
{
  return window;
}

- (NSDictionary *)shelfRepresentation
{
  return [shelf storableRepresentation];
}

// --- Path manipulations
// displayedPath - relative path which displayed in PathView and Viewer
// relativePath == displayedPath == path
// absolutePath - absolute file system path starting from root of file system
// rootPath - static absolute path of viewer.

- (NSString *)rootPath
{
  return rootPath;
}

- (NSString *)displayedPath
{
  return displayedPath;
}

- (NSString *)absolutePath
{
  if (isRootViewer)
    {
      return displayedPath;
    }

  return [rootPath stringByAppendingPathComponent:displayedPath];
}

- (NSArray *)selection
{
  return selection;
}

- (void)setPathFromAbsolutePath:(NSString *)absolutePath
{
  NSString *pathType, *appName;
  NSString *filename;

  [(NSWorkspace *)[NSApp delegate] getInfoForFile:absolutePath
                                      application:&appName
                                             type:&pathType];
  
  if ([pathType isEqualToString:NSDirectoryFileType] ||
      [pathType isEqualToString:NSFilesystemFileType])
    {
      ASSIGN(displayedPath, [self pathFromAbsolutePath:absolutePath]);
      ASSIGN(selection, nil);
    }
  else
    {
      // Set file selection ivar
      filename = [absolutePath lastPathComponent];
      ASSIGN(selection, [NSArray arrayWithObject:filename]);
      // Set path
      absolutePath = [absolutePath stringByDeletingLastPathComponent];
      ASSIGN(displayedPath, [self pathFromAbsolutePath:absolutePath]);
    }
  NSLog(@"=== displayPath now: %@ (%@)", displayedPath, selection);
}

- (NSString *)absolutePathFromPath:(NSString *)relPath
{
  if (isRootViewer)
    {
      return relPath;
    }

  // TODO: check if 'relPath' already contains absolute path

  return [rootPath stringByAppendingPathComponent:relPath];
}

- (NSString *)pathFromAbsolutePath:(NSString *)absolutePath
{
  NSString   *path;
  NSString   *relPath;
  NSUInteger length;

  if (isRootViewer)
    {
      return absolutePath;
    }

  length = [rootPath length];
  path = [absolutePath substringToIndex:length];
  if (![rootPath isEqualToString:path])
    {
      NSLog(@"[FileViewer-pathFromAbsolutePath] provided path %@ is not absloute in %@!",
	    absolutePath, rootPath);
      return absolutePath;
    }

  path = [absolutePath substringFromIndex:length];
  if ([path length] <= 1)
    {
      return @"/";
    }

  return path;
}

- (NSArray *)absolutePathsForPaths:(NSArray *)relPaths
{
  NSMutableArray *absPaths = [NSMutableArray new];
  NSEnumerator   *e = [relPaths objectEnumerator];
  NSString       *relPath;

//  NSLog(@"[FileViewer] relative paths: %@", relPaths);

  while ((relPath = [e nextObject]))
    {
      [absPaths addObject:[self absolutePathFromPath:relPath]];
    }

//  NSLog(@"[FileViewer] absolute paths: %@", absPaths);

  return (NSArray *)absPaths;
}

- (NSArray *)directoryContentsAtPath:(NSString *)relPath
                             forPath:(NSString *)targetPath
{
  NXFileManager *xfm = [NXFileManager sharedManager];
  NSString      *path = [rootPath stringByAppendingPathComponent:relPath];
  NSDictionary  *folderDefaults;
  
  // Get sorted directory contents
  if ((folderDefaults = [[NXDefaults userDefaults] objectForKey:path]) != nil)
    {
      sortFilesBy = [[folderDefaults objectForKey:@"SortBy"] intValue];
    }
  else
    {
      sortFilesBy = [xfm sortFilesBy];
    }

  showHiddenFiles = [xfm isShowHiddenFiles];
  
  return [xfm directoryContentsAtPath:path
                              forPath:targetPath
                             sortedBy:sortFilesBy
                           showHidden:showHiddenFiles];
}

//=============================================================================
// Actions
//=============================================================================

- (NSArray *)checkSelection:(NSArray *)filenames
		     atPath:(NSString *)relativePath
{
  NSFileManager  *fm = [NSFileManager defaultManager];
  NSMutableArray *files = [NSMutableArray array];
  NSEnumerator   *e = [filenames objectEnumerator];
  NSString       *fullPath;
  NSString       *fileName;
  NSString       *filePath;

  fullPath = [rootPath stringByAppendingPathComponent:relativePath];
  while ((fileName = [e nextObject]))
    {
      filePath = [fullPath stringByAppendingPathComponent:fileName];
      if ([fm fileExistsAtPath:filePath] &&
          [fm isReadableFileAtPath:filePath])
	{
	  [files addObject:fileName];
	}
    }

  if ([files count] == 0)
    {
      return nil;
    }

  return [NSArray arrayWithArray:files];
}

- (void)validatePath:(NSString **)relativePath
           selection:(NSArray **)filenames
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString      *path;
  NSString      *fullPath;
  BOOL          isDir;
  NSString      *fileType, *appName;

  NSDebugLLog(@"FileViewer", @"Validate path %@ %@", *relativePath, *filenames);

  path = *relativePath;

  // Check if displayed path still exists. If not, strip down by one directory
  // and check recursively. Finaly if root path is not valid anymore, close
  // the viewer.
  // It should work even if one of internal component invalidated (renamed,
  // moved, deleted, permission changed).
  fullPath = [self absolutePathFromPath:path];
  // Non-readable and non-executable path components left in place for
  // the ability to view attributes and permissions in the Inspector.
  while (![fm fileExistsAtPath:fullPath isDirectory:&isDir])
    {
      if ([path isEqualToString:@"/"])
	{
          if (!isRootViewer)
            {
              ASSIGN(*filenames, nil);
              ASSIGN(*relativePath, nil);
              [window close];
            }
	  return;
	}
      path = [path stringByDeletingLastPathComponent];
      fullPath = [rootPath stringByAppendingPathComponent:path];
      ASSIGN(*filenames, nil);
      NSLog(@"Stripped down to %@", path);
    }
  
  // If 'filenames' is empty, check if 'relativePath' is path with
  // filename in it. If so, move filename from path to 'filenames' array.
  if ((!filenames || [*filenames count] == 0) &&
      ![path isEqualToString:@"/"])
    {
      [[NSApp delegate] getInfoForFile:fullPath
                           application:&appName
                                  type:&fileType];
      if (![fileType isEqualToString:NSDirectoryFileType] &&
          ![fileType isEqualToString:NSFilesystemFileType])
        {
          *filenames = [NSArray arrayWithObject:[path lastPathComponent]];
          path = [path stringByDeletingLastPathComponent];
        }
    }
  else
    {
      // *filenames = [self checkSelection:*filenames atPath:path];;
    }
  
  *relativePath = path;
}

// Method called by FileViewer subviews (Shelf, PathView, Viewer)
// It's a dispatch method: set path to all of its subviews.
- (void)displayPath:(NSString *)relativePath
	  selection:(NSArray *)filenames
	     sender:(id)sender
{
  int      numSelection = 0;
  NSString *oldDisplayedPath = [displayedPath copy];
  NSString *fullPath;
  BOOL     pathIsReadable;

  [self setWindowEdited:YES];

  if ([relativePath isEqualToString:@""])
    {
      relativePath = @"/";
    }

  // check parameters
  [self validatePath:&relativePath selection:&filenames];
  if (relativePath == nil)
    { // Bad news: rootPath disappeared
      return;
    }
  
  // check the shelf contents as well
  [self checkShelfContentsExist];

  fullPath = [rootPath stringByAppendingPathComponent:relativePath];
  
  NSDebugLLog(@"FileViewer", @"displayPath:%@ selection:%@",
              relativePath, filenames);

  ASSIGN(displayedPath, relativePath);
  ASSIGN(dirContents, [[NSFileManager defaultManager]
                        directoryContentsAtPath:fullPath]);
  ASSIGN(selection, filenames);

  // Viewer
  if (viewer && sender != viewer)
    {
      [viewer displayPath:displayedPath selection:selection];
    }

  // Path View
  if (pathView)
    {
      [self setPathViewPath:displayedPath selection:selection];
      [self pathViewSyncEmptyColumns];
    }

  [viewer becomeFirstResponder];

  // Window
  [window setMiniwindowImage:[[NSApp delegate] iconForFile:fullPath]];
  [window setMiniwindowTitle:[rootPath lastPathComponent]];

  // Disk info label
  [self updateDiskInfo];

  // Update Inspector
  if ([window isMainWindow] == YES)
    {
      Inspector *inspector = [(Controller *)[NSApp delegate] inspectorPanel];
      if (inspector != nil)
        {
          [inspector revert:self];
        }
    }

  // FileSystemMonitor
  // TODO:
  // Even if path is not changed attributes of selected directory may be
  // changed. For example, from non-readable to readable.
  if (![oldDisplayedPath isEqualToString:displayedPath])
    {
      NSString *pathToMonitor=nil, *pathToUnmonitor=nil;
      if (isFolderViewer)
        {
          if (oldDisplayedPath && ![oldDisplayedPath isEqualToString:@""])
            {
              pathToUnmonitor =
                [rootPath stringByAppendingPathComponent:oldDisplayedPath];
            }
          pathToMonitor = [rootPath stringByAppendingPathComponent:displayedPath];
        }
      else
        {
          if (oldDisplayedPath && ![oldDisplayedPath isEqualToString:@""])
            {
              pathToUnmonitor = oldDisplayedPath;
            }
          pathToMonitor = displayedPath;
        }

      // if (pathToUnmonitor != nil &&
      //     [[NSFileManager defaultManager] isReadableFileAtPath:pathToUnmonitor])
      if (pathToUnmonitor != nil)
        {
          [fileSystemMonitor removePath:pathToUnmonitor];
        }
  
      // if (pathToMonitor != nil &&
      //     [[NSFileManager defaultManager] isReadableFileAtPath:pathToMonitor])
      if (pathToMonitor != nil)
        {
          [fileSystemMonitor addPath:pathToMonitor];
        }
    }
  
  [self setWindowEdited:NO];
}

// Updating window width called in 2 cases:
//   1. User has changed size of a window. Actions:
//      - window add/remove column in viewer.
//   2. User has changed column (browser) width. Actions:
//      - ask viewer for width of column and column count
//      - window adopt its width without changing columns count in viewer
#define WINDOW_BORDER_WIDTH   1 // window border that drawn by window manager
#define WINDOW_CONTENT_OFFSET 8 // side space between viewer and window edge
#define SUNKEN_FRAME_WIDTH    2 // size of viewer sunken frame
#define WINDOW_INNER_OFFSET   ((WINDOW_BORDER_WIDTH + WINDOW_CONTENT_OFFSET + SUNKEN_FRAME_WIDTH) * 2)
- (void)updateWindowWidth:(id)sender
{
  NSRect       frame;
  NSScrollView *sv;
  NSSize       s, windowMinSize;
  NSScroller   *scroller;
  CGFloat      sValue;

  // Prevent recursive calling
  // Recursive calls may be caused by changing column width via preferences
  if (!lock || [lock tryLock] == NO)
    {
      NSLog(@"LOCK FAILED! Going out...");
      return;
    }

  NSLog(@"[FileViewer] >>> updateWindowWidth");

  frame = [window frame];

  // --- Viewer
  // Always set column width. It seems that NSBrowser recalculates column count
  // on resizing. In the event of changed column width window frame is set in
  // code above ([window setFrame:display]) but we dont want to recalculate
  // column width and column count.
  // THINK: Do we need to store ivars for Viewer parameters?
  viewerColumnWidth = [viewer columnWidth];
  viewerColumnCount =
    roundf((frame.size.width - WINDOW_INNER_OFFSET) / viewerColumnWidth);
  [viewer setColumnCount:viewerColumnCount];
  [viewer setColumnWidth:viewerColumnWidth];
  NSLog(@"[FileViewer updateWindowWidth]: column count: %lu (width = %.0f)",
        viewerColumnCount, viewerColumnWidth);

  windowMinSize = NSMakeSize((2 * viewerColumnWidth) + WINDOW_INNER_OFFSET,
                             WIN_MIN_HEIGHT);

  if (sender == window)
    {
      [window setMinSize:windowMinSize];
      [window setResizeIncrements:NSMakeSize(viewerColumnWidth, 1)];
      return;
    }

  // Remember scroller value
  scroller = [[pathView enclosingScrollView] horizontalScroller];
  sValue = [scroller floatValue];

  // --- Resize window
  NSLog(@"[FileViewer] window width: %f", frame.size.width);
  frame.size.width = (viewerColumnCount * viewerColumnWidth) + WINDOW_INNER_OFFSET;
  [window setMinSize:windowMinSize];
  [window setResizeIncrements:NSMakeSize(viewerColumnWidth, 1)];
  [window setFrame:frame display:NO];

  // --- PathView scroller
  sv = [pathView enclosingScrollView];
  if ([sv lineScroll] != viewerColumnWidth)
    {
      [sv setLineScroll:viewerColumnWidth];
    }
  // Set scroller value after window resizing (GNUstep bug?)
  [scroller setFloatValue:sValue];
  [self constrainScroller:scroller];

  // PathView icon slot size
  s = [pathView slotSize];
  if (s.width != viewerColumnWidth)
    {
      s.width = viewerColumnWidth;
      [pathView setSlotSize:s];
    }

  NSLog(@"[FileViewer] <<< updateWindowWidth");

  [lock unlock];
}

- (BOOL)renameCurrentFileTo:(NSString *)newName
	       updateViewer:(BOOL)updateViewer
{
  NSFileManager *fm = [NSFileManager defaultManager];
  BOOL          isDir;
  NSString      *oldFullPath = nil;
  NSString      *newFullPath = nil;
  NSString      *oldFileName = nil;
  NSString      *newPath = nil;

  if (selection && [selection count] != 1)
    {
      [NSException raise:NSInternalInconsistencyException
		  format:@"Attempt to change the " \
		  @"filename while multiple files are selected"];
    }

//  NSLog(@"Rename selection: %@", selection);

  if ([selection count]) // It's a file
    {
      NSString *prefix;

      prefix = [self absolutePath];
      oldFileName = [selection objectAtIndex:0];
      oldFullPath = [prefix stringByAppendingPathComponent:oldFileName];
      newFullPath = [prefix stringByAppendingPathComponent:newName];
      newPath = [newFullPath stringByDeletingLastPathComponent];
    }
  else // It's a directory
    {
      oldFullPath = [self absolutePath];
      newFullPath = [[oldFullPath stringByDeletingLastPathComponent]
	stringByAppendingPathComponent:newName];
      newPath = newFullPath;
    }

  if ([fm fileExistsAtPath:newFullPath isDirectory:&isDir])
    {
      NSString *alreadyExists;

      if (isDir)
	{
	  alreadyExists = [NSString stringWithFormat: 
	    @"Directory '%@' already exists.\n" 
	    @"Do you want to replace existing directory?", newName];
	}
      else
	{
	  alreadyExists = [NSString stringWithFormat: 
	    @"File '%@' already exists.\n" 
	    @"Do you want to replace existing file?", newName];
	}

      switch (NSRunAlertPanel(_(@"Rename"), alreadyExists,
			      _(@"Cancel"), _(@"Replace"), nil))
	{
	case NSAlertDefaultReturn: // Cancel
	  return NO;
	  break;
	case NSAlertAlternateReturn: // Replace
	  break;
	}
    }

//  NSLog(@"Rename from %@ to %@", oldFullPath, newFullPath);

  if (rename([oldFullPath cString], [newFullPath cString]) == -1)
    {
      NSRunAlertPanel(_(@"Rename"),
		      [NSString stringWithFormat:_(@"Couldn't rename %s"),
		      strerror(errno)],
		      nil, nil, nil);
      
      return NO;
    }

  if (updateViewer)
    {
      [viewer currentSelectionRenamedTo:[self pathFromAbsolutePath:newFullPath]];
      [self displayPath:[self pathFromAbsolutePath:newFullPath]
              selection:nil
                 sender:self];
    }

  return YES;
}

//=============================================================================
- (void)scrollDisplayToRange:(NSRange)aRange
{
  // TODO
}

//=============================================================================
// Shelf
//=============================================================================

- (void)configureShelf
{
  NXDefaults   *df = [NXDefaults userDefaults];
  NSDictionary *shelfRep = nil;
  NSArray      *paths = nil;
  PathIcon     *icon = nil;

  [self shelfIconSlotWidthChanged:nil];
  
  [shelf setTarget:self];
  [shelf setDelegate:self];
  [shelf setAction:@selector(shelfIconClicked:)];
  [shelf setDoubleAction:@selector(shelfIconDoubleClicked:)];
  [shelf setDragAction:@selector(shelfIconDragged:event:)];
  [shelf 
    registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];

  if (isRootViewer)
    {
      shelfRep = [df objectForKey:@"RootShelfContents"];
      if (!shelfRep || [shelfRep count] == 0)
	{
	  shelfRep = nil;
	  paths = [NSArray arrayWithObject:NSHomeDirectory()];
	}
    }
  else if (isFolderViewer)
    {
      shelfRep = [self dotDirObjectForKey:@"ShelfContents"];
      if (!shelfRep || [shelfRep count] == 0)
	{
	  shelfRep = nil;
	  paths = [NSArray arrayWithObject:rootPath];
	}
    }
  else // Copy of RootViewer
    {
      // ...get current shelf rep of RootViewer
      shelfRep = [[[NSApp delegate] rootViewer] shelfRepresentation];
    }

  if (shelfRep)
    {
      [shelf reconstructFromRepresentation:shelfRep];
    }
  else
    {
      icon = [self shelf:shelf createIconForPaths:paths];
      [shelf putIcon:icon intoSlot:NXMakeIconSlot(0,0)];
    }

  [[shelf icons] makeObjectsPerformSelector:@selector(setDelegate:)
                                 withObject:self];

  [self checkShelfContentsExist];
  [self shelfAddMountedRemovableMedia];
}

- (void)checkShelfContentsExist
{
  NSEnumerator  *e;
  NSArray       *icons;
  PathIcon      *icon;
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString      *path;

  NSDebugLLog(@"FileViewer", @">>>>>>>>> checkShelfContentsExist");

  icons = [shelf icons];
  e = [icons objectEnumerator];
  while ((icon = [e nextObject]) != nil)
    {
      path = [[icon paths] objectAtIndex:0];
      if (![fm fileExistsAtPath:path])
	{
	  NSLog(@"Shelf element %@ doesn't exist.", path);
	  [shelf removeIcon:icon];
	}
    }
}

- (void)shelfAddMountedRemovableMedia
{
  NSArray        *mountPoints = [mediaManager mountedRemovableMedia];
  NSEnumerator   *e = [mountPoints objectEnumerator];
  NSString       *mp;
  NSDictionary   *info;
  NSNotification *notif;

  while ((mp = [e nextObject]) != nil)
    {
      info = [NSDictionary dictionaryWithObject:mp forKey:@"MountPoint"];
      notif = [NSNotification notificationWithName:NXVolumeMounted
                                            object:mediaManager
                                          userInfo:info];
      [self volumeDidMount:notif];
    }
}

- (void)shelfIconClicked:sender
{
  PathIcon *selectedIcon = [[sender selectedIcons] anyObject];
  NSString *path = [[selectedIcon paths] objectAtIndex:0];
  NSArray  *filenames = nil;
  NSString *fmFileType = nil;
  NSString *wmFileType = nil;
  NSString *appName = nil;

  NSLog(@"FileViewer: Shelf icon CLICKED! %@", path);

  if (![[NXDefaults userDefaults] boolForKey:@"DontSlideIconsFromShelf"])
    {
      NSWorkspace *ws = [NSWorkspace sharedWorkspace];
      unsigned    offset;
      NSPoint     startPoint, endPoint;
      NSView      *view = [pathView enclosingScrollView];
      NSSize      svSize = [view frame].size;
      unsigned    numPathComponents;
      NSImage     *icon = [selectedIcon iconImage];
      NSSize      iconSize = [icon size];

      numPathComponents = [[path pathComponents] count];
      if (numPathComponents >= viewerColumnCount)
	{
	  offset = viewerColumnCount;
	}
      else
	{
	  offset = numPathComponents;
	}

      endPoint = NSMakePoint((svSize.width / viewerColumnCount) *
			     (offset - 0.5) - iconSize.width / 2,
			     svSize.height * 0.55);
      endPoint = [view convertPoint: endPoint toView: nil];
      endPoint = [window convertBaseToScreen: endPoint];

      startPoint = NSMakePoint([selectedIcon iconSize].width / 2 - 
			       iconSize.width / 2,
			       [selectedIcon iconSize].height / 2 - 
			       iconSize.height / 2);
      startPoint = [selectedIcon convertPoint:startPoint toView:nil];
      startPoint = [window convertBaseToScreen:startPoint];

      [ws slideImage:icon from:startPoint to:endPoint];
    }
  else
    {
      [sender display];
    }

  // FilesystemInterface accepts relative paths so made 'path' variable
  // contents as relative path
  if (isFolderViewer)
    {
      if ([path isEqualToString:rootPath])
	{
	  path = @"/";
	}
      else
	{
	  path = [path substringFromIndex:[rootPath length]];
	}
    }

  // For wrappers (bundle, etc.). fileTypeAtPath returns NSPlainFileType
  fmFileType = [[[NSFileManager defaultManager] fileAttributesAtPath:path
                                                        traverseLink:NO]
                 fileType];
  if (![fmFileType isEqualToString:NSFileTypeDirectory])
    {
      [(NSWorkspace *)[NSApp delegate] getInfoForFile:path
                                          application:&appName
                                                 type:&wmFileType];
      if (![wmFileType isEqualToString:NSDirectoryFileType]
          && ![fmFileType isEqualToString:NSFilesystemFileType])
        {
          filenames = [NSArray arrayWithObject:[path lastPathComponent]];
          path = [path stringByDeletingLastPathComponent];
        }
    }

  NSLog(@"PATH[%@] -> %@", wmFileType, path);
  [self displayPath:path selection:filenames sender:shelf];
  [shelf selectIcons:nil]; // deselect all selected icons
}

- (void)shelfIconDoubleClicked:sender
{
  PathIcon *selectedIcon = [[sender selectedIcons] anyObject];
  NSString *path = [[selectedIcon paths] objectAtIndex:0];

  // if (![path isEqualToString:rootPath])
  //   {
      [selectedIcon setDimmed:YES];

      [self open:selectedIcon];
    // }

  [shelf selectIcons:nil];
  [selectedIcon setDimmed:NO];
}

- (NSArray *)shelf:(ShelfView *)aShelf
      pathsForDrag:(id <NSDraggingInfo>)draggingInfo
{
  NSArray *paths;

  paths = [[draggingInfo draggingPasteboard]
            propertyListForType:NSFilenamesPboardType];

  if (![paths isKindOfClass:[NSArray class]] || [paths count] != 1)
    {
      return nil;
    }

  return paths;
}

- (PathIcon *)shelf:(ShelfView *)aShelf
 createIconForPaths:(NSArray *)paths
{
  PathIcon *icon;
  NSString *path;
  NSString *relativePath;

  if ((path = [paths objectAtIndex:0]) == nil)
    {
      return nil;
    }

  // make sure its a subpath of our current root path
  if ([path rangeOfString:rootPath].location != 0)
    {
      return nil;
    }
  relativePath = [path substringFromIndex:[rootPath length]];

  icon = [[PathIcon new] autorelease];
  if ([paths count] == 1)
    {
      [icon setIconImage:[[NSApp delegate] iconForFile:path]];
    }
  [icon setPaths:paths];
  [icon setDelegate:self];
  [icon setDoubleClickPassesClick:NO];
  [icon setEditable:NO];
  [[icon label] setNextKeyView:[viewer view]];

  return icon;
}

- (void) shelf:(ShelfView *)aShelf
 didAcceptIcon:(PathIcon *)anIcon
	inDrag:(id <NSDraggingInfo>)draggingInfo
{
  // NSLog(@"[FileViewer] didAcceptIcon in shelf");
  if ([[anIcon paths] count] == 1)
    {
      [anIcon 
        registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
    }
  [anIcon setDelegate:self];
}

- (void)shelfIconDragged:sender event:(NSEvent *)ev
{
  NSDictionary *iconInfo;
  NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSDragPboard];
  NSArray      *pbTypes = nil;
  NSRect       iconFrame = [sender frame];
  NSPoint      iconLocation = iconFrame.origin;
  NXIconSlot   iconSlot = [shelf slotForIcon:sender];

  NSLog(@"FileViewer:shelfIconDragged");

  draggedSource = shelf;
  draggedIcon = sender;

  [draggedIcon setSelected:NO];

  iconLocation.x += 8;
  iconLocation.y += iconFrame.size.width - 16;

  if (iconSlot.x == 0 && iconSlot.y == 0)
    {
      draggingSourceMask = (NSDragOperationMove|NSDragOperationCopy);
    }
  else
    {
      draggingSourceMask = (NSDragOperationMove|NSDragOperationCopy);
      [draggedIcon setDimmed:YES];
      [shelf removeIcon:draggedIcon];
    }

  // Pasteboard info for 'draggedIcon'
  pbTypes = [NSArray arrayWithObjects:NSFilenamesPboardType,NSGeneralPboardType,
                     nil];
  [pb declareTypes:pbTypes owner:nil];
  [pb setPropertyList:[draggedIcon paths] forType:NSFilenamesPboardType];
  if ((iconInfo = [draggedIcon info]) != nil)
    {
      [pb setPropertyList:iconInfo forType:NSGeneralPboardType];
    }

  [shelf dragImage:[draggedIcon iconImage]
		at:iconLocation
	    offset:NSZeroSize
	     event:ev
	pasteboard:pb
	    source:draggedSource
	 slideBack:NO];
}

// --- Notifications

- (void)shelfIconSlotWidthChanged:(NSNotification *)notif
{
  NXDefaults *df = [NXDefaults userDefaults];
  NSSize     slotSize = [shelf slotSize];
  CGFloat    width = 0.0;

  if ((width = [df floatForKey:ShelfIconSlotWidth]) > 0.0)
    {
      slotSize.width = width;
    }
  else
    {
      slotSize.width = SHELF_LABEL_WIDTH;
    }
  [shelf setSlotSize:slotSize];
}

- (void)shelfResizableStateChanged:(NSNotification *)notif
{
  NSInteger rState =
    [[NXDefaults userDefaults] integerForKey:@"ShelfIsResizable"];

  // NSLog(@"[FileViewer] shelfResizableStateChanged");

    if (rState == 0)
    [splitView setResizableState:0];
  else
    [splitView setResizableState:1];
}

//=============================================================================
// PathView
//=============================================================================

- (void)configurePathView
{
  PathViewScroller *scroller;
  NSScrollView     *sv;

  sv = [pathView enclosingScrollView];
  scroller = [[PathViewScroller new] autorelease];
  [scroller setDelegate:self];
  [sv setHorizontalScroller:scroller];
  [sv setHasHorizontalScroller:YES];
  [sv setBackgroundColor:[NSColor windowBackgroundColor]];

  [pathView setTarget:self];
  [pathView setDelegate:self];
  [pathView setDragAction:@selector(pathViewIconDragged:event:)];
  [pathView setDoubleAction:@selector(open:)];
  [pathView setIconDragTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
}

- (void)setPathViewPath:(NSString *)relativePath
	      selection:(NSArray *)filenames
{
  PathIcon    *pathIcon;
  NXIconLabel *pathIconLabel;

  [pathView displayDirectory:relativePath andFiles:filenames];
  [pathView scrollPoint:NSMakePoint([pathView frame].size.width, 0)];

//  NSLog(@"PathView icons=%i path components=%i", 
//	[pathViewIcons count], [[relativePath pathComponents] count]);

  // Last icon
  pathIcon = [[pathView icons] lastObject];
  // Using [viewer keyView] leads to segfault if 'keyView' changed (reloaded)
  // on the fly
  [pathIcon setNextKeyView:[viewer view]];

  // Last icon label
  pathIconLabel = [pathIcon label];
  [pathIconLabel setNextKeyView:[viewer view]];

  [[pathView icons] makeObjectsPerform:@selector(setDelegate:)
   			    withObject:self];
}

// --- PathView delegate

- (void)pathViewIconDragged:sender event:(NSEvent *)ev
{
  NSArray      *paths;
  NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSDragPboard];
  NSRect       iconFrame = [sender frame];
  NSPoint      iconLocation = iconFrame.origin;

  draggedSource = pathView;
  draggedIcon = sender;

  iconLocation.x += 8;
  iconLocation.y += iconFrame.size.width - 16;

  if ([[pathView icons] lastObject] != sender)
    {
      [sender setSelected:NO];
    }

  paths = [draggedIcon paths];
  draggingSourceMask = [self draggingSourceOperationMaskForPaths:paths];

  [pb declareTypes:[NSArray arrayWithObject:NSFilenamesPboardType] owner:nil];
  [pb setPropertyList:paths forType:NSFilenamesPboardType];

  [pathView dragImage:[sender iconImage]
		   at:iconLocation //[ev locationInWindow]
	       offset:NSZeroSize
		event:ev
	   pasteboard:pb
	       source:draggedSource
	    slideBack:YES];
}

- (NSImage *)pathView:(PathView *)aPathView
   imageForIconAtPath:(NSString *)aPath
{
  NSString *fullPath;
  
  //  NSLog(@"[FileViewer] imageForIconAtPath: %@", aPath);
  
  fullPath = [rootPath stringByAppendingPathComponent:aPath];
  return [[NSApp delegate] iconForFile:fullPath];
}

// TODO: remove?
- (NSString *)pathView:(PathView *)aPathView
    labelForIconAtPath:(NSString *)aPath
{
  // return [iface labelForFile:aPath];
  return @"-";
}

- (void)pathView:(PathView *)aPathView
 didChangePathTo:(NSString *)newPath
{
  // Path view can change path only to directory
  [self displayPath:newPath selection:nil sender:pathView];
}

- (void)pathViewSyncEmptyColumns
{
  NSUInteger numEmptyCols = 0;

  // Update cahed column attributes here.
  viewerColumnWidth = [viewer columnWidth];
  viewerColumnCount = [viewer columnCount];

  // Set empty columns to PathView
  numEmptyCols = [viewer numberOfEmptyColumns];

  NSDebugLLog(@"FilViewer", @"pathViewSyncEmptyColumns: selection: %@",
              selection);

  // Browser has empty columns and file(s) selected
  if (selection && [selection count] >= 1 && numEmptyCols > 0)
    {
      numEmptyCols--;
    }
  [pathView setNumberOfEmptyColumns:numEmptyCols];
}

//=============================================================================
// Scroller delegate
//=============================================================================

// Called when user drag scroller's knob
- (void)constrainScroller:(NSScroller *)aScroller
{
  NSUInteger num = [pathView slotsWide] - viewerColumnCount;
  CGFloat    v;

  NSLog(@"[FileViewer -contrainScroller] PathView # of icons: %lu", 
	[[pathView icons] count]);

  if (num == 0)
    {
      v = 0.0;
      [aScroller setFloatValue:0.0 knobProportion:1.0];
    }
  else
    {
      v = rintf(num * [aScroller floatValue]) / num;
      [aScroller setFloatValue:v];
    }

  [pathView scrollRectToVisible:
              NSMakeRect(([pathView frame].size.width - 
                          [[pathView superview] frame].size.width) * v, 0,
                         [[pathView superview] frame].size.width, 0)];
}

// Called whenver user click on PathView's scrollbar
- (void)trackScroller:(NSScroller *)aScroller
{
  NSUInteger iconsNum = [pathView slotsWide];
  CGFloat    sValue = [aScroller floatValue];
  NSRange    r;
  CGFloat    rangeStart;
  NSInteger  emptyCols;

  NSLog(@"0. [FileViewer] document visible rect: %@",
        NSStringFromRect([scrollView documentVisibleRect]));
  NSLog(@"0. [FileViewer] document rect: %@",
        NSStringFromRect([pathView frame]));
  NSLog(@"0. [FileViewer] scroll view rect: %@",
        NSStringFromRect([scrollView frame]));

  rangeStart = rintf((iconsNum - viewerColumnCount) * sValue);
  r = NSMakeRange(rangeStart, viewerColumnCount);

  NSLog(@"1. [FileViewer] trackScroller: value %f proportion: %f," 
        @"scrolled to range: %0.f - %lu", 
	sValue, [aScroller knobProportion], 
        rangeStart, viewerColumnCount);

  // Update viewer display
  [viewer scrollToRange:r];

  // Synchronize positions of icons in PathView and columns 
  // in BrowserViewer
  NSArray *files = [pathView files];

  if (files != nil && [files count] > 0) // file selected
    {
      if (iconsNum - (iconsNum * sValue) <= 1.0)
	{ // scrolled maximum to the right 
	  // scroller value close to 1.0 (e.g. 0.98)
	  [viewer setNumberOfEmptyColumns:1];
	}
      else
	{
          [self pathViewSyncEmptyColumns];
	}
    }
  else
    {
      [self pathViewSyncEmptyColumns];
    }

  // Set keyboard focus to last visible column
  [viewer becomeFirstResponder];

  /*  NSLog(@"2. [FileViewer] trackScroller: value %f proportion: %f," 
        @"scrolled to range: %0.f - %i", 
	[aScroller floatValue], [aScroller knobProportion], 
        rangeStart, viewerColumnCount);

  NSLog(@"3. [FileViewer] PathView slotsWide = %i, viewerColumnCount = %i", 
	[pathView slotsWide], viewerColumnCount);*/
}

//=============================================================================
// Viewer delegate
//=============================================================================

// Called when viewer contains NXIcons with editable label (IconViewer)
- (BOOL)viewerRenamedCurrentFileTo:(NSString *)newName
{
  return [self renameCurrentFileTo:newName updateViewer:NO];
}

- (void)viewerDidSetPathTo:(NSString *)path 
		 selection:(NSArray *)files
{
  //
}

//=============================================================================
// Splitview delegate
//=============================================================================
- (void)         splitView:(NSSplitView *)sender
 resizeSubviewsWithOldSize:(NSSize)oldSize
{
  NSSize splitViewSize = [splitView frame].size;
  NSRect shelfRect;
  NSRect boxRect;

  NSLog(@"[FileViewer:splitView:resizeWithOldSuperviewSize] shelf:%@", 
	NSStringFromRect([shelf frame]));

  // Shelf
  shelfRect = [shelf frame];
  shelfRect.size.width = splitViewSize.width;
  [shelf setFrame:shelfRect];
  [shelf resizeWithOldSuperviewSize:splitViewSize];

  NSLog(@"[FileViewer:splitView:resizeWithOldSuperviewSize] shelf:%@ splitView:%fx%f", 
	NSStringFromRect(shelfRect), oldSize.width, oldSize.height);

  // PathView and Viewer
  boxRect.origin.x = 0;
  boxRect.origin.y = shelfRect.size.height + [splitView dividerThickness];
  boxRect.size.width = splitViewSize.width;
  boxRect.size.height = splitViewSize.height - boxRect.origin.y;

  [containerBox setFrame:boxRect];
}

- (CGFloat)   splitView:(NSSplitView *)sender
 constrainSplitPosition:(CGFloat)proposedPosition
            ofSubviewAt:(NSInteger)offset
{
  NSSize    minSize;
  NSSize    slotSize;
  NSInteger newSlot;
  CGFloat   maxY;

  slotSize = [shelf slotSize];

  // NSLog(@"[FileViewer-splitView:constrainSplitPosition] slot height: %0.f",
  //       slotSize.height);

  newSlot = rintf(proposedPosition / slotSize.height);

  maxY = [sender frame].size.height -
    [[pathView enclosingScrollView] frame].size.height - 30;
  if (maxY < newSlot * slotSize.height)
    {
      newSlot = floorf(maxY / slotSize.height);
    }

  minSize = [window minSize];
  minSize.height = newSlot * slotSize.height + 
    [[pathView enclosingScrollView] frame].size.height + 30;
  [window setMinSize:minSize];

  return newSlot * slotSize.height + 6;
}

- (void)splitViewDidResizeSubviews:(NSNotification *)notification
{
  [shelf resizeWithOldSuperviewSize:[splitView frame].size];
}

//=============================================================================
// NXIconLabel delegate
//=============================================================================

// Called by icon in PathView or IconViewer
- (void)   iconLabel:(NXIconLabel *)anIconLabel
 didChangeStringFrom:(NSString *)oldLabelString
		  to:(NSString *)newLabelString
{
  PathIcon *icon;
  NSString *path;

  NSLog(@"Icon label did change to %@", newLabelString);

  if (![self renameCurrentFileTo:newLabelString updateViewer:YES])
    {
      [[anIconLabel icon] setLabelString:oldLabelString];
      return;
    }

  // Set attributes of icon
  icon = (PathIcon *)[anIconLabel icon];
  path = [[icon paths] objectAtIndex:0];
  // NSLog(@"Icon old path: %@", path);
  path = [path stringByDeletingLastPathComponent];
  path = [path stringByAppendingPathComponent:newLabelString];
  // NSLog(@"Icon new path: %@", path);
  [icon setPaths:[NSArray arrayWithObject:path]];
  // NSLog(@"Icon now have paths: %@", [icon paths]);
}

//=============================================================================
// Window
//=============================================================================
- (void)windowDidBecomeMain:(NSNotification *)notif
{
  Inspector *inspector = [(Controller *)[NSApp delegate] inspectorPanel];
  
  if (inspector != nil)
    {
      [inspector revert:self];
    }
}

- (void)windowWillClose:(NSNotification *)notif
{
  NSLog(@"[FileViewer][%@] windowWillClose [%@]",
        displayedPath, [[notif object] className]);

  if (!isRootViewer)
    {
      [fileSystemMonitor 
	removePath:[rootPath stringByAppendingPathComponent:displayedPath]];
    }
  
  // unset viewer to decrease retain count on FileViewer
  [self useViewer:nil]; 

  [[NSApp delegate] closeViewer:self];
}

- (void)windowDidResize:(NSNotification*)notif
{
  // NSLog(@"[FileViewer windowDidResize:] viewer column count: %lu", 
  //       [(NSBrowser *)[viewer view] numberOfVisibleColumns]);

  // Update column attributes here.
  // Call to updateWindowWidth: leads to segfault because of active
  // resizing operation.
  [self pathViewSyncEmptyColumns];
  [self updateInfoLabels:nil];
}

- (void)setWindowEdited:(BOOL)onState
{
  if (onState == YES)
    {
      [window setDocumentEdited:YES];
      setEditedStateCount++;
    }
  else if(--setEditedStateCount <= 0)
    {
      [window setDocumentEdited:NO];
    }
}

//=============================================================================
// Notifications
//=============================================================================
- (void)browserColumnWidthChanged:(NSNotification *)notif
{
  [self updateWindowWidth:viewer];
}

- (void)updateDiskInfo
{
  NSString *labelstr;
  NSString *sizeString;

  sizeString = [NXFileSystem fileSystemFreeSizeAtPath:[self absolutePath]];
  labelstr = [NSString 
    stringWithFormat:@"%@ available on hard disk", sizeString];

  [diskInfo setStringValue:labelstr];
  [diskInfo setNeedsDisplay:YES];
}

- (void)updateInfoLabels:(NSNotification *)notif
{
  //NXSplitView *sv = splitView;
  NSPoint     labelOrigin;
  NSRect      frame;

  labelOrigin = [shelf convertPoint:[shelf frame].origin
                             toView:[window contentView]];
  
  frame = [diskInfo frame];
  frame.origin = labelOrigin;
  frame.origin.y -= ([shelf frame].size.height + frame.size.height - 2);
  [diskInfo setFrame:frame];

  frame = [operationInfo frame];
  frame.size.height = 12;
  frame.origin = labelOrigin;
  frame.origin.y -= ([shelf frame].size.height + frame.size.height - 2);
  frame.origin.x = [window frame].size.width - frame.size.width - 10;
  [operationInfo setFrame:frame];
  [operationInfo setNeedsDisplay:YES];

  [self updateDiskInfo];
}

// --- Filesystem events

// "NXFileSystemChangedAtPath" notification callback
// Paths are absolute here.
// Notification holds dictionary with objects:
//   "ChangedPath"   - source directory path
//   "ChangedFile"   - source file name
//   "ChangedFileTo" - destination file name
//   "Operations"    - array of operations: Write, Rename, Delete, Link
- (void)fileSystemChangedAtPath:(NSNotification *)notif
{
  id           object = [notif object];
  NSDictionary *changes = [notif userInfo];
  NSString     *changedPath = [changes objectForKey:@"ChangedPath"];
  NSString     *selectedPath = [self absolutePath];
  NSArray      *operations = nil;
  
  NSString *changedFile, *changedFileTo, *selectedFile = nil;
  NSString *changedFullPath, *newFullPath, *selectedFullPath = nil;

  // Check if root folder still exists.
  if (![[NSFileManager defaultManager] fileExistsAtPath:rootPath])
    {
      [window close];
      return;
    }
  
  NSString *commonPath = NXIntersectionPath(selectedPath, changedPath);
  if (([commonPath length] < 1) || ([commonPath length] < [rootPath length]))
    { // No intersection or changed path is out of our focus.
      return;
    }

  operations = [changes objectForKey:@"Operations"];

  // NSLog(@"[FileViewer:%@] NXFileSystem got filesystem changes %@ at %@",
  //       [self displayedPath], operations, changedPath);

  // 'selectedPath' contains absolute path with 1 FS object selected
  // 'changedPath' - directory where changes occured
  // 'newPath' - absulte path of new name of 1 FS object

  changedFile = [changes objectForKey:@"ChangedFile"];
  changedFileTo = [changes objectForKey:@"ChangedFileTo"];
  // 'changedPath' already set
  changedFullPath = [changedPath stringByAppendingPathComponent:changedFile];
  
  // Now decide what and how should be updated
  if ([operations indexOfObject:@"Rename"] != NSNotFound)
    { // ChangedPath, ChangedFile, ChangedFileTo must be filled
      
      newFullPath = [changedPath stringByAppendingPathComponent:changedFileTo];
      
      if ([selection count])
        {
          selectedFile = [selection lastObject];
          selectedFullPath = [selectedPath
                               stringByAppendingPathComponent:selectedFile];
        }
      else
        {
          selectedFullPath = [NSString stringWithString:selectedPath];
        }
        
      // changedFullPath  == "changedPath/changedFile"
      // newFullPath      == "changedPath/changedFileTo"
      // selectedFullPath == "selectedPath/selectedFile"

      // NSLog(@"[FileViewer] NXFileSystem: 'Rename' "
      //       @"operation occured for %@(%@). New name %@",
      //       changedFullPath, selectedFullPath, newFullPath);
      
      commonPath = NXIntersectionPath(selectedFullPath, changedFullPath);
      
      if ([changedFullPath isEqualToString:selectedFullPath])
        {
          // Last selected name changed
          NSLog(@"Last selected name changed");
          [viewer
            currentSelectionRenamedTo:[self pathFromAbsolutePath:newFullPath]];
          [self displayPath:[self pathFromAbsolutePath:changedPath]
                  selection:[NSArray arrayWithObject:changedFileTo]
                     sender:self];
        }
      else if ([changedPath isEqualToString:selectedPath])
        {
          // Selected dir contents changed
          NSLog(@"Selected dir contents changed");
          // Reload column in browser for changed directory contents
          ASSIGN(selection, [self checkSelection:selection
                                          atPath:displayedPath]);
          [viewer reloadPath:displayedPath];
        }
      else if ([commonPath isEqualToString:changedFullPath])
        {
          selectedPath = [selectedPath
                           stringByReplacingOccurrencesOfString:commonPath
                                                     withString:newFullPath];
          // Changed directory name, part of selectedPath 
          NSLog(@"Changed directory name, part of selectedPath");
          // [viewer reloadPath:[self pathFromAbsolutePath:selectedPath]];
          [self displayPath:[self pathFromAbsolutePath:selectedPath]
                  selection:selection
                     sender:self];
        }
      else
        {
          NSLog(@"One of not selected (but displayed) row name changed");
          // One of not selected (but displayed) row name changed
          // Reload column in browser for changed directory contents
          [viewer reloadPath:[self pathFromAbsolutePath:changedPath]];
        }
    }
  else if (([operations indexOfObject:@"Write"] != NSNotFound))
    {   // Write - monitored object was changed (Create, Delete)
      // NSLog(@"[FileViewer] NXFileSystem: 'Write' "
      //       @"operation occured for %@ (%@) selection %@",
      //       changedPath, selectedPath, selection);

      // Check selection before path will be reloaded
      ASSIGN(selection, 
             [self checkSelection:selection atPath:displayedPath]);
      // Reload column in browser for changed directory contents
      [viewer reloadPath:[self pathFromAbsolutePath:changedPath]];

      // Check existance of path components and update ivars, other views
      [self displayPath:displayedPath selection:selection sender:self];
    }
  else if (([operations indexOfObject:@"Attributes"] != NSNotFound))
    {
      [self displayPath:displayedPath selection:selection sender:self];
    }
}

- (void)directorySortMethodChanged:(NSNotification *)aNotif
{
  NSString *changedPath = [aNotif object];
  
  if ([[self absolutePath] isEqualToString:changedPath] == YES)
    {
      [viewer reloadPath:[self pathFromAbsolutePath:changedPath]];
    }
}

// --- Preferences (NXGlobalDomain) changes

- (void)globalUserPreferencesDidChange:(NSNotification *)aNotif
{
  NXFileManager *xfm = [NXFileManager sharedManager];
  BOOL          hidden = [xfm isShowHiddenFiles];
  NXSortType    sort = [xfm sortFilesBy];

  if ((showHiddenFiles != hidden) || (sortFilesBy != sort))
    {
      [viewer displayPath:[self displayedPath] selection:selection];
    }
    
  NSLog(@"[Workspace]: NXGlobalDomain was changed.");
}


// --- NXMediaManager events

// volumeDid* methods are for updating views.
- (void)volumeDidMount:(NSNotification *)notif
{
  NSEnumerator *e = [[shelf icons] objectEnumerator];
  PathIcon     *icon;
  NSString     *mountPoint = [[notif userInfo] objectForKey:@"MountPoint"];
  NSString     *iconPath;
  NSDictionary *ui;

  // NSLog(@"Volume '%@' did mount at path: %@",
  //       [[notif userInfo] objectForKey:@"UNIXDevice"], mountPoint);

  while ((icon = [e nextObject]) != nil)
    {
      iconPath = [[icon paths] objectAtIndex:0];
      if ([mountPoint isEqualToString:iconPath])
	{
	  [icon setIconImage:[[NSApp delegate] iconForFile:iconPath]];
	  return;
	}
    }

  icon = [self shelf:shelf
               createIconForPaths:[NSArray arrayWithObject:mountPoint]];
  if (icon)
    {
      [self shelf:shelf didAcceptIcon:icon inDrag:nil];
      [icon setInfo:[notif userInfo]];
      [shelf addIcon:icon];
    }
}

- (void)volumeDidUnmount:(NSNotification *)notif
{
  NSEnumerator *e = [[shelf icons] objectEnumerator];
  PathIcon     *icon;
  NSString     *mountPoint = [[notif userInfo] objectForKey:@"MountPoint"];
  NSString     *iconPath;

  // NSLog(@"Volume '%@' mounted at '%@' did unmount",
  //       [[notif userInfo] objectForKey:@"UNIXDevice"], mountPoint);
  
  while ((icon = [e nextObject]) != nil)
    {
      iconPath = [[icon paths] objectAtIndex:0];
      if ([mountPoint isEqualToString:iconPath])
	{
	  [shelf removeIcon:icon];
	  return;
	}
    }
}

// --- File operations (ProcessManager, BGOperation)

- (void)fileOperationDidStart:(NSNotification *)notif
{
  [self setWindowEdited:YES];
}

- (void)fileOperationDidEnd:(NSNotification *)notif
{
  [self setWindowEdited:NO];
}

- (void)fileOperationProcessingFile:(NSNotification *)notif
{
  // BGOperation *fop = [notif object];

  // NSLog(@"[FileViewer] %@ object %@", [fop operationType], [fop filename]);
}

//=============================================================================
// Dragging
//   FileViewer is delegate for PathView (with PathIcon),
//   ShelfView (with PathIcon).
//   
//   Dragging consequnce is the following:
//   - starts with calling 'dragAction'
//       pathViewIconDragged:event:
//       shelfIconDragged:event: 
//   - 'dragAction' calls draggingSourceOperationMaskForPaths:
//   - draggingSourceOperationMaskForPaths: defines 'draggingSourceMask' ivar
//   - NSDraggingDestination methods implemented in PathIcon
//   - draggingDestinationMaskForPaths:intoPath: called by draggingEntered:
//=============================================================================

// --- NSDraggingSource (NXIconView delegate methods)

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
                                              iconView:(NXIconView *)sender
{
  NSLog(@"[FileViewer] draggingSourceOperationMaskForLocal: %@",
        [sender className]);
  return draggingSourceMask;
}


- (void)draggedImage:(NSImage *)image
	     endedAt:(NSPoint)screenPoint
	   operation:(NSDragOperation)operation
{
//  NSLog(@"draggedImage:endedAt:operation:%i", operation);

  if (draggedSource == shelf)
    {
      NXIconSlot iconSlot = [shelf slotForIcon:draggedIcon];
      NSPoint    windowPoint = [window convertScreenToBase:screenPoint];
      NSPoint    shelfPoint = [shelf convertPoint:windowPoint fromView:nil];

      [draggedIcon setDimmed:NO];

      // Root icon must never be moved or removed
      if (iconSlot.x == 0 && iconSlot.y == 0)
	{
	  return;
	}

      NSLog(@"windowPoint %@ shelfPoint %@", 
	    NSStringFromPoint(windowPoint), NSStringFromPoint(shelfPoint));

      // TODO: Check correctness of drag&drop inside shelf
      if (operation == NSDragOperationNone && 
	  !NSPointInRect(screenPoint, [window frame]))
	{
	  [shelf removeIcon:draggedIcon];
	}
    }

  draggedSource = nil;
  draggedIcon = nil;
}

// - Dragging Source helper
- (unsigned int)draggingSourceOperationMaskForPaths:(NSArray *)filenames
{
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSEnumerator  *e;
  NSString      *filePath;
  NSString      *parentPath;
  unsigned int  mask;

  if ([filenames count] == 0)
    {
      return NSDragOperationNone;
    }

//  NSLog(@"[FileViewer] draggingSourceOperationMaskForPaths: %@", filenames);

  mask = NSDragOperationCopy | NSDragOperationLink |
         NSDragOperationMove | NSDragOperationDelete;

  // Get first object from array
  filePath = [filenames objectAtIndex:0];
  parentPath = [filePath stringByDeletingLastPathComponent];

  // Check if file is root '/' or directory containing file is not writable.
  // If so, restrict operation to Copy and Link
  if (([filenames count] == 1 && [filePath isEqualToString:@"/"])
      || ![fileManager isWritableFileAtPath:parentPath])
    {
      mask &= ~(NSDragOperationMove | NSDragOperationDelete);
    }

  // Check if files can be read
  e = [filenames objectEnumerator];
  while ((filePath = [e nextObject]) != nil)
    {
      if (![fileManager isReadableFileAtPath:filePath])
	{
	  mask = NSDragOperationNone;
	}
    }

  return mask;
}

// - Dragging Destination helper
- (unsigned int)draggingDestinationMaskForPaths:(NSArray *)paths
				       intoPath:(NSString *)destPath
{
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSString     *path;
  NSEnumerator *e;
  unsigned int mask = (NSDragOperationCopy | NSDragOperationMove | 
                      NSDragOperationLink | NSDragOperationDelete);

  if (![fileManager isWritableFileAtPath:destPath])
    {
      NSLog(@"[FileViewer] %@ is not writable!", destPath);
      return NSDragOperationNone;
    }

  if (![[[fileManager fileAttributesAtPath:destPath traverseLink:YES]
	fileType] isEqualToString:NSFileTypeDirectory])
    {
      NSLog(@"[FileViewer] %@ == NSFileTypeDirectory!", destPath);
      return NSDragOperationNone;
    }

  e = [paths objectEnumerator];
  while ((path = [e nextObject]) != nil)
    {
      NSRange r;

      if (![fileManager isDeletableFileAtPath:path])
	{
	  NSLog(@"[FileViewer] file %@ is not deletable!", path);
	  mask ^= NSDragOperationMove;
	}

      if ([path isEqualToString:destPath])
	{
	  NSLog(@"[FileViewer] %@ == %@", path, destPath);
	  return NSDragOperationNone;
	}

      if ([[path stringByDeletingLastPathComponent] isEqualToString:destPath])
	{
	  NSLog(@"[FileViewer] %@ == %@ (2)", path, destPath);
	  return NSDragOperationNone;
	}

      r = [destPath rangeOfString: path];
      if (r.location == 0 && r.length != NSNotFound)
	{
	  NSLog(@"[FileViewer] r.location == 0 && NSNotFound for %@", path);
	  mask ^= (NSDragOperationCopy | NSDragOperationMove);
	}
    }

  return mask;
}

//=============================================================================
// Workspace menu
//=============================================================================

//--- Menu actions

// Menu items in 'Viewers' submenu loaded by [Controller _loadViewMenu]
- (void)setViewerType:(id)sender
{
  NSString    *viewerType = [sender title];
  id <Viewer> aViewer;

  aViewer = [[ModuleLoader shared] viewerForType:viewerType];

  if (aViewer != nil)
    {
      [self useViewer:aViewer];
      
      // remeber this one as the preferred viewer
      [[NXDefaults userDefaults] setObject:viewerType 
				    forKey:@"PreferredViewer"];
    }
  else
    {
      [NSException raise:NSInternalInconsistencyException
  		  format:_(@"Failed to initialize viewer of type %@"),
                   viewerType];
    }
}

// File
- (void)open:(id)sender
{
  NSImage        *image;
  NSString       *filePath;
  NSMutableArray *extensions;
  NSString	 *ext;

  // "Return" key press in *Viewer, File->Open menu item, double click
  if (![sender isKindOfClass:[PathIcon class]] || 
      ![[sender superview] isKindOfClass:[ShelfView class]])
    {
      sender = [[pathView icons] lastObject];
    }

  // For multiple files:
  // For each type call openFile:fromImage:at:inView with 'image' for first
  // file in list (flying icon) and 'nil' for the rest (no flying icon).
  extensions = [[NSMutableArray new] autorelease];
  for (filePath in [sender paths])
    {
      ext = [filePath pathExtension];
      if ([ext isEqualToString:@"app"] == YES ||
          [extensions containsObject:ext] == NO)
        {
          [extensions addObject:[filePath pathExtension]];
          image = [[NSApp delegate] iconForFile:filePath];
        }
      else
        {
          image = nil;
        }
      
      if ([[NSApp delegate] openFile:filePath
                           fromImage:image
                                  at:NSMakePoint((64-image.size.width)/2, 0)
                              inView:sender] == NO)
        {
          break;
        }
    }
}

- (void)openAsFolder:(id)sender
{
  NSString   *filePath = [self absolutePath];
  NSString   *wrapperName;
  FileViewer *fv = nil;

  if (selection != nil)
    { // It's a wrapper - add filename to path
      wrapperName = [selection objectAtIndex:0];
      filePath = [filePath stringByAppendingPathComponent:wrapperName];
    } 

  [[NSApp delegate] openNewViewerIfNotExistRootedAt:filePath];
}

- (void)newFolder:(id)sender
{
  int           idx;
  NSString      *folderName = _(@"NewFolder");
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString      *selectedPath = [self absolutePath];
  NSString      *newPath;
  PathIcon      *selectedIcon = [[pathView icons] lastObject];;
  NXIconLabel   *label;

  NSLog(@"NF: %@", selectedPath);

  newPath = [selectedPath stringByAppendingPathComponent:folderName];
  for (idx = 1; [fm fileExistsAtPath:newPath]; idx++)
    {
      folderName = [NSString stringWithFormat:_(@"NewFolder%d"),idx];
      newPath = [selectedPath stringByAppendingPathComponent:folderName];
    }

  if (![fm createDirectoryAtPath:newPath attributes:nil])
    {
      NSRunAlertPanel(_(@"New Folder"),
		      _(@"Unable to create folder.\n\
			The selected path is not writable"),
		      nil, nil, nil);
      return;
    }

  newPath = [self pathFromAbsolutePath:newPath];

  NSLog(@"NewFolder: %@", newPath);
  [self displayPath:newPath selection:nil sender:self];

  // Here is new selected icon
  selectedIcon = [[pathView icons] lastObject];
  label = [selectedIcon label];
  [window makeFirstResponder:label];
  [label selectAll:nil];
}

- (void)duplicate:(id)sender
{
  NSArray *files = nil;
  
  // NSLog(@"[FileViewer duplicate] path=%@ selection=%@",
  //       [self absolutePath], selection);
  
  /*  if (NSRunAlertPanel(@"Duplicate", 
                      @"Start duplicating files in selected directory?",
                      @"Duplicate", @"Cancel", nil) 
      != NSAlertDefaultReturn)
    {
      return;
      }*/

  if ([selection count] > 0)
    {
      files = selection;
    }
  
  [[FileMover alloc] initWithOperationType:DuplicateOperation
                                 sourceDir:[self absolutePath]
                                 targetDir:nil
                                     files:files
                                   manager:[ProcessManager shared]];
}

// TODO
- (void)compress:(id)sender
{
  // TODO
}

- (void)destroy:(id)sender
{
  NSString *fullPath;
  NSArray  *files = nil;
  BOOL     started;

  if (NSRunAlertPanel(@"Destroy", 
                      @"Do you want to destroy selected files?",
                      @"Destroy", @"Cancel", nil) 
      != NSAlertDefaultReturn)
    {
      return;
    }
  
  fullPath = [self absolutePath];
  if ([selection count] > 0)
    {
      files = selection;
    }
  else
    {
      files = [NSArray arrayWithObject:[fullPath lastPathComponent]];
      fullPath = [fullPath stringByDeletingLastPathComponent];
    }

  NSLog(@"Destroy: %@/%@", fullPath, files);

  [[FileMover alloc] initWithOperationType:DeleteOperation
                                 sourceDir:fullPath
                                 targetDir:nil
                                     files:files
                                   manager:[ProcessManager shared]];

  //NSLog(@"Relative path after destroy: %@", relPath);
}

// Disk
- (void)unmount:(id)sender
{
  [mediaManager unmountRemovableVolumeAtPath:[self absolutePath]];
}

- (void)eject:(id)sender
{
  NSLog(@"[FileViewer:%@] eject", [self absolutePath]);
  [mediaManager unmountAndEjectDeviceAtPath:[self absolutePath]];
}

//--- Menu validation (menu items targeted to FileViewer (NSFirstResonder))

- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem
{
  NSString *menuTitle = [[menuItem menu] title];
  NSString *selectedPath = [self absolutePath];

  // File operations
  if ([menuTitle isEqualToString:@"File"])
    {
      NSFileManager *fm = [NSFileManager defaultManager];
      NSString      *parentPath;
      NSString      *fileType;
      NSString      *fullPath;

      parentPath = [selectedPath stringByDeletingLastPathComponent];
      // Always enabled (TODO?)
      // if ([[menuItem title] isEqualToString:@"Open"] &&
      //     (![fm fileExistsAtPath:selectedPath isDirectory:&isDir] || isDir)) return NO;

      if ([[menuItem title] isEqualToString:@"Open as Folder"])
        {
          if ([selection count] == 1)
            {
              fullPath = [selectedPath
                           stringByAppendingPathComponent:[selection lastObject]];
              fileType = [[fm fileAttributesAtPath:fullPath traverseLink:YES] fileType];
              if (![fileType isEqualToString:NSFileTypeDirectory])
                return NO;
            }
          else
            {
              fileType = [[fm fileAttributesAtPath:selectedPath traverseLink:YES] fileType];
              if (![fileType isEqualToString:NSFileTypeDirectory] ||
                  [selection count] > 1)
                return NO;
            }
        }
      
      if ([[menuItem title] isEqualToString:@"New Folder"] &&
          ![fm isWritableFileAtPath:selectedPath]) return NO;
          
      if ([[menuItem title] isEqualToString:@"Destroy"] ||
          [[menuItem title] isEqualToString:@"Duplicate"] ||
          [[menuItem title] isEqualToString:@"Compress"])
        {
          if ([selection count] > 0 && ![fm isWritableFileAtPath:selectedPath])
            {
              return NO;
            }
          if ([selection count] == 0 && ![fm isWritableFileAtPath:parentPath])
            {
              return NO;
            }
        }
    }
  
  // Media operations
  if ([menuTitle isEqualToString:@"Disk"])
    {
      NSArray  *mountedRemovables;
      NSString *selectedMountPoint;

      mountedRemovables = [mediaManager mountedRemovableMedia];
      selectedMountPoint = [mediaManager mountPointForPath:selectedPath];
      
      if ([mountedRemovables indexOfObjectIdenticalTo:selectedMountPoint]
          == NSNotFound)
        {
          if ([[menuItem title] isEqualToString:@"Eject"]) return NO;
          if ([[menuItem title] isEqualToString:@"Unmount"]) return NO;
        }
    }

  return YES;
}

@end
