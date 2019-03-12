/*
   Controller.m
   The main app controller.

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

#import <sys/utsname.h>
#import <string.h>
#import <errno.h>

#import <X11/Xlib.h>
#import <GNUstepGUI/GSDisplayServer.h>

#import <NXAppKit/NXAppKit.h>
#import <NXFoundation/NXDefaults.h>
#import <NXSystem/NXSystemInfo.h>
#import <NXSystem/NXMediaManager.h>
#import <NXSystem/NXFileSystemMonitor.h>
#import <NXSystem/NXScreen.h>
#import <NXSystem/NXDisplay.h>
#import <NXSystem/NXPower.h>

#import "Workspace+WindowMaker.h"

#import "Controller.h"
#import "Controller+NSWorkspace.h"

#import "Viewers/FileViewer.h"
#import "Preferences.h"
#import "Launcher.h"
#import "Finder.h"
#import "Recycler.h"

#import "ModuleLoader.h"

#import <Operations/ProcessManager.h>
#import <Operations/Mounter.h>
#import <Processes/Processes.h>

#import <NXAppKit/NXAlert.h>

static NSString *WorkspaceVersion = @"0.8";

//============================================================================
// Notifications 
//============================================================================

// Inspectors
#import "Workspace.h"
NSString *WMFolderSortMethodDidChangeNotification = @"WMFolderSortMethodDidChangeNotification";
NSString *WMFilePermissionsDidChangeNotification = @"WMFilePermissionsDidChangeNotification";
NSString *WMFileOwnerDidChangeNotification = @"WMFileOwnerDidChangeNotification";

static NSString *WMSessionShouldFinishNotification = @"WMSessionShouldFinishNotification";
static NSString *WMComputerShouldGoDownNotification = @"WMComputerShouldGoDownNotification";

@interface Controller (Private)

- (void)_loadViewMenu:(id)viewMenu;
- (void)_loadInpectors;

- (NSString *)_windowServerVersion;
- (void)fillInfoPanelWithSystemInfo;
- (void)_saveWindowsStateAndClose;
- (void)_startSavedApplications;

@end

@implementation Controller (Private)

- (void)_loadViewMenu:(id)viewMenu
{
  NSDictionary *viewerTypes = [[ModuleLoader shared] menuViewerInfo];

  for (NSString *viewerType in [viewerTypes allKeys]) {
    [viewMenu insertItemWithTitle:viewerType
                           action:@selector(setViewerType:)
                    keyEquivalent:[viewerTypes objectForKey:viewerType]
                          atIndex:0];
  }
}

- (void)_loadInpectors
{
  NSString *inspectorsPath;
  NSBundle *inspectorsBundle;
  
  inspectorsPath = [[[NSBundle mainBundle] resourcePath]
                     stringByAppendingPathComponent:@"Inspectors.bundle"];
  
  // NSLog(@"[Controller] Inspectors: %@", inspectorsPath);
  
  inspectorsBundle = [[NSBundle alloc] initWithPath:inspectorsPath];

  // NSLog(@"[Controller] Inspectors Class: %@",
  //       [inspectorsBundle principalClass]);
  inspector = [[[inspectorsBundle principalClass] alloc] init];
}

// TODO: Move to NXSystem framework and enhance
- (NSString *)_windowServerVersion
{
  Display *xDisplay = [GSCurrentServer() serverDevice]; 
  int     vendrel = VendorRelease(xDisplay);

  return [NSString stringWithFormat:@"%s %d.%d.%d",
                   ServerVendor(xDisplay),
                   vendrel / 10000000,
                   (vendrel / 100000) % 100,
                   (vendrel / 1000) % 100];
}

- (void)fillInfoPanelWithSystemInfo
{
  NSString *osVersion;
  NSString *processorType;
  NSString *memorySize;

  [infoPanelImage setImage:[NSApp applicationIconImage]];
  
  [hostName setStringValue:[NXSystemInfo hostName]];

  // Processor:
  processorType = [NSString stringWithFormat:@"%@ @ %@",
                            [NXSystemInfo tidyCPUName],
                            [NXSystemInfo humanReadableCPUSpeed]];
  [cpuType setStringValue:processorType];

  // Memory:
  [memory setStringValue:
            [NSString stringWithFormat:@"%llu MB",
                      [NXSystemInfo realMemory]/1024/1024]];

  // Operating System:
  [osType setStringValue:[NXSystemInfo operatingSystemRelease]];

  // Window Server:
  [wsVersion setStringValue:[NSString stringWithFormat:@"%@", 
                                      [self _windowServerVersion]]];

  // Foundation Kit and AppKit
  // extern char *gnustep_base_version;

  [baseVersion setStringValue:[NSString stringWithFormat:@"%s",
                                        STRINGIFY(GNUSTEP_BASE_VERSION)]];
  [guiVersion setStringValue:[NSString stringWithFormat:@"%s",
                                       STRINGIFY(GNUSTEP_GUI_VERSION)]];
}

#define X_WINDOW(win) (Window)[GSCurrentServer() windowDevice:[(win) windowNumber]]

- (void)_saveWindowsStateAndClose
{
  NSMutableArray *windows = [[NSMutableArray alloc] init];
  NSArray        *_fvs = [NSArray arrayWithArray:fileViewers];
  NSDictionary   *winInfo;
  NSString       *winState, *type;
  FileViewer     *_rootFileViewer;

  // Console
  if (console) {
    winState = WWMWindowState([console window]);
    if (winState) {
      winInfo = @{@"Type":@"Console", @"State":winState};
      [windows addObject:winInfo];
      if ([winState isEqualToString:@"Shaded"]) {
        wUnshadeWindow(wWindowFor(X_WINDOW([console window])));
      }
      [console deactivate];
    }
    [console release];
  }
  // Inspector
  if (inspector && [[inspector window] isVisible]) {
    [inspector deactivateInspector:self];
  }
  // Processes
  if (procPanel && [[procPanel window] isVisible]) {
    [[procPanel window] close];
  }
  // Preferences
  if (preferences)
    [preferences release];
  
  // Finder
  if (finder) {
    winState = WWMWindowState([finder window]);
    if (winState) {
      winInfo = @{@"Type":@"Finder", @"State":winState};
      [windows addObject:winInfo];
      if ([winState isEqualToString:@"Shaded"]) {
        wUnshadeWindow(wWindowFor(X_WINDOW([finder window])));
      }
      [finder deactivate];
    }
    [finder release];
  }
  
  // Viewers
  for (FileViewer *fv in _fvs) {
    winState = WWMWindowState([fv window]);
    if (winState) {
      if ([fv isRootViewer] != NO)
        type = @"RootViewer";
      else
        type = @"FolderViewer";
        
      winInfo = @{@"Type":type,
                  @"ViewerType":[[[fv viewer] class] viewerType],
                  @"State":winState,
                  @"RootPath":[fv rootPath],
                  @"Path":[fv displayedPath],
                  @"Selection":([fv selection]) ? [fv selection] : @[]};
      [windows addObject:winInfo];
      
      if ([winState isEqualToString:@"Shaded"]) {
        wUnshadeWindow(wWindowFor(X_WINDOW([fv window])));
      }
      [[fv window] close];
    }
  }
  
  [[NXDefaults userDefaults] setObject:windows forKey:@"SavedWindows"];
  
  [windows release];
  [fileViewers release];

  NSLog(@"_closeAllFileViewers shared FS monitor RC: %lu",
        [fileSystemMonitor retainCount]);
}

- (void)_restoreWindows
{
  NXDefaults          *df = [NXDefaults userDefaults];
  NSArray             *savedWindows = [df objectForKey:@"SavedWindows"];
  NSMutableArray      *winViews = [NSMutableArray new];
  NSMutableDictionary *winViewInfo;
  NSString            *winType;
  FileViewer          *fv;
  NSWindow            *window;
  NSWindow            *rootViewerWindow = nil;
  BOOL                showFinder = NO;

  // Restore saved windows
  for (NSDictionary *winInfo in savedWindows) {
    
    winType = [winInfo objectForKey:@"Type"];
    
    if ([winType isEqualToString:@"FolderViewer"] ||
        [winType isEqualToString:@"RootViewer"]) {
      
      if ([winType isEqualToString:@"RootViewer"]) {
        fv = [self newViewerRootedAt:@"/"
                              viewer:[winInfo objectForKey:@"ViewerType"]
                              isRoot:YES];
        rootViewerWindow = [fv window];
        rootViewer = fv;
      }
      else {
        fv = [self newViewerRootedAt:[winInfo objectForKey:@"RootPath"]
                              viewer:[winInfo objectForKey:@"ViewerType"]
                              isRoot:NO];
      }
      
      if (fv != nil) {
        [fv displayPath:[winInfo objectForKey:@"Path"]
              selection:[winInfo objectForKey:@"Selection"]
                 sender:self];
      }
      [[fv window] orderFront:nil];
      
      winViewInfo = [NSMutableDictionary dictionaryWithDictionary:winInfo];
      [winViewInfo setObject:[fv window] forKey:@"Window"];
      [winViews addObject:winViewInfo];
      [winViewInfo release];
    }
    else if ([winType isEqualToString:@"Console"]) {
      [self showConsole:self];
      winViewInfo = [NSMutableDictionary dictionaryWithDictionary:winInfo];
      [winViewInfo setObject:[console window] forKey:@"Window"];
      [winViews addObject:winViewInfo];
      [winViewInfo release];
    }
    else if ([winType isEqualToString:@"Finder"]) {
      [self finder];
      winViewInfo = [NSMutableDictionary dictionaryWithDictionary:winInfo];
      [winViewInfo setObject:[finder window] forKey:@"Window"];
      [winViews addObject:winViewInfo];
      [winViewInfo release];
      showFinder = YES;
    }
  }

  if (rootViewerWindow == nil) {
    NXDefaults *df = [NXDefaults userDefaults];

    NSLog(@"No saved root FileViewer window. Open default with viewer type: %@",
          [df objectForKey:@"PreferredViewer"]);
    
    fv = [self newViewerRootedAt:@"/"
                          viewer:[df objectForKey:@"PreferredViewer"]
                          isRoot:YES];
    [fv displayPath:NSHomeDirectory() selection:nil sender:self];
    rootViewerWindow = [fv window];
    [[fv window] orderFront:nil];
  }

  // Restore state of windows
  for (NSDictionary *winInfo in winViews) {
    window = [winInfo objectForKey:@"Window"];
    
    if ([[winInfo objectForKey:@"State"] isEqualToString:@"Miniaturized"]) {
      [window miniaturize:self];
    }
    else if ([[winInfo objectForKey:@"State"] isEqualToString:@"Shaded"]) {
      wShadeWindow(wWindowFor(X_WINDOW(window)));
    }
  }

  if ([rootViewerWindow isMiniaturized] == NO) {
    if (showFinder != NO && [[finder window] isMiniaturized] == NO) {
      [finder setFileViewer:rootViewer];
      [finder activateWithString:@""];
    }
    else {
      [rootViewerWindow makeKeyAndOrderFront:self];
    }
  }
}

- (void)_saveRunningApplications
{
  [[NXDefaults userDefaults] setObject:WWMNotDockedAppList()
                                forKey:@"SavedApplications"];
}

- (void)_startSavedApplications
{
  NSArray *savedApps;
  savedApps = [[NXDefaults userDefaults] objectForKey:@"SavedApplications"];

  for (NSDictionary *appInfo in savedApps) {
    if (WWMIsAppRunning([appInfo objectForKey:@"Name"]) == NO) {
      WWMExecuteCommand([appInfo objectForKey:@"Command"]);
    }
  }
}

- (void)_finishTerminateProcess
{
  // Filesystem monitor
  [fileSystemMonitor pause];
  [fileSystemMonitor terminate];
  // Close and save file viewers, close panels.
  [self _saveWindowsStateAndClose];
  NSLog(@"_finishTerminateProcess fileSystemMonitor RC: %lu",
        [fileSystemMonitor retainCount]);
  if ([fileSystemMonitor retainCount] > 1) {
    [fileSystemMonitor release];
  }

  // Launcher
  if (launcher) {
    [launcher deactivate];
    [launcher release];
  }

  // Close XWindow applications - wipeDesktop?
  
  if (useInternalWindowManager) {
    // Hide Dock
    WWMDockHideIcons(wScreenWithNumber(0)->dock);
    if (recycler) {
      [[recycler appIcon] close];
      [recycler release];
    }
    [workspaceBadge release];
  }
  
  // Media and media manager
  // NSLog(@"NXMediaManager RC:%lu", [mediaManager retainCount]);
  [mediaAdaptor ejectAllRemovables];
  [mediaManager release]; //  mediaAdaptor released also
  [mediaOperations release];

  // NXSystem objects declared in Workspace+WindowMaker.h
  if (useInternalWindowManager) {
    [systemPower stopEventsMonitor];
    [systemPower release];
  }
        
  // Workspace Tools
  TEST_RELEASE(inspector);
  TEST_RELEASE(console);
  TEST_RELEASE(procPanel);
  TEST_RELEASE(procManager);

  // Quit WindowManager, close all X11 applications.
  if (useInternalWindowManager) {
    WWMShutdown(WSKillMode);
    // // Trigger WindowMaker state variable
    // SIG_WCHANGE_STATE(WSTATE_NEED_EXIT);
    // // Generate some event to wake up WindowMaker GCD thread (wmaker_q)
    // XWarpPointer(dpy, None, None, 0, 0, 0, 0, 100, 100);
    // fprintf(stderr, "XWarpPointer called.\n");
  }
}

@end

@implementation Controller

- (FileViewer *)newViewerRootedAt:(NSString *)path
                           viewer:(NSString *)viewerType
                           isRoot:(BOOL)root
{
  NSFileManager *fm = [NSFileManager defaultManager];
  BOOL          isDir;
  FileViewer   *fv;
  
  if ([fm fileExistsAtPath:path isDirectory:&isDir] && isDir) {
    fv = [[FileViewer alloc] initRootedAtPath:path
                                       viewer:viewerType
                                       isRoot:root];
    [fileViewers addObject:fv];
    [fv release];
  }
  else {
    NXRunAlertPanel(_(@"Open as Folder"), _(@"%@ is not a folder."),
                    nil, nil, nil, path);
    return nil;
  }
  
  if (inspector != nil) {
    [inspector revert:fv];
  }
  
  return fv;
}

- (FileViewer *)openNewViewerIfNotExistRootedAt:(NSString *)path
{
  FileViewer *fv;
  NXDefaults *df = [NXDefaults userDefaults];
  
  for (fv in fileViewers) {
    if ([[fv rootPath] isEqualToString:path]) {
      [[fv window] makeKeyAndOrderFront:self];
      return fv;
    }
  }
  
  fv = [self newViewerRootedAt:path
                        viewer:[df objectForKey:@"PreferredViewer"]
                        isRoot:NO];
  [fv displayPath:path selection:nil sender:self];
  [[fv window] makeKeyAndOrderFront:self];
  
  return fv;
}

//============================================================================
// NSApplication delegate 
//============================================================================

- (BOOL)application:(NSApplication *)app openFile:(NSString *)filename
{
  FileViewer *fv;
  NXDefaults *df = [NXDefaults userDefaults];
  
  fv = [self newViewerRootedAt:filename
                        viewer:[df objectForKey:@"PreferredViewer"]
                        isRoot:NO];

  if (fv == nil) {
    return NO;
  }

  [[fv window] makeKeyAndOrderFront:self];
  return YES;
}

- (void)applicationWillFinishLaunching:(NSNotification *)notif
{
  //NSUpdateDynamicServices();
  // [[NSWorkspace sharedWorkspace] findApplications];

  procManager = [ProcessManager shared];

  // ProcessManager created - Workspace is ready to register applications.
  // Show Dock and start applications in it
  if (useInternalWindowManager)
    {
      WDock *dock = wScreenWithNumber(0)->dock;

      [self updateWorkspaceBadge];
      
      // Detect lid close/open events
      systemPower = [NXPower new];
      [systemPower startEventsMonitor];
      [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(lidDidChange:)
               name:NXPowerLidDidChangeNotification
             object:systemPower];
      
      recycler = [[Recycler alloc] initWithDock:dock];
      
      WWMDockAutoLaunch(dock);
    }

  return;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notif
{
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  NSUserDefaults       *df = [NSUserDefaults standardUserDefaults];

  // Initialize private NSWorkspace implementation
  [self initNSWorkspace];

  // Init Workspace's tools
  mediaOperations = [[NSMutableDictionary alloc] init];
  // [self mediaManager];
  fileSystemMonitor = nil;
  console = nil;
  procPanel = nil;
  inspector = nil;

  // Fill menu 'View' with file viewers
  [self _loadViewMenu:[viewMenuItem submenu]];

  // File Viewers and Console
  fileViewers = [[NSMutableArray alloc] init];
  
  // Now we are ready to show windows and menu
  [df setObject:@"NO" forKey:@"NXAutoLaunch"];
  if (WWMIsDockAppAutolaunch(0) != NO) {
    [self _restoreWindows];
    [[NSApp mainMenu] display];
  }
  else {
    [nc addObserver:self
           selector:@selector(activateApplication:)
               name:NSApplicationWillBecomeActiveNotification
             object:NSApp];
  }

  // NXMediaManager
  // For future use
  [nc addObserver:self
         selector:@selector(diskDidAdd:)
             name:NXDiskDisappeared
           object:mediaAdaptor];
  [nc addObserver:self
         selector:@selector(diskDidEject:)
             name:NXDiskDisappeared
           object:mediaAdaptor];
  // Operations
  [nc addObserver:self
         selector:@selector(mediaOperationDidStart:)
             name:NXMediaOperationDidStart
           object:mediaAdaptor];
  [nc addObserver:self
         selector:@selector(mediaOperationDidEnd:)
             name:NXMediaOperationDidEnd
           object:mediaAdaptor];
 
  [mediaAdaptor checkForRemovableMedia];

  if (useInternalWindowManager) {
    WAppIcon *btn = [recycler dockIcon];
    WDock    *dock = wScreenWithNumber(0)->dock;

    if (btn) {
      btn->icon->owner = dock->icon_array[0]->icon->owner;
      btn->main_window = dock->icon_array[0]->main_window;
      [[recycler appIcon] orderFrontRegardless];
    }
  }

  [self _startSavedApplications];
}

- (void)activateApplication:(NSNotification *)aNotification
{
  [[NSNotificationCenter defaultCenter]
      removeObserver:self
                name:NSApplicationWillBecomeActiveNotification
              object:NSApp];
  [self _restoreWindows];
  [[NSApp mainMenu] display];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
  // Log Out -
  // close all running applications, close all windows and panels, unmount all
  // removable media.
  // Power Off - all of the above + tell Login to start power off process after
  // Workspace quit.
  // Log Out and Power Off terminate quitting when some application won't stop,
  // some removable media won't unmount/eject (optional: think).
  switch (NXRunAlertPanel(_(@"Log Out"),
			  _(@"Do you really want to log out?"),
			  _(@"Log out"), _(@"Power off"), _(@"Cancel")))
    {
    case NSAlertDefaultReturn: // Log Out
      isQuitting = YES;
      if ([procManager terminateAllBGOperations] == NO) {
        isQuitting = NO;
        return NO;
      }

      // Save running applications
      [self _saveRunningApplications];
  
      if ([procManager terminateAllApps] == NO) {
        [NSApp activateIgnoringOtherApps:YES];
        NSRunAlertPanel(_(@"Power Off"),
                        _(@"Some application terminate power off process."),
                        _(@"Dismiss"), nil, nil);
        isQuitting = NO;
        return NO;
      }

      // Close Workspace windows, hide Dock, quit WindowMaker
      [self _finishTerminateProcess];
      
      return YES;
      break;
    case NSAlertAlternateReturn: // Power off
      isQuitting = YES;
      if ([procManager terminateAllBGOperations] == NO)
        {
          isQuitting = NO;
          return NO;
        }
        
      // if ([procManager terminateAllApps] == NO)
      //   {
      //     [NSApp activateIgnoringOtherApps:YES];
      //     NSRunAlertPanel(_(@"Power Off"),
      //                     _(@"Some application terminate power off process."),
      //                     _(@"Dismiss"), nil, nil);
      //     isQuitting = NO;
      //     return NO;
      //   }
      
      [self _finishTerminateProcess];
      
      // Tell Login.app to shutdown a computer
      /*	  [[NSDistributedNotificationCenter 
                  notificationCenterForType:GSPublicNotificationCenterType] 
                  postNotificationName:XSComputerShouldGoDown
                  object:@"WorkspaceManager"];*/
      return YES;
      break;
    default:
      NSLog(@"Workspace->Quit->Cancel");
      isQuitting = NO;
      break;
    }

  return NO;
}
- (void)applicationWillTerminate:(NSNotification *)aNotif
{
  NSLog(@"Application will terminate");
  // [NSApp deactivate];
  [[NXDefaults userDefaults] synchronize];
}
  
- (void)activate
{
  if (isQuitting != NO)
    return;
  
  NSLog(@"Activating Workspace from Controller!");
  [NSApp activateIgnoringOtherApps:YES];
}

//============================================================================
// Access to Workspace data via NSApp
//============================================================================
- (FileViewer *)rootViewer
{
  return rootViewer;
}

- (FileViewer *)fileViewerForWindow:(NSWindow *)window
{
  FileViewer *viewer;
  
  if (!fileViewers || ![fileViewers isKindOfClass:[NSArray class]])
    return nil;

  for (viewer in fileViewers) {
    if ([viewer window] == window) {
      break;
    }
  }
  
  return viewer;
}

- (Inspector *)inspectorPanel
{
  return inspector;
}

// First viewer which will call this method bring monitor to life.
// fileSystemMonitor will be released on application termination.
- (NXFileSystemMonitor *)fileSystemMonitor
{
  if (!fileSystemMonitor)
    {
      // Must be released in -dealloc.
      fileSystemMonitor = [NXFileSystemMonitor sharedMonitor];
      
      NSLog(@"[Controller] fileSystemMonitor RC: %lu",
            [fileSystemMonitor retainCount]);
      
      while ([fileSystemMonitor monitorThread] == nil)
        {// wait for event monitor
          [[NSRunLoop currentRunLoop] 
            runMode:NSDefaultRunLoopMode
            beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
        }
      // - Start filesystem event monitor
      [fileSystemMonitor start];
    }
  
  return fileSystemMonitor;
}

- (id<MediaManager>)mediaManager
{
  if (!mediaManager)
    {
      mediaManager = [[NXMediaManager alloc] init];
      mediaAdaptor = [mediaManager adaptor];
    }

  return mediaAdaptor;
}

- (Processes *)processesPanel
{
  return procPanel;
}

- (Recycler *)recycler
{
  return recycler;
}

- (Finder *)finder
{
  if (finder == nil) {
    finder = [[Finder alloc] initWithFileViewer:rootViewer];
  }
  return finder;
}

//============================================================================
// Appicon badges
//============================================================================
- (void)createWorkspaceBadge
{
  workspaceBadge = [[NXIconBadge alloc]
                             initWithPoint:NSMakePoint(5,48)
                                      text:@"0"
                                      font:[NSFont systemFontOfSize:9]
                                 textColor:[NSColor blackColor]
                               shadowColor:[NSColor whiteColor]];
  [[[NSApp iconWindow] contentView] addSubview:workspaceBadge];
  [workspaceBadge release];
  [self updateWorkspaceBadge];
}

- (void)updateWorkspaceBadge
{
  NSString *wsCurrent;

  if ([[NXDefaults userDefaults] boolForKey:@"ShowWorkspaceInDock"])
    {
      if (!workspaceBadge)
        {
          [self createWorkspaceBadge];
        }
      wsCurrent = [NSString stringWithFormat:@"%i",
                            wScreenWithNumber(0)->current_workspace+1];
      [workspaceBadge setStringValue:wsCurrent];
    }
  else
    {
      if (workspaceBadge)
        {
          [workspaceBadge removeFromSuperview];
          workspaceBadge = nil;
        }
    }
}

//============================================================================
// Application menu
//============================================================================

// Info
- (void)showInfoPanel:sender
{
  if (infoPanel == nil)
    {
      [NSBundle loadNibNamed:@"InfoPanel" owner:self];
      [self fillInfoPanelWithSystemInfo];
    }

  [infoPanel makeKeyAndOrderFront:nil];
}

- (void)showLegalPanel:sender
{
  if (legalPanel == nil)
    {
      NSScrollView *sv;
      NSData       *text;
      NSString     *textPath;

      [NSBundle loadNibNamed:@"LegalPanel" owner:self];
      [legalPanel center];
      
      textPath = [[NSBundle mainBundle] pathForResource:@"LegalInformation"
                                                 ofType: @"rtf"];
      text = [NSData dataWithContentsOfFile:textPath];
      [legalText replaceCharactersInRange:NSMakeRange(0, 0)
                                  withRTF:text];
    }
  
  [legalPanel makeKeyAndOrderFront:nil];
}

// TODO
- (void)saveLegalToFile:sender
{
  NSSavePanel * sp = [NSSavePanel savePanel];

  [sp setRequiredFileType: @"rtf"];
  [sp setTitle: _(@"Save Legal Information to File")];

  if ([sp runModal] == NSOKButton)
    {
      if ([[legalText RTFFromRange: NSMakeRange(0,[[legalText string] length])]
            writeToFile:[sp filename]
             atomically: NO] == NO)
        {
          NSRunAlertPanel(_(@"Failed to write file"),
                          nil, nil, nil, nil);
        }
    }
}

- (void)showPrefsPanel:(id)sender
{
  if (!preferences) {
    preferences = [Preferences shared];
  }
  [preferences activate];
}

// File
- (void)newViewer:(id)sender
{
  FileViewer *fv;
  NXDefaults *df = [NXDefaults userDefaults];
  
  fv = [self newViewerRootedAt:@"/"
                        viewer:[df objectForKey:@"PreferredViewer"]
                        isRoot:NO];
  [[fv window] makeKeyAndOrderFront:self];
}

- (void)closeViewer:(id)viewer
{
  NSLog(@"Controller: closeViewer[%lu] (%@)", [viewer retainCount], [viewer rootPath]);
  if ([fileViewers count] > 0) {
    [fileViewers removeObject:viewer];
  }
}

- (void)emptyRecycler:(id)sender
{
  [recycler empty];
}

// Disk
// TODO
- (void)initializeDisk:(id)sender
{
}

- (void)checkForDisks:(id)sender
{
  [mediaAdaptor checkForRemovableMedia];
}

// View
- (void)setViewerType:(id)sender
{
  [[self fileViewerForWindow:[NSApp keyWindow]] setViewerType:sender];
}

- (void)updateViewers:(id)sender
{
  id           viewer;
  NSEnumerator *e = [fileViewers objectEnumerator];

  while((viewer = [e nextObject]))
    {
      [viewer displayPath:nil selection:nil sender:self];
    }
}

// Tools -> Inspector
- (void)showAttributesInspector:sender
{
  if (!inspector)
    {
      [self _loadInpectors];
    }
  [inspector showAttributesInspector:self];
}

- (void)showContentsInspector:sender
{
  if (!inspector)
    {
      [self _loadInpectors];
    }
 [inspector showContentsInspector:self];
}

- (void)showToolsInspector:sender
{
  if (!inspector)
    {
      [self _loadInpectors];
    }
 [inspector showToolsInspector:self];
}

- (void)showPermissionsInspector:sender
{
  if (!inspector)
    {
      [self _loadInpectors];
    }
 [inspector showPermissionsInspector:self];
}

// Tools
- (void)showFinder:(id)sender
{
  [[self finder] activateWithString:@""];
}

- (void)showProcesses:(id)sender
{
  if (!procPanel)
    {
      // NSString *path;
      // NSBundle *bundle;
  
      // path = [[[NSBundle mainBundle] resourcePath]
      //                    stringByAppendingPathComponent:@"Processes.bundle"];
  
      // bundle = [[NSBundle alloc] initWithPath:path];
      // processesPanel = [[[bundle principalClass] alloc] initWithManager:self];
      procPanel = [[Processes alloc] initWithManager:procManager];
    }
  
  [procPanel show];
}

- (void)showConsole:(id)sender
{
  if (console == nil) {
    console = [[Console alloc] init];
  }
  [console activate];
}

- (void)showLauncher:sender
{
  if (launcher == nil) {
    launcher = [[Launcher alloc] init];
  }
  [launcher activate];
}

// Dock
- (void)setDockVisibility:(id)sender
{
  WScreen *scr = wScreenWithNumber(0);

  if ([[sender title] isEqualToString:@"Hide"])
    {
      WWMDockHideIcons(scr->dock);
      wScreenUpdateUsableArea(scr);
      if (!scr->dock->mapped)
        [sender setTitle:@"Show"];
    }
  else
    {
      WWMDockShowIcons(scr->dock);
      wScreenUpdateUsableArea(scr);
      if (scr->dock->mapped)
        [sender setTitle:@"Hide"];
    }
}
- (void)setDockCollapse:(id)sender
{
  WScreen *scr = wScreenWithNumber(0);
  
  if ([[sender title] isEqualToString:@"Collapse"]) {
    WWMDockCollapse(scr->dock);
    if (scr->dock->collapsed) {
      [sender setTitle:@"Uncollapse"];
    }
  }
  else {
    WWMDockUncollapse(scr->dock);
    if (!scr->dock->collapsed) {
      [sender setTitle:@"Collapse"];
    }
  }  
}

// Icon Yard
- (void)setIconYardVisibility:(id)sender
{
  WScreen *scr = wScreenWithNumber(0);

  if ([[sender title] isEqualToString:@"Hide"]) {
    WWMIconYardHideIcons(scr);
    // wScreenUpdateUsableArea(scr);
    // if (!scr->dock->mapped)
    [sender setTitle:@"Show"];
  }
  else {
    WWMIconYardShowIcons(scr);
    // wScreenUpdateUsableArea(scr);
    // if (scr->dock->mapped)
    [sender setTitle:@"Hide"];
  }
}

//--- Validation
- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem
{
  NSString   *menuTitle = [[menuItem menu] title];
  FileViewer *fileViewer;
  NSString   *selectedPath;

  if (isQuitting != NO)
    return NO;
  
  fileViewer = [self fileViewerForWindow:[NSApp keyWindow]];
  if (fileViewer) {
    selectedPath = [fileViewer absolutePath];
  }
  // NSLog(@"Validate menu: %@ item: %@", menuTitle, [menuItem title]);

  if ([menuTitle isEqualToString:@"File"]) {
    if ([[menuItem title] isEqualToString:@"Empty Recycler"]) {
      if (!recycler || [recycler itemsCount] == 0) {
        return NO;
      }
    }
  }
  else if ([menuTitle isEqualToString:@"Dock"]) {
    if ([[menuItem title] isEqualToString:@"Collapse"] ||
        [[menuItem title] isEqualToString:@"Uncollapse"]) {
      if (!wScreenWithNumber(0)->dock->mapped) {
        return NO;
      }
    }
    if ([[menuItem title] isEqualToString:@"Hide"] &&
        !wScreenWithNumber(0)->dock->mapped) {
      [menuItem setTitle:@"Show"];
    }
  }
  else if ([menuTitle isEqualToString:@"Icon Yard"]) {
    if ([[menuItem title] isEqualToString:@"Hide"] &&
        !wScreenWithNumber(0)->flags.icon_yard_mapped) {
      [menuItem setTitle:@"Show"];
    }
  }
  else if ([menuTitle isEqualToString:@"Disk"]) {
    if ([[menuItem title] isEqualToString:@"Initialize..."])
      return NO;
    if ([[menuItem title] isEqualToString:@"Check For Disks"] && !mediaAdaptor)
      return NO;
  }
  else if ([menuTitle isEqualToString:@"View"]) {
    if ([[menuItem title] isEqualToString:[[[fileViewer viewer] class] viewerType]]) {
      return NO;
    }
  }
  else if ([menuTitle isEqualToString:@"Inspector"]) {
      if (!fileViewer) {
        if ([[menuItem title] isEqualToString:@"Attributes"]) return NO;
        if ([[menuItem title] isEqualToString:@"Contents"]) return NO;
        if ([[menuItem title] isEqualToString:@"Tools"]) return NO;
        if ([[menuItem title] isEqualToString:@"Permissions"]) return NO;
      }
  }

  return YES;
}

//============================================================================
// NXMediaManager events (alert panels, Processes-Background updates).
//============================================================================
- (void)diskDidAdd:(NSNotification *)notif
{
  // Placeholder for actions to show devices
}

- (void)diskDidEject:(NSNotification *)notif
{
  // Placeholder for actions to hide devices
}

- (void)mediaOperationDidStart:(NSNotification *)notif
{
  NSDictionary *info = [notif userInfo];

  if ([[info objectForKey:@"Success"] isEqualToString:@"false"])
    {
      [NSApp activateIgnoringOtherApps:YES];
      NSRunAlertPanel([info objectForKey:@"Title"],
                      [info objectForKey:@"Message"],
                      nil, nil, nil);
    }
  else
    {
      Mounter *bgop = [[Mounter alloc] initWithInfo:info];
      
      [mediaOperations setObject:bgop forKey:[bgop source]];
      [bgop release];
      
      NSLog(@"[Contoller media-start] <%@> %@ [%@]",
            [info objectForKey:@"Title"],
            [info objectForKey:@"Message"],
            [bgop source]);
   }
}

- (void)mediaOperationDidEnd:(NSNotification *)notif
{
  NSDictionary *info = [notif userInfo];
  NSString     *source = [info objectForKey:@"UNIXDevice"];
  Mounter      *bgop = [mediaOperations objectForKey:source];

  if ([[info objectForKey:@"Success"] isEqualToString:@"false"] && bgop)
    {
      [bgop destroyOperation:info];
    }
  else if (bgop)
    {
      if (isQuitting)
        {
          [bgop destroyOperation:info];
        }
      else
        {
          [bgop finishOperation:info];
        }
      [mediaOperations removeObjectForKey:source];
    }
  else // probably disk ejected without unmounting
    {
      [NSApp activateIgnoringOtherApps:YES];
      NSRunAlertPanel([info objectForKey:@"Title"],
                      [info objectForKey:@"Message"],
                      nil, nil, nil);
    }
      
  NSLog(@"[Contoller media-end] <%@> %@ [%@]",
        [info objectForKey:@"Title"],
        [info objectForKey:@"Message"],
        source);
}

//============================================================================
// NXScreen events
//============================================================================
- (void)lidDidChange:(NSNotification *)aNotif
{
  NXDisplay *builtinDisplay = nil;
  NXScreen  *screen = [NXScreen new];

  for (NXDisplay *d in [screen connectedDisplays])
    {
      if ([d isBuiltin])
        {
          builtinDisplay = d;
          break;
        }
    }
  
  if (builtinDisplay)
    {
      if (![systemPower isLidClosed] && ![builtinDisplay isActive])
        {
          NSLog(@"Workspace: activating display %@",
                [builtinDisplay outputName]);
          [screen activateDisplay:builtinDisplay];
        }
      else if ([systemPower isLidClosed] && [builtinDisplay isActive])
        {
          NSLog(@"Workspace: DEactivating display %@",
                [builtinDisplay outputName]);
          [screen deactivateDisplay:builtinDisplay];
        }
    }
  [screen release];
}

//============================================================================
// WindowMaker events
//============================================================================
- (void)showWMAlert:(NSMutableDictionary *)alertInfo
{
  NSInteger result;
  
  // NSLog(@"WMShowAlertPanel thread: %@ (main: %@) mode: %@", [NSThread currentThread],
  //       [NSThread mainThread], [[NSRunLoop currentRunLoop] currentMode]);

  result = NXRunAlertPanel([alertInfo objectForKey:@"Title"],
                           [alertInfo objectForKey:@"Message"],
                           [alertInfo objectForKey:@"DefaultButton"],
                           [alertInfo objectForKey:@"AlternateButton"],
                           [alertInfo objectForKey:@"OtherButton"]);
  [alertInfo setObject:[NSNumber numberWithInt:result] forKey:@"Result"];
}

@end
