/*
   ProcessManager.h
   The background processes registrator and manager.
   This is not GUI part. GUI is in Process (controller of "Processes" panel).
   
   Copyright (C) 2015 Sergii Stoian

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

// ProcessManager:
// - initialized on Workspace start;
// - start BGOperation subclasses of known types;
// - register started BGOperation (can be started outside of Processes);
// - call GUI via ProcessManager on request from managed operations (user
//   attention or action is needed);
// - register and terminate applications;
// - provide information about registered applications and operations;
//
// BGOperation (and it's subclasses):
// - perform operation with requested filesystemd objects (by itself or by
//   calling appropriate tool);
// - notify about state changes;
// - update delegate's GUI (objects managed by ProcessManager) if delegate
//   was set;
//
// BGProcess:
// - provides GUI placed into bottom part of "Processes" panel;
// - receive and display progress info from corresponding BGOperation;
// - provide alert panel on BGOpertation state change to OperationAlert;
// - call BGOpertation actions on user actions to GUI (progress and alert);
// 
// Processes (controller of "Processes" panel):
// - initialized on panel creation (firsr click on Tools->Processes...
//   menu item);
// - provide and manage "Processes" panel;
// - provide GUI to display and manage running applications;
// - provide GUI (progress, alert) for background operations;
// - information about running applications and background processes requested
//   from ProcessManager (see above);

#import <Foundation/Foundation.h>

@class Processes;

extern NSString *WMOperationDidCreateNotification;
extern NSString *WMOperationWillDestroyNotification;
extern NSString *WMOperationDidChangeStateNotification;
extern NSString *WMOperationProcessingFileNotification;

extern NSString *WMApplicationDidTerminateSubprocessNotification;

typedef enum {
  CopyOperation,
  DuplicateOperation,
  MoveOperation,
  LinkOperation,
  DeleteOperation,
  RecycleOperation,
  MountOperation,
  UnmountOperation,
  EjectOperation,
  SizeOperation,
  PermissionOperation
} OperationType;

typedef enum {
  OperationPrepare,
  OperationRunning,
  OperationPaused,
  OperationAlert,
  OperationCompleted,
  OperationStopping,
  OperationStopped,
} OperationState;

@interface ProcessManager : NSObject
{
  // Array of objects which represents active operations (BGOperation).
  NSMutableArray *operations;
  NSMutableArray *applications;

  NSMutableArray *backInfoLabelCopies;
}

+ shared;

- (id)init;
- (void)dealloc;

- (NSArray *)applications;
- (NSArray *)operations;

@end

@interface ProcessManager (Applications)

- (NSDictionary *)_normalizeApplicationInfo:(NSDictionary *)appInfo;
- (NSDictionary *)_applicationWithName:(NSString *)appName;
  
- (void)applicationWillLaunch:(NSNotification *)notif;
- (void)applicationDidLaunch:(NSNotification *)notif;
- (void)applicationDidTerminate:(NSNotification *)notif;
- (void)applicationDidTerminateSubprocess:(NSNotification *)notif;

- (BOOL)terminateAllApps;

@end

@interface ProcessManager (Background)

// Logic:
// 1. Initalize appropriate subclass of BGOperation with supplied parameters.
// 2. Save initialized :BGOperation into 'operations' array.
// 3. Start operation.
// Copy, Move, Link - mandatory:source,target optional: files
// Delete - mandatory:source optional:files
// Size - mandatory:source optional:files
// Mount, Unmount - mandatory:source
// Permission - mandatory:source optional:files
- (id)startOperationWithType:(OperationType)opType
                      source:(NSString *)src
                      target:(NSString *)dest
                       files:(NSArray *)files;

- (void)operationDidCreate:(NSNotification *)notif;
- (void)operationWillDestroy:(NSNotification *)notif;
- (void)operationDidChangeState:(NSNotification *)notif;

- (BOOL)terminateAllBGOperations;

@end

@interface ProcessManager (InfoLabels)

- (id)backInfoLabel;

- (void)releaseBackInfoLabel:(id)label;

- (void)updateBackInfoLabel;

@end
