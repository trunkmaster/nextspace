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
     "WMShould..." - from GNUstep app to Workspace Manager
     "WMDid..." - from Window Manager to Workspace Manager

   If notification was received from CoreFoundation:
     - userInfo objects are converted from CoreFoundation to Foundation;
     - notification is sent to local (if `name` has "WMDid..." prefix) and
       global (if object == @"GSWorkspaceNotification") NCs;

   User info dictionary may contain (NS or CF): Array, Dictionary, String, Number.
 */

#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFNumber.h>
#include <CoreFoundation/CFString.h>
#include <CoreFoundation/CFArray.h>
#include <CoreFoundation/CFDictionary.h>
#include <CoreFoundation/CFNotificationCenter.h>

#include <WM/core/log_utils.h>

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
static id _convertCFtoNS(CFTypeRef value);

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
  if (!stringPtr) {
    return @"";
  } else {
    return [NSString stringWithCString:stringPtr];
  }
}
NSArray *_convertCFtoNSArray(CFArrayRef cfArray)
{
  NSMutableArray *nsArray = [NSMutableArray new];
  CFIndex cfCount = CFArrayGetCount(cfArray);

  for (CFIndex i=0; i < cfCount; i++) {
    [nsArray addObject:_convertCFtoNS(CFArrayGetValueAtIndex(cfArray, i))];
  }
  
  return [nsArray autorelease];
}
NSDictionary *_convertCFtoNSDictionary(CFDictionaryRef cfDictionary)
{
  NSMutableDictionary *nsDictionary = nil;
  const void *keys;
  const void *values;

  if (cfDictionary == NULL) {
    return nil;
  }
  
  nsDictionary = [NSMutableDictionary new];
  CFDictionaryGetKeysAndValues(cfDictionary, &keys, &values);
  for (int i = 0; i < CFDictionaryGetCount(cfDictionary); i++) {
    [nsDictionary setObject:_convertCFtoNS(&values[i])
                     forKey:_convertCFtoNSString(&keys[i])]; // always CFStringRef
  }
  
  return nsDictionary;
}
id _convertCFtoNS(CFTypeRef value)
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
static CFNumberRef _convertNStoCFNumber(NSNumber *nsNumber);
static CFArrayRef _convertNStoCFArray(NSArray *nsArray);
static CFDictionaryRef _convertNStoCFDictionary(NSDictionary *dictionary);
static CFTypeRef _convertNStoCF(id value);

CFStringRef _convertNStoCFString(NSString *nsString)
{
  CFStringRef cfString;
  cfString = CFStringCreateWithCString(kCFAllocatorDefault,
                                       [nsString cString],
                                       CFStringGetSystemEncoding());
  return cfString;
}
CFNumberRef _convertNStoCFNumber(NSNumber *nsNumber)
{
  CFNumberRef cfNumber;
  int number = [nsNumber intValue];
  cfNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &number);
  return cfNumber;
}
CFArrayRef _convertNStoCFArray(NSArray *nsArray)
{
  CFMutableArrayRef cfArray = CFArrayCreateMutable(kCFAllocatorDefault, [nsArray count], NULL);

  for (id object in nsArray) {
    CFArrayAppendValue(cfArray, _convertNStoCF(object));
  }
  
  return cfArray;
}
CFDictionaryRef _convertNStoCFDictionary(NSDictionary *dictionary)
{
  CFMutableDictionaryRef cfDictionary;
  CFDictionaryRef returnedDictionary;
  CFStringRef keyCFString;
  CFTypeRef valueCF;

  cfDictionary = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                           [[dictionary allKeys] count],
                                           &kCFTypeDictionaryKeyCallBacks,
                                           &kCFTypeDictionaryValueCallBacks);
  for (NSString *key in [dictionary allKeys]) {
    keyCFString = _convertNStoCFString(key);
    // NSLog(@"Converted key: %@", key);
    valueCF = _convertNStoCF([dictionary objectForKey:key]);
    // NSLog(@"Converted value: %@", [dictionary objectForKey:key]);
    CFDictionaryAddValue(cfDictionary, keyCFString, valueCF);
    CFRelease(keyCFString);
    CFRelease(valueCF);
  }
  returnedDictionary = CFDictionaryCreateCopy(kCFAllocatorDefault, cfDictionary);
  CFRelease(cfDictionary);
  
  return returnedDictionary;
}

CFTypeRef _convertNStoCF(id value)
{
  CFTypeRef returnValue = "(CoreFoundation NULL)";
  
  if ([value isKindOfClass:[NSString class]]) {
    returnValue = _convertNStoCFString(value);
  }
  else if ([value isKindOfClass:[NSNumber class]]) {
    returnValue = _convertNStoCFNumber(value);
  }
  else if ([value isKindOfClass:[NSArray class]]) {
    returnValue = _convertNStoCFArray(value);
  }
  else if ([value isKindOfClass:[NSDictionary class]]) {
    returnValue = _convertNStoCFDictionary(value);
  }

  return returnValue;
}

@implementation CFObject @end

//-----------------------------------------------------------------------------
// Workspace notification center
//-----------------------------------------------------------------------------

static WMNotificationCenter *_workspaceCenter = nil;

typedef enum {
  LocalNC,
  DistributedNC,
  CoreFoundationNC
} NotificationSource;

@implementation WMNotificationCenter (Private)

// CoreFoundation notifications
//-------------------------------------------------------------------------------------------------
- (void)_postCFNotification:(NSString *)name
                   userInfo:(NSDictionary *)info
{
  CFStringRef cfName;
  CFDictionaryRef cfUserInfo;

  // name
  cfName = _convertNStoCFString(name);
  // userInfo
  cfUserInfo = _convertNStoCFDictionary(info);
 
  WMLogWarning("[WMNC] post CF notification: %@ - %@", cfName, cfUserInfo);
  
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
static void _handleCFNotification(CFNotificationCenterRef center,
                                   void *observer,
                                   CFNotificationName name,
                                   const void *object,
                                   CFDictionaryRef userInfo)
{
  CFObject *nsObject;
  NSString *nsName;
  NSDictionary *nsUserInfo = nil;

  // This is the mirrored notification sent by us
  if (object == _workspaceCenter) {
    WMLogWarning("_handleCFNotification: Received mirrored notification from CF. Ignoring...");
    return;
  }
  
  nsName = _convertCFtoNSString(name);
  nsObject = [CFObject new];
  nsObject.object = object;
  
  if (userInfo != NULL) {
    nsUserInfo = _convertCFtoNSDictionary(userInfo);
  }

  WMLogWarning("[WMNC] _handleCFNotificaition: dispatching CF notification %@ - %@", name,
               userInfo);

  [_workspaceCenter postNotificationName:nsName object:nsObject userInfo:nsUserInfo];
  
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
- (void)_handleRemoteNotification:(NSNotification*)aNotification
{
  NSString *name = [aNotification name];
  id object = [aNotification object];
  NSString *objectName = @"N/A";

  if ([object isKindOfClass:[NSString class]]) {
    objectName = object;
  }

  WMLogWarning("[WMNC] handle remote notification: %s - %s", [name cString], [objectName cString]);

  if ([name hasPrefix:@"WMShould"]) {
    [self _postCFNotification:name userInfo:[aNotification userInfo]];
  } else {
    // NSWorkspaceWillLaunchApplicationNotification - by Controller+NSWorkspace
    // NSWorkspaceDidLaunchApplicationNotification - by AppKit
    // NSWorkspaceDidTerminateApplicationNotification - by AppKit or Controller+NSWorkspace
    [super postNotification:aNotification];
  }
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
    _workspaceCenter = self;
    
    _remoteCenter = [[NSDistributedNotificationCenter defaultCenter] retain];
    @try {
      [_remoteCenter addObserver:self
                        selector:@selector(_handleRemoteNotification:)
                            name:nil
                          object:@"GSWorkspaceNotification"];
    }
    @catch (NSException *e) {
      NSLog(@"Workspace Manager caught exception while connecting to"
            " Distributed Notification Center %@: %@", [e name], [e reason]);
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
- (void)addObserver:(id)observer
           selector:(SEL)selector
               name:(NSString *)name
             object:(id)object
{
  CFStringRef cfName;

  if (!name || [name length] == 0) {
    return;
  }

  /* Register observer-name in NSNotificationCenter.
     There's no need to register in NSDistributedNotificationCenter because
     notifications which are sent to it will be forwarded to NSNotificationCenter. */
  [super addObserver:observer
            selector:selector
                name:name
              object:nil];
  
  // Register handler-name in CFNotificationCenter
  cfName = _convertNStoCFString(name);
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
- (void)postNotification:(NSNotification*)aNotification
{
  [self postNotificationName:[aNotification name]
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
  if (!object) {
    WMLogWarning("[WMNC postNotification:::] can't post notification with nil object!!!");
    return;
  }

  // locally (e.g. Controller or ProcessManager)
  if ([name hasPrefix:@"WMDid"]) {
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
