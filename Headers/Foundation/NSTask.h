/* Interface for NSTask for GNUstep
   Copyright (C) 1998 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: 1998

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
   */

#ifndef __NSTask_h_GNUSTEP_BASE_INCLUDE
#define __NSTask_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSObject.h>
#import	<Foundation/NSString.h>
#import	<Foundation/NSArray.h>
#import	<Foundation/NSDictionary.h>
#import	<Foundation/NSFileHandle.h>

#if	defined(__cplusplus)
extern "C" {
#endif

DEFINE_BLOCK_TYPE_NO_ARGS(GSTaskTerminationHandler, void);
  
@class  NSThread;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_5,GS_API_LATEST)
enum {
  NSTaskTerminationReasonExit = 1,
  NSTaskTerminationReasonUncaughtSignal = 2
};
typedef NSInteger NSTaskTerminationReason;
#endif

GS_EXPORT_CLASS
@interface NSTask : NSObject
{
#if	GS_EXPOSE(NSTask)
@protected
  NSString	*_currentDirectoryPath;
  NSString	*_launchPath;
  NSArray	*_arguments;
  NSDictionary	*_environment;
  id		_standardError;
  id		_standardInput;
  id		_standardOutput;
  int		_taskId;
  int		_terminationStatus;
  BOOL		_hasLaunched;
  BOOL		_hasTerminated;
  BOOL		_hasCollected;
  BOOL		_hasNotified;
  NSThread      *_launchingThread;
  NSTaskTerminationReason       _terminationReason;
  GSTaskTerminationHandler      _handler;
#endif
#if     GS_NONFRAGILE
#else
  /* Pointer to private additional data used to avoid breaking ABI
   * when we don't have the non-fragile ABI available.
   * Use this mechanism rather than changing the instance variable
   * layout (see Source/GSInternal.h for details).
   */
  @private id _internal GS_UNUSED_IVAR;
#endif
}

+ (NSTask*) launchedTaskWithLaunchPath: (NSString*)path
			     arguments: (NSArray*)args;

/*
 *	Querying task parameters.
 */
- (NSArray*) arguments;
- (NSString*) currentDirectoryPath;
- (NSDictionary*) environment;
- (NSString*) launchPath;
- (id) standardError;
- (id) standardInput;
- (id) standardOutput;

/*
 *	Setting task parameters.
 */
- (void) setArguments: (NSArray*)args;
- (void) setCurrentDirectoryPath: (NSString*)path;
- (void) setEnvironment: (NSDictionary*)env;
- (void) setLaunchPath: (NSString*)path;
- (void) setStandardError: (id)hdl;
- (void) setStandardInput: (id)hdl;
- (void) setStandardOutput: (id)hdl;

/*
 *	Obtaining task state
 */
- (BOOL) isRunning;
#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
- (int) processIdentifier;
#endif
#if OS_API_VERSION(MAC_OS_X_VERSION_10_5,GS_API_LATEST)
- (NSTaskTerminationReason) terminationReason;
#endif
- (int) terminationStatus;

/*
 *	Handling a task.
 */
- (void) interrupt;
- (void) launch;
#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
- (BOOL) resume;
- (BOOL) suspend;
#endif
- (void) terminate;
- (void) waitUntilExit;

#if OS_API_VERSION(GS_API_NONE, GS_API_NONE)
- (BOOL) usePseudoTerminal;
- (NSString*) validatedLaunchPath;
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_13, GS_API_LATEST)
+ (NSTask *) launchedTaskWithExecutableURL: (NSURL *)url 
                                 arguments: (NSArray *)arguments 
                                     error: (NSError **)error 
                        terminationHandler: (GSTaskTerminationHandler)terminationHandler;

- (BOOL) launchAndReturnError: (NSError **)error;

- (NSURL *) executableURL;

- (NSURL *) currentDirectoryURL;
#endif
@end

/**
 *  Notification posted when an [NSTask] terminates, either due to the
 *  subprocess ending or the [NSTask-terminate] method explicitly being
 *  called.
 */
GS_EXPORT NSString* const NSTaskDidTerminateNotification;

#if	defined(__cplusplus)
}
#endif

#if     !NO_GNUSTEP && !defined(GNUSTEP_BASE_INTERNAL)
#import <GNUstepBase/NSTask+GNUstepBase.h>
#endif

#endif /* __NSTask_h_GNUSTEP_BASE_INCLUDE */
