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

#import <sys/types.h>
#import <signal.h>
#import <DesktopKit/NXTAlert.h>

#import "Controller.h"
#import "Processes/Processes.h"

#import "Operations/ProcessManager.h"
#import "Operations/FileMover.h"

NSString *WMOperationDidCreateNotification = @"BGOperationDidCreate";
NSString *WMOperationWillDestroyNotification = @"BGOperationWillDestroy";
NSString *WMOperationDidChangeStateNotification = @"BGOperationDidChangeState";
NSString *WMOperationProcessingFileNotification = @"BGOperationProcessingFile";

NSString *WMApplicationDidTerminateSubprocessNotification =
  @"WMAppDidTerminateSubprocess";


static Processes *shared = nil;
static BOOL      _workspaceQuitting = NO;

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
  NSLog(@"ProcessManager: dealloc");

  [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];

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
  NSFileManager        *fm;

  [super init];

  fm = [NSFileManager defaultManager];
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

  //  Applications
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

// Convert "NSApplicationProcessIdentifier" to mutable array of strings
- (NSDictionary *)_normalizeApplicationInfo:(NSDictionary *)appInfo
{
  NSMutableDictionary *_appInfo = [appInfo mutableCopy];
  id                   nsapi;
  NSString            *appPID;

  // Detect class of "NSApplicationProcessIdentifier" value and replace
  // with mutable array of strings.
  nsapi = [_appInfo objectForKey:@"NSApplicationProcessIdentifier"];

  // "NSApplicationProcessIdentifier" can be NSSmallInt, NSConstantString,
  // GSCInlineString. Expected that all except NSSmallInt is kind of class
  // NSString.
  if ([nsapi isKindOfClass:[NSArray class]])
    {
      return appInfo;
    }
  else if ([nsapi isKindOfClass:[NSString class]])
    {
      appPID = nsapi;
    }
  else
    {
      appPID = [NSString stringWithFormat:@"%i", [nsapi intValue]];
    }
  
  [_appInfo setObject:[NSMutableArray arrayWithObject:appPID]
               forKey:@"NSApplicationProcessIdentifier"];

  return [_appInfo autorelease];
}

- (NSDictionary *)_applicationWithName:(NSString *)appName
{
  NSDictionary *entry;
  NSString     *eAppName;
  
  for (entry in applications)
    {
      eAppName = [entry objectForKey:@"NSApplicationName"];
      if ([eAppName isEqualToString:appName]) 
	{
          return entry;
	}
    }
  
  return nil;
}

// NSWorkspaceWillLaunchApplicationNotification
// Do nothing. Launched application registered upon receiving
// NSWorkspaceDidLaunchApplicationNotification.
// TODO
- (void)applicationWillLaunch:(NSNotification *)notif
{
  /*  NSMutableDictionary *info = [[[notif userInfo] mutableCopy] autorelease];

  NSLog(@"willLaunchApp: %@", info);

  [info setObject:@"YES"
	   forKey:@"StartingUp"];

  [apps addObject:[[info copy] autorelease]];

  if (appList != nil)
    {
      [appList reloadData];
    }*/
}

// NSWorkspaceDidLaunchApplicationNotification
// Register launched application.
// TODO
- (void)applicationDidLaunch:(NSNotification *)notif
{
  NSDictionary   *newAppInfo;
  NSString       *newAppName;
  NSDictionary   *aInfo;
  NSString       *aName;
  NSMutableArray *aPIDList, *newAppPID;
  NSUInteger     i;
  BOOL           skipLaunchedApp = NO;

  newAppInfo = [self _normalizeApplicationInfo:[notif userInfo]];
  
  NSLog(@"didLaunchApp: %@", newAppInfo);
  
  newAppName = [newAppInfo objectForKey:@"NSApplicationName"];
  newAppPID = [newAppInfo objectForKey:@"NSApplicationProcessIdentifier"];

  // Check if application already in app list. If so - append PID to the
  // "NSApplicationProcessIdentifier" of existing object in 'applications' list.
  // for (aInfo in applications)
  for (i=0; i < [applications count]; i++)
    {
      aInfo = [applications objectAtIndex:i];
      aName = [aInfo objectForKey:@"NSApplicationName"];
      aPIDList = [aInfo objectForKey:@"NSApplicationProcessIdentifier"];

      if ([aName isEqualToString:newAppName])
        {
          skipLaunchedApp = YES;

          if (![aPIDList containsObject:@""] &&
              ([aPIDList indexOfObject:[newAppPID objectAtIndex:0]] == NSNotFound))
            {
              [aPIDList addObjectsFromArray:newAppPID];
            }
          
          break;
        }
    }

  if (skipLaunchedApp == NO)
    {
      [applications addObject:newAppInfo];
    }
  
  if ([[NSApp delegate] processesPanel])
    {
      [[[NSApp delegate] processesPanel] updateAppList];
    }
  
  // NSLog(@"Processes: %@",
  //       [[NSWorkspace sharedWorkspace] launchedApplications]);
}

// NSWorkspaceDidTerminateApplicationNotification
- (void)applicationDidTerminate:(NSNotification *)notif
{
  NSString     *appName;
  NSDictionary *appInfo;

  if (_workspaceQuitting)
    return;

  appName = [[notif userInfo] objectForKey:@"NSApplicationName"];
  
  if ((appInfo = [self _applicationWithName:appName]))
    {
      [applications removeObject:appInfo];
    }

  if ([[NSApp delegate] processesPanel])
    {
      [[[NSApp delegate] processesPanel] updateAppList];
    }
}

// NSWorkspaceDidTerminateSubprocessNotification
// 1. Determine application which owns subprocess
// 2. Check if processes still exists from application PID list with
//    kill (pid, 0).
- (void)applicationDidTerminateSubprocess:(NSNotification *)notif
{
  NSString            *appName;
  NSDictionary        *appInfo;
  NSMutableArray      *appPIDList, *_appPIDList;
  NSString            *pidString;
  int                 pid;

  if (_workspaceQuitting)
    return;

  appName = [[notif userInfo] objectForKey:@"NSApplicationName"];
  if (!(appInfo = [self _applicationWithName:appName]))
    return;
  
  appPIDList = [appInfo objectForKey:@"NSApplicationProcessIdentifier"];
  _appPIDList = [appPIDList copy];
  for (pidString in _appPIDList)
    {
      pid = [pidString integerValue];
      if ((kill(pid, 0) == -1) && (errno == ESRCH)) // process doesn't exist
        {
          [appPIDList removeObject:pidString];
        }
    }
  [_appPIDList release];
  
  if ([[NSApp delegate] processesPanel])
    {
      [[[NSApp delegate] processesPanel] updateAppList];
    }
}

// Performs gracefull termination of running GNUstep applications.
// Returns:
//   YES -- if all applications exited
//    NO -- if some application returns NO on applicationShouldTerminate: call.
- (BOOL)terminateAllApps
{
  NSArray      *_appsCopy = [applications copy];
  NSEnumerator *e = [_appsCopy objectEnumerator];
  NSDictionary *_appDict = nil;
  NSString     *_appName = nil;
  id           _app;
  BOOL         _noRunningApps = YES;

  // Workspace goes into quit process.
  // Application removal from list will be processed inside this method
  _workspaceQuitting = YES;

//  NSLog(@"Launched applications: %@", apps);
  while ((_appDict = [e nextObject])) {
    if ([[_appDict objectForKey:@"IsXWindowApplication"]
            isEqualToString:@"YES"]) {
      NSArray *pidList;
      pidList = [_appDict objectForKey:@"NSApplicationProcessIdentifier"];
          
      for (NSString *pidString in pidList) {
        // If PID is '-1' let window manager kill that app.
        if (![pidString isEqualToString:@"-1"]) {
          kill([pidString integerValue], SIGKILL);
        }
      }
      [applications removeObject:_appDict];
      continue; // go to 'while' statement
    }
    else {
      _appName = [_appDict objectForKey:@"NSApplicationName"];
      if ([_appName isEqualToString:@"Workspace"] ||
          [_appName isEqualToString:@"Login"])
        {
          // don't remove from app list - system apps
          continue; // go to 'while' statement
        }
      NSLog(@"Terminating - %@", _appName);
      _app = [NSConnection
                   rootProxyForConnectionWithRegisteredName:_appName
                                                       host:@""];
      if (_app == nil) {
        NSLog(@"Connection to %@ failed. Removing from list of known applications",
              _appName);
        [applications removeObject:_appDict];
        continue; // go to 'while' statement
      }
          
      @try {
        [_app terminate:nil];
      }
      @catch (NSException *e){
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
  if ([operations count] <= 0)
    {
      return YES;
    }

  switch (NSRunAlertPanel(@"Log Out",
                          @"You have background file operations running.\n"
                          @"Do you want to stop all operations and quit?",
                          @"Cancel", @"Review operations", @"Stop and quit", 
                          nil))
    {
    case NSAlertDefaultReturn: // Cancel
      NSLog(@"Workspace quit: cancel terminating running background "
            @"operations.");
      break;
    case NSAlertAlternateReturn: // Review operations
      [[[NSApp delegate] processesPanel]
        showOperation:[operations objectAtIndex:0]];
      break;
    default:
      // Stop running operations
      e = [operations objectEnumerator];
      while ((bgOp = [e nextObject]))
        {
          [bgOp stop:self];
        }
      success = YES;
      break;
    }

  // Wait for operations to terminate
  while ([operations count] > 0)
    {
      [[NSRunLoop currentRunLoop]
        runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
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

  NSLog(@"[Processes] backInfoLabel: labels befor create new: %lu",
	[backInfoLabelCopies count]);

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
