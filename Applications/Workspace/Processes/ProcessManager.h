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

//
// The background processes registrator and manager.
// This is not GUI part. GUI is in Process (controller of "Processes" panel).
//
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
  CopyOperation = 1,
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
  NSMutableArray *backInfoLabelCopies;
}

  // Array of objects which represents active operations (BGOperation).
@property (readonly) NSMutableArray *applications;
@property (readonly) NSMutableArray *operations;

@property (readonly) NSDictionary *activeApplication;
// Operation introduced by "Edit" menu (Cut, Copy)
@property (readonly) NSDictionary *editOperation;

+ shared;

- (id)init;
- (void)dealloc;

@end

@interface ProcessManager (Applications)

- (NSDictionary *)_normalizeApplicationInfo:(NSDictionary *)appInfo;
- (NSDictionary *)_applicationWithName:(NSString *)appName;

- (void)sendSignal:(int)signal toApplication:(NSDictionary *)appInfo;
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

- (BOOL)terminateAllBGOperations;

@end

@interface ProcessManager (InfoLabels)

- (id)backInfoLabel;
- (void)releaseBackInfoLabel:(id)label;
- (void)updateBackInfoLabel;

@end

extern NSString *EditOperationTypeKey;
extern NSString *EditPathKey;
extern NSString *EditObjectsKey;

@interface ProcessManager (EditOperations)

// Operation type could be either CopyOperation (Edit->Copy) or MoveOperation (Edit->Cut)
- (BOOL)registerEditOperation:(OperationType)opType
                directoryPath:(NSString *)dir
                      objects:(NSArray *)objects;
- (void)unregisterEditOperation;

@end
