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

#import <DesktopKit/NXTAlert.h>
#import <DesktopKit/NXTFileManager.h>

#import "Controller.h"
#import "WorkspaceNotificationCenter.h"
#import "Workspace+WM.h"
#import "Processes/Processes.h"

#import "Operations/ProcessManager.h"
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
  if (shared == nil)
    {
      shared = [self new];
    }
  return shared;
}

- (void)dealloc
{
  NSDebugLLog(@"Memory", @"ProcessManager: dealloc");

  [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
  [[WorkspaceNotificationCenter defaultCenter] removeObserver:self];

  RELEASE(applications);
  RELEASE(operations);
  
  TEST_RELEASE(backInfoLabelCopies);
  
  shared = nil;

  [super dealloc];
}

- init
{
  NSNotificationCenter *nc;
  NSWorkspace          *ws;

  [super init];

  ws = [NSWorkspace sharedWorkspace];
  nc = [ws notificationCenter];

  applications = [[NSMutableArray alloc]
                   initWithArray:[ws launchedApplications]];
  for (int i=0; i < [applications count]; i++)
    {
      NSDictionary *_appInfo;
      
      _appInfo = [self _normalizeApplicationInfo:[applications objectAtIndex:i]];
      [applications replaceObjectAtIndex:i withObject:_appInfo];
    }
  
  operations = [[NSMutableArray alloc] init];

  //  Applications - AppKit notifications
  [nc addObserver:self
         selector:@selector(applicationWillLaunch:)
             name:NSWorkspaceWillLaunchApplicationNotification
           object:nil];
  [nc addObserver:self
         selector:@selector(applicationDidLaunch:)
             name:NSWorkspaceDidLaunchApplicationNotification
           object:nil];
  [nc addObserver:self
         selector:@selector(applicationDidTerminate:)
             name:NSWorkspaceDidTerminateApplicationNotification
           object:nil];

  // Background operations
  [[NSNotificationCenter defaultCenter] 
    addObserver:self
       selector:@selector(operationDidCreate:)
	   name:WMOperationDidCreateNotification
	 object:nil];
  [[NSNotificationCenter defaultCenter] 
    addObserver:self
       selector:@selector(operationWillDestroy:)
	   name:WMOperationWillDestroyNotification
	 object:nil];
  [[NSNotificationCenter defaultCenter] 
    addObserver:self
       selector:@selector(operationDidChangeState:)
	   name:WMOperationDidChangeStateNotification
	 object:nil];
  // [[NSNotificationCenter defaultCenter] 
  //   addObserver:self
  //      selector:@selector(operationProcessingFile:)
  //          name:WMOperationProcessingFileNotification
  //        object:nil];

  // WM - CoreFoundation notifications
  [[WorkspaceNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(applicationDidCreate:)
	   name:WMDidCreateApplicationNotification];
  [[WorkspaceNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(applicationDidDestroy:)
	   name:WMDidDestroyApplicationNotification];
  [[WorkspaceNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(applicationDidOpenWindow:)
	   name:WMDidManageWindowNotification];
  [[WorkspaceNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(applicationDidCloseWindow:)
	   name:WMDidUnmanageWindowNotification];
  
  return self;
}

- (NSArray *)applications
{
  return applications;
}

- (NSArray *)operations
{
  return operations;
}

@end


@implementation ProcessManager (Applications)

// Convert "NSApplicationProcessIdentifier" to mutable set of strings
- (NSDictionary *)_normalizeApplicationInfo:(NSDictionary *)appInfo
{
  NSMutableDictionary *_appInfo = [appInfo mutableCopy];
  id nsapi;
  NSString *appPID;

  // Detect class of "NSApplicationProcessIdentifier" value and replace
  // with mutable array of strings.
  nsapi = [_appInfo objectForKey:@"NSApplicationProcessIdentifier"];

  // "NSApplicationProcessIdentifier" can be NSSmallInt, NSConstantString,
  // GSCInlineString. Expected that all except NSSmallInt is kind of class
  // NSString.
  if ([nsapi isKindOfClass:[NSString class]]) {
    appPID = nsapi;
  } else {
    appPID = [NSString stringWithFormat:@"%i", [nsapi intValue]];
  }
  
  [_appInfo setObject:[NSMutableOrderedSet orderedSetWithObject:appPID]
               forKey:@"NSApplicationProcessIdentifier"];

  return [_appInfo autorelease];
}

- (NSDictionary *)_applicationWithName:(NSString *)appName
{
  NSDictionary *entry;
  NSString *eAppName;
  
  for (entry in applications) {
    eAppName = [entry objectForKey:@"NSApplicationName"];
    if ([eAppName isEqualToString:appName]) {
      return entry;
    }
  }
  
  return nil;
}

// NSWorkspaceWillLaunchApplicationNotification
// Do nothing. Launched application registered upon receiving
// NSWorkspaceDidLaunchApplicationNotification.
- (void)applicationWillLaunch:(NSNotification *)notif
{
}

// NSWorkspaceDidLaunchApplicationNotification
// Register launched application.
// TODO
- (void)applicationDidLaunch:(NSNotification *)notif
{
  NSDictionary *newAppInfo;
  NSString *newAppName;
  NSDictionary *aInfo;
  NSString *aName;
  NSMutableOrderedSet *aPIDList, *newAppPID;
  BOOL skipLaunchedApp = NO;

  NSLog(@"NSWorkspaceDidLaunchApplication: %@", [notif userInfo]);
  
  newAppInfo = [self _normalizeApplicationInfo:[notif userInfo]];
  newAppName = [newAppInfo objectForKey:@"NSApplicationName"];
  newAppPID = [newAppInfo objectForKey:@"NSApplicationProcessIdentifier"];

  // Check if application already in app list. If so - append PID to the
  // "NSApplicationProcessIdentifier" of existing object in 'applications' list.
  for (aInfo in applications) {
    aName = [aInfo objectForKey:@"NSApplicationName"];
    aPIDList = [aInfo objectForKey:@"NSApplicationProcessIdentifier"];
    
    if ([aName isEqualToString:newAppName]) {
      skipLaunchedApp = YES;
      if ([aPIDList containsObject:@""] == NO &&
          ([aPIDList containsObject:[newAppPID firstObject]] == NO)) {
        [aPIDList unionOrderedSet:newAppPID];
      }
      break;
    }
  }

  if (skipLaunchedApp == NO) {
    [applications addObject:newAppInfo];
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

  if (_workspaceQuitting) {
    return;
  }
  appName = [[notif userInfo] objectForKey:@"NSApplicationName"];
  
  if ((appInfo = [self _applicationWithName:appName])) {
    [applications removeObject:appInfo];
    if ([[NSApp delegate] processesPanel]) {
      [[[NSApp delegate] processesPanel] updateAppList];
    }
  }
}

// Performs gracefull termination of running GNUstep applications.
// Returns:
//   YES -- if all applications exited
//    NO -- if some application returns NO on applicationShouldTerminate: call.
- (BOOL)terminateAllApps
{
  NSArray *_appsCopy = [applications copy];
  NSString *_appName = nil;
  id _app;
  BOOL _noRunningApps = YES;

  // Workspace goes into quit process.
  // Application removal from list will be processed inside this method
  _workspaceQuitting = YES;

//  NSLog(@"Launched applications: %@", apps);
  for (NSDictionary *_appDict in _appsCopy) {
    if ([[_appDict objectForKey:@"IsXWindowApplication"] isEqualToString:@"YES"]) {
      NSSet *pidList;
      pidList = [_appDict objectForKey:@"NSApplicationProcessIdentifier"];
          
      for (NSString *pidString in pidList) {
        // If PID is '-1' let window manager kill that app.
        if ([pidString isEqualToString:@"-1"] == NO) {
          kill([pidString integerValue], SIGKILL);
        }
      }
      [applications removeObject:_appDict];
      continue; // go to 'while' statement
    }
    else {
      _appName = [_appDict objectForKey:@"NSApplicationName"];
      if ([_appName isEqualToString:@"Workspace"] || [_appName isEqualToString:@"Login"]) {
        // don't remove from app list - system apps
        continue; // go to 'while' statement
      }
      NSLog(@"Terminating - %@", _appName);
      _app = [NSConnection rootProxyForConnectionWithRegisteredName:_appName host:@""];
      if (_app == nil) {
        NSLog(@"Connection to %@ failed. Removing from list of known applications",
              _appName);
        [applications removeObject:_appDict];
        continue; // go to 'while' statement
      }
          
      @try {
        [_app terminate:nil];
      }
      @catch (NSException *e) {
        // application terminated -- remove app from launched apps list
        [applications removeObject:_appDict];
        [[_app connectionForProxy] invalidate];
        continue; // go to 'while' statement
      }
    }

    NSLog(@"Application %@ ignore terminate request!", _appName);
    _noRunningApps = NO;
    _workspaceQuitting = NO;
    [[[NSApp delegate] processesPanel] updateAppList];
    break;
  }

  NSLog(@"Terminating of runnig apps completed!");
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
      appPath = [[NXTFileManager defaultManager]
                  absolutePathForCommand:[NSString stringWithCString:app_command]];
    }
  }
  // NSApplicationName = NSString*
  [appInfo setObject:appName forKey:@"NSApplicationName"];
  // NSApplicationPath = NSString*
  if (appPath) {
    [appInfo setObject:appPath forKey:@"NSApplicationPath"];
  } else if (app_command) {
    [appInfo setObject:[NSString stringWithCString:app_command]
                forKey:@"NSApplicationPath"];
  } else {
    [appInfo setObject:@"--" forKey:@"NSApplicationPath"];
  }

  // NSApplicationProcessIdentifier = NSString*
  if ((app_pid = wNETWMGetPidForWindow(wwin->client_win)) > 0) {
    [appInfo setObject:[NSString stringWithFormat:@"%i", app_pid]
                forKey:@"NSApplicationProcessIdentifier"];
  }
  else if ((app_pid = wNETWMGetPidForWindow(wwin->main_window)) > 0) {
    [appInfo setObject:[NSString stringWithFormat:@"%i", app_pid]
                forKey:@"NSApplicationProcessIdentifier"];
  }
  else {
    [appInfo setObject:@"-1" forKey:@"NSApplicationProcessIdentifier"];
  }

  return (NSDictionary *)appInfo;
}

- (NSDictionary *)_applicationInfoForApp:(WApplication *)wapp window:( WWindow *)wwin
{
  NSMutableDictionary *appInfo = [[self _applicationInfoForWindow:wwin] mutableCopy];
  
  // Get icon image from windowmaker app structure(WApplication)
  // NSApplicationIcon=NSImage*
  // NSLog(@"%@ icon filename: %s", xAppName, wapp->app_icon->icon->file);
  if (wapp->app_icon->icon->file_image) {
    [appInfo setObject:WSImageForRasterImage(wapp->app_icon->icon->file_image)
                forKey:@"NSApplicationIcon"];
  }

  return (NSDictionary *)[appInfo autorelease];
}

- (NSMutableOrderedSet *)_pidsForApplicationWithName:(NSString *)appName
{
  NSDictionary *appInfo = [self _applicationWithName:appName];

  if (!appInfo) {
    return nil;
  }
  
  return [appInfo objectForKey:@"NSApplicationProcessIdentifier"];
}

// WMDidCreateApplicationNotification
- (void)applicationDidCreate:(NSNotification *)notif
{
  WApplication *wapp = (WApplication *)[(CFObject *)[notif object] object];
  NSNotification *localNotif = nil;
  NSDictionary *appInfo = nil;
  WAppIcon *appIcon;
  WWindow *wwin;

  if (_workspaceQuitting != NO || !wapp) {
    return;
  }

  appIcon = wLaunchingAppIconForInstance(wapp->main_window_desc->screen_ptr,
                                         wapp->main_window_desc->wm_instance,
                                         wapp->main_window_desc->wm_class);
  if (appIcon) {
    wLaunchingAppIconFinish(wapp->main_window_desc->screen_ptr, appIcon);
    appIcon->main_window = wapp->main_window;
  }

  // GNUstep application will register itself in ProcessManager with AppKit notification.
  if (!strcmp(wapp->main_window_desc->wm_class, "GNUstep")) {
    return;
  }
    
  wwin = (WWindow *)CFArrayGetValueAtIndex(wapp->windows, 0);
  appInfo = [self _applicationInfoForApp:wapp window:wwin];
  NSDebugLLog(@"WM", @"ProcessManager-applicationDidCreate: %@", appInfo);

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
- (void)applicationDidDestroy:(NSNotification *)notif
{
  WApplication *wapp = (WApplication *)[(CFObject *)[notif object] object];
  NSNotification *localNotif = nil;
  NSDictionary *appInfo = nil;

  if (_workspaceQuitting != NO || !wapp || !strcmp(wapp->main_window_desc->wm_class,"GNUstep")) {
    return;
  }
  
  appInfo = [self _applicationInfoForApp:wapp window:wapp->main_window_desc];
  localNotif = [NSNotification notificationWithName:NSWorkspaceDidTerminateApplicationNotification
                                             object:nil
                                           userInfo:appInfo];
  [self applicationDidTerminate:localNotif];
}

// WMDidManageWindowNotification
- (void)applicationDidOpenWindow:(NSNotification *)notif
{
  WWindow *wwin = (WWindow *)[(CFObject *)[notif object] object];
  NSDictionary *appInfo;
  NSMutableOrderedSet *pidList;
  
  if (_workspaceQuitting != NO || !wwin || !strcmp(wwin->wm_class,"GNUstep")) {
    return;
  }
  
  appInfo = [self _applicationInfoForWindow:wwin];
  NSLog(@"TODO: appInfo - %@", appInfo);
  if (!appInfo) {
    return;
  }
  pidList = [self _pidsForApplicationWithName:[appInfo objectForKey:@"NSApplicationName"]];
  if (!pidList) {
    return;
  }
  [pidList addObject:[appInfo objectForKey:@"NSApplicationProcessIdentifier"]];
  if ([[NSApp delegate] processesPanel]) {
    [[[NSApp delegate] processesPanel] updateAppList];
  }
}

// WMDidUnmanageWindowNotification
// 1. Determine application which owns subprocess
// 2. Check if processes still exists from application PID list with
//    kill (pid, 0).
- (void)applicationDidCloseWindow:(NSNotification *)notif
{
  WWindow *wwin = (WWindow *)[(CFObject *)[notif object] object];
  NSDictionary *wwinAppInfo, *appInfo;
  NSString *appName;
  NSMutableOrderedSet *appPIDList;
  NSArray *_appPIDList;
  int pid;
  
  if (_workspaceQuitting != NO || !wwin || !strcmp(wwin->wm_class,"GNUstep")) {
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
    if ((kill(pid, 0) == -1) && (errno == ESRCH)) { // process doesn't exist
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
  BGOperation	*newOperation = nil;
  NSString	*message = nil;
  NSString	*format;
  NSString	*object;
   
  
  switch (opType)
    {
    case CopyOperation:
    case LinkOperation:
      {
        newOperation = [[FileMover alloc] initWithOperationType:opType
                                                      sourceDir:src
                                                      targetDir:dest
                                                          files:files
                                                        manager:self];
      }
      break;
    case MoveOperation:
      {
        if ([dest isEqualToString:[[[NSApp delegate] recycler] path]])
          {
            if ([files count] > 1)
              {
                message = @"Do you really want to recycle selected files?";
              }
            else
              {
                if (files && [files count] > 0)
                  object = [files lastObject];
                else
                  object = src;
                format = @"Do you really want to recycle \n%@?";
                message = [NSString stringWithFormat:format, object];
              }
            if (NXTRunAlertPanel(_(@"Workspace"), message,
                                _(@"Recycle"), _(@"Cancel"), nil) 
                != NSAlertDefaultReturn)
              {
                return nil;
              }
          }

        newOperation = [[FileMover alloc] initWithOperationType:MoveOperation
                                                      sourceDir:src
                                                      targetDir:dest
                                                          files:files
                                                        manager:self];
      }
      break;
    case DeleteOperation:
      {
        if ([src isEqualToString:[[[NSApp delegate] recycler] path]])
          {
            message = @"Do you really want to destroy items in Recycler?";
          }
        else if (files && [files count] > 1)
          {
            format = @"Do you really want to destroy selected files in \n%@?";
            message = [NSString stringWithFormat:format, src];
          }
        else
          {
            if (files && [files count] > 0)
              object = [files lastObject];
            else
              object = src;
            format = @"Do you really want to destroy \n%@?";
            message = [NSString stringWithFormat:format, object];
          }
        
        if (NXTRunAlertPanel(_(@"Workspace"),message,
                            _(@"Destroy"), _(@"Cancel"), nil) 
            != NSAlertDefaultReturn)
          {
            return nil;
          }

        newOperation = [[FileMover alloc] initWithOperationType:DeleteOperation
                                                      sourceDir:src
                                                      targetDir:dest
                                                          files:files
                                                        manager:self];
      }
      break;
    default:
      NSLog(@"ProcessManager: requested operation is not supported!");
    }
  // newOperation will be registered upon receiving
  // WMOperationDidCreateNotification

  return newOperation;
}

- (void)operationDidCreate:(NSNotification *)notif
{
  [operations addObject:[notif object]];
  
  if ([[NSApp delegate] processesPanel])
    {
      [[[NSApp delegate] processesPanel] updateBGProcessList];
    }
  
  [self updateBackInfoLabel];
}

- (void)operationWillDestroy:(NSNotification *)notif
{
  [operations removeObject:[notif object]];
  
  if ([[NSApp delegate] processesPanel])
    {
      [[[NSApp delegate] processesPanel] updateBGProcessList];
    }
  
  [self updateBackInfoLabel];
}

- (void)operationDidChangeState:(NSNotification *)notif
{
  BGOperation *op = [notif object];
  
  if (![[NSApp delegate] processesPanel] && [op state] == OperationAlert)
    {
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
  BGOperation  *bgOp;
  BOOL         success = NO;

  // No running background processes
  if ([operations count] <= 0) {
    return YES;
  }

  switch (NXTRunAlertPanel(@"Log Out",
                           @"You have background file operations running.\n"
                           @"Do you want to stop all operations and quit?",
                           @"Cancel", @"Review operations", @"Stop and quit", 
                           nil))
    {
    case NSAlertDefaultReturn: // Cancel
      NSLog(@"Workspace quit: cancel terminating running background operations.");
      break;
    case NSAlertAlternateReturn: // Review operations
      [[[NSApp delegate] processesPanel] showOperation:[operations objectAtIndex:0]];
      break;
    default:
      // Stop running operations
      e = [operations objectEnumerator];
      while ((bgOp = [e nextObject])) {
        [bgOp stop:self];
      }
      success = YES;
      break;
    }

  // Wait for operations to terminate
  while ([operations count] > 0 && success != NO) {
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

  if (!backInfoLabelCopies)
    {
      backInfoLabelCopies = [[NSMutableArray alloc] initWithCapacity:1];
    }

  // NSLog(@"[Processes] backInfoLabel: labels befor create new: %lu",
  //       [backInfoLabelCopies count]);

  label = [[NSTextField alloc] initWithFrame:NSMakeRect(0,0,180,12)];
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
  if (backInfoLabelCopies)
    {
      [backInfoLabelCopies removeObject:label];
    }
}

- (NSString *)_typeMessageForOperation:(BGOperation *)op
{
  switch ([op type])
    {
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
  NSColor  *labelColor = [NSColor darkGrayColor];

  if ([operations count] == 0)
    {
      labelText = @"";
    }
  else if ([operations count] == 1)
    {
      labelText = [self _typeMessageForOperation:[operations objectAtIndex:0]];
    }
  else
    {
      labelText = [NSString stringWithFormat:@"%lu background processes",
                            [operations count]];
    }

  for (BGOperation *op in operations)
    {
      if ([op state] == OperationAlert)
        {
          labelColor = [NSColor whiteColor];
        }
    }
  
  [backInfoLabelCopies makeObjectsPerformSelector:@selector(setStringValue:)
				       withObject:labelText];
  [backInfoLabelCopies makeObjectsPerformSelector:@selector(setTextColor:)
				       withObject:labelColor];
}

@end
