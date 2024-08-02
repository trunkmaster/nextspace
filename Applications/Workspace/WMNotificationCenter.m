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

/**
   Workspace notification center is a connection point (bridge) of 3
   notification centers:
     1. NSNotificationCenter - local, used inside Workspace Manager;
     2. NSDistributesNotificationCenter - global, inter-application
        notifications;
     3. CFNotificationCenter - notification center of Window Manager.

   Notification names may have prefix:
     "NSApplication..." - from AppKit
     "NSWorkspace..." - from AppkKit or Workspace (Controller+NSWorkspace.m)
     "WMShould..." - from GNUstep app to Window Manager
     "WMDid..." - from Window Manager to Window Manager
   Basically, WMShould* and WMDid* notifications is a way to communicate between
   AppKit applications and Window Manager (WMShould* - request, WMDid* - response).

   If notification was received from CoreFoundation:
     - userInfo objects are converted from CoreFoundation to Foundation;
     - notification is sent to local (if `name` has "WMDid..." prefix) and
       global (if object == @"GSWorkspaceNotification") NCs;

   User info dictionary may contain (NS or CF): Array, Dictionary, String, Number.
 */

#include <CoreFoundation/CFNotificationCenter.h>

#include <WM/core/log_utils.h>

#import <Foundation/NSException.h>
#import <Foundation/NSDebug.h>
#import <AppKit/NSWorkspace.h>
#import <AppKit/NSApplication.h>

#import "CoreFoundationBridge.h"
#import "WMNotificationCenter.h"

@implementation CFObject
@end

//-----------------------------------------------------------------------------
// Workspace notification center
//-----------------------------------------------------------------------------

static WMNotificationCenter *_windowManagerCenter = nil;

typedef enum NotificationSource { LocalNC, DistributedNC, CoreFoundationNC } NotificationSource;

@implementation WMNotificationCenter (Private)

// CoreFoundation notifications
//-------------------------------------------------------------------------------------------------
- (void)_postCFNotification:(NSString *)name userInfo:(NSDictionary *)info
{
  CFStringRef cfName;
  CFDictionaryRef cfUserInfo;

  // name
  cfName = convertNStoCFString(name);
  // userInfo
  cfUserInfo = convertNStoCFDictionary(info);

  // WMLogWarning("post CF notification: %@", cfName);

  CFNotificationCenterPostNotification(_coreFoundationCenter, cfName, self, cfUserInfo, TRUE);

  CFRelease(cfName);
  CFRelease(cfUserInfo);
}

/* CF to NS notification conversion.
     1. Convert notification name (CFNotificationName -> NSString)
     2. Convert userInfo (CFDisctionaryRef -> NSDictionary)
     3. Create and send NSNotification to WMNotificationCenter

   Dispatching is performed in WMNotificationCenter's postNotificationName::: method call.
*/
static void _handleCFNotification(CFNotificationCenterRef center, void *observer,
                                  CFNotificationName name, const void *object,
                                  CFDictionaryRef userInfo)
{
  CFObject *nsObject;
  NSString *nsName;
  NSDictionary *nsUserInfo = nil;

  // This is the mirrored notification sent by us
  if (object == _windowManagerCenter) {
    WMLogWarning("handle CF notification: Received mirrored notification from CF. Ignoring...");
    return;
  }

  nsName = convertCFtoNSString(name);
  nsObject = [CFObject new];
  nsObject.object = object;

  if (userInfo != NULL) {
    nsUserInfo = convertCFtoNSDictionary(userInfo);
  }

  WMLogWarning("handle CF notificaition: Dispatching %@ - %@", name, userInfo);

  [_windowManagerCenter postNotificationName:nsName object:nsObject userInfo:nsUserInfo];

  [nsObject release];
  [nsUserInfo release];
}

// Global notifications
//-------------------------------------------------------------------------------------------------
/*
  Forward a notification from a remote application to observers in this
  application. Object always has value @"GSWorkspaceNotification" because we
  observe notifications to that object only.
 */
- (void)_handleRemoteNotification:(NSNotification *)aNotification
{
  NSString *name = [aNotification name];
  id object = [aNotification object];
  NSString *objectName = @"N/A";

  if ([object isKindOfClass:[NSString class]]) {
    objectName = object;
  }

  if ([name hasPrefix:@"NSApplication"]) {
    NSString *appName = [aNotification userInfo][@"NSApplicationName"];
    WMLogWarning("handle remote notification: %s - %s", [aNotification name].cString, appName.cString);
  } else {
    WMLogWarning("handle remote notification: %@ - %@", convertNStoCFString(name),
                 convertNStoCFString(objectName));
  }

  // Post all notifications to CFNotificationCenter
  [self _postCFNotification:name userInfo:[aNotification userInfo]];

  // if ([name hasPrefix:@"WM"]) {
  //   [self _postCFNotification:name userInfo:[aNotification userInfo]];
  // } else {
  if ([name hasPrefix:@"WM"] == NO) {
    // Examples:
    //   NSWorkspaceWillLaunchApplicationNotification - by Controller+NSWorkspace
    //   NSWorkspaceDidLaunchApplicationNotification - by AppKit
    //   NSWorkspaceDidTerminateApplicationNotification - by AppKit or Controller+NSWorkspace
    [super postNotification:aNotification];
  }
}

@end

@implementation WMNotificationCenter

+ (instancetype)defaultCenter
{
  if (!_windowManagerCenter) {
    [[WMNotificationCenter alloc] init];
  }
  return _windowManagerCenter;
}

- (void)dealloc
{
  NSDebugLLog(@"Memory", @"WMNotificationCenter: dealloc");
  
  CFNotificationCenterRemoveEveryObserver(_coreFoundationCenter, self);
  CFRelease(_coreFoundationCenter);
  [_remoteCenter removeObserver:self];
  [_remoteCenter release];

  [super dealloc];
}

- (id)init
{
  self = [super init];

  if (self != nil) {
    _windowManagerCenter = self;

    _remoteCenter = [[NSDistributedNotificationCenter defaultCenter] retain];
    @try {
      [_remoteCenter addObserver:self
                        selector:@selector(_handleRemoteNotification:)
                            name:nil
                          object:@"GSWorkspaceNotification"];
    } @catch (NSException *e) {
      NSLog(@"Workspace Manager caught exception while connecting to"
             " Distributed Notification Center %@: %@",
            [e name], [e reason]);
    }

    _coreFoundationCenter = CFNotificationCenterGetLocalCenter();
    CFRetain(_coreFoundationCenter);
  }

  return self;
}

// Observers management
//-------------------------------------------------------------------------------------------------

// Caller will observe notification with `name` in local, remote and CF notification centers.

/* Register observer-name in NSNotificationCenter and CFNotificationCenter.
   In CF callback _handleCFNotification() notification will be forwarded to
   NSNotificationCenter with name specified in `name` parameter.
   `selector` of the caller must be registered in NSNotificationCenter to be called. */
- (void)addObserver:(id)observer selector:(SEL)selector name:(NSString *)name object:(id)object
{
  CFStringRef cfName;

  if (!name || [name length] == 0) {
    return;
  }

  /* Register observer-name in NSNotificationCenter.
     There's no need to register in NSDistributedNotificationCenter because
     notifications which are sent to it will be forwarded to NSNotificationCenter. */
  [super addObserver:observer selector:selector name:name object:nil];

  // Register handler-name in CFNotificationCenter
  cfName = convertNStoCFString(name);
  CFNotificationCenterAddObserver(_coreFoundationCenter,  // created in -init
                                  self,                   // observer
                                  _handleCFNotification,  // callback: CFNotificationCallback
                                  cfName,                 // notification name: CFStringRef
                                  NULL,                   // object
                                  CFNotificationSuspensionBehaviorDeliverImmediately);
  CFRelease(cfName);
}

- (void)removeObserver:(id)observer
{
  [super removeObserver:observer];
  CFNotificationCenterRemoveEveryObserver(_coreFoundationCenter, observer);
}

// Native notifications
//
// At this time this is used only by classes inside Workspace Manager.
// Access can be obtained with call to [[NSApp delegate] notificationCenter].
// After integration with NSWorkspace will be implemented any application could
// use these calls accessing the [[NSWorkspace sharedWorkspce] notificationCenter].
//
// The methods below dispatch notifications to NSNotificationCenter and CFNotificationCenter.
//-------------------------------------------------------------------------------------------------
- (void)postNotification:(NSNotification *)aNotification
{
  [self postNotificationName:[aNotification name]
                      object:[aNotification object]
                    userInfo:[aNotification userInfo]];
}

- (void)postNotificationName:(NSString *)name object:(id)object
{
  [self postNotificationName:name object:object userInfo:nil];
}

- (void)postNotificationName:(NSString *)name object:(id)object userInfo:(NSDictionary *)info
{
  if (!object) {
    WMLogWarning("[WMNC postNotification:::] can't post notification with nil object!!!");
    return;
  }

  // locally (e.g. Controller or ProcessManager)
  if ([name hasPrefix:@"WMDid"] || [name hasPrefix:@"NSWorkspace"]) {
    WMLogWarning("[WMNC postNotification:::] - %@", convertNStoCFDictionary(info));
    [super postNotificationName:name object:object userInfo:info];
  }

  // globally from Workspace to applications (from _handleCFNotificaition: or Workspace)
  if ([object isKindOfClass:[NSString class]] != NO &&
      [object isEqualToString:@"GSWorkspaceNotification"] != NO) {
    // dispatch to NSDistributedNotificationCenter
    [_remoteCenter postNotificationName:name object:object userInfo:info];
  }

  // post to CFNC only if it hasn't came from CFNC
  if ([object isKindOfClass:[CFObject class]] == NO) {
    [self _postCFNotification:name userInfo:info];
  }
}

@end
