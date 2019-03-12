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

#import <Preferences/Browser/BrowserPrefs.h>
#import <Finder.h>

#define NOTIFICATION_CENTER [NSNotificationCenter defaultCenter]
#define WIN_MIN_HEIGHT 380
#define WIN_DEF_WIDTH 560
#define SPLIT_DEF_WIDTH WIN_DEF_WIDTH-16

@interface FileViewerWindow : NSWindow
- (void)handleWindowKeyUp:(NSEvent *)theEvent;
@end

@implementation FileViewerWindow
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
    NSLog(@"[NSWindow] click on %@", [v className]);
    if ([v isKindOfClass:[PathIcon class]]) {
      [v mouseDown:theEvent];
      return;
    }
  }
  else if ([theEvent type] == NSKeyUp) {
    [_delegate handleWindowKeyUp:theEvent];
  }  

  [super sendEvent:theEvent];
}
- (void)handleWindowKeyUp:(NSEvent *)theEvent
{
  // Should be implemented by delegate
}
@end

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

  if ([fm fileExistsAtPath:dotDir]) {
    dotDirDict = [NSDictionary dictionaryWithContentsOfFile:dotDir];
    return [dotDirDict objectForKey:key];
  }

  return nil;
}
- (void)useViewer:(id <Viewer>)aViewer
{
  if (aViewer) {
    ASSIGN(viewer, aViewer);

    [viewer setOwner:self];
    [viewer setRootPath:rootPath];
    [(NSBox *)box setContentView:[viewer view]];
    [viewer displayPath:displayedPath selection:selection];
  }
  else {
    // Use this for case when aViewer set to 'nil'
    // to decrease retain count on FileViwer.
    // Example: [self windowWillClose:]
    [[viewer view] removeFromSuperview];
    [viewer autorelease];
  }
}
@end

@implementation FileViewer

//=============================================================================
// Create and destroy
//=============================================================================

- initRootedAtPath:(NSString *)aRootPath
            viewer:(NSString *)viewerType
	    isRoot:(BOOL)isRoot
{
  NXDefaults           *df = [NXDefaults userDefaults];
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  NSString             *relativePath = nil;
  NSSize               aSize;

  [super init];

  isRootViewer = isRoot;

  setEditedStateCount = 0;

  ASSIGN(rootPath, aRootPath);
  ASSIGN(displayedPath, @"");

  // Initalize NXIconView frame. 
  // NXIconView is a parent class for ShelfView and PathView
  aSize = NSMakeSize(66, 52); // Size of hilite.tiff 66x52
  [NXIcon setDefaultIconSize:aSize];
  // Set NXIconView slot size
  if ([df objectForKey:@"IconLabelWidth"]) {
    aSize = NSMakeSize([df floatForKey:@"IconLabelWidth"], PATH_VIEW_HEIGHT);
  }
  else {
    aSize = NSMakeSize(168, PATH_VIEW_HEIGHT);
  }
  [NXIconView setDefaultSlotSize:aSize];
  
  // [NSBundle loadNibNamed:@"FileViewer" owner:self];
  // To avoid .gorm loading ineterference manually construct File Viewer window.
  [self awakeFromNib];

  if (isRootViewer) {
    [window setTitle:@"File Viewer"];
    [window setFrameAutosaveName:@"RootViewer"];
      
    // try the saved path, then the home directory and as last
    // resort "/"
    (relativePath = [df objectForKey:@"RootViewerPath"]) != nil ||
      (relativePath = NSHomeDirectory()) != nil ||
      (relativePath = @"/");
  }
  else if ([self isRootViewerCopy]) {
    // copy of RootViewer
    // NSRect rootFrame = [[[[NSApp delegate] rootViewer] window] frame];
    // rootFrame.origin.x += 20;
    // rootFrame.origin.y -= 20;
    // [window setFrame:rootFrame display:NO];
    [window center];
    relativePath = rootPath;
  }
  else {
    NSString *viewerWindow = [self dotDirObjectForKey:@"ViewerWindow"];
    NSString *vType;

    [window setTitle:
              [NSString stringWithFormat:_(@"File Viewer  \u2014  %@"), rootPath]];
    if (viewerWindow) {
      [window setFrame:NSRectFromString(viewerWindow) display:NO];
    }
    else {
      [window center];
    }
    if ((relativePath = [self dotDirObjectForKey:@"ViewerPath"]) == nil) {
      relativePath = @"/";
    }
    vType = [self dotDirObjectForKey:@"ViewerType"];
    if (vType && ![vType isEqualToString:@""]) {
      viewerType = vType;
    }
  }

  if (!viewerType || [viewerType isEqualToString:@""]) {
    viewerType = @"Browser";
  }
  // Load the viewer
  [self useViewer:[[ModuleLoader shared] viewerForType:viewerType]];

  // Resize window to just loaded viewer columns and
  // defined window frame (setFrameAutosaveName, setFrame)
  lock = [NSLock new];
  [self updateWindowWidth:nil];

  // Window content adjustments
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
  if (isRootViewer)
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
  if ([self isRootViewerCopy] != NO) {
    [self displayPath:[[[NSApp delegate] rootViewer] displayedPath]
            selection:nil
               sender:self];
  }

  // Configure Shelf later after viewer loaded path to make 
  // setNextKeyView working correctly
  [self restoreShelf];

  // Make initial placement of disk and operation info labels
  [self updateInfoLabels:nil];

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
  if (isRootViewer) {
    styleMask = (NSTitledWindowMask | NSMiniaturizableWindowMask
                 | NSResizableWindowMask);
  }
  else {
    styleMask = (NSTitledWindowMask | NSMiniaturizableWindowMask
                 | NSResizableWindowMask | NSClosableWindowMask);
    }

  // window = [[NSWindow alloc] initWithContentRect:contentRect
  window = [[FileViewerWindow alloc] initWithContentRect:contentRect
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
  shelf = [[ShelfView alloc] initWithFrame:NSMakeRect(0,0,SPLIT_DEF_WIDTH,76)
                                     owner:self];
  [shelf setAutoresizingMask:NSViewWidthSizable];
  [splitView addSubview:shelf];
  NSLog(@"Shelf created with slots tall: %i", [shelf slotsTall]);
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

  pathView = [[PathView alloc] initWithFrame:NSMakeRect(0,0,SPLIT_DEF_WIDTH-4,98)
                                       owner:self];
  [pathView setAutoresizingMask:0];
  [scrollView setDocumentView:pathView];
  [pathView release];
  [containerBox addSubview:scrollView];
  [scrollView release];
  
  PathViewScroller *scroller = [[PathViewScroller new] autorelease];
  [scroller setDelegate:pathView];
  [scrollView setHorizontalScroller:scroller];
  [scrollView setHasHorizontalScroller:YES];
  [scrollView setBackgroundColor:[NSColor windowBackgroundColor]];

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
    
    if (isRootViewer) {
      shelfHeight = [df floatForKey:@"RootViewerShelfSize"];
    }
    else {
      shelfHeight = [[self dotDirObjectForKey:@"ShelfSize"] floatValue];
    }
    
    if (shelfHeight > 0.0) {
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
  NSLog(@"FileViewer %@: dealloc", rootPath);

  [[NSNotificationCenter defaultCenter] removeObserver:self];

  // [viewer release];
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

- (BOOL)isRootViewerCopy
{
  if (isRootViewer == NO &&
      [[[[NSApp delegate] rootViewer] rootPath] isEqualToString:rootPath]) {
    return YES;
  }
  return NO;
}

- (NSWindow *)window
{
  return window;
}

- (NSDictionary *)shelfRepresentation
{
  return [shelf storableRepresentation];
}

- (id<Viewer>)viewer
{
  return viewer;
}

- (PathView *)pathView
{
  return pathView;
}

//=============================================================================
// Path manipulations
//=============================================================================
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

  if ([relativePath isEqualToString:@""]) {
    relativePath = @"/";
  }

  // check parameters
  [self validatePath:&relativePath selection:&filenames];
  if (relativePath == nil) { // Bad news: rootPath disappeared
    return;
  }
  
  // check the shelf contents as well
  [shelf checkIfContentsExist];

  fullPath = [rootPath stringByAppendingPathComponent:relativePath];
  
  NSDebugLLog(@"FileViewer", @"displayPath:%@ selection:%@",
              relativePath, filenames);

  ASSIGN(displayedPath, relativePath);
  ASSIGN(dirContents, [[NSFileManager defaultManager]
                        directoryContentsAtPath:fullPath]);
  ASSIGN(selection, filenames);

  // Viewer
  if (viewer && sender != viewer) {
    [viewer displayPath:displayedPath selection:selection];
  }

  // Path View
  if (pathView) {
    [pathView setPath:displayedPath selection:selection];
    [pathView syncEmptyColumns];
  }

  [viewer becomeFirstResponder];

  // Window
  [window setMiniwindowImage:[[NSApp delegate] iconForFile:fullPath]];
  [window setMiniwindowTitle:[rootPath lastPathComponent]];

  // Disk info label
  [self updateDiskInfo];

  // Update Inspector
  if ([window isMainWindow] == YES) {
    Inspector *inspector = [(Controller *)[NSApp delegate] inspectorPanel];
    if (inspector != nil) {
        [inspector revert:self];
    }
  }

  // FileSystemMonitor
  // TODO:
  // Even if path is not changed attributes of selected directory may be
  // changed. For example, from non-readable to readable.
  if (![oldDisplayedPath isEqualToString:displayedPath]) {
    NSString *pathToMonitor=nil, *pathToUnmonitor=nil;
    
    if (isRootViewer == NO) {
      if (oldDisplayedPath && ![oldDisplayedPath isEqualToString:@""]) {
        pathToUnmonitor = [rootPath stringByAppendingPathComponent:oldDisplayedPath];
      }
      pathToMonitor = [rootPath stringByAppendingPathComponent:displayedPath];
    }
    else {
      if (oldDisplayedPath && ![oldDisplayedPath isEqualToString:@""]) {
        pathToUnmonitor = oldDisplayedPath;
      }
      pathToMonitor = displayedPath;
    }

    if (pathToUnmonitor != nil) {
      [fileSystemMonitor removePath:pathToUnmonitor];
    }
  
    if (pathToMonitor != nil) {
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
  CGFloat      columnWidth;
  NSUInteger   columnCount;

  // Prevent recursive calling
  // Recursive calls may be caused by changing column width via preferences
  if (!lock || [lock tryLock] == NO) {
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
  columnWidth = [pathView slotSize].width;
  columnCount = roundf((frame.size.width - WINDOW_INNER_OFFSET) / columnWidth);
  [viewer setColumnCount:columnCount];
  [viewer setColumnWidth:columnWidth];
  NSLog(@"[FileViewer updateWindowWidth]: column count: %lu (width = %.0f)",
        columnCount, columnWidth);

  windowMinSize = NSMakeSize((2 * columnWidth) + WINDOW_INNER_OFFSET, WIN_MIN_HEIGHT);

  if (sender == window)
    {
      [window setMinSize:windowMinSize];
      [window setResizeIncrements:NSMakeSize(columnWidth, 1)];
      return;
    }

  // Remember scroller value
  scroller = [[pathView enclosingScrollView] horizontalScroller];
  sValue = [scroller floatValue];

  // --- Resize window
  NSLog(@"[FileViewer] window width: %f", frame.size.width);
  frame.size.width = (columnCount * columnWidth) + WINDOW_INNER_OFFSET;
  [window setMinSize:windowMinSize];
  [window setResizeIncrements:NSMakeSize(columnWidth, 1)];
  [window setFrame:frame display:NO];

  // --- PathView scroller
  sv = [pathView enclosingScrollView];
  if ([sv lineScroll] != columnWidth)
    {
      [sv setLineScroll:columnWidth];
    }
  // Set scroller value after window resizing (GNUstep bug?)
  [scroller setFloatValue:sValue];
  [pathView constrainScroller:scroller];

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

  if (selection && [selection count] != 1) {
      [NSException raise:NSInternalInconsistencyException
		  format:@"Attempt to change the " \
		  @"filename while multiple files are selected"];
    }

//  NSLog(@"Rename selection: %@", selection);

  if ([selection count]) {
    // It's a file
    NSString *prefix;

    prefix = [self absolutePath];
    oldFileName = [selection objectAtIndex:0];
    oldFullPath = [prefix stringByAppendingPathComponent:oldFileName];
    newFullPath = [prefix stringByAppendingPathComponent:newName];
  }
  else {
    // It's a directory
    oldFullPath = [self absolutePath];
    newFullPath = [[oldFullPath stringByDeletingLastPathComponent]
                    stringByAppendingPathComponent:newName];
  }

  if ([fm fileExistsAtPath:newFullPath isDirectory:&isDir]) {
    NSString *alreadyExists;
    
    if (isDir) {
      alreadyExists = [NSString stringWithFormat:
                                  @"Directory '%@' already exists.\n" 
                                @"Do you want to replace existing directory?",
                                newName];
    }
    else
      {
        alreadyExists = [NSString stringWithFormat: 
                                    @"File '%@' already exists.\n" 
                                  @"Do you want to replace existing file?", newName];
      }

    switch (NSRunAlertPanel(_(@"Rename"), alreadyExists,
                            _(@"Cancel"), _(@"Replace"), nil)) {
    case NSAlertDefaultReturn: // Cancel
      return NO;
      break;
    case NSAlertAlternateReturn: // Replace
      break;
    }
  }

  if (rename([oldFullPath cString], [newFullPath cString]) == -1) {
    NSString *alertFormat = _(@"Couldn't rename `%@` to `%@`. Error: %s");
    NXRunAlertPanel(_(@"Rename"),
                    [NSString stringWithFormat:alertFormat,
                              oldFullPath, newFullPath,
                              strerror(errno)],
                    nil, nil, nil);
      
      return NO;
    }

  // Leave this for a specific cases when viewer's missed the change.
  if (updateViewer) {
    [viewer currentSelectionRenamedTo:[self pathFromAbsolutePath:newFullPath]];
  }

  return YES;
}

//=============================================================================
- (void)scrollDisplayToRange:(NSRange)aRange
{
  // TODO
}
- (void)slideToPathFromShelfIcon:(PathIcon *)shelfIcon
{
  unsigned    offset;
  NSPoint     startPoint, endPoint;
  NSString    *path;
  NSView      *view = [pathView enclosingScrollView];
  NSSize      svSize = [view frame].size;
  unsigned    numPathComponents;
  NSImage     *image = [shelfIcon iconImage];
  NSSize      imageSize = [image size];
  NSUInteger  columnCount;

  path = [[shelfIcon paths] objectAtIndex:0];
  numPathComponents = [[path pathComponents] count];
  columnCount = [pathView visibleColumnCount];
  if (numPathComponents >= columnCount) {
    offset = columnCount;
  }
  else {
    offset = numPathComponents;
  }

  endPoint = NSMakePoint((svSize.width / columnCount) *
                         (offset - 0.5) - imageSize.width / 2,
                         svSize.height * 0.55);
  endPoint = [view convertPoint:endPoint toView:nil];
  endPoint = [window convertBaseToScreen:endPoint];

  startPoint = NSMakePoint([shelfIcon iconSize].width / 2 - 
                           imageSize.width / 2,
                           [shelfIcon iconSize].height / 2 - 
                           imageSize.height / 2);
  startPoint = [shelfIcon convertPoint:startPoint toView:nil];
  startPoint = [window convertBaseToScreen:startPoint];

  [[NSWorkspace sharedWorkspace] slideImage:image from:startPoint to:endPoint];
}

//=============================================================================
// Shelf
//=============================================================================

- (void)restoreShelf
{
  NXDefaults   *df = [NXDefaults userDefaults];
  NSDictionary *shelfRep = nil;
  NSArray      *paths = nil;
  PathIcon     *icon = nil;

  [shelf iconSlotWidthChanged:nil];
 
  if (isRootViewer) {
    shelfRep = [df objectForKey:@"RootShelfContents"];
    if (!shelfRep || [shelfRep count] == 0) {
      shelfRep = nil;
      paths = [NSArray arrayWithObject:NSHomeDirectory()];
    }
  }
  else {
    shelfRep = [self dotDirObjectForKey:@"ShelfContents"];
    if (!shelfRep || [shelfRep count] == 0) {
      shelfRep = nil;
      paths = [NSArray arrayWithObject:rootPath];
    }
  }

  if (shelfRep) {
    [shelf reconstructFromRepresentation:shelfRep];
  }
  else {
    icon = [shelf createIconForPaths:paths];
    [shelf putIcon:icon intoSlot:NXMakeIconSlot(0,0)];
  }

  [[shelf icons] makeObjectsPerformSelector:@selector(setDelegate:)
                                 withObject:shelf];

  [shelf checkIfContentsExist];
  [shelf shelfAddMountedRemovableMedia];
}

//=============================================================================
// Viewer delegate (BrowserViewer, IconViewer, ListViewer, etc.)
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

  NSLog(@"Icon label did change from %@ to %@", oldLabelString, newLabelString);

  if (![self renameCurrentFileTo:newLabelString updateViewer:NO]) {
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
  NSLog(@"FileViewer(%@): Icon now have paths: %@", rootPath, [icon paths]);
}

//=============================================================================
// Window
//=============================================================================
- (void)windowDidBecomeMain:(NSNotification *)notif
{
  Inspector *inspector = [(Controller *)[NSApp delegate] inspectorPanel];
  
  if (inspector != nil) {
    [inspector revert:self];
  }
  [window makeFirstResponder:[viewer keyView]];
}

- (void)windowWillClose:(NSNotification *)notif
{
  NXDefaults    *df = [NXDefaults userDefaults];
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString      *file = nil;

  if ([selection count] > 0) {
    file = [selection objectAtIndex:0];
  }
  
  NSLog(@"[FileViewer][%@] windowWillClose [%@]",
        rootPath, [[notif object] className]);

  if (!isRootViewer && fileSystemMonitor) {
    [fileSystemMonitor 
	removePath:[rootPath stringByAppendingPathComponent:displayedPath]];
  }

  if (isRootViewer) {
    [df setObject:[displayedPath stringByAppendingPathComponent:file]
           forKey:@"RootViewerPath"];
    [df setObject:[shelf storableRepresentation]
           forKey:@"RootShelfContents"];
    [df setFloat:[shelf frame].size.height 
          forKey:@"RootViewerShelfSize"];
  }
  else if (![self isRootViewerCopy] && [fm isWritableFileAtPath:rootPath]) {
    NSString            *appName, *fileType;
    NSMutableDictionary *fvdf;
    [[NSApp delegate] getInfoForFile:rootPath
                         application:&appName
                                type:&fileType];
    if (fileType != NSPlainFileType && fileType != NSApplicationFileType) {
      fvdf = [NSMutableDictionary new];
      [fvdf setObject:[[viewer class] viewerType]
               forKey:@"ViewerType"];
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
  [pathView syncEmptyColumns];
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

- (void)handleWindowKeyUp:(NSEvent *)theEvent
{
  unichar  c = [[theEvent characters] characterAtIndex:0];
  NSString *string;

  // NSLog(@"[FileViewer] window received key up: %X", c);

  switch (c) {
  case '/':
  case '~':
    string = [NSString stringWithCharacters:&c length:1];
    [[[NSApp delegate] finder] activateWithString:string];
    break;
  case 27:
    [[[NSApp delegate] finder]  activateWithString:[self absolutePath]];
    break;
  }
}

//=============================================================================
// Notifications
//=============================================================================
- (void)shelfResizableStateChanged:(NSNotification *)notif
{
  NSInteger rState;

  rState = [[NXDefaults userDefaults] integerForKey:@"ShelfIsResizable"];
  [splitView setResizableState:rState];
}

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
  if (![[NSFileManager defaultManager] fileExistsAtPath:rootPath]) {
    [window close];
    return;
  }
  
  NSString *commonPath = NXIntersectionPath(selectedPath, changedPath);
  if (([commonPath length] < 1) || ([commonPath length] < [rootPath length])) {
    // No intersection or changed path is out of our focus.
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
  if ([operations indexOfObject:@"Rename"] != NSNotFound) {
    // ChangedPath, ChangedFile, ChangedFileTo must be filled
      
    newFullPath = [changedPath stringByAppendingPathComponent:changedFileTo];
      
    if ([selection count]) {
      selectedFile = [selection lastObject];
      selectedFullPath = [selectedPath stringByAppendingPathComponent:selectedFile];
    }
    else {
      selectedFullPath = [NSString stringWithString:selectedPath];
    }
        
    // changedFullPath  == "changedPath/changedFile"
    // newFullPath      == "changedPath/changedFileTo"
    // selectedFullPath == "selectedPath/selectedFile"

    // NSLog(@"[FileViewer] NXFileSystem: 'Rename' "
    //       @"operation occured for %@(%@). New name %@",
    //       changedFullPath, selectedFullPath, newFullPath);
      
    commonPath = NXIntersectionPath(selectedFullPath, changedFullPath);
      
    if ([changedFullPath isEqualToString:selectedFullPath]) {
      // Last selected name changed
      NSLog(@"Last selected name changed from %@ to %@",
            selectedFullPath, newFullPath);
      // Optimization: do not use [self displayPath:selection:sender:] - just
      // set values for particular parts of FileViewer
      [pathView setPath:[self pathFromAbsolutePath:newFullPath] selection:nil];
      [viewer currentSelectionRenamedTo:[self pathFromAbsolutePath:newFullPath]];
      [self setPathFromAbsolutePath:newFullPath];
      // Update Inspector
      if ([window isMainWindow] == YES) {
        Inspector *inspector = [(Controller *)[NSApp delegate] inspectorPanel];
        if (inspector != nil) {
          [inspector revert:self];
        }
      }
    }
    else if ([changedPath isEqualToString:selectedPath]) {
      // Selected dir contents changed
      NSLog(@"Selected dir contents changed");
      // Reload column in browser for changed directory contents
      ASSIGN(selection, [self checkSelection:selection
                                      atPath:displayedPath]);
      [viewer reloadPath:displayedPath];
    }
    else if ([commonPath isEqualToString:changedFullPath]) {
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
    else {
      NSLog(@"One of not selected (but displayed) row name changed");
      // One of not selected (but displayed) row name changed
      // Reload column in browser for changed directory contents
      [viewer reloadPath:[self pathFromAbsolutePath:changedPath]];
    }
  }
  else if (([operations indexOfObject:@"Write"] != NSNotFound)) {
    // Write - monitored object was changed (Create, Delete)
    NSLog(@"[FileViewer] NXFileSystem: 'Write' "
          @"operation occured for %@/(%@) selected path %@ selection %@",
          changedPath, changedFile, selectedPath, selection);

    // Check selection before path will be reloaded
    ASSIGN(selection, [self checkSelection:selection atPath:displayedPath]);
    // Reload changed directory contents without changing path
    [viewer reloadPath:[self pathFromAbsolutePath:changedPath]];

    // Check existance of path components and update ivars, other views
    [self displayPath:displayedPath selection:selection sender:viewer];
  }
  else if (([operations indexOfObject:@"Attributes"] != NSNotFound)) {
    NSLog(@"[FileViewer] NXFileSystem: 'Attributes' "
          @"operation occured for %@ (%@) selection %@",
          changedPath, selectedPath, selection);
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

  if ((showHiddenFiles != hidden) || (sortFilesBy != sort)) {
    [viewer displayPath:[self displayedPath] selection:selection];
  }
    
  NSLog(@"[Workspace]: NXGlobalDomain was changed.");
}


// --- NXMediaManager events

// volumeDid* methods are for updating views.
- (void)volumeDidMount:(NSNotification *)notif
{
  NSString *mountPoint = [[notif userInfo] objectForKey:@"MountPoint"];
  PathIcon *icon;
  NSString *iconPath;

  // NSLog(@"Volume '%@' did mount at path: %@",
  //       [[notif userInfo] objectForKey:@"UNIXDevice"], mountPoint);

  // Check if mounted removable icon already exist in the Shelf
  for (icon in [shelf icons]) {
    iconPath = [[icon paths] objectAtIndex:0];
    if ([mountPoint isEqualToString:iconPath]) {
      [icon setIconImage:[[NSApp delegate] iconForFile:iconPath]];
      return;
    }
  }

  // No icon in the Shelf exists - create and add new
  icon = [shelf createIconForPaths:@[mountPoint]];
  if (icon) {
    NSLog(@"Adding icon to the Shelf with info: %@", [notif userInfo]);
    [icon setInfo:[notif userInfo]];
    [icon setDelegate:shelf];
    [icon registerForDraggedTypes:@[NSFilenamesPboardType]];
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
//   - starts with calling 'dragAction' - iconDragged:event:
//   - 'dragAction' calls draggingSourceOperationMaskForPaths:
//   - draggingSourceOperationMaskForPaths: defines 'draggingSourceMask' ivar
//   - NSDraggingDestination methods implemented in PathIcon
//=============================================================================

// - Dragging Source helper
- (NSDragOperation)draggingSourceOperationMaskForPaths:(NSArray *)paths
{
  NSFileManager  *fileManager = [NSFileManager defaultManager];
  NSString       *filePath;
  NSString       *parentPath;
  NSDragOperation mask;

  if ([paths count] == 0) {
    return NSDragOperationNone;
  }

//  NSLog(@"[FileViewer] draggingSourceOperationMaskForPaths: %@", filenames);

  mask = (NSDragOperationCopy | NSDragOperationLink |
          NSDragOperationMove | NSDragOperationDelete);

  // Get first object from array
  filePath = [paths objectAtIndex:0];
  parentPath = [filePath stringByDeletingLastPathComponent];

  // Remove Move and Delete operations if `path` is root '/' or
  // directory containing file is not writable.
  if (([paths count] == 1 && [filePath isEqualToString:@"/"]) ||
      ![fileManager isWritableFileAtPath:parentPath]) {
    mask &= ~(NSDragOperationMove | NSDragOperationDelete);
  }

  // Check if files can be read
  for (NSString *path in paths) {
    if (![fileManager isReadableFileAtPath:path]) {
      mask = NSDragOperationNone;
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

  if ([[[viewer class] viewerType] isEqualToString:viewerType])
    return;

  aViewer = [[ModuleLoader shared] viewerForType:viewerType];

  if (aViewer != nil) {
      [self useViewer:aViewer];
    }
  else {
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
  if (![sender isKindOfClass:[PathIcon class]]) {
    sender = [[pathView icons] lastObject];
  }

  // For multiple files:
  // For each type call openFile:fromImage:at:inView with 'image' for first
  // file in list (flying icon) and 'nil' for the rest (no flying icon).
  extensions = [[NSMutableArray new] autorelease];
  for (filePath in [sender paths]) {
    ext = [filePath pathExtension];
    if ([ext isEqualToString:@"app"] == YES ||
        [extensions containsObject:ext] == NO) {
      [extensions addObject:[filePath pathExtension]];
      image = [[NSApp delegate] iconForFile:filePath];
    }
    else {
      image = nil;
    }
      
    if ([[NSApp delegate] openFile:filePath
                         fromImage:image
                                at:NSMakePoint((64-image.size.width)/2, 0)
                            inView:sender] == NO) {
      break;
    }
  }
}

- (void)openAsFolder:(id)sender
{
  NSString   *filePath = [self absolutePath];
  NSString   *wrapperName;
  FileViewer *fv = nil;

  if (selection != nil) { // It's a wrapper - add filename to path
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
