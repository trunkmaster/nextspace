//
// Project: Workspace
//
// Copyright (C) 2014-2021 Sergii Stoian
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

#import <errno.h>
#import <string.h>
#import <sys/utsname.h>

#import <GNUstepGUI/GSDisplayServer.h>
#import <X11/Xlib.h>

#include <core/log_utils.h>
#include <core/string_utils.h>

#import <DesktopKit/DesktopKit.h>
#import <DesktopKit/NXTHelpPanel.h>

#import <SystemKit/OSEDisplay.h>
#import <SystemKit/OSEFileSystemMonitor.h>
#import <SystemKit/OSEKeyboard.h>
#import <SystemKit/OSEMediaManager.h>
#import <SystemKit/OSEPower.h>
#import <SystemKit/OSEScreen.h>
#import <SystemKit/OSESystemInfo.h>

#include "CoreFoundationBridge.h"
#import "Workspace+WM.h"

#import "Application.h"
#import "Controller+NSWorkspace.h"
#import "Controller.h"

#import "Finder.h"
#import "Launcher.h"
#import "Preferences.h"
#import "Recycler.h"
#import "Viewers/FileViewer.h"

#import "ModuleLoader.h"

#import "WMNotificationCenter.h"

#import <Operations/Mounter.h>
#import <Processes/ProcessManager.h>
#import <Processes/Processes.h>

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

- (NSString *)_stateForWindow:(NSWindow *)nsWindow;
- (NSArray *)_undockedApplicationsList;
- (BOOL)_isApplicationRunning:(NSString *)appName;
- (pid_t)_executeCommand:(NSString *)command;
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

  inspectorsPath =
      [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Inspectors.bundle"];

  // NSLog(@"[Controller] Inspectors: %@", inspectorsPath);

  inspectorsBundle = [[NSBundle alloc] initWithPath:inspectorsPath];

  // NSLog(@"[Controller] Inspectors Class: %@",
  //       [inspectorsBundle principalClass]);
  inspector = [[[inspectorsBundle principalClass] alloc] init];
}

// TODO: Move to SystemKit framework and enhance
- (NSString *)_windowServerVersion
{
  Display *xDisplay = [GSCurrentServer() serverDevice];
  int vendrel = VendorRelease(xDisplay);

  return [NSString stringWithFormat:@"%s %d.%d.%d", ServerVendor(xDisplay), vendrel / 10000000,
                                    (vendrel / 100000) % 100, (vendrel / 1000) % 100];
}

- (void)fillInfoPanelWithSystemInfo
{
  NSString *osVersion;
  NSString *processorType;
  NSString *memorySize;
  NSString *backendContext;

  [infoPanelImage setImage:[NSApp applicationIconImage]];

  [hostName setStringValue:[OSESystemInfo hostName]];

  // Processor:
  processorType = [NSString stringWithFormat:@"%@ @ %@", [OSESystemInfo tidyCPUName],
                                             [OSESystemInfo humanReadableCPUSpeed]];
  [cpuType setStringValue:processorType];

  // Memory:
  [memory setStringValue:[NSString stringWithFormat:@"%llu MB",
                                                    [OSESystemInfo realMemory] / 1024 / 1024]];

  // Operating System:
  [osType setStringValue:[OSESystemInfo operatingSystemRelease]];

  // Window Server:
  [wsVersion setStringValue:[NSString stringWithFormat:@"%@", [self _windowServerVersion]]];

  // Foundation Kit and AppKit
  [baseVersion setStringValue:[NSString stringWithFormat:@"%s", STRINGIFY(GNUSTEP_BASE_VERSION)]];
  backendContext = [[[[NSApp mainWindow] graphicsContext] className]
      stringByReplacingOccurrencesOfString:@"Context"
                                withString:@""];
  [guiVersion setStringValue:[NSString stringWithFormat:@"%s (%@)", STRINGIFY(GNUSTEP_GUI_VERSION),
                                                        backendContext]];
}

#define X_WINDOW(win) (Window)[GSCurrentServer() windowDevice:[(win) windowNumber]]

- (void)_saveWindowsStateAndClose
{
  NSMutableArray *windows = [[NSMutableArray alloc] init];
  NSArray *_fvs = [NSArray arrayWithArray:fileViewers];
  NSDictionary *winInfo;
  NSString *winState, *type;
  FileViewer *_rootFileViewer;

  // Console
  if (console) {
    winState = [self _stateForWindow:[console window]];
    if (winState) {
      winInfo = @{@"Type" : @"Console", @"State" : winState};
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
    [inspector release];
  }

  // Processes Panel & Process Manager
  TEST_RELEASE(procManager);
  TEST_RELEASE(procPanel);

  // Preferences
  TEST_RELEASE(preferences);

  // Finder
  if (finder) {
    winState = [self _stateForWindow:[finder window]];
    if (winState) {
      winInfo = @{@"Type" : @"Finder", @"State" : winState};
      [windows addObject:winInfo];
      if ([winState isEqualToString:@"Shaded"]) {
        wUnshadeWindow(wWindowFor(X_WINDOW([finder window])));
      }
      [finder deactivate];
    }
    [finder release];
  }

  // Info
  if (infoPanel) {
    [infoPanel close];
    [infoPanel release];
  }

  // Legal
  if (legalPanel) {
    [legalPanel close];
    [legalPanel release];
  }

  // Launcher
  if (launcher) {
    [launcher deactivate];
    [launcher release];
  }

  // Viewers
  for (FileViewer *fv in _fvs) {
    winState = [self _stateForWindow:[fv window]];
    if (winState) {
      if ([fv isRootViewer] != NO) {
        type = @"RootViewer";
      } else {
        type = @"FolderViewer";
      }
      winInfo = @{
        @"Type" : type,
        @"ViewerType" : [[[fv viewer] class] viewerType],
        @"State" : winState,
        @"RootPath" : [fv rootPath],
        @"Path" : [fv displayedPath],
        @"Selection" : ([fv selection]) ? [fv selection] : @[]
      };
      [windows addObject:winInfo];
      [winInfo release];

      if ([winState isEqualToString:@"Shaded"]) {
        wUnshadeWindow(wWindowFor(X_WINDOW([fv window])));
      }
      [[fv window] close];
    }
  }

  [[NXTDefaults userDefaults] setObject:windows forKey:@"SavedWindows"];

  [windows release];
  [fileViewers release];

  NSDebugLLog(@"Memory", @"_closeAllFileViewers shared FS monitor RC: %lu",
              [fileSystemMonitor retainCount]);
}

- (void)_restoreWindows
{
  NXTDefaults *df = [NXTDefaults userDefaults];
  NSArray *savedWindows = [df objectForKey:@"SavedWindows"];
  NSMutableArray *winViews = [NSMutableArray new];
  NSMutableDictionary *winViewInfo;
  NSString *winType;
  FileViewer *fv;
  NSWindow *window;
  NSWindow *rootViewerWindow = nil;
  BOOL showFinder = NO;

  // Restore saved windows
  for (NSDictionary *winInfo in savedWindows) {
    winType = [winInfo objectForKey:@"Type"];

    if ([winType isEqualToString:@"FolderViewer"] || [winType isEqualToString:@"RootViewer"]) {
      if ([winType isEqualToString:@"RootViewer"]) {
        fv = [self newViewerRootedAt:@"/" viewer:[winInfo objectForKey:@"ViewerType"] isRoot:YES];
        rootViewerWindow = [fv window];
        rootViewer = fv;
      } else {
        fv = [self newViewerRootedAt:[winInfo objectForKey:@"RootPath"]
                              viewer:[winInfo objectForKey:@"ViewerType"]
                              isRoot:NO];
      }

      if (fv != nil) {
        [fv displayPath:[winInfo objectForKey:@"Path"]
              selection:[winInfo objectForKey:@"Selection"]
                 sender:self];
      }
      [[fv window] makeKeyAndOrderFront:nil];

      winViewInfo = [NSMutableDictionary dictionaryWithDictionary:winInfo];
      [winViewInfo setObject:[fv window] forKey:@"Window"];
      [winViews addObject:winViewInfo];
      [winViewInfo release];
    } else if ([winType isEqualToString:@"Console"]) {
      [self showConsole:self];
      winViewInfo = [NSMutableDictionary dictionaryWithDictionary:winInfo];
      [winViewInfo setObject:[console window] forKey:@"Window"];
      [winViews addObject:winViewInfo];
      [winViewInfo release];
    } else if ([winType isEqualToString:@"Finder"]) {
      [self finder];
      winViewInfo = [NSMutableDictionary dictionaryWithDictionary:winInfo];
      [winViewInfo setObject:[finder window] forKey:@"Window"];
      [winViews addObject:winViewInfo];
      [winViewInfo release];
      showFinder = YES;
    }
  }

  if (rootViewerWindow == nil) {
    NXTDefaults *df = [NXTDefaults userDefaults];

    WMLogWarning("No saved root FileViewer window. Open default with viewer type: %@",
                 convertNStoCF([df objectForKey:@"PreferredViewer"]));

    fv = [self newViewerRootedAt:@"/" viewer:[df objectForKey:@"PreferredViewer"] isRoot:YES];
    [fv displayPath:NSHomeDirectory() selection:nil sender:self];
    rootViewerWindow = [fv window];
    rootViewer = fv;
    [[fv window] makeKeyAndOrderFront:self];
  }

  // Restore state of windows
  for (NSDictionary *winInfo in winViews) {
    window = [winInfo objectForKey:@"Window"];

    if ([[winInfo objectForKey:@"State"] isEqualToString:@"Miniaturized"]) {
      [window miniaturize:self];
    } else if ([[winInfo objectForKey:@"State"] isEqualToString:@"Shaded"]) {
      wShadeWindow(wWindowFor(X_WINDOW(window)));
    }
  }

  if ([rootViewerWindow isMiniaturized] == NO) {
    if (showFinder != NO && [[finder window] isMiniaturized] == NO) {
      [finder setFileViewer:rootViewer];
      [finder activateWithString:@""];
    }
  }
}

- (void)_saveRunningApplications
{
  [[NXTDefaults userDefaults] setObject:[self _undockedApplicationsList]
                                 forKey:@"SavedApplications"];
}

- (void)_startSavedApplications
{
  NSArray *savedApps;
  savedApps = [[NXTDefaults userDefaults] objectForKey:@"SavedApplications"];

  for (NSDictionary *appInfo in savedApps) {
    if ([self _isApplicationRunning:[appInfo objectForKey:@"Name"]] == NO) {
      [self _executeCommand:[appInfo objectForKey:@"Command"]];
    }
  }
}

- (void)_finishTerminateProcess
{
  // Filesystem monitor
  if (fileSystemMonitor) {
    [fileSystemMonitor pause];
    [fileSystemMonitor terminate];
  }

  // We don't need to handle events on quit.
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  // Not need to remove observers explicitely for NSWorkspaceCenter.
  [_windowManagerCenter release];

  // Close and save file viewers, close panels.
  [self _saveWindowsStateAndClose];

  // Quit Window Manager - stop runloop and make cleanup
  // wShutdown(WMExitMode);

  // Hide Dock
  wDockHideIcons(wDefaultScreen()->dock);
  if (recycler) {
    [[recycler appIcon] close];
    [recycler release];
  }
  [workspaceBadge release];

  // Media and media manager
  // NSLog(@"OSEMediaManager RC:%lu", [mediaManager retainCount]);
  [mediaAdaptor ejectAllRemovables];
  [mediaManager release];  //  mediaAdaptor released also
  [mediaOperations release];

  // NXTSystem objects declared in Workspace+WM.h
  [systemPower stopEventsMonitor];
  [systemPower release];

  // System Beep
  if (bellSound) {
    [bellSound stop];
    [bellSound release];
  }

  // Controller (NSWorkspace) objects
  TEST_RELEASE(_wrappers);
  TEST_RELEASE(_iconMap);
  TEST_RELEASE(_launched);
  TEST_RELEASE(_appListPath);
  TEST_RELEASE(_applications);
  TEST_RELEASE(_extPrefPath);
  TEST_RELEASE(_extPreferences);

  [[NXTDefaults userDefaults] synchronize];

  // Quit NSApplication runloop
  [NSApp stop:self];
}

- (NSString *)_stateForWindow:(NSWindow *)nsWindow
{
  WWindow *wWin = wWindowFor(X_WINDOW(nsWindow));

  if (!wWin)
    return nil;

  if (wWin->flags.miniaturized) {
    return @"Miniaturized";
  } else if (wWin->flags.shaded) {
    return @"Shaded";
  } else if (wWin->flags.hidden) {
    return @"Hidden";
  } else {
    return @"Normal";
  }
}
- (NSArray *)_undockedApplicationsList
{
  NSMutableArray *appList = [[NSMutableArray alloc] init];
  NSString *appName;
  NSString *appCommand;
  WAppIcon *appIcon;
  char *command = NULL;

  appIcon = wDefaultScreen()->app_icon_list;
  while (appIcon->next) {
    if (!strcmp(appIcon->wm_class, "GNUstep") && !strcmp(appIcon->wm_instance, "Login")) {
      appIcon = appIcon->next;
      continue;
    }
    if (!appIcon->flags.docked) {
      if (appIcon->command && appIcon->command != NULL) {
        command = wstrdup(appIcon->command);
      }
      if (command == NULL && appIcon->icon->owner != NULL) {
        command = wGetCommandForWindow(appIcon->icon->owner->client_win);
      }
      if (command != NULL) {
        appName =
            [[NSString alloc] initWithFormat:@"%s.%s", appIcon->wm_instance, appIcon->wm_class];
        appCommand = [[NSString alloc] initWithCString:command];
        [appList addObject:@{@"Name" : appName, @"Command" : appCommand}];
        [appName release];
        [appCommand release];
        wfree(command);
        command = NULL;
      } else {
        NSLog(@"Application `%s.%s` was not saved. No application command found.",
              appIcon->wm_instance, appIcon->wm_class);
      }
    }
    appIcon = appIcon->next;
  }

  return [appList autorelease];
}
- (BOOL)_isApplicationRunning:(NSString *)appName
{
  NSArray *nameComps = [appName componentsSeparatedByString:@"."];
  char *app_instance = (char *)[[nameComps objectAtIndex:0] cString];
  char *app_class = (char *)[[nameComps objectAtIndex:1] cString];
  BOOL isAppFound = NO;
  WAppIcon *appIcon;

  appIcon = wDefaultScreen()->app_icon_list;
  while (appIcon->next) {
    if (!strcmp(app_instance, appIcon->wm_instance) && !strcmp(app_class, appIcon->wm_class)) {
      isAppFound = YES;
      break;
    }
    appIcon = appIcon->next;
  }

  return isAppFound;
}

- (pid_t)_executeCommand:(NSString *)command
{
  WScreen *scr = wDefaultScreen();
  pid_t pid;
  char **argv;
  int argc;

  wtokensplit((char *)[command cString], &argv, &argc);

  if (!argc) {
    return 0;
  }

  pid = fork();
  if (pid == 0) {
    char **args;
    int i;

    args = malloc(sizeof(char *) * (argc + 1));
    if (!args)
      exit(111);
    for (i = 0; i < argc; i++) {
      args[i] = argv[i];
    }

    sigset_t sigs;
    sigfillset(&sigs);
    sigprocmask(SIG_UNBLOCK, &sigs, NULL);

    args[argc] = NULL;
    execvp(argv[0], args);
    exit(111);
  }
  while (argc > 0) {
    wfree(argv[--argc]);
  }
  wfree(argv);

  return pid;
}

@end

@implementation Controller

- (FileViewer *)newViewerRootedAt:(NSString *)path viewer:(NSString *)viewerType isRoot:(BOOL)root
{
  NSFileManager *fm = [NSFileManager defaultManager];
  BOOL isDir;
  FileViewer *fv;

  if ([fm fileExistsAtPath:path isDirectory:&isDir] && isDir) {
    fv = [[FileViewer alloc] initRootedAtPath:path viewer:viewerType isRoot:root];
    [fileViewers addObject:fv];
    [fv release];
  } else {
    NXTRunAlertPanel(_(@"Open as Folder"), _(@"%@ is not a folder."), nil, nil, nil, path);
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
  NXTDefaults *df = [NXTDefaults userDefaults];

  for (fv in fileViewers) {
    if ([[fv rootPath] isEqualToString:path]) {
      [[fv window] makeKeyAndOrderFront:self];
      return fv;
    }
  }

  fv = [self newViewerRootedAt:path viewer:[df objectForKey:@"PreferredViewer"] isRoot:NO];
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
  NXTDefaults *df = [NXTDefaults userDefaults];

  fv = [self newViewerRootedAt:filename viewer:[df objectForKey:@"PreferredViewer"] isRoot:NO];

  if (fv == nil) {
    return NO;
  }

  [[fv window] makeKeyAndOrderFront:self];
  return YES;
}

- (void)applicationWillFinishLaunching:(NSNotification *)notif
{
  // Update Workspace application icon (main Dock icon)
  [self createWorkspaceBadge];
  [self updateKeyboardBadge:nil];

  // Workspace Notification Central
  _windowManagerCenter = [WMNotificationCenter defaultCenter];

  // Window Manager events
  [_windowManagerCenter addObserver:self
                       selector:@selector(updateWorkspaceBadge:)
                           name:CF_NOTIFICATION(WMDidChangeDesktopNotification)
                         object:nil];
  [_windowManagerCenter addObserver:self
                       selector:@selector(updateKeyboardBadge:)
                           name:CF_NOTIFICATION(WMDidChangeKeyboardLayoutNotification)
                         object:nil];

  // Update Services
  // NSUpdateDynamicServices();

  // Detect lid close/open events
  systemPower = [OSEPower new];
  [systemPower startEventsMonitor];
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc addObserver:self
         selector:@selector(lidDidChange:)
             name:OSEPowerLidDidChangeNotification
           object:systemPower];

  [nc addObserver:self
         selector:@selector(applicationDidChangeScreenParameters:)
             name:NSApplicationDidChangeScreenParametersNotification
           object:NSApp];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notif
{
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  NSUserDefaults *df = [NSUserDefaults standardUserDefaults];

  // Services
  [NSApp setServicesProvider:self];

  // Initialize private NSWorkspace implementation
  [self initNSWorkspace];

  // ProcessManager must be ready to register automatically started applications.
  procManager = [ProcessManager shared];

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
  WAppIcon *appicon = wDockAppiconAtSlot(wDefaultScreen()->dock, 0);
  if (appicon && appicon->flags.auto_launch == 1) {
    [self _restoreWindows];
    [[NSApp mainMenu] display];
  } else {
    [nc addObserver:self
           selector:@selector(activateApplication:)
               name:NSApplicationWillBecomeActiveNotification
             object:NSApp];
  }

  // OSEMediaManager
  // For future use
  [nc addObserver:self selector:@selector(diskDidAdd:) name:OSEDiskDisappeared object:mediaAdaptor];
  [nc addObserver:self
         selector:@selector(diskDidEject:)
             name:OSEDiskDisappeared
           object:mediaAdaptor];
  // Operations
  [nc addObserver:self
         selector:@selector(mediaOperationDidStart:)
             name:OSEMediaOperationDidStart
           object:mediaAdaptor];
  [nc addObserver:self
         selector:@selector(mediaOperationDidEnd:)
             name:OSEMediaOperationDidEnd
           object:mediaAdaptor];

  [mediaAdaptor checkForRemovableMedia];

  // Recycler
  recycler = [[Recycler alloc] initWithDock:wDefaultScreen()->dock];
  [[recycler appIcon] orderFrontRegardless];

  // Show Dock
  wDockShowIcons(wDefaultScreen()->dock);

  // Start docked applications with `AutoLaunch = Yes`
  wDockDoAutoLaunch(wDefaultScreen()->dock, 0);

  // WM startup completed
  wDefaultScreen()->flags.startup2 = 0;

  fprintf(stderr, "=== Workspace is ready. Welcome to the NeXT world! ===\n");

  // Start last session active not-docked applications
  [self _startSavedApplications];
}

- (void)activateApplication:(NSNotification *)aNotification
{
  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:NSApplicationWillBecomeActiveNotification
                                                object:NSApp];
  [self _restoreWindows];
  [[NSApp mainMenu] display];
}

// Log Out -
// close all running applications, close all windows and panels, unmount all
// removable media.
// Power Off - all of the above + tell Login to start power off process after
// Workspace quit.
// Log Out and Power Off terminate quitting when some application won't stop,
// some removable media won't unmount/eject (optional: think).
#define LogOut NSAlertDefaultReturn
#define PowerOff NSAlertAlternateReturn
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
  NSApplicationTerminateReply terminateReply;

  wDefaultScreen()->flags.ignore_focus_events = 1;

  switch (NXTRunAlertPanel(_(@"Log Out"), _(@"Do you really want to log out?"), _(@"Log out"),
                           _(@"Power off"), _(@"Cancel"))) {
    case LogOut:
    {
      [[NSApp mainMenu] close];
      _isQuitting = [procManager terminateAllBGOperations];
      if (_isQuitting != NO) {
        // Save running applications
        [self _saveRunningApplications];
        _isQuitting = [procManager terminateAllApps];
        if (_isQuitting == NO) {
          NXTRunAlertPanel(_(@"Log Out"), _(@"'%@' application request to cancel Log Out."), _(@"Dismiss"), nil, nil,
                           [self activeApplication][@"NSApplicationName"]);
        }
      }

      if (_isQuitting == NO) {
        terminateReply = NSTerminateCancel;
      } else {
        // Close Workspace windows, hide Dock, quit WM
        [self _finishTerminateProcess];
        terminateReply = NSTerminateNow;
        ws_quit_code = WSLogoutOnQuit;
      }
    } break;
    case PowerOff:
    {
      [[NSApp mainMenu] close];
      _isQuitting = [procManager terminateAllBGOperations];
      if (_isQuitting != NO) {
        // Save running applications
        [self _saveRunningApplications];
        _isQuitting = [procManager terminateAllApps];
        if (_isQuitting == NO) {
          NXTRunAlertPanel(_(@"Power Off"), _(@"'%@' application request to cancel Power Off."),
                           _(@"Dismiss"), nil, nil, [self activeApplication][@"NSApplicationName"]);
        }
      }
      if (_isQuitting == NO) {
        terminateReply = NSTerminateCancel;
      } else {
        [self _finishTerminateProcess];
        terminateReply = NSTerminateNow;
        ws_quit_code = WSPowerOffOnQuit;

      }
    } break;
    default:
      _isQuitting = NO;
      terminateReply = NSTerminateCancel;
      break;
  }

  if (_isQuitting == NO) {
    [[NSApp mainMenu] display];
    // FIXME: restore Workspace focus. It's not correct from user POV - managed application
    // may want to have focus to review unsaved data. For now it's better not to have two app
    // menus visible with focus mess. Currently WM info about focused window differs from
    // GNUstep app.
    [[NSApp mainWindow] makeKeyAndOrderFront:self];
    NSDebugLLog(@"Workspace", @"Active application: %@", [self activeApplication][@"NSApplicationName"]);
  }

  wDefaultScreen()->flags.ignore_focus_events = 0;

  return terminateReply;
}

- (void)activate
{
  if (_isQuitting != NO)
    return;

  // NSLog(@"Activating Workspace from Controller!");
  [NSApp activateIgnoringOtherApps:YES];
}

- (void)applicationDidChangeScreenParameters:(NSNotification *)aNotification
{
  WSUpdateScreenParameters();
}

- (void)openFileViewerService:(NSPasteboard *)pboard
                     userData:(NSString *)userData
                        error:(NSString **)error
{
  NSString *path = [[pboard stringForType:NSStringPboardType]
      stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\n\r"]];
  path = [path stringByStandardizingPath];

  if ([self openFile:path]) {
    *error = NULL;
  } else {
    *error = [NSString stringWithFormat:@"path \"%@\" does not exist", path];
  }
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
  if (_isQuitting != NO) {
    return nil;
  }
  return inspector;
}

// First viewer which will call this method bring monitor to life.
// fileSystemMonitor will be released on application termination.
- (OSEFileSystemMonitor *)fileSystemMonitor
{
  if (_isQuitting != NO) {
    return nil;
  }
  if (!fileSystemMonitor) {
    // Must be released in -dealloc.
    fileSystemMonitor = [OSEFileSystemMonitor sharedMonitor];

    NSDebugLLog(@"Memory", @"[Controller] fileSystemMonitor RC: %lu",
                [fileSystemMonitor retainCount]);

    while ([fileSystemMonitor monitorThread] == nil) {  // wait for event monitor
      [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                               beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
    // - Start filesystem event monitor
    [fileSystemMonitor start];
  }

  return fileSystemMonitor;
}

- (id<MediaManager>)mediaManager
{
  if (_isQuitting != NO) {
    return nil;
  }
  if (!mediaManager) {
    mediaManager = [[OSEMediaManager alloc] init];
    mediaAdaptor = [mediaManager adaptor];
  }
  return mediaAdaptor;
}

- (Processes *)processesPanel
{
  if (_isQuitting != NO) {
    return nil;
  }
  return procPanel;
}

- (Recycler *)recycler
{
  if (_isQuitting != NO) {
    return nil;
  }
  return recycler;
}

- (Finder *)finder
{
  if (_isQuitting != NO) {
    return nil;
  }
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
  NSString *currentWorkspace;

  if ([[NXTDefaults userDefaults] boolForKey:@"ShowWorkspaceInDock"] == NO) {
    return;
  }

  workspaceBadge = [[NXTIconBadge alloc] initWithPoint:NSMakePoint(5, 48)
                                                  text:@"0"
                                                  font:[NSFont systemFontOfSize:9]
                                             textColor:[NSColor blackColor]
                                           shadowColor:[NSColor whiteColor]];
  [[[NSApp iconWindow] contentView] addSubview:workspaceBadge];
  [workspaceBadge release];

  currentWorkspace = [NSString stringWithFormat:@"%i", wDefaultScreen()->current_desktop + 1];
  [workspaceBadge setStringValue:currentWorkspace];
}

- (void)destroyWorkspaceBadge
{
  if (workspaceBadge) {
    [workspaceBadge removeFromSuperview];
    workspaceBadge = nil;
  }
}

- (void)updateWorkspaceBadge:(NSNotification *)aNotification
{
  NSDictionary *info = [aNotification userInfo];
  NSString *currentWorkspace;

  if ([[NXTDefaults userDefaults] boolForKey:@"ShowWorkspaceInDock"] != NO) {
    if (!workspaceBadge) {
      [self createWorkspaceBadge];
    } else {
      currentWorkspace =
          [NSString stringWithFormat:@"%i", [[info objectForKey:@"workspace"] intValue] + 1];
      [workspaceBadge setStringValue:currentWorkspace];
    }
  }
}

- (void)createKeyboardBadge
{
  NSColor *textColor = [NSColor colorWithCalibratedRed:(100.0 / 255.0)
                                                 green:0.0
                                                  blue:0.0
                                                 alpha:1.0];
  keyboardBadge = [[NXTIconBadge alloc] initWithPoint:NSMakePoint(5, 2)
                                                 text:@"us"
                                                 font:[NSFont systemFontOfSize:9]
                                            textColor:[NSColor blackColor]
                                          shadowColor:[NSColor lightGrayColor]];
  [[[NSApp iconWindow] contentView] addSubview:keyboardBadge];
  [keyboardBadge release];
}

- (void)updateKeyboardBadge:(NSNotification *)aNotification
{
  OSEKeyboard *keyboard = [OSEKeyboard new];
  NSString *layout;
  int group;

  if (aNotification == nil) {
    group = 0;
  } else {
    group = [[[aNotification userInfo] objectForKey:@"XkbGroup"] integerValue];
  }

  if ([[keyboard layouts] count] <= 1) {
    layout = @"";
  } else {
    layout = [[keyboard layouts] objectAtIndex:group];
  }
  [keyboard release];

  if (!keyboardBadge) {
    [self createKeyboardBadge];
  }
  [keyboardBadge setStringValue:[layout uppercaseString]];
}

//============================================================================
// Application menu
//============================================================================

- (void)hideOtherApplications:(id)sender
{
  Window xWindow = (Window)[GSCurrentServer() windowDevice:[[NSApp keyWindow] windowNumber]];
  NSDictionary *info =
      @{@"WindowID" : [NSNumber numberWithUnsignedLong:xWindow], @"ApplicationName" : @"Workspace"};

  NSLog(@"hideOtherApplications for X window ID: %lu", xWindow);
  
  [[NSDistributedNotificationCenter defaultCenter]
      postNotificationName:CF_NOTIFICATION(WMShouldHideOthersNotification)
                    object:@"GSWorkspaceNotification"
                  userInfo:info];
}

// Info
- (void)showInfoPanel:(id)sender
{
  if (infoPanel == nil) {
    [NSBundle loadNibNamed:@"InfoPanel" owner:self];
    [self fillInfoPanelWithSystemInfo];
  }

  [infoPanel center];
  [infoPanel makeKeyAndOrderFront:nil];
}

- (void)showLegalPanel:(id)sender
{
  if (legalPanel == nil) {
    NSScrollView *sv;
    NSData *text;
    NSString *textPath;

    [NSBundle loadNibNamed:@"LegalPanel" owner:self];
    [legalPanel center];

    textPath = [[NSBundle mainBundle] pathForResource:@"LegalInformation" ofType:@"rtf"];
    text = [NSData dataWithContentsOfFile:textPath];
    [legalText replaceCharactersInRange:NSMakeRange(0, 0) withRTF:text];
  }

  [legalPanel makeKeyAndOrderFront:nil];
}

// TODO
- (void)saveLegalToFile:(id)sender
{
  NSSavePanel *sp = [NXTSavePanel savePanel];

  [sp setRequiredFileType:@"rtf"];
  [sp setTitle:_(@"Save Legal Information to File")];

  if ([sp runModal] == NSOKButton) {
    if ([[legalText RTFFromRange:NSMakeRange(0, [[legalText string] length])]
            writeToFile:[sp filename]
             atomically:NO] == NO) {
      NXTRunAlertPanel(_(@"Failed to write legal text to file `%@`"), nil, nil, nil, [sp filename]);
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
- (void)closeViewer:(id)viewer
{
  NSDebugLLog(@"Memory", @"Controller: closeViewer[%lu] (%@)", [viewer retainCount],
              [viewer rootPath]);
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

- (void)newViewer:(id)sender
{
  FileViewer *fv;
  NXTDefaults *df = [NXTDefaults userDefaults];

  fv = [self newViewerRootedAt:@"/" viewer:[df objectForKey:@"PreferredViewer"] isRoot:NO];
  [[fv window] makeKeyAndOrderFront:self];
}

- (void)updateViewers:(id)sender
{
  id viewer;
  NSEnumerator *e = [fileViewers objectEnumerator];

  while ((viewer = [e nextObject])) {
    [viewer displayPath:nil selection:nil sender:self];
  }
}

// Tools -> Inspector
- (void)showAttributesInspector:(id)sender
{
  if (!inspector) {
    [self _loadInpectors];
  }
  [inspector showAttributesInspector:self];
}

- (void)showContentsInspector:(id)sender
{
  if (!inspector) {
    [self _loadInpectors];
  }
  [inspector showContentsInspector:self];
}

- (void)showToolsInspector:(id)sender
{
  if (!inspector) {
    [self _loadInpectors];
  }
  [inspector showToolsInspector:self];
}

- (void)showPermissionsInspector:(id)sender
{
  if (!inspector) {
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
  if (!procPanel) {
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

- (void)showLauncher:(id)sender
{
  if (launcher == nil) {
    launcher = [[Launcher alloc] init];
  }
  [launcher activate];
}

// Dock
- (void)setDockVisibility:(id)sender
{
  WScreen *scr = wDefaultScreen();

  if ([[sender title] isEqualToString:@"Hide"]) {
    wDockHideIcons(scr->dock);
    wScreenUpdateUsableArea(scr);
    if (!scr->dock->mapped) {
      [sender setTitle:@"Show"];
    }
  } else {
    wDockShowIcons(scr->dock);
    wScreenUpdateUsableArea(scr);
    if (scr->dock->mapped) {
      [sender setTitle:@"Hide"];
    }
  }
}
- (void)setDockCollapse:(id)sender
{
  WScreen *scr = wDefaultScreen();

  if ([[sender title] isEqualToString:@"Collapse"]) {
    wDockCollapse(scr->dock);
    if (scr->dock->collapsed) {
      [sender setTitle:@"Uncollapse"];
    }
  } else {
    wDockUncollapse(scr->dock);
    if (!scr->dock->collapsed) {
      [sender setTitle:@"Collapse"];
    }
  }
}

// Icon Yard
- (void)setIconYardVisibility:(id)sender
{
  WScreen *scr = wDefaultScreen();

  if ([[sender title] isEqualToString:@"Hide"]) {
    wIconYardHideIcons(scr);
    // wScreenUpdateUsableArea(scr);
    // if (!scr->dock->mapped)
    [sender setTitle:@"Show"];
  } else {
    wIconYardShowIcons(scr);
    // wScreenUpdateUsableArea(scr);
    // if (scr->dock->mapped)
    [sender setTitle:@"Hide"];
  }
}

//--- Validation
- (BOOL)validateMenuItem:(id<NSMenuItem>)menuItem
{
  NSString *menuTitle = [[menuItem menu] title];
  FileViewer *fileViewer;
  // NSString   *selectedPath;

  if (_isQuitting != NO)
    return NO;

  fileViewer = [self fileViewerForWindow:[NSApp keyWindow]];
  // if (fileViewer) {
  //   selectedPath = [fileViewer absolutePath];
  // }
  // NSLog(@"Validate menu: %@ item: %@", menuTitle, [menuItem title]);

  if ([menuTitle isEqualToString:@"File"]) {
    if ([[menuItem title] isEqualToString:@"Empty Recycler"]) {
      if (!recycler || [recycler itemsCount] == 0) {
        return NO;
      }
    }
  } else if ([menuTitle isEqualToString:@"Dock"]) {
    if ([[menuItem title] isEqualToString:@"Collapse"] ||
        [[menuItem title] isEqualToString:@"Uncollapse"]) {
      if (!wDefaultScreen()->dock->mapped) {
        return NO;
      }
    }
    if ([[menuItem title] isEqualToString:@"Hide"] && !wDefaultScreen()->dock->mapped) {
      [menuItem setTitle:@"Show"];
    }
  } else if ([menuTitle isEqualToString:@"Icon Yard"]) {
    if ([[menuItem title] isEqualToString:@"Hide"] && !wDefaultScreen()->flags.icon_yard_mapped) {
      [menuItem setTitle:@"Show"];
    }
  } else if ([menuTitle isEqualToString:@"Disk"]) {
    if ([[menuItem title] isEqualToString:@"Initialize..."])
      return NO;
    if ([[menuItem title] isEqualToString:@"Check For Disks"] && !mediaAdaptor)
      return NO;
  } else if ([menuTitle isEqualToString:@"View"]) {
    if ([[menuItem title] isEqualToString:[[[fileViewer viewer] class] viewerType]]) {
      return NO;
    }
  } else if ([menuTitle isEqualToString:@"Inspector"]) {
    if (!fileViewer) {
      if ([[menuItem title] isEqualToString:@"Attributes"])
        return NO;
      if ([[menuItem title] isEqualToString:@"Contents"])
        return NO;
      if ([[menuItem title] isEqualToString:@"Tools"])
        return NO;
      if ([[menuItem title] isEqualToString:@"Permissions"])
        return NO;
    }
  }

  return YES;
}

//============================================================================
// OSEMediaManager events (alert panels, Processes-Background updates).
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

  if ([[info objectForKey:@"Success"] isEqualToString:@"false"]) {
    [NSApp activateIgnoringOtherApps:YES];
    NXTRunAlertPanel([info objectForKey:@"Title"], [info objectForKey:@"Message"], nil, nil, nil);
  } else {
    Mounter *bgop = [[Mounter alloc] initWithInfo:info];

    [mediaOperations setObject:bgop forKey:[bgop source]];
    [bgop release];

    NSLog(@"[Contoller media-start] <%@> %@ [%@]", [info objectForKey:@"Title"],
          [info objectForKey:@"Message"], [bgop source]);
  }
}

- (void)mediaOperationDidEnd:(NSNotification *)notif
{
  NSDictionary *info = [notif userInfo];
  NSString *source = [info objectForKey:@"UNIXDevice"];
  Mounter *bgop = [mediaOperations objectForKey:source];

  if ([[info objectForKey:@"Success"] isEqualToString:@"false"] && bgop) {
    [bgop destroyOperation:info];
  } else if (bgop) {
    if (_isQuitting) {
      [bgop destroyOperation:info];
    } else {
      [bgop finishOperation:info];
    }
    [mediaOperations removeObjectForKey:source];
  } else  // probably disk ejected without unmounting
  {
    [NSApp activateIgnoringOtherApps:YES];
    NXTRunAlertPanel([info objectForKey:@"Title"], [info objectForKey:@"Message"], nil, nil, nil);
  }

  NSLog(@"[Contoller media-end] <%@> %@ [%@]", [info objectForKey:@"Title"],
        [info objectForKey:@"Message"], source);
}

//============================================================================
// OSEScreen events
//============================================================================
- (void)lidDidChange:(NSNotification *)aNotif
{
  OSEDisplay *builtinDisplay = nil;
  OSEScreen *screen = [OSEScreen new];

  for (OSEDisplay *d in [screen connectedDisplays]) {
    if ([d isBuiltin]) {
      builtinDisplay = d;
      break;
    }
  }

  if (builtinDisplay) {
    if (![systemPower isLidClosed] && ![builtinDisplay isActive]) {
      NSLog(@"Workspace: activating display %@", [builtinDisplay outputName]);
      [screen activateDisplay:builtinDisplay];
    } else if ([systemPower isLidClosed] && [builtinDisplay isActive]) {
      NSLog(@"Workspace: DEactivating display %@", [builtinDisplay outputName]);
      [screen deactivateDisplay:builtinDisplay];
    }
  }
  [screen release];
}

//============================================================================
// WM events
//============================================================================
- (void)showWMAlert:(NSMutableDictionary *)alertInfo
{
  NSInteger result;

  // NSLog(@"WMShowAlertPanel thread: %@ (main: %@) mode: %@", [NSThread currentThread],
  //       [NSThread mainThread], [[NSRunLoop currentRunLoop] currentMode]);

  result = NXTRunAlertPanel([alertInfo objectForKey:@"Title"], [alertInfo objectForKey:@"Message"],
                            [alertInfo objectForKey:@"DefaultButton"],
                            [alertInfo objectForKey:@"AlternateButton"],
                            [alertInfo objectForKey:@"OtherButton"]);
  [alertInfo setObject:[NSNumber numberWithInt:result] forKey:@"Result"];
}

//============================================================================
// Sounds
//============================================================================
// static NSTimer  *soundTimer = nil;
- (void)ringBell
{
  if (bellSound == nil) {
    NXTDefaults *defs = [NXTDefaults globalUserDefaults];
    NSString *bellPath = [defs objectForKey:@"NXSystemBeep"];
    if (bellPath == nil || [[NSFileManager defaultManager] fileExistsAtPath:bellPath] == NO) {
      bellPath = @"/usr/NextSpace/Sounds/Bonk.snd";
    }
    bellSound = [[NXTSound alloc] initWithContentsOfFile:bellPath
                                             byReference:YES
                                              streamType:SNDEventType];
  }

  [bellSound play];
}

@end
