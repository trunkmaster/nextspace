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
    NSLog(@"Converted key: %@", key);
    valueCF = _convertNStoCF([dictionary objectForKey:key]);
    NSLog(@"Converted value: %@", [dictionary objectForKey:key]);
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

@interface WMNotificationCenter (Private)
- (void)_postNSNotification:(NSString *)name
                     object:(id)object
                   userInfo:(NSDictionary *)info
                     source:(NotificationSource)source;
- (void)_postCFNotification:(NSString*)name
                   userInfo:(NSDictionary*)info;
@end
@implementation WMNotificationCenter (Private)

- (void)_postNSNotification:(NSString *)name
                     object:(id)object
                   userInfo:(NSDictionary *)info
                     source:(NotificationSource)source
{
  NSNotification *aNotif;
  
  NSLog(@"WMNC: post NS notification: %@ - %@ source: %u", name, object, source);

  // NSNotificationCenter
  if (source != LocalNC) {
    aNotif = [NSNotification notificationWithName:name object:object userInfo:info];
    [super postNotification:aNotif];
  }

  // NSDistributedNotificationCenter
  // TODO: CFObject is not a good object to send
  // if (source != DistributedNC) {
  //   aNotif = [NSNotification notificationWithName:name object:@"GSWorkspaceNotification" userInfo:info];
  //   @try {
  //     [_remoteCenter postNotification:aNotif];
  //   }
  //   @catch (NSException *e) {
  //   }
  // }
}

- (void)_postCFNotification:(NSString *)name
                   userInfo:(NSDictionary *)info
{
  CFStringRef cfName;
  CFDictionaryRef cfUserInfo;

  // name
  cfName = _convertNStoCFString(name);
  // userInfo
  cfUserInfo = _convertNStoCFDictionary(info);
 
  NSLog(@"WMNC: post CF notification: %@ - %@", name, info);
  
  CFNotificationCenterPostNotification(_coreFoundationCenter, cfName, self, cfUserInfo, TRUE);

  CFRelease(cfName);
  CFRelease(cfUserInfo);
}

/*
 * Forward a notification from a remote application to observers in this application.
 */
- (void)_handleRemoteNotification:(NSNotification*)aNotification
{
  NSLog(@"WMNC: handle remote notification: %@ - %@", [aNotification name], [aNotification object]);
  // local
  [self _postNSNotification:[aNotification name]
                     object:[aNotification object]
                   userInfo:[aNotification userInfo]
                     source:DistributedNC];

  id object = [aNotification object];
  if (object &&
      [object isKindOfClass:[NSString class]] &&
      [object isEqualToString:@"GSWorkspaceNotification"] != NO) {
    return;
  }
  
  // TODO: CFNotificationCenter
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
  CFObject *cfObject;
  NSString *nsName;
  NSDictionary *nsUserInfo = nil;

  // This is the mirrored notification sent by us
  if (object == _workspaceCenter) {
    NSLog(@"_handleCFNotification: Received mirrored notification from CF. Ignoring...");
    return;
  }
  
  cfObject = [CFObject new];
  nsName = _convertCFtoNSString(name);
  cfObject.object = object;
  
  if (userInfo != NULL) {
    nsUserInfo = _convertCFtoNSDictionary(userInfo);
  }
  
  NSLog(@"[WMNC] _handleCFNotificaition: dispatching CF notification %@ - %@", nsName, nsUserInfo);
  
  [_workspaceCenter _postNSNotification:nsName
                                 object:cfObject
                               userInfo:nsUserInfo
                                 source:CoreFoundationNC];
  [cfObject release];
  [nsUserInfo release];
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

  if (!name || [name length] == 0) {
    return;
  }
  
  /* Register observer-name in NSNotificationCenter.
     There's no need to register in NSDistributedNotificationCenter because */
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
  // if ([name isEqual:NSWorkspaceDidTerminateApplicationNotification] == YES ||
  //     [name isEqual:NSWorkspaceDidLaunchApplicationNotification] == YES ||
  //     [name isEqualToString:NSApplicationDidBecomeActiveNotification] == YES ||
  //     [name isEqualToString:NSApplicationDidResignActiveNotification] == YES) {
  //   // Posts distributed notification
  //   [[[NSWorkspace sharedWorkspace] notificationCenter] postNotification:aNotification];
  // }
  
  NSLog(@"[WMNC] postNotificationName: %@:%@ - %@", name, object, info);
  // local and remote
  [self _postNSNotification:name object:object userInfo:info source:LocalNC];

  // CFNotificationCenter
  [self _postCFNotification:name userInfo:info];
}

@end
