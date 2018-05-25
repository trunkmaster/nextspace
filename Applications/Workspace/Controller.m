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
NSString *WMFolderSortMethodDidChangeNotification =
  @"WMFolderSortMethodDidChangeNotification";
NSString *WMFilePermissionsDidChangeNotification =
  @"WMFilePermissionsDidChangeNotification";
NSString *WMFileOwnerDidChangeNotification =
  @"WMFileOwnerDidChangeNotification";

static NSString *WMSessionShouldFinishNotification =
  @"WMSessionShouldFinishNotification";
static NSString *WMComputerShouldGoDownNotification =
  @"WMComputerShouldGoDownNotification";

@interface Controller (Private)

- (void)_loadViewMenu:(id)viewMenu;
- (void)_loadInpectors;

- (NSString *)_windowServerVersion;
- (void)fillInfoPanelWithSystemInfo;
- (void)_closeAllFileViewers;

@end

@implementation Controller (Private)

- (void)_loadViewMenu:(id)viewMenu
{
  NSDictionary *viewerTypes;
  NSEnumerator *e;
  NSString     *viewerType;
  NSArray      *viewerTypeNames;

  viewerTypes = [[ModuleLoader shared] menuViewerInfo];
  /*  viewerTypeNames = [[viewerTypes allKeys] sortedArrayUsingSelector:
						      @selector(compare:)];*/
  viewerTypeNames = [viewerTypes allKeys];
  e = [viewerTypeNames objectEnumerator];
  while ((viewerType = [e nextObject]) != nil)
    {
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

// TODO: Move to SystemConfig framework and enhance
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

- (void)_closeAllFileViewers
{
  NSArray      *_fvs = [fileViewers copy];
  NSEnumerator *_e = [_fvs objectEnumerator];
  FileViewer   *_fileViewer;
  FileViewer   *_rootFileViewer;
  
  NSMutableArray *viewers = [NSMutableArray new];
  NSDictionary   *vInfo;

  // To remove NXFileSystem's event monitor path correctly
  // first close all folder viewers (while catching root viewer)...
  while ((_fileViewer = [_e nextObject]))
    {
      if ([_fileViewer isRootViewer])
	{
	  _rootFileViewer = _fileViewer;
	}
      else
	{
          if ([_fileViewer isFolderViewer])
            {
              vInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [_fileViewer rootPath], @"RootPath",
                                    [_fileViewer displayedPath], @"Path",
                                    [_fileViewer selection], @"Selection",
                                    nil];
              [viewers addObject:vInfo];
            }
	  [[_fileViewer window] close];
	}
    }
  [[NXDefaults userDefaults] setObject:viewers forKey:@"SavedViewers"];

  // ...and filnally close left root viewer
  [[_rootFileViewer window] close];

  NSLog(@"_closeAllFileViewers shared FS monitor RC: %lu",
        [fileSystemMonitor retainCount]);

  [_fvs release];
  [fileViewers release];
}

- (void)_closeWindows
{
  NXDefaults          *xud = [NXDefaults userDefaults];
  NSMutableArray      *panels = [NSMutableArray new];
  // NSMutableDictionary *viewers = [NSMutableDictionary new];
  
  // 1. Close panels: Processes, Inspector, Console, Finder.
  //    For Processes and Inspector save opened section (mode).
  if (console && [[console window] isVisible])
    {
      [[NXDefaults userDefaults] setBool:YES forKey:@"OpenConsoleAtStart"];
      [console deactivate];
    }
  else
    {
      [[NXDefaults userDefaults] setBool:NO forKey:@"OpenConsoleAtStart"];
    }
  if (inspector && [[inspector window] isVisible])
    {
      [inspector deactivateInspector:self];
    }
  if (procPanel && [[procPanel window] isVisible])
    {
      [[procPanel window] close];
    }
  
  // 2. Close FileViewers and save their 'rootPath'.
  [self _closeAllFileViewers];
}

- (void)_restoreWindows
{
  NXDefaults *xud = [NXDefaults userDefaults];
  NSArray    *viewers;
  FileViewer *fv;
  NSArray    *panels;

  // Open root viewer
  fileViewers = [[NSMutableArray alloc] init];
  rootViewer = [[FileViewer alloc] initRootedAtPath:@"/" 
					   asFolder:NO
					     isRoot:YES];
  [fileViewers addObject:rootViewer];
  [rootViewer release];

  // Restore folder viewers
  viewers = [xud objectForKey:@"SavedViewers"];
  for (NSDictionary *vInfo in viewers)
    {
      fv = [self openNewViewerRootedAt:[vInfo objectForKey:@"RootPath"]];
      [fv displayPath:[vInfo objectForKey:@"Path"]
            selection:[vInfo objectForKey:@"Selection"]
               sender:self];
    }

  if ([xud boolForKey:@"OpenConsoleAtStart"])
    {
      [self showConsole:self];
    }
}

- (void)_finishTerminateProcess
{
  // Close and save file viewers, close panels.
  [self _closeWindows];

  // Close XWindow applications - wipeDesktop?
  
  if (useInternalWindowManager)
    {
      // Hide Dock
      WWMDockHideIcons(wScreenWithNumber(0)->dock);
      if (wmRecycler)
        {
          [wmRecycler close];
          [wmRecycler release];
        }
    }
  
  // NSLog(@"Application should terminate fileSystemMonitor RC: %lu",
  //       [fileSystemMonitor retainCount]);
  // Filesystem monitor
  [fileSystemMonitor pause];
  [fileSystemMonitor terminate];
  if ([fileSystemMonitor retainCount] > 1) [fileSystemMonitor release];

  // Media and media manager
  // NSLog(@"NXMediaManager RC:%lu", [mediaManager retainCount]);
  [mediaAdaptor ejectAllRemovables];
  [mediaManager release]; //  mediaAdaptor released also
  [mediaOperations release];

  // NXSystem objects declared in Workspace+WindowMaker.h
  if (useInternalWindowManager)
    {
      [systemPower stopEventsMonitor];
      [systemPower release];
    }
        
  // Workspace Tools
  TEST_RELEASE(inspector);
  TEST_RELEASE(console);
  TEST_RELEASE(procPanel);
  TEST_RELEASE(procManager);
  
  // Quit WindowManager, close all X11 applications.
  if (useInternalWindowManager)
    {
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

- (FileViewer *)openNewViewerRootedAt:(NSString *)path
{
  NSFileManager *fm = [NSFileManager defaultManager];
  BOOL          isDir;
  FileViewer   *fv;
  
  if ([fm fileExistsAtPath:path isDirectory:&isDir] && isDir)
    {
      fv = [[FileViewer alloc] initRootedAtPath:path asFolder:YES isRoot:NO];
      [fileViewers addObject:fv];
    }
  else
    {
      NSRunAlertPanel(_(@"Open as Folder"),
  		      _(@"%@ is not a folder."),
		      nil, nil, nil, path);
      return nil;
    }
  
  if (inspector != nil)
    {
      [inspector revert:fv];
    }
  
  return [fv autorelease];
}

- (FileViewer *)openNewViewerIfNotExistRootedAt:(NSString *)path
{
  NSEnumerator *e = [fileViewers objectEnumerator];
  FileViewer   *fv;

  while ((fv = [e nextObject]) != nil)
    {
      if ([[fv rootPath] isEqualToString:path])
        {
          [[fv window] makeKeyAndOrderFront:self];
          return fv;
        }
    }

  return [self openNewViewerRootedAt:path];
}

//============================================================================
// NSApplication delegate 
//============================================================================

- (BOOL)application:(NSApplication *)app openFile:(NSString *)filename
{
  if ([self openNewViewerRootedAt:filename] == nil)
    {
      return NO;
    }
  
  return YES;
}

#include <startup.h>
- (void)applicationWillFinishLaunching:(NSNotification *)notif
{
  //NSUpdateDynamicServices();
  //[[NSWorkspace sharedWorkspace] findApplications];

  procManager = [ProcessManager shared];

  // ProcessManager created - Workspace is ready to register applications.
  // Show Dock and start applications in it
  if (useInternalWindowManager)
    {
      // WWMDockShowIcons(dock);
      // wDockDoAutoLaunch(wScreenWithNumber(0)->dock, 0);
      // WWMDockAutoLaunch(dock);
    }
  
  if (useInternalWindowManager)
    {
      WDock *dock = wScreenWithNumber(0)->dock;
      
      // Detect lid close/open events
      systemPower = [NXPower new];
      [systemPower startEventsMonitor];
      [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(lidDidChange:)
               name:NXPowerLidDidChangeNotification
             object:systemPower];
      
      wmRecycler = [[RecyclerIcon alloc] initWithDock:dock];
      WWMDockAutoLaunch(dock);
    }
  
  return;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notif
{
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  NXDefaults           *df = [NXDefaults userDefaults];

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
  [self _restoreWindows];

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

  if (useInternalWindowManager)
    {
      WAppIcon *btn = [wmRecycler dockIcon];

      btn->icon->owner = btn->dock->icon_array[0]->icon->owner;
      [wmRecycler orderFrontRegardless];
    }
}


#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
#else
- (BOOL)applicationShouldTerminate:(id)sender
#endif
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
      if ([procManager terminateAllBGOperations] == NO)
        {
          isQuitting = NO;
          return NO;
        }

      if ([procManager terminateAllApps] == NO)
        {
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

//============================================================================
// Access to Workspace data via NSApp
//============================================================================
- (FileViewer *)rootViewer
{
  return rootViewer;
}

- (FileViewer *)fileViewerForWindow:(NSWindow *)window
{
  NSEnumerator *e = [fileViewers objectEnumerator];
  FileViewer   *viewer = nil;

  // NSLog(@"Controller fileViewerForWindow");

  while ((viewer = [e nextObject]))
    {
      if ([viewer window] == window)
        {
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

- (RecyclerIcon *)recyclerIcon
{
  return wmRecycler;
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
  [[Preferences shared] activate];
}

// File
- (void)newViewer:(id)sender
{
  FileViewer *fv = [[FileViewer alloc] initRootedAtPath:@"/"
			    		       asFolder:NO
				    		 isRoot:NO];
  [fileViewers addObject:fv];
  [fv release];
}

- (void)closeViewer:(id)viewer
{
  NSLog(@"Controller: closeViewer[%lu]", [viewer retainCount]);
  [fileViewers removeObject:viewer];
}

- (void)emptyRecycler:(id)sender
{
  /* insert your code here */
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
//  [[Finder shared] activate];
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
  if (console == nil)
    {
      console = [[Console alloc] init];
    }
  [console activate];
}

- (void)showLauncher:sender
{
  NSLog(@"Init and show \"Run Command\" panel");
  [[Launcher shared] activate];
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
  
  if ([[sender title] isEqualToString:@"Collapse"])
    {
      WWMDockCollapse(scr->dock);
      if (scr->dock->collapsed)
        [sender setTitle:@"Uncollapse"];
    }
  else
    {
      WWMDockUncollapse(scr->dock);
      if (!scr->dock->collapsed)
        [sender setTitle:@"Collapse"];
    }
  
}

//--- Validation
- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem
{
  NSString   *menuTitle = [[menuItem menu] title];
  FileViewer *fileViewer = [self fileViewerForWindow:[NSApp keyWindow]];
  NSString   *selectedPath = [fileViewer absolutePath];

  // NSLog(@"Validate menu: %@ item: %@", menuTitle, [menuItem title]);

  if ([menuTitle isEqualToString:@"File"])
    {
      // Not implemented yet
      if ([[menuItem title] isEqualToString:@"Empty Recycler"]) return NO;
    }
  
  if ([menuTitle isEqualToString:@"Disk"])
    {
      if ([[menuItem title] isEqualToString:@"Initialize..."]) return NO;
      if ([[menuItem title] isEqualToString:@"Check For Disks"] &&
          !mediaAdaptor) return NO;
    }

  if ([menuTitle isEqualToString:@"Inspector"])
    {
      if (!fileViewer)
        {
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

@end
