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
   Workspace notification center is a connection point (bridge) of 3 notification centers:
   1. NSNotificationCenter - local, used inside Workspace Manager;
   2. NSDistributesNotificationCenter- global, inter-application notifications;
   3. CFNotificationCenter - notification center of Window Manager.

   If notification was received from CoreFoundation:
     - converts userInfo objects from CoreFoundation to Foundation;
     - sends notification to local and global NCs of Foundation;
 */

#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFNumber.h>
#include <CoreFoundation/CFString.h>
#include <CoreFoundation/CFArray.h>
#include <CoreFoundation/CFDictionary.h>
#include <CoreFoundation/CFNotificationCenter.h>

#import <Foundation/NSValue.h>
#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSException.h>
#import <AppKit/NSWorkspace.h>
#import <AppKit/NSApplication.h>

#import "WMNotificationCenter.h"

// Object conversion functions
//-----------------------------------------------------------------------------
static NSNumber *_convertCFtoNSNumber(CFNumberRef cfNumber);
static NSString *_convertCFtoNSString(CFStringRef cfString);
static NSArray *_convertCFtoNSArray(CFArrayRef cfArray);
static NSDictionary *_convertCFtoNSDictionary(CFDictionaryRef cfDictionary);
static id _convertCoreFoundationToFoundation(CFTypeRef value);

NSNumber *_convertCFtoNSNumber(CFNumberRef cfNumber)
{
  int value;
  CFNumberGetValue(cfNumber, CFNumberGetType(cfNumber), &value);
  return [NSNumber numberWithInt:value];
}
NSString *_convertCFtoNSString(CFStringRef cfString)
{
  const char *stringPtr;
  stringPtr = CFStringGetCStringPtr(cfString, CFStringGetSystemEncoding());
  return [NSString stringWithCString:stringPtr];
}
// TODO
NSArray *_convertCFtoNSArray(CFArrayRef cfArray)
{
  NSMutableArray *nsArray = [NSMutableArray new];
  return [nsArray autorelease];
}
NSDictionary *_convertCFtoNSDictionary(CFDictionaryRef cfDictionary)
{
  NSMutableDictionary *nsDictionary = nil;
  const void          *keys;
  const void          *values;

  if (cfDictionary) {
    nsDictionary = [NSMutableDictionary new];
    CFDictionaryGetKeysAndValues(cfDictionary, &keys, &values);
    for (int i = 0; i < CFDictionaryGetCount(cfDictionary); i++) {
      [nsDictionary setObject:_convertCoreFoundationToFoundation(&values[i]) // may be recursive
                       forKey:_convertCFtoNSString(&keys[i])]; // always CFStringRef
    }
  }
  
  return (nsDictionary ? [nsDictionary autorelease] : nil);
}
id _convertCoreFoundationToFoundation(CFTypeRef value)
{
  CFTypeID valueType = CFGetTypeID(value);
  id       returnValue = @"(null)";
  
  if (valueType == CFStringGetTypeID()) {
    returnValue = _convertCFtoNSString(value);
  }
  else if (valueType == CFNumberGetTypeID()) {
    returnValue = _convertCFtoNSNumber(value);
  }
  else if (valueType == CFArrayGetTypeID()) {
    returnValue = _convertCFtoNSArray(value);
  }
  else if (valueType == CFDictionaryGetTypeID()) {
    returnValue = _convertCFtoNSDictionary(value);
  }

  return returnValue;
}

static CFStringRef _convertNStoCFString(NSString *nsString);
static CFDictionaryRef _convertNStoCFDictionary(NSDictionary *dictionary);

CFStringRef _convertNStoCFString(NSString *nsString)
{
  CFStringRef cfString;
  cfString = CFStringCreateWithCString(kCFAllocatorDefault, [nsString cString],
                                       CFStringGetSystemEncoding());
  return cfString;
}

CFDictionaryRef _convertNStoCFDictionary(NSDictionary *dictionary)
{
  CFMutableDictionaryRef cfDictionary;
  CFStringRef keyCFString;
  CFStringRef valueCFString;

  cfDictionary = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, NULL);
  for (id key in [dictionary allKeys]) {
    id value = [dictionary objectForKey:key];
    if ([value isKindOfClass:[NSString class]]) {
      keyCFString = CFStringCreateWithCString(kCFAllocatorDefault, [key cString],
                                              CFStringGetSystemEncoding());
      valueCFString = CFStringCreateWithCString(kCFAllocatorDefault, [value cString],
                                                CFStringGetSystemEncoding());
      CFDictionaryAddValue(cfDictionary, keyCFString, valueCFString);
      CFRelease(keyCFString);
      CFRelease(valueCFString);
    }
  }
  return cfDictionary;
}

@implementation CFObject @end

//-----------------------------------------------------------------------------
// Workspace notification center
//-----------------------------------------------------------------------------

static WMNotificationCenter *_workspaceCenter = nil;

@interface WMNotificationCenter (Private)
- (void)_postNSNotification:(NSString *)name object:(id)object userInfo:(NSDictionary *)info;
- (void)_postCFNotification:(NSString*)name userInfo:(NSDictionary*)info;
@end
@implementation WMNotificationCenter (Private)

- (void)_postNSNotification:(NSString *)name
                     object:(id)object
                   userInfo:(NSDictionary *)info
{
  NSNotification *aNotification = [NSNotification notificationWithName:name
                                                                object:object
                                                              userInfo:info];
  // NSNotificationCenter
  [super postNotification:aNotification];
  // NSDistributedNotificationCenter
  // TODO: CFObject is not a good object to send
  // [_remoteCenter postNotification:aNotification];
}

- (void)_postCFNotification:(NSString *)name
                   userInfo:(NSDictionary *)info
{
  const void *cfObject;
  CFStringRef cfName;
  CFDictionaryRef cfUserInfo;

  // name
  cfName = CFStringCreateWithCString(kCFAllocatorDefault, [name cString], CFStringGetSystemEncoding());
  // userInfo
  cfUserInfo = _convertNStoCFDictionary(info);
  // object
  cfObject = NULL;
 
  CFNotificationCenterPostNotification(_coreFoundationCenter, cfName, cfObject, cfUserInfo, TRUE);

  CFRelease(cfName);
  CFRelease(cfUserInfo);
}

/*
 * Forward a notification from a remote application to observers in this application.
 */
- (void)_handleRemoteNotification:(NSNotification*)aNotification
{
  // local and remote
  [self _postNSNotification:[aNotification name]
                     object:nil
                   userInfo:[aNotification userInfo]];
  // CFNotificationCenter
  [self _postCFNotification:[aNotification name]
                   userInfo:[aNotification userInfo]];
}

/* CF to NS notification dispatching.
   1. Convert notification name (CFNotificationName -> NSString)
   2. Convert userInfo (CFDisctionaryRef -> NSDictionary)
   3. Create and send NSNotification to NSNotificationCenter with
   [NSNotification notificationWithName:name   // converted from CFString
                                 object:object // NSObject.object
                               userInfo:info]  // converted from CFDictionaryRef
*/
/* CF notification sent with this call:
   CFNotificationCenterPostNotification(CFNotificationCenterGetLocalCenter(),
                                       "WMDidManageWindowNotification", // notification name
                                       wwin,                            // object
                                       NULL,                            // userInfo
                                       TRUE);

*/
static void _handleCFNotification(CFNotificationCenterRef center,
                                   void *observer,
                                   CFNotificationName name,
                                   const void *object,
                                   CFDictionaryRef userInfo)
{
  CFObject *cfObject = [CFObject new];
  NSString *nsName = _convertCFtoNSString(name);
  NSDictionary *nsUserInfo = _convertCFtoNSDictionary(userInfo);
  
  cfObject.object = object;
  
  NSLog(@"[WorkspaceNC] _handleCFNotificaition: %@ - %@", nsName, nsUserInfo);
  
  [_workspaceCenter _postNSNotification:nsName object:cfObject userInfo:nsUserInfo];
  
  [cfObject release];
}

@end

@implementation	WMNotificationCenter

+ (instancetype)defaultCenter
{
  if (!_workspaceCenter) {
    [[WMNotificationCenter alloc] init];
  }
  return _workspaceCenter;
}

- (void)dealloc
{
  NSLog(@"WMNotificationCenter: dealloc");
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
    _remoteCenter = [[NSDistributedNotificationCenter defaultCenter] retain];
    // @try {
    //   [_remoteCenter addObserver:self
    //                    selector:@selector(_handleRemoteNotification:)
    //                        name:nil
    //                      object:nil];
    // }
    // @catch (NSException *e) {
    //   NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];

    //   if ([defs boolForKey:@"GSLogWorkspaceTimeout"]) {
    //     NSLog(@"Workspace Manager caught exception while connecting to"
    //           " Distributed Notification Center %@: %@", [e name], [e reason]);
    //   }
    //   else {
    //     [e raise];
    //   }
    // }
    _coreFoundationCenter = CFNotificationCenterGetLocalCenter();
    CFRetain(_coreFoundationCenter);
    _workspaceCenter = self;
  }
  
  return self;
}

// Observers management
//-------------------------------------------------------------------------------------------------

// Caller will observe notification with `name` in local, remote and CF notification centers.
 
/* Register observer-name in NSNotificationCenter.
   In CF notification callback (_handleCFNotification()) this notification will
   be forwarded to NSNotificationCenter with name specified in `name` parameter.
   `selector` of the caller must be registered in NSNotificationCenter to be called. */
- (void)addObserver:(id)observer
           selector:(SEL)selector
               name:(NSString *)name
             object:(id)object
{
  CFStringRef cfName;

  // TODO: check of `name` is not empty
  cfName = _convertNStoCFString(name);
  
  // Register observer-name in NSNotificationCenter and NSDistributedNotificationCenter.
  [super addObserver:observer
            selector:selector
                name:name
              object:nil];
  [_remoteCenter addObserver:observer
                   selector:selector
                       name:name
                     object:nil];

  // Register handler-name in CFNotificationCenter
  CFNotificationCenterAddObserver(_coreFoundationCenter,  // created in -init
                                  self,                   // observer
                                  _handleCFNotification, // callback: CFNotificationCallback
                                  cfName,                 // notification name: CFStringRef
                                  NULL,                   // object
                                  CFNotificationSuspensionBehaviorDeliverImmediately);
  CFRelease(cfName);
}

 
// Notification dispatching
//-------------------------------------------------------------------------------------------------
- (void)postNotification:(NSNotification*)aNotification
{
  NSString *name = [aNotification name];
  
  if ([name isEqual:NSWorkspaceDidTerminateApplicationNotification] == YES ||
      [name isEqual:NSWorkspaceDidLaunchApplicationNotification] == YES ||
      [name isEqualToString:NSApplicationDidBecomeActiveNotification] == YES ||
      [name isEqualToString:NSApplicationDidResignActiveNotification] == YES) {
    // Posts distributed notification
    [[[NSWorkspace sharedWorkspace] notificationCenter] postNotification:aNotification];
  }
  
  [self postNotificationName:name
                      object:[aNotification object]
                    userInfo:[aNotification userInfo]];
}

- (void)postNotificationName:(NSString*)name 
                      object:(id)object
{
  [self postNotificationName:name
                      object:object
                    userInfo:nil];
}

- (void)postNotificationName:(NSString*)name
                      object:(id)object
                    userInfo:(NSDictionary*)info
{
  // local and remote
  [self _postNSNotification:name object:object userInfo:info];
  // CFNotificationCenter
  [self _postCFNotification:name userInfo:info];
}

@end
