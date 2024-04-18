/*
  Copyright (c) 2015-2017 Sergii Stoian <stoyan255@gmail.com>

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

#import <sys/wait.h>
#include "InfoPanel.h"

#import <DesktopKit/DesktopKit.h>

#import "Defaults.h"

#import "TerminalServices.h"
#import "TerminalView.h"
#import "TerminalWindow.h"
#import "TerminalFinder.h"

#import "Controller.h"

//-----------------------------------------------------------------------------
// Child shells management
//-----------------------------------------------------------------------------
// static void child_action_handler(int signal, siginfo_t *siginfo, void *context)
// {
//   NSLog(@"Received signal %i: PID=%i error=%i status=%i",
//         signal, siginfo->si_pid,
//         siginfo->si_errno, siginfo->si_status);

//   [[NSApp delegate] childWithPID:siginfo->si_pid
//                          didExit:siginfo->si_status];
// }
// {
//   struct  sigaction child_action;
//   child_action.sa_sigaction = &child_action_handler;
//   child_action.sa_flags = SA_SIGINFO;
//   sigaction(SIGCHLD, &child_action, NULL);
// }
//-----------------------------------------------------------------------------

@implementation Controller

- init
{
  if (!(self = [super init]))
    return nil;

  windows = [[NSMutableDictionary alloc] init];
  isAppAutoLaunched = NO;

  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [timer invalidate];

  [windows release];
  [idleList release];

  [super dealloc];
}

// --- Menu

// Info > Info Panel...
- (void)openInfoPanel:(id)sender
{
  if (infoPanel == nil) {
    infoPanel = [[InfoPanel alloc] init];
  }
  [infoPanel activatePanel];
}

// Info > Preferences
- (void)openPreferences:(id)sender
{
  // load Preferences.bundle, send 'activate' to principal class
  if (preferencesPanel == nil) {
    NSString *bundlePath;
    NSBundle *bundle;

    bundlePath =
        [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Preferences.bundle"];

    // NSLog(@"[Controller] Inspectors: %@", inspectorsPath);

    bundle = [[NSBundle alloc] initWithPath:bundlePath];

    // NSLog(@"[Controller] Inspectors Class: %@",
    //       [inspectorsBundle principalClass]);
    preferencesPanel = [[[bundle principalClass] alloc] init];
  }
  [preferencesPanel activatePanel];
}

- (void)openServicesPanel:(id)sender
{
  if (servicesPanel == nil) {
    servicesPanel = [[TerminalServicesPanel alloc] init];
  }
  [servicesPanel activatePanel];
}

// Shell > New
- (void)openWindow:(id)sender
{
  [[self newWindowWithShell] showWindow:self];
}

// Shell > Open...
- (void)openSession:(id)sender
{
  NXTOpenPanel *panel = [NXTOpenPanel openPanel];
  NSString *sessionDir, *path;
  NSInteger result;

  [panel setCanChooseDirectories:NO];
  [panel setAllowsMultipleSelection:NO];
  [panel setTitle:@"Open Shell"];
  [panel setShowsHiddenFiles:NO];

  if ((sessionDir = [Defaults sessionsDirectory]) == nil) {
    return;
  }

  result = [panel runModalForDirectory:sessionDir
                                  file:@"Default.term"
                                 types:[NSArray arrayWithObject:@"term"]];
  if (result == NSOKButton) {
    if ((path = [panel filename]) != nil) {
      [self openStartupFile:path];
    }
  }
}
// Shell > Save
- (void)_saveMultiSession:(NSString *)path allWindows:(BOOL)all
{
  NSMutableDictionary *sessionDict = [NSMutableDictionary new];
  NSMutableArray *winDefs = [NSMutableArray new];
  NSMutableArray *winsToSave = [NSMutableArray new];
  Defaults *prefs;

  // sessionDict = {MultipleWindows = YES; Windows = (dict, dict,...)}
  [sessionDict setObject:@"YES" forKey:@"MultipleWindows"];
  if (all == NO) {
    // Save windows that have represented filename equal to 'path'.
    for (TerminalWindowController *twc in [windows allValues]) {
      if ([[[twc window] representedFilename] isEqualToString:path]) {
        [winsToSave addObject:twc];
      }
    }
  } else {
    [winsToSave addObjectsFromArray:[windows allValues]];
  }

  for (TerminalWindowController *twc in winsToSave) {
    if ((prefs = [twc livePreferences]) == nil) {
      prefs = [twc preferences];
    }
    [prefs setBool:[[twc window] isMiniaturized] forKey:@"WindowMiniaturized"];
    [prefs setBool:[[twc window] isMainWindow] forKey:@"WindowMain"];
    [prefs setObject:NSStringFromRect([[twc window] frame]) forKey:@"WindowFrame"];
    [winDefs addObject:[prefs dictionaryRep]];
  }
  [sessionDict setObject:winDefs forKey:@"Windows"];
  [sessionDict writeToFile:path atomically:YES];
}
- (void)saveSession:(id)sender
{
  TerminalWindowController *twc;
  NSString *filePath;

  twc = [self terminalWindowForWindow:[NSApp mainWindow]];
  filePath = [[twc window] representedFilename];

  // Loaded startup file doesn't exist now
  if (filePath && [[NSFileManager defaultManager] fileExistsAtPath:filePath] == NO)
    filePath = nil;

  // Loaded startup file exists
  if (filePath != nil) {
    // Main window preferences were changed
    if ([self preferencesForWindow:[NSApp mainWindow] live:YES] != nil) {
      // Check if startup file contains multiple windows
      NSDictionary *existingStartup;
      existingStartup = [NSDictionary dictionaryWithContentsOfFile:filePath];

      if ([[existingStartup allKeys] containsObject:@"MultipleWindows"]) {
        // Save all windows loaded from specific file
        [self _saveMultiSession:filePath allWindows:NO];
      } else {
        // Save single window loaded from file
        Defaults *defs = [twc livePreferences];
        if (defs == nil)
          defs = [twc preferences];

        [defs setObject:NSStringFromRect([[twc window] frame]) forKey:@"WindowFrame"];
        [defs writeToFile:filePath atomically:YES];
      }
    }
  } else {
    // If it's a default session (changed or not) - open "Save As..." panel
    NSLog(@"It's a default session - will open \"Save As...\" panel");
    [self saveSessionAs:sender];
  }
}
// Shell -> Save As...
- (void)saveSessionAs:(id)sender
{
  TerminalWindowController *twc;
  NSString *fileName, *filePath;
  NXTSavePanel *panel;
  NSString *sessionDir;
  Defaults *prefs;

  if ((sessionDir = [Defaults sessionsDirectory]) == nil)
    return;

  panel = [NXTSavePanel savePanel];
  [panel setTitle:@"Save As"];
  [panel setShowsHiddenFiles:NO];

  // Accessory view
  if (accView == nil) {
    [NSBundle loadNibNamed:@"SaveAsAccessory" owner:self];
    [accView retain];
  }
  [windowPopUp selectItemWithTag:0];  // MainWindow
  [loadAtStartupBtn setState:0];
  [panel setAccessoryView:accView];

  twc = [self terminalWindowForWindow:[NSApp mainWindow]];
  if ((filePath = [[twc window] representedFilename]) == nil) {
    fileName = @"Default.term";
    filePath = [sessionDir stringByAppendingPathComponent:fileName];
  } else {
    fileName = [filePath lastPathComponent];
  }

  if ([panel runModalForDirectory:sessionDir file:fileName] == NSOKButton) {
    filePath = [panel filename];
    if ([windowPopUp selectedTag]) {  // All Windows
      // NSLog(@"Save all opened windows As %@.", filePath);
      [self _saveMultiSession:filePath allWindows:YES];
    } else {
      // NSLog(@"Save single window As %@.", filePath);
      if ((prefs = [twc livePreferences]) == nil)
        prefs = [twc preferences];
      [prefs setObject:NSStringFromRect([[twc window] frame]) forKey:@"WindowFrame"];
      [prefs writeToFile:filePath atomically:YES];
    }

    if ([loadAtStartupBtn state]) {
      Defaults *defs = [Defaults shared];
      [defs setStartupFile:filePath];
      [defs setStartupAction:OnStartOpenFile];
      [defs synchronize];
    }
  }
}
// Shell > Set Title...
- (void)openSetTitlePanel:(id)sender
{
  if (setTitlePanel == nil) {
    setTitlePanel = [[SetTitlePanel alloc] init];
  }
  [setTitlePanel activatePanel];
}

// Edit > Find > Find Panel...
- (void)openFindPanel:(id)sender
{
  [[TerminalFinder sharedInstance] orderFrontFindPanel:self];
}
- (void)findNext:(id)sender
{
  [[TerminalFinder sharedInstance] findNext:self];
}
- (void)findPrevious:(id)sender
{
  [[TerminalFinder sharedInstance] findPrevious:self];
}
- (void)enterSelection:(id)sender
{
  TerminalFinder *finder = [TerminalFinder sharedInstance];
  NSString *string;
  TerminalView *tv;

  tv = [[self terminalWindowForWindow:[NSApp keyWindow]] terminalView];
  string = [[tv stringRepresentation] substringFromRange:[tv selectedRange]];
  [finder setFindString:string];
}
- (void)jumpToSelection:(id)sender
{
  TerminalView *tv;

  tv = [[self terminalWindowForWindow:[NSApp keyWindow]] terminalView];
  [tv scrollRangeToVisible:[tv selectedRange]];
}

// "Font" menu
- (void)orderFrontFontPanel:(id)sender
{
  NSFontManager *fm = [NSFontManager sharedFontManager];
  TerminalWindowController *twc = [self terminalWindowForWindow:mainWindow];
  Defaults *prefs = [twc livePreferences];

  if (prefs == nil)
    prefs = [twc preferences];

  [fm setSelectedFont:[prefs terminalFont] isMultiple:NO];
  [fm orderFrontFontPanel:sender];
}
// Bold and Italic
- (void)addFontTrait:(id)sender
{
  [[NSFontManager sharedFontManager] addFontTrait:sender];
}
// Larger and Smaller
- (void)modifyFont:(id)sender
{
  [[NSFontManager sharedFontManager] modifyFont:sender];
}

- (BOOL)validateMenuItem:(id<NSMenuItem>)menuItem
{
  NSString *menuTitle = [[menuItem menu] title];
  NSString *itemTitle = [menuItem title];

  if ([self terminalWindowForWindow:[NSApp keyWindow]] == nil) {
    // NSLog(@"Controller: Validate menu: %@: key window is not Terminal",
    //       menuTitle);
    if ([itemTitle isEqualToString:@"Save"])
      return NO;
    if ([itemTitle isEqualToString:@"Save As..."])
      return NO;
    if ([itemTitle isEqualToString:@"Set Title..."])
      return NO;

    if ([menuTitle isEqualToString:@"Font"])
      return NO;
    if ([menuTitle isEqualToString:@"Find"])
      return NO;
  }

  return YES;
}

// --- NSApplication delegate
- (void)applicationWillFinishLaunching:(NSNotification *)n
{
  idleList = [[NSMutableArray alloc] init];

  [TerminalView registerPasteboardTypes];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(noMoreActiveTerminalWindows:)
                                               name:TerminalWindowNoMoreActiveWindowsNotification
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(mainWindowDidChange:)
                                               name:NSWindowDidBecomeMainNotification
                                             object:nil];
}

- (void)applicationDidFinishLaunching:(NSNotification *)n
{
  NSArray *args;
  NSInteger index;
  TerminalWindowController *twc;

  [NSApp setServicesProvider:[[TerminalServices alloc] init]];

  // Check for -autolaunch
  args = [[NSProcessInfo processInfo] arguments];
  index = [args indexOfObject:@"-autolaunch"];
  if (index != NSNotFound) {
    if ([[args objectAtIndex:++index] isEqualToString:@"YES"]) {
      isAppAutoLaunched = YES;
    }
  }

  switch ([[Defaults shared] startupAction]) {
    case OnStartCreateShell:
      twc = [self newWindowWithShell];
      [twc showWindow:self];
      break;
    case OnStartOpenFile:
      [self openStartupFile:[[Defaults shared] startupFile]];
      break;
    default:
      // OnStartDoNothing == do nothing
      break;
  }

  // By default "-NXAutoLaunch YES" option resigns active state from
  // starting application.
  if (isAppAutoLaunched == YES && [[Defaults shared] hideOnAutolaunch] == YES) {
    [NSApp hide:self];
  } else {
    [NSApp activateIgnoringOtherApps:YES];
  }

  // Activate timer for windows state checking
  timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                           target:self
                                         selector:@selector(checkTerminalWindowsState)
                                         userInfo:nil
                                          repeats:NO];
}

- (void)applicationWillTerminate:(NSNotification *)n
{
  if (preferencesPanel) {
    [preferencesPanel closePanel];
    [preferencesPanel release];
  }
  if (setTitlePanel) {
    [setTitlePanel closeSetTitlePanel:self];
    [setTitlePanel release];
  }
  if (infoPanel) {
    [infoPanel closePanel];
    [infoPanel release];
  }
  
  // Clear font pasteboard data
  NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSFontPboard];
  if ([pb dataForType:NSFontPboardType] != nil) {
    [pb setData:nil forType:NSFontPboardType];
  }
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
  TerminalWindowController *twc;
  NSInteger alertChoice;

  if (![self numberOfActiveTerminalWindows]) {
    return NSTerminateNow;
  }

  // manually check state of windows
  [self checkTerminalWindowsState];

  for (NSString *windowKey in windows) {
    twc = [windows objectForKey:windowKey];
    if ([[twc window] isDocumentEdited]) {
      break;
    } else {
      twc = nil;
    }
  }

  if (twc != nil) {
    [NSApp activateIgnoringOtherApps:YES];
    alertChoice = NXTRunAlertPanel((@"Quit"), (@"Some windows have running commands."), (@"Review"),
                                   (@"Quit Anyway"), (@"Cancel"));

    if (alertChoice == NSAlertAlternateReturn) {
      return NSTerminateNow;
    } else {
      if (alertChoice == NSAlertDefaultReturn) {
        [[twc window] makeKeyAndOrderFront:self];
      }
      return NSTerminateLater;
    }
  }

  return NSTerminateNow;
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename
{
  if ([[filename pathExtension] isEqualToString:@"term"]) {
    [self openStartupFile:filename];
  }
  return YES;
}

@end

//-----------------------------------------------------------------------------
// Child shells management
//---
// Role of these methods are to create, monitor and close terminal windows
// In method names 'Window' means NSWindow,
// 'TerminalWindow' - TerminalWindowController
//-----------------------------------------------------------------------------
@implementation Controller (TerminalController)

- (void)childWithPID:(int)pid didExit:(int)status
{
  TerminalWindowController *twc;
  int windowCloseBehavior;

  // NSLog(@"Child with pid: %i did exit(%i)", pid, status);

  twc = [windows objectForKey:[NSString stringWithFormat:@"%i", pid]];
  [twc setDocumentEdited:NO];

  windowCloseBehavior = [[twc preferences] windowCloseBehavior];
  if (windowCloseBehavior != WindowCloseNever) {
    if ((windowCloseBehavior == WindowCloseAlways) || (status == 0)) {
      [twc close];
    }
  }
}

- (void)mainWindowDidChange:(NSNotification *)notif
{
  NSFontManager *fm = [NSFontManager sharedFontManager];
  NSFontPanel *fp = [fm fontPanel:NO];
  Defaults *defs;

  mainWindow = [notif object];

  if (fp == nil) {
    return;
  }

  if ((defs = [self preferencesForWindow:mainWindow live:YES]) == nil) {
    if ((defs = [self preferencesForWindow:mainWindow live:NO]) == nil) {
      // this is not terminal window
      return;
    }
  }

  [fm setSelectedFont:[defs terminalFont] isMultiple:NO];
}

- (void)noMoreActiveTerminalWindows:(NSNotification *)n
{
  if (quitPanelOpen) {
    [NSApp replyToApplicationShouldTerminate:YES];
  }
}

- (int)numberOfActiveTerminalWindows
{
  return [windows count] - [idleList count];
}

- (void)checkActiveTerminalWindows
{
  if (![self numberOfActiveTerminalWindows]) {
    [[NSNotificationCenter defaultCenter]
        postNotificationName:TerminalWindowNoMoreActiveWindowsNotification
                      object:self];
  }
}

- (void)checkTerminalWindowsState
{
  if ([windows count] <= 0)
    return;

  NSArray *wins = [windows allValues];

  for (TerminalWindowController *twc in wins) {
    // NSLog(@"%@: idleList contains = %i, user programm = %i ",
    //       [twc shellPath],
    //       [idleList containsObject:twc],
    //       [[twc terminalView] isUserProgramRunning]);

    if (([[twc terminalView] isUserProgramRunning] ||
         [self isProgramClean:[twc shellPath]] == NO) &&
        [idleList containsObject:twc] == NO) {
      [twc setDocumentEdited:YES];
    } else {
      [twc setDocumentEdited:NO];
    }
  }
}

- (int)pidForTerminalWindow:(TerminalWindowController *)twc
{
  NSArray *keys = [windows allKeys];
  int pid = -1;

  for (NSString *PID in keys) {
    if ([windows objectForKey:PID] == twc) {
      pid = [PID integerValue];
    }
  }

  return pid;
}

- (TerminalWindowController *)terminalWindowForWindow:(NSWindow *)win
{
  for (TerminalWindowController *windowController in [windows allValues]) {
    if ([windowController window] == win) {
      return windowController;
    }
  }

  return nil;
}

- (void)terminalWindow:(TerminalWindowController *)twc becameIdle:(BOOL)idle
{
  if (idle) {
    int pid, status;

    // NSLog(@"Window %@ became idle.", [twc shellPath]);
    [idleList addObject:twc];

    if ((pid = [self pidForTerminalWindow:twc]) > 0) {
      // fprintf(stderr, "Idle: Waiting for PID: %i...", pid);
      waitpid(pid, &status, 0);
      // fprintf(stderr, "\tdone!\n");

      // [self childWithPID:pid didExit:status];
      int windowCloseBehavior = [[Defaults shared] windowCloseBehavior];
      [twc setDocumentEdited:NO];

      windowCloseBehavior = [twc closeBehavior];
      if (windowCloseBehavior != WindowCloseNever) {
        // WindowCloseAlways - "Always close the window"
        // 'status == 0' - "Close the window if shell exits cleanly"
        if ((windowCloseBehavior == WindowCloseAlways) || (status == 0)) {
          [twc close];
        }
      }
    }
  } else {
    NSLog(@"Window %@ became non idle.", [twc shellPath]);
    [idleList removeObject:twc];
  }

  [[NSApp delegate] checkActiveTerminalWindows];
}

// Idle window is window that doesn't run in 'Shell' or 'Program' mode.
// Obviously it's a window that was not closed after command ended.
- (BOOL)isTerminalWindowIdle:(TerminalWindowController *)twc
{
  return [idleList containsObject:twc];
}

- (TerminalWindowController *)idleTerminalWindow
{
  NSDebugLLog(@"idle", @"get idle window from idle list: %@", idleList);

  if ([idleList count])
    return [idleList objectAtIndex:0];
  else
    return nil;
}

// TODO: TerminalWindowDidCloseNotification -> windowDidClose:(NSNotification*)n
- (void)closeTerminalWindow:(TerminalWindowController *)twc
{
  int pid, status;

  if ([idleList containsObject:twc])
    [idleList removeObject:twc];

  if ((pid = [self pidForTerminalWindow:twc]) > 0) {
    kill(pid, SIGKILL);
    // fprintf(stderr, "Close: Waiting for PID: %i...", pid);
    waitpid(pid, &status, 0);
    // fprintf(stderr, "\tdone!\n");

    [windows removeObjectForKey:[NSString stringWithFormat:@"%i", pid]];
  }

  [[NSApp delegate] checkActiveTerminalWindows];
}

// Terminal window can be run in 2 modes: 'Shell' and 'Program'
//
// In 'Shell' mode launched shell is not considered as running program
// (close window button has normal state). Close window button change its state
// to 'document edited' until some program executed in the shell (as aresult
// shell has child process).
//
// In 'Program' mode any programm executed considered as important and close
// window button has 'document edited' state. This button changes its state
// to normal when running program finishes.
// Also in 'Program' mode window will never close despite the 'When Shell Exits'
// preferences setting.

- (BOOL)_noDuplicatesOf:(NSString *)string inside:(NSArray *)array
{
  for (NSString *s in array) {
    if ([[s lastPathComponent] isEqualToString:[string lastPathComponent]]) {
      return NO;
    }
  }
  return YES;
}
// Fill in array with items from /etc/shells
// Omit 'nologin' as shell and duplicates (/bin/sh and /usr/bin/sh are
// duplicates).
- (NSArray *)shellList
{
  NSString *etc_shells = [NSString stringWithContentsOfFile:@"/etc/shells"];
  NSString *lString;
  NSRange lRange;
  NSUInteger index, stringLength = [etc_shells length];
  NSMutableArray *shells = [[NSMutableArray alloc] init];

  for (index = 0; index < stringLength;) {
    lRange = [etc_shells lineRangeForRange:NSMakeRange(index, 0)];
    lRange.length -= 1;  // Do not include new line char
    lString = [etc_shells substringFromRange:lRange];
    if ([lString rangeOfString:@"nologin"].location == NSNotFound &&
        [self _noDuplicatesOf:lString inside:shells]) {
      [shells addObject:lString];
    }
    index = lRange.location + lRange.length + 1;
  }

  return [shells autorelease];
}

// For now it's only a shells
- (BOOL)isProgramClean:(NSString *)program
{
  for (NSString *s in [self shellList]) {
    if ([[s lastPathComponent] isEqualToString:[program lastPathComponent]]) {
      return YES;
    }
  }
  return NO;
}

- (void)setupTerminalWindow:(TerminalWindowController *)controller
{
  if ([[controller preferences] isActivityMonitorEnabled]) {
    [controller setDocumentEdited:YES];
  }

  if ([[windows allValues] count] > 0) {
    NSRect mwFrame = [[NSApp mainWindow] frame];
    NSPoint wOrigin = mwFrame.origin;

    wOrigin.x += [NSScroller scrollerWidth] + 3;
    wOrigin.y -= 24;
    [[controller window] setFrameOrigin:wOrigin];
  } else {
    [[controller window] center];
  }
}

- (TerminalWindowController *)newWindow
{
  TerminalWindowController *twc = [[TerminalWindowController alloc] init];

  if (twc == nil)
    return nil;

  [self setupTerminalWindow:twc];

  return twc;
}

// Create default terminal window (Shell->New menu item, on app startup)
- (TerminalWindowController *)newWindowWithShell
{
  TerminalWindowController *twc = [self newWindow];
  int pid;

  if (twc == nil)
    return nil;

  pid = [[twc terminalView] runShell];
  [windows setObject:twc forKey:[NSString stringWithFormat:@"%i", pid]];

  return twc;
}

// Used for 'Services' purposes.
// Created window will be added to 'windows' and 'idleList'
- (TerminalWindowController *)newWindowWithProgram:(NSString *)program
                                         arguments:(NSArray *)args
                                             input:(NSString *)input
{
  TerminalWindowController *twc = [self newWindow];
  int pid;

  if (twc == nil) {
    return nil;
  }
  if (program == nil) {
    program = [[twc preferences] shell];
  }
  pid = [[twc terminalView] runProgram:program withArguments:args initialInput:input];
  [windows setObject:twc forKey:[NSString stringWithFormat:@"%i", pid]];

  return twc;
}

// Create window, and run shell.
// Add window to 'windows' array.
- (TerminalWindowController *)newWindowWithPreferences:(id)defs startupFile:(NSString *)path
{
  TerminalWindowController *twc;
  NSString *shell;
  NSArray *args;
  int pid;

  twc = [[TerminalWindowController alloc] initWithPreferences:defs startupFile:path];
  [self setupTerminalWindow:twc];

  args = [[[twc preferences] shell] componentsSeparatedByString:@" "];
  shell = [[args objectAtIndex:0] copy];
  if ([args count] > 1) {
    args = [args subarrayWithRange:NSMakeRange(1, [args count] - 1)];
  } else {
    args = nil;
  }
  pid = [[twc terminalView] runProgram:shell
                         withArguments:args
                           inDirectory:nil
                          initialInput:nil
                                  arg0:shell];
  [windows setObject:twc forKey:[NSString stringWithFormat:@"%i", pid]];

  [shell release];

  return twc;
}

- (void)openStartupFile:(NSString *)filePath
{
  NSDictionary *fileDict;
  NSDictionary *defs;
  TerminalWindowController *twc;
  NSRect wFrame;

  fileDict = [[NSDictionary alloc] initWithContentsOfFile:filePath];
  if ([fileDict objectForKey:@"MultipleWindows"] != nil) {
    NSWindow *mWindow;
    for (defs in [fileDict objectForKey:@"Windows"]) {
      twc = [self newWindowWithPreferences:defs startupFile:filePath];
      wFrame = NSRectFromString([defs objectForKey:@"WindowFrame"]);
      [[twc window] setFrameOrigin:wFrame.origin];
      if ([[twc preferences] boolForKey:@"WindowMain"] == YES) {
        mWindow = [twc window];
      }
      [twc showWindow:self];
      if ([[twc preferences] boolForKey:@"WindowMiniaturized"] == YES) {
        [[twc window] miniaturize:self];
      }
    }
    [mWindow makeKeyAndOrderFront:self];
  } else {
    defs = [[NSDictionary alloc] initWithContentsOfFile:filePath];
    twc = [self newWindowWithPreferences:defs startupFile:filePath];
    wFrame = NSRectFromString([defs objectForKey:@"WindowFrame"]);
    [[twc window] setFrameOrigin:wFrame.origin];
    [defs release];
    [twc showWindow:self];
  }
  [fileDict release];
}

- (void)runProgram:(NSString *)commandLine
{
  NSMutableArray *args;
  NSString *prog;
  TerminalWindowController *twc;
  Defaults *prefs;

  args = [NSMutableArray arrayWithArray:[commandLine componentsSeparatedByString:@" "]];
  prog = [args objectAtIndex:0];
  [args removeObjectAtIndex:0];

  twc = [self idleTerminalWindow];
  if (twc != nil) {
    [[twc terminalView] runProgram:prog withArguments:args initialInput:nil];
  } else {
    twc = [self newWindowWithProgram:prog arguments:args input:nil];
  }

  // Set close behaviour
  prefs = [[Defaults alloc] initEmpty];
  [prefs setWindowCloseBehavior:WindowCloseNever];
  [[NSNotificationCenter defaultCenter]
      postNotificationName:TerminalPreferencesDidChangeNotification
                    object:[twc window]
                  userInfo:@{@"Preferences" : prefs}];

  [[twc window] makeKeyAndOrderFront:self];
}

//-----------------------------------------------------------------------------
// Preferences and sessions
//---
- (id)preferencesForWindow:(NSWindow *)win live:(BOOL)isLive
{
  TerminalWindowController *twc = [self terminalWindowForWindow:win];

  if (twc != nil) {
    if (isLive) {
      return [twc livePreferences];
    } else {
      return [twc preferences];
    }
  }
  return nil;
}

@end
