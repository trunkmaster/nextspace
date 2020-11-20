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

#include <CoreFoundation/CFString.h>

#import "WorkspaceNotificationCenter.h"

//-----------------------------------------------------------------------------
// Workspace notification center
//-----------------------------------------------------------------------------
// NSString *GSWorkspaceNotification 	= @"GSWorkspaceNotification";
// NSString *GSWorkspacePreferencesChanged	= @"GSWorkspacePreferencesChanged";

@interface WorkspaceNotificationCenter (Private)
- (void)_handleRemoteNotification:(NSNotification*)aNotification;
- (void)_postLocal: (NSString*)name userInfo:(NSDictionary*)info;
@end
@implementation WorkspaceNotificationCenter (Private)

- (void)_postNSLocal:(NSString*)name userInfo:(NSDictionary*)info
{
  NSNotification *aNotification;

  aNotification = [NSNotification notificationWithName:name
						object:self
					      userInfo:info];
  [super postNotification:aNotification];
}

- (void)_postCFLocal:(NSString*)name userInfo:(NSDictionary*)info
{
  const void             *cfObject = NULL;
  CFStringRef            cfName;
  CFMutableDictionaryRef cfUserInfo;

  cfName = CFStringCreateWithCString(kCFAllocatorDefault, [name cString], CFStringGetSystemEncoding);

  for (id value in [info allKeys]) {
    
  }
  
  CFNotificationCenterPostNotification(coreFoundationCenter, cfName, cfObject, cfUserInfo, TRUE);

  CFRelease(cfName);
  CFRelease(cfUserInfo);
}

@end

@implementation	WorkspaceNotificationCenter

- (void)dealloc
{
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  coreFoundationCenter = CFNotificationCenterGetLocalCenter();
  
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

@end

