/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - SystemKit framework
//
// Description: Monitor file system events (delete, create, rename,
//              change attributes)
//
// Copyright (C) 2014-2019 Sergii Stoian
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

// Process of creating monitor process:
// NXFileSystem             OSEFileSystemMonitor
// (owner)                  (thread)
// ----------------------------------------------
// sharedEventMonitor
// createEventMonitorThread -----> connectWithPorts:
//                                 initWithConnection:
// setEventMonitor: <------------- initWithConnection:
// addEventMonitorPath
//
// Process of deleting of monitor process:
//                          stopEventMonitor
//                          invalidateEventMonitor
//
// (EventMonitorOwner) category methods is primary way to manipulate
// process of monitoring file system events (front class for applications).

#import <Foundation/Foundation.h>

extern NSString *OSEFileSystemChangedAtPath;

@class OSEFileSystemMonitorThread;

@interface OSEFileSystemMonitor : NSObject
{
  // Event monitor vars
  OSEFileSystemMonitorThread *monitorThread; // event monitor OS-specific worker
  NSTimer                   *checkTimer;

  // Monitor thread state
  BOOL monitorThreadShouldStart;
  BOOL monitorThreadPaused;
  BOOL monitorThreadStopped;
  BOOL monitorThreadTerminated;
}

// --- Monitor creation
+ (OSEFileSystemMonitor *)sharedMonitor;

- (OSEFileSystemMonitorThread *)monitorThread;
// callback on thread creation
- (oneway void)_setEventMonitor:(OSEFileSystemMonitorThread *)aMonitor;

// --- Properties
// returns file descriptor
- (void)addPath:(NSString *)absolutePath;
- (void)removePath:(NSString *)absolutePath;

// --- Monitor managing
- (void)start;
- (void)stop;
- (void)pause;
- (void)resume;
- (void)terminate;
- (void)handleEvent:(NSDictionary *)event;

@end

@interface OSEFileSystemMonitorThread : NSObject
{
  NSMutableDictionary *threadDict;
  OSEFileSystemMonitor *monitorOwner;  // event monitor initiator
}

// --- General part of thread
+ (void)connectWithPorts:(NSArray *)portArray;

// --- OS-specific
- (id)initWithConnection:(NSConnection *)conn;
- (void)_addPath:(NSString *)absolutePath;
- (void)_removePath:(NSString *)absolutePath;

- (oneway void)_startThread;
- (oneway void)_stopThread;
- (oneway void)_terminateThread;

- (void)checkForEvents;

@end

