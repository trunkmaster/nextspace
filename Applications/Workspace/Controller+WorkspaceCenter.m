/* -*- mode: objc -*- */
//
// Project: Workspace
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

#import <Foundation/Foundation.h>
#import "Controller+NSWorkspace.h"
#import "Controller+WorkspaceCenter.h"

//-----------------------------------------------------------------------------
// Workspace notification center
//-----------------------------------------------------------------------------

NSString *GSWorkspaceNotification 	= @"GSWorkspaceNotification";
NSString *GSWorkspacePreferencesChanged	= @"GSWorkspacePreferencesChanged";

/*
 * Depending on the 'active' flag this returns either the currently
 * active application or an array containing all launched apps.<br />
 * The 'notification' argument is either nil (simply query on disk
 * database) or a notification containing information to be used to
 * update the database.
 */
static id GSLaunched(NSNotification *notification, BOOL active)
{
  static NSString		*path = nil;
  static NSDistributedLock	*lock = nil;
  NSDictionary			*info = [notification userInfo];
  NSString			*mode = [notification name];
  NSMutableDictionary		*file = nil;
  NSString			*name;
  NSDictionary			*apps = nil;
  BOOL				modified = NO;

  NSLog(@"WorkspaceManager: GSLaunched() called");
  
  if (path == nil) {
    path = [NSTemporaryDirectory()
               stringByAppendingPathComponent: @"GSLaunchedApplications"];
    RETAIN(path);
    lock = [[NSDistributedLock alloc]
               initWithPath:[path stringByAppendingPathExtension: @"lock"]];
  }
  if ([lock tryLock] == NO) {
    unsigned	sleeps = 0;

    /*
     * If the lock is really old ... assume the app has died and break it.
     */
    if ([[lock lockDate] timeIntervalSinceNow] < -20.0) {
      @try {
        [lock breakLock];
      }
      @catch (NSException *e) {
        NSLog(@"Unable to break lock %@ ... %@", lock, e);
      }
    }
    /*
     * Retry locking several times if necessary before giving up.
     */
    for (sleeps = 0; sleeps < 10; sleeps++) {
      if ([lock tryLock] == YES) {
        break;
      }
      sleeps++;
      [NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
    }
    if (sleeps >= 10) {
      NSLog(@"Unable to obtain lock %@", lock);
      return nil;
    }
  }

  if ([[NSFileManager defaultManager] isReadableFileAtPath:path] == YES) {
    file = [NSMutableDictionary dictionaryWithContentsOfFile: path];
  }
  if (file == nil) {
    file = [NSMutableDictionary dictionaryWithCapacity: 2];
  }
  apps = [file objectForKey: @"GSLaunched"];
  if (apps == nil) {
    apps = [NSDictionary new];
    [file setObject: apps forKey: @"GSLaunched"];
    RELEASE(apps);
  }

  if (info != nil
      && (name = [info objectForKey:@"NSApplicationName"]) != nil) {
    NSDictionary	*oldInfo = [apps objectForKey:name];

    if ([mode isEqualToString:
                NSApplicationDidResignActiveNotification] == YES
        || [mode isEqualToString:
                   NSWorkspaceDidTerminateApplicationNotification] == YES) {
      if ([name isEqual: [file objectForKey: @"GSActive"]] == YES) {
        [file removeObjectForKey: @"GSActive"];
        modified = YES;
      }
    }
    else if ([mode isEqualToString:
                     NSApplicationDidBecomeActiveNotification] == YES) {
      if ([name isEqual: [file objectForKey: @"GSActive"]] == NO) {
        [file setObject: name forKey: @"GSActive"];
        modified = YES;
      }
    }

    if ([mode isEqualToString:
                NSWorkspaceDidTerminateApplicationNotification] == YES) {
      if (oldInfo != nil) {
        NSMutableDictionary	*m = [apps mutableCopy];

        [m removeObjectForKey: name];
        [file setObject: m forKey: @"GSLaunched"];
        apps = m;
        RELEASE(m);
        modified = YES;
      }
    }
    else if ([mode isEqualToString:
                     NSApplicationDidResignActiveNotification] == NO) {
      if ([info isEqual: oldInfo] == NO) {
        NSMutableDictionary	*m = [apps mutableCopy];

        [m setObject:info forKey:name];
        [file setObject:m forKey:@"GSLaunched"];
        apps = m;
        RELEASE(m);
        modified = YES;
      }
    }
  }

  if (modified == YES) {
    [file writeToFile:path atomically:YES];
  }
  [lock unlock];

  if (active == YES) {
    NSString	*activeName = [file objectForKey:@"GSActive"];

    if (activeName == nil) {
      return nil;
    }
    return [apps objectForKey:activeName];
  }
  else {
    return [[file objectForKey: @"GSLaunched"] allValues];
  }
}

@interface WorkspaceCenter (Private)
- (void)_handleRemoteNotification:(NSNotification*)aNotification;
- (void)_postLocal: (NSString*)name userInfo:(NSDictionary*)info;
@end

@implementation	WorkspaceCenter

- (void)dealloc
{
  [remote removeObserver:self name:nil object:GSWorkspaceNotification];
  RELEASE(remote);
  [super dealloc];
}

- (id)init
{
  self = [super init];
  if (self != nil) {
    remote = RETAIN([NSDistributedNotificationCenter defaultCenter]);
    @try {
      [remote addObserver:self
                 selector:@selector(_handleRemoteNotification:)
                     name:nil
                   object:GSWorkspaceNotification];
    }
    @catch (NSException *e) {
      NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];

      if ([defs boolForKey:@"GSLogWorkspaceTimeout"]) {
        NSLog(@"NSWorkspace caught exception %@: %@", [e name], [e reason]);
      }
      else {
        [e raise];
      }
    }
  }
  return self;
}

/*
 * Post notification remotely - since we are listening for distributed
 * notifications, we will observe the notification arriving from the
 * distributed notification center, and it will get sent out locally too.
 */
- (void)postNotification:(NSNotification*)aNotification
{
  NSNotification	*rem;
  NSString		*name = [aNotification name];
  NSDictionary		*info = [aNotification userInfo];

  if ([name isEqual:NSWorkspaceDidTerminateApplicationNotification] == YES
      || [name isEqual:NSWorkspaceDidLaunchApplicationNotification] == YES
      || [name isEqualToString:NSApplicationDidBecomeActiveNotification] == YES
      || [name isEqualToString:NSApplicationDidResignActiveNotification] == YES) {
    GSLaunched(aNotification, YES);
  }

  rem = [NSNotification notificationWithName:name
				      object:GSWorkspaceNotification
				    userInfo:info];
  @try {
    [remote postNotification:rem];
  }
  @catch (NSException *e) {
    NSUserDefaults	*defs = [NSUserDefaults standardUserDefaults];

    if ([defs boolForKey: @"GSLogWorkspaceTimeout"]) {
      NSLog(@"NSWorkspace caught exception %@: %@", [e name], [e reason]);
    }
    else {
      [e raise];
    }
  }
}

- (void)postNotificationName:(NSString*)name 
                      object:(id)object
{
  [self postNotification:[NSNotification notificationWithName:name
                                                       object:object]];
}

- (void)postNotificationName:(NSString*)name 
                      object:(id)object
                    userInfo:(NSDictionary*)info
{
  [self postNotification:[NSNotification notificationWithName:name
                                                       object:object
                                                     userInfo:info]];
}

/*
 * Forward a notification from a remote application to observers in this
 * application.
 */
- (void)_handleRemoteNotification:(NSNotification*)aNotification
{
  [self _postLocal:[aNotification name]
	  userInfo:[aNotification userInfo]];
}

/*
 * Method allowing a notification to be posted locally.
 */
- (void)_postLocal:(NSString*)name userInfo:(NSDictionary*)info
{
  NSNotification	*aNotification;

  aNotification = [NSNotification notificationWithName:name
						object:self
					      userInfo:info];
  [super postNotification:aNotification];
}

@end
