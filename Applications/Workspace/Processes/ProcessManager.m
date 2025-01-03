/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Copyright (C) 2015 Sergii Stoian
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

#include <sys/types.h>
#include <signal.h>

#import <Foundation/NSString.h>

#import <DesktopKit/NXTAlert.h>
#import <SystemKit/OSEFileManager.h>

#include "CoreFoundationBridge.h"

#import "Controller.h"
#import "WMNotificationCenter.h"
#import "Workspace+WM.h"

#import "Processes/Processes.h"
#import "Processes/ProcessManager.h"
#import "Operations/FileMover.h"

NSString *WMOperationDidCreateNotification = @"BGOperationDidCreate";
NSString *WMOperationWillDestroyNotification = @"BGOperationWillDestroy";
NSString *WMOperationDidChangeStateNotification = @"BGOperationDidChangeState";
NSString *WMOperationProcessingFileNotification = @"BGOperationProcessingFile";

NSString *WMApplicationDidTerminateSubprocessNotification = @"WMAppDidTerminateSubprocess";

static Processes *shared = nil;
static BOOL _workspaceQuitting = NO;

@implementation ProcessManager

+ shared
{
  if (shared == nil) {
    shared = [self new];
  }
  return shared;
}

- (void)dealloc
{
  NSDebugLLog(@"Memory", @"ProcessManager: dealloc");

  [[NSNotificationCenter defaultCenter] removeObserver:self];

  RELEASE(_applications);
  RELEASE(_operations);

  TEST_RELEASE(_editOperation);
  TEST_RELEASE(backInfoLabelCopies);
  TEST_RELEASE(_activeApplication);

  shared = nil;

  [super dealloc];
}

- init
{
  [super init];

  if (self != nil) {
    NSNotificationCenter *workspaceCenter = [WMNotificationCenter defaultCenter];
    NSNotificationCenter *localCenter = [NSNotificationCenter defaultCenter];
    NSDictionary *_appInfo;

    _applications =
        [[NSMutableArray alloc] initWithArray:[[NSWorkspace sharedWorkspace] launchedApplications]];
    for (int i = 0; i < [_applications count]; i++) {
      _appInfo = [self _normalizeApplicationInfo:[_applications objectAtIndex:i]];
      [_applications replaceObjectAtIndex:i withObject:_appInfo];
    }

    _operations = [[NSMutableArray alloc] init];

    //  Applications - AppKit notifications
    // [[[NSWorkspace sharedWorkspace] notificationCenter]
    [workspaceCenter addObserver:self
                        selector:@selector(applicationDidLaunch:)
                            name:NSWorkspaceDidLaunchApplicationNotification
                          object:nil];
    // [[[NSWorkspace sharedWorkspace] notificationCenter]
    [workspaceCenter addObserver:self
                        selector:@selector(applicationDidTerminate:)
                            name:NSWorkspaceDidTerminateApplicationNotification
                          object:nil];
    [workspaceCenter addObserver:self
                        selector:@selector(applicationDidBecomeActive:)
                            name:NSApplicationDidBecomeActiveNotification
                          object:nil];

    // Background operations
    [localCenter addObserver:self
                    selector:@selector(operationDidCreate:)
                        name:WMOperationDidCreateNotification
                      object:nil];
    [localCenter addObserver:self
                    selector:@selector(operationWillDestroy:)
                        name:WMOperationWillDestroyNotification
                      object:nil];
    [localCenter addObserver:self
                    selector:@selector(operationDidChangeState:)
                        name:WMOperationDidChangeStateNotification
                      object:nil];
    // [[NSNotificationCenter defaultCenter]
    //   addObserver:self
    //      selector:@selector(operationProcessingFile:)
    //          name:WMOperationProcessingFileNotification
    //        object:nil];

    // WM - CoreFoundation notifications
    [workspaceCenter addObserver:self
                        selector:@selector(windowManagerDidCreateApplication:)
                            name:CF_NOTIFICATION(WMDidCreateApplicationNotification)
                          object:nil];
    [workspaceCenter addObserver:self
                        selector:@selector(windowManagerDidDestroyApplication:)
                            name:CF_NOTIFICATION(WMDidDestroyApplicationNotification)
                          object:nil];
    [workspaceCenter addObserver:self
                        selector:@selector(windowManagerDidActivateApplication:)
                            name:CF_NOTIFICATION(WMDidActivateApplicationNotification)
                          object:nil];
    
    [workspaceCenter addObserver:self
                        selector:@selector(windowManagerDidManageWindow:)
                            name:CF_NOTIFICATION(WMDidManageWindowNotification)
                          object:nil];
    [workspaceCenter addObserver:self
                        selector:@selector(windowManagerDidUnmanageWindow:)
                            name:CF_NOTIFICATION(WMDidUnmanageWindowNotification)
                          object:nil];
  }

  return self;
}

@end

@implementation ProcessManager (Applications)

// Convert "NSApplicationProcessIdentifier" to mutable set
- (NSDictionary *)_normalizeApplicationInfo:(NSDictionary *)appInfo
{
  NSMutableDictionary *_appInfo = [appInfo mutableCopy];
  NSString *appPID = _appInfo[@"NSApplicationProcessIdentifier"];

  _appInfo[@"NSApplicationProcessIdentifier"] = [NSMutableOrderedSet orderedSetWithObject:appPID];
  // [_appInfo setObject:[NSMutableOrderedSet orderedSetWithObject:appPID]
  //              forKey:@"NSApplicationProcessIdentifier"];

  return [_appInfo autorelease];
}

- (NSDictionary *)_applicationWithName:(NSString *)appName
{
  for (NSDictionary *entry in _applications) {
    if ([entry[@"NSApplicationName"] isEqualToString:appName]) {
      return entry;
    }
  }

  return nil;
}

// NSWorkspaceDidLaunchApplicationNotification
// Register launched application.
- (void)applicationDidLaunch:(NSNotification *)notif
{
  NSString *appName;
  BOOL appAlreadyRegistered = NO;

  WMLogWarning("NSWorkspaceDidLaunchApplication: %@",
               convertNStoCFString([notif userInfo][@"NSApplicationName"]));


  // Check if application already in app list.
  appName = [notif userInfo][@"NSApplicationName"];
  for (NSDictionary *aInfo in _applications) {
    if ([appName isEqualToString:aInfo[@"NSApplicationName"]]) {
      appAlreadyRegistered = YES;
      break;
    }
  }

  if (appAlreadyRegistered == NO) {
    NSDictionary *appInfo = [self _normalizeApplicationInfo:[notif userInfo]];
    [_applications addObject:appInfo];
  }

  if ([[NSApp delegate] processesPanel]) {
    [[[NSApp delegate] processesPanel] updateAppList];
  }
}

// NSWorkspaceDidTerminateApplicationNotification
- (void)applicationDidTerminate:(NSNotification *)notif
{
  NSString *appName;
  NSDictionary *appInfo;

  appName = [[notif userInfo] objectForKey:@"NSApplicationName"];
  if (appName == nil) {
    return;
  }
  appInfo = [self _applicationWithName:appName];
  if (appInfo == nil) {
    return;
  }

  NSDebugLLog(@"Processes", @"Application `%@` terminated, notification object: %@", appName,
              [notif object]);

  [_applications removeObject:appInfo];
  if (_workspaceQuitting == NO) {
    if ([[NSApp delegate] processesPanel]) {
      [[[NSApp delegate] processesPanel] updateAppList];
    }
  }
}

- (void)applicationDidBecomeActive:(NSNotification *)notif
{
  // WMLogWarning("ApplicationDidBecomeActive: %@", convertNStoCFDictionary([notif userInfo]));
  _activeApplication = [[notif userInfo] copy];
}

- (void)sendSignal:(int)signal toApplication:(NSDictionary *)appInfo
{
  NSSet *pidList = appInfo[@"NSApplicationProcessIdentifier"];
  NSNotification *notif;

  for (NSNumber *pid in pidList) {
    // If PID is '-1' let window manager kill that app.
    if ([pid intValue] != -1) {
      NSDebugLLog(@"Processes", @"Sending signal %i to %i", signal, [pid intValue]);
      kill([pid intValue], signal);
    }

    // X11 app: In normal running mode it is tracked by Window Wanager.
    // WM sends notification on app terminate. When Workspace is quiting we need to generate such
    // notification because Window Manager preparing to quit.
    // GNUstep app: send notification to remove app from list
    if ([appInfo[@"IsXWindowApplication"] isEqualToString:@"NO"] && _workspaceQuitting == YES) {
      notif = [NSNotification notificationWithName:NSWorkspaceDidTerminateApplicationNotification
                                            object:@"ProcessManager"
                                          userInfo:appInfo];
      [[[NSWorkspace sharedWorkspace] notificationCenter] postNotification:notif];
    }
  }
}

- (BOOL)_terminateApplication:(NSDictionary *)appInfo
{
  NSString *_appName;
  id _app = nil;

  _appName = appInfo[@"NSApplicationName"];
  if ([_appName isEqualToString:@"Workspace"] || [_appName isEqualToString:@"Login"]) {
    // don't remove from app list - system apps
    return YES;
  }

  NSDebugLLog(@"Processes", @"Terminating - %@", _appName);

  _app = [NSConnection rootProxyForConnectionWithRegisteredName:_appName host:@""];
  if (_app == nil) {
    NSDebugLLog(@"Processes", @"Connection to %@ failed. Removing from list of known applications", _appName);
    [_applications removeObject:appInfo];
    return YES;
  }
  @try {
    [_app terminate:NSApp];
  } @catch (NSException *e) {
    // application terminated -- remove app from launched apps list
    [_applications removeObject:appInfo];
    [[_app connectionForProxy] invalidate];
    // libobjc2 prints out info to console all exception (even catched).
    NSDebugLLog(@"Processes", @"Application %@ was terminated. Ignore ObjC runtime exception - it's catched.", _appName);
    return YES;
  }

  [[_app connectionForProxy] invalidate];

  return NO;
}

// Performs gracefull termination of running GNUstep applications.
// Returns:
//   YES -- if all applications exited
//    NO -- if some application returns NO on applicationShouldTerminate: call.
- (BOOL)terminateAllApps
{
  NSArray *_appsCopy = [_applications copy];
  BOOL _noRunningApps = YES;

  // Workspace goes into quit process.
  // Application removal from list will be processed inside this method
  _workspaceQuitting = YES;

  NSDebugLLog(@"Processes", @"Terminating of runnig apps started!");

  for (int idx = [_appsCopy count] - 1; idx >= 0; idx--) {
    NSDictionary *_appDict = _appsCopy[idx];
    if ([_appDict[@"IsXWindowApplication"] isEqualToString:@"YES"]) {
      [self sendSignal:SIGKILL toApplication:_appDict];
      continue;
    } else if ([self _terminateApplication:_appDict] != NO) {
      continue;
    }

    NSDebugLLog(@"Processes", @"Application '%@' refused to terminate!",
                [_appDict objectForKey:@"NSApplicationName"]);
    _noRunningApps = NO;
    _workspaceQuitting = NO;
    [[[NSApp delegate] processesPanel] updateAppList];
    break;
  }

  NSDebugLLog(@"Processes", @"Terminating of runnig apps completed!");
  [_appsCopy release];

  return _noRunningApps;
}

@end

@implementation ProcessManager (WindowManager)

- (NSDictionary *)_applicationInfoForWindow:(WWindow *)wwin
{
  NSMutableDictionary *appInfo = [NSMutableDictionary dictionary];
  NSString *appName = nil;
  NSString *appPath = nil;
  int app_pid;
  char *app_command;

  // Gather NSApplicationName and NSApplicationPath
  if (!strcmp(wwin->wm_class, "GNUstep")) {
    [appInfo setObject:@"NO" forKey:@"IsXWindowApplication"];
    appName = [NSString stringWithCString:wwin->wm_instance];
    appPath = [[NSWorkspace sharedWorkspace] fullPathForApplication:appName];
  } else {
    [appInfo setObject:@"YES" forKey:@"IsXWindowApplication"];
    appName = [NSString stringWithCString:wwin->wm_class];
    app_command = wGetCommandForWindow(wwin->client_win);
    if (app_command) {
      appPath = [[OSEFileManager defaultManager]
          absolutePathForCommand:[NSString stringWithCString:app_command]];
    }
  }
  // NSApplicationName = NSString*
  [appInfo setObject:appName forKey:@"NSApplicationName"];
  // NSApplicationPath = NSString*
  if (appPath) {
    [appInfo setObject:appPath forKey:@"NSApplicationPath"];
  } else if (app_command) {
    [appInfo setObject:[NSString stringWithCString:app_command] forKey:@"NSApplicationPath"];
  } else {
    [appInfo setObject:@"--" forKey:@"NSApplicationPath"];
  }

  // NSApplicationProcessIdentifier = NSNumber*
  if ((app_pid = wNETWMGetPidForWindow(wwin->client_win)) > 0) {
    [appInfo setObject:[NSNumber numberWithInt:app_pid] forKey:@"NSApplicationProcessIdentifier"];
  } else if ((app_pid = wNETWMGetPidForWindow(wwin->main_window)) > 0) {
    [appInfo setObject:[NSNumber numberWithInt:app_pid] forKey:@"NSApplicationProcessIdentifier"];
  } else {
    [appInfo setObject:[NSNumber numberWithInt:-1] forKey:@"NSApplicationProcessIdentifier"];
  }

  return (NSDictionary *)appInfo;
}

- (NSDictionary *)_applicationInfoForApp:(WApplication *)wapp window:(WWindow *)wwin
{
  NSMutableDictionary *appInfo = [[self _applicationInfoForWindow:wwin] mutableCopy];
  NSImage *iconImage = nil;

  // Get icon image from windowmaker app structure(WApplication)
  // NSApplicationIcon=NSImage*
  NSDebugLLog(@"Processes", @"%@ icon filename: %s", appInfo[@"NSApplicationName"],
              wapp->app_icon->icon->file);
  if (wapp->app_icon->icon->file_image) {
    iconImage = WSImageForRasterImage(wapp->app_icon->icon->file_image);
  } else if (wapp->app_icon->icon->file) {
    iconImage = [[NSImage alloc]
        initByReferencingFile:[NSString stringWithCString:wapp->app_icon->icon->file]];
  }
  if (iconImage) {
    [appInfo setObject:WSImageForRasterImage(wapp->app_icon->icon->file_image)
                forKey:@"NSApplicationIcon"];
  }

  return (NSDictionary *)[appInfo autorelease];
}

// WMDidCreateApplicationNotification
- (void)windowManagerDidCreateApplication:(NSNotification *)notif
{
  WApplication *wapp = (WApplication *)[(CFObject *)[notif object] object];
  NSNotification *localNotif = nil;
  NSDictionary *appInfo = nil;
  WAppIcon *appIcon;
  WWindow *wwin;

  if (_workspaceQuitting != NO || !wapp) {
    return;
  }

  appIcon = wLaunchingAppIconForInstance(wapp->main_wwin->screen, wapp->main_wwin->wm_instance,
                                         wapp->main_wwin->wm_class);
  if (appIcon) {
    wLaunchingAppIconFinish(wapp->main_wwin->screen, appIcon);
    appIcon->main_window = wapp->main_window;
  }

  // GNUstep application will register itself in ProcessManager with AppKit notification.
  if (!strcmp(wapp->main_wwin->wm_class, "GNUstep")) {
    return;
  }

  if (CFArrayGetCount(wapp->windows) <= 0) {
    wwin = wapp->main_wwin;
  } else {
    wwin = (WWindow *)CFArrayGetValueAtIndex(wapp->windows, 0);
  }
  appInfo = [self _applicationInfoForApp:wapp window:wwin];
  NSDebugLLog(@"Processes", @"ProcessManager-windowManagerDidCreateApplication: %@", appInfo);

  localNotif = [NSNotification notificationWithName:NSWorkspaceDidLaunchApplicationNotification
                                             object:appInfo
                                           userInfo:appInfo];
  [self applicationDidLaunch:localNotif];
}

// WMDidDestroyApplicationNotification
// Application could be terminate in 2 ways:
// 1. normal - AppKit notfication mechanism works
// 2. crash - no AppKit involved so we should use this code to inform ProcessManager
// [ProcessManager applicationDidTerminate:] should expect 2 calls for option #1.
- (void)windowManagerDidDestroyApplication:(NSNotification *)notif
{
  WApplication *wapp = (WApplication *)[(CFObject *)[notif object] object];
  NSNotification *localNotif = nil;
  NSDictionary *appInfo = nil;

  if (_workspaceQuitting != NO || !wapp) {
    return;
  }

  appInfo = [self _applicationInfoForApp:wapp window:wapp->main_wwin];
  localNotif = [NSNotification notificationWithName:NSWorkspaceDidTerminateApplicationNotification
                                             object:@"WindowManager"
                                           userInfo:appInfo];
  [self applicationDidTerminate:localNotif];
}

- (void)windowManagerDidActivateApplication:(NSNotification *)notif
{
  WApplication *wapp = (WApplication *)[(CFObject *)[notif object] object];
  WWindow *wwin = NULL;

  if (wapp == NULL) {
    return;
  }

  if (CFArrayGetCount(wapp->windows) <= 0) {
    wwin = wapp->main_wwin;
  } else {
    wwin = wapp->last_focused ? wapp->last_focused : (WWindow *)CFArrayGetValueAtIndex(wapp->windows, 0);
  }

  _activeApplication = [self _applicationInfoForWindow:wwin];

  WMLogWarning("Window Manager Did Activate Application: %@", convertNStoCFDictionary(_activeApplication));
}

// WMDidManageWindowNotification
- (void)windowManagerDidManageWindow:(NSNotification *)notif
{
  WWindow *wwin = (WWindow *)[(CFObject *)[notif object] object];
  NSDictionary *windowAppInfo, *appInfo;
  NSMutableOrderedSet *pidList = nil;

  if (_workspaceQuitting != NO || !wwin || !strcmp(wwin->wm_class, "GNUstep")) {
    return;
  }

  windowAppInfo = [self _applicationInfoForWindow:wwin];
  if (!windowAppInfo) {
    return;
  }

  if ((appInfo = [self _applicationWithName:windowAppInfo[@"NSApplicationName"]]) != nil) {
    pidList = appInfo[@"NSApplicationProcessIdentifier"];
  }
  if (!pidList) {
    return;
  }

  [pidList addObject:windowAppInfo[@"NSApplicationProcessIdentifier"]];
  if ([[NSApp delegate] processesPanel]) {
    [[[NSApp delegate] processesPanel] updateAppList];
  }
}

// WMDidUnmanageWindowNotification
// 1. Determine application which owns subprocess
// 2. Check if processes still exists from application PID list with
//    kill (pid, 0).
- (void)windowManagerDidUnmanageWindow:(NSNotification *)notif
{
  WWindow *wwin = (WWindow *)[(CFObject *)[notif object] object];
  NSDictionary *wwinAppInfo, *appInfo;
  NSString *appName;
  NSMutableOrderedSet *appPIDList;
  NSArray *_appPIDList;
  int pid;

  if (_workspaceQuitting != NO || !wwin || !strcmp(wwin->wm_class, "GNUstep")) {
    return;
  }

  wwinAppInfo = [self _applicationInfoForWindow:wwin];
  appName = [wwinAppInfo objectForKey:@"NSApplicationName"];
  if (!(appInfo = [self _applicationWithName:appName])) {
    return;
  }
  appPIDList = [appInfo objectForKey:@"NSApplicationProcessIdentifier"];
  _appPIDList = [appPIDList array];
  for (NSString *pidString in _appPIDList) {
    pid = [pidString integerValue];
    if ((kill(pid, 0) == -1) && (errno == ESRCH)) {  // process doesn't exist
      [appPIDList removeObject:pidString];
    }
  }
  [_appPIDList release];

  if ([[NSApp delegate] processesPanel]) {
    [[[NSApp delegate] processesPanel] updateAppList];
  }
}

@end

@implementation ProcessManager (Background)

// It's just a alternative method to start some operation.
// Background operations can be started anywhere in Workspace.
// Each operation must post WMOperationDidCreateNotification to
// register in ProcessManager and thus to list in "Background" of "Processes"
// panel.
// FIXME: only Copy, Link, Move, Delete operations are supported.
- (id)startOperationWithType:(OperationType)opType
                      source:(NSString *)src
                      target:(NSString *)dest
                       files:(NSArray *)files
{
  BGOperation *newOperation = nil;
  NSString *message = nil;
  NSString *format;
  NSString *object;

  switch (opType) {
    case CopyOperation:
    case LinkOperation: {
      newOperation = [[FileMover alloc] initWithOperationType:opType
                                                    sourceDir:src
                                                    targetDir:dest
                                                        files:files
                                                      manager:self];
    } break;
    case MoveOperation: {
      if ([dest isEqualToString:[[[NSApp delegate] recycler] path]]) {
        if ([files count] > 1) {
          message = @"Do you really want to recycle selected files?";
        } else {
          if (files && [files count] > 0)
            object = [files lastObject];
          else
            object = src;
          format = @"Do you really want to recycle \n%@?";
          message = [NSString stringWithFormat:format, object];
        }
        if (NXTRunAlertPanel(_(@"Workspace"), message, _(@"Recycle"), _(@"Cancel"), nil) !=
            NSAlertDefaultReturn) {
          return nil;
        }
      }

      newOperation = [[FileMover alloc] initWithOperationType:MoveOperation
                                                    sourceDir:src
                                                    targetDir:dest
                                                        files:files
                                                      manager:self];
    } break;
    case DeleteOperation: {
      if ([src isEqualToString:[[[NSApp delegate] recycler] path]]) {
        message = @"Do you really want to destroy items in Recycler?";
      } else if (files && [files count] > 1) {
        format = @"Do you really want to destroy selected files in \n%@?";
        message = [NSString stringWithFormat:format, src];
      } else {
        if (files && [files count] > 0)
          object = [files lastObject];
        else
          object = src;
        format = @"Do you really want to destroy \n%@?";
        message = [NSString stringWithFormat:format, object];
      }

      if (NXTRunAlertPanel(_(@"Workspace"), message, _(@"Destroy"), _(@"Cancel"), nil) !=
          NSAlertDefaultReturn) {
        return nil;
      }

      newOperation = [[FileMover alloc] initWithOperationType:DeleteOperation
                                                    sourceDir:src
                                                    targetDir:dest
                                                        files:files
                                                      manager:self];
    } break;
    default:
      NSDebugLLog(@"Processes", @"ProcessManager: requested operation is not supported!");
  }
  // newOperation will be registered upon receiving
  // WMOperationDidCreateNotification

  return newOperation;
}

- (void)operationDidCreate:(NSNotification *)notif
{
  [_operations addObject:[notif object]];

  if ([[NSApp delegate] processesPanel]) {
    [[[NSApp delegate] processesPanel] updateBGProcessList];
  }

  [self updateBackInfoLabel];
}

- (void)operationWillDestroy:(NSNotification *)notif
{
  [_operations removeObject:[notif object]];

  if ([[NSApp delegate] processesPanel]) {
    [[[NSApp delegate] processesPanel] updateBGProcessList];
  }

  [self updateBackInfoLabel];
}

- (void)operationDidChangeState:(NSNotification *)notif
{
  BGOperation *op = [notif object];

  if (![[NSApp delegate] processesPanel] && [op state] == OperationAlert) {
    // 'Processes' missed the notification so show operation view directly
    [[NSApp delegate] showProcesses:self];
    [[[NSApp delegate] processesPanel] setView:op];
  }

  [self updateBackInfoLabel];
}

// Called on Workspace quitting
- (BOOL)terminateAllBGOperations
{
  NSEnumerator *e;
  BGOperation *bgOp;
  BOOL success = NO;

  // No running background processes
  if ([_operations count] <= 0) {
    return YES;
  }

  switch (NXTRunAlertPanel(@"Log Out",
                           @"You have background file operations running.\n"
                           @"Do you want to stop all operations and quit?",
                           @"Cancel", @"Review operations", @"Stop and quit", nil)) {
    case NSAlertDefaultReturn:  // Cancel
      NSDebugLLog(@"Processes", @"Workspace quit: cancel terminating running background operations.");
      break;
    case NSAlertAlternateReturn:  // Review operations
      [[[NSApp delegate] processesPanel] showOperation:[_operations objectAtIndex:0]];
      break;
    default:
      // Stop running operations
      e = [_operations objectEnumerator];
      while ((bgOp = [e nextObject])) {
        [bgOp stop:self];
      }
      success = YES;
      break;
  }

  // Wait for operations to terminate
  while ([_operations count] > 0 && success != NO) {
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
  }

  return success;
}

@end

//--- FileViewer info labels
@implementation ProcessManager (InfoLabels)

- (id)backInfoLabel
{
  NSTextField *label;

  if (!backInfoLabelCopies) {
    backInfoLabelCopies = [[NSMutableArray alloc] initWithCapacity:1];
  }

  NSDebugLLog(@"Processes", @"[Processes] backInfoLabel: labels befor create new: %lu",
              [backInfoLabelCopies count]);

  label = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 180, 12)];
  [label setTextColor:[NSColor darkGrayColor]];
  [label setDrawsBackground:NO];
  [label setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
  [label setAlignment:NSRightTextAlignment];
  [label setBordered:NO];
  [label setBezeled:NO];

  [backInfoLabelCopies addObject:label];
  [label release];

  return [backInfoLabelCopies lastObject];
}

- (void)releaseBackInfoLabel:(id)label
{
  if (backInfoLabelCopies) {
    [backInfoLabelCopies removeObject:label];
  }
}

- (NSString *)_typeMessageForOperation:(BGOperation *)op
{
  switch ([op type]) {
    case CopyOperation:
      return @"Copying...";
    case DuplicateOperation:
      return @"Duplicating...";
    case MoveOperation:
      return @"Moving...";
    case LinkOperation:
      return @"Linking...";
    case DeleteOperation:
      return @"Destroying...";
    case RecycleOperation:
      return @"Recycling...";
    case MountOperation:
      return @"Mounting media...";
    case UnmountOperation:
      return @"Unmounting media...";
    case EjectOperation:
      return @"Ejecting media...";
    case SizeOperation:
      return @"Sizing...";
    case PermissionOperation:
      return @"Changing permissions...";
  }

  return @"Performing background operation...";
}

- (void)updateBackInfoLabel
{
  NSString *labelText;
  NSColor *labelColor = [NSColor darkGrayColor];

  if ([_operations count] == 0) {
    labelText = @"";
  } else if ([_operations count] == 1) {
    labelText = [self _typeMessageForOperation:[_operations objectAtIndex:0]];
  } else {
    labelText = [NSString stringWithFormat:@"%lu background processes", [_operations count]];
  }

  for (BGOperation *op in _operations) {
    if ([op state] == OperationAlert) {
      labelColor = [NSColor whiteColor];
    }
  }

  [backInfoLabelCopies makeObjectsPerformSelector:@selector(setStringValue:) withObject:labelText];
  [backInfoLabelCopies makeObjectsPerformSelector:@selector(setTextColor:) withObject:labelColor];
}

@end

NSString *EditOperationTypeKey = @"OperationType";
NSString *EditPathKey = @"Path";
NSString *EditObjectsKey = @"Objects";

@implementation ProcessManager (EditOperations)

- (BOOL)registerEditOperation:(OperationType)opType
                directoryPath:(NSString *)dir
                      objects:(NSArray *)objects
{
  _editOperation = @{
    EditOperationTypeKey : [NSNumber numberWithInteger:opType],
    EditPathKey : dir,
    EditObjectsKey : objects
  };

  [_editOperation retain];

  return YES;
}

- (void)unregisterEditOperation
{
  [_editOperation release];
  _editOperation = nil;
}

@end
