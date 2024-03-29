/*
 * Copyright (c) 2009 Stuart Crook.  All rights reserved.
 *
 * Created by Stuart Crook on 23/02/2009.
 * This source code is a reverse-engineered implementation of the notification center from
 * Apple's core foundation library.
 *
 * The PureFoundation code base consists of a combination of original code provided by contributors
 * and open-source code drawn from a nuber of other projects -- chiefly Cocotron (www.coctron.org)
 * and GNUStep (www.gnustep.org). Under the principal that the least-liberal licence trumps the others,
 * the PureFoundation project as a whole is released under the GNU Lesser General Public License (LGPL).
 * Where code has been included from other projects, that project's licence, along with a note of the
 * exact source (eg. file name) is included inline in the source.
 *
 * Since PureFoundation is a dynamically-loaded shared library, it is my interpretation of the LGPL
 * that any application linking to it is not automatically bound by its terms.
 *
 * See the text of the LGPL (from http://www.gnu.org/licenses/lgpl-3.0.txt, accessed 26/2/09):
 * 
 */

#include <CoreFoundation/CFPropertyList.h>
#include <CoreFoundation/CFNumber.h>
#include <CoreFoundation/CFMessagePort.h>
#include <CoreFoundation/CFStream.h>
#include <CoreFoundation/CFString.h>
#include <CoreFoundation/CFLocking.h>

#include "CFNotificationCenter.h"
#include "CFRuntime.h"
#include "CFRuntime_Internal.h"
#include "CFRuntime.h"
#include "CFPriv.h"
#include "CFInternal.h"
#include "CFLogUtilities.h"

#include <stdlib.h>
#include <stdio.h>
#if DEPLOYMENT_TARGET_MACOSX || DEPLOYMENT_TARGET_LINUX
#include <unistd.h>
#endif

#define CF_LOCAL_CENTER		0
#define CF_DIST_CENTER		1
#define CF_DARWIN_CENTER	2

#define CF_OBS_SIZE	32

typedef struct __CFObserver {
  //CFStringRef name; // can be NULL
  CFHashCode hash; // hashed string, for speed. can be NULL
  const void *object; // can be NULL
  const void *observer; // may be NULL
  CFNotificationCallback callback;
  CFNotificationSuspensionBehavior sb;
} __CFObserver;

typedef OSSpinLock CFSpinLock_t;

struct __CFNotificationCenter {
  CFRuntimeBase _base;
  CFIndex type;
  CFIndex suspended; // <- move into base bits?
  CFIndex observers;
  CFIndex capacity;
  __CFObserver *obs;
  CFSpinLock_t lock;
};


// STRUCTURES FOR DISTRIBUTED CENTER HERE
// message ids recognised by ddistnoted
#define NOTIFICATION			0
#define REGISTER_PORT			1
#define UNREGISTER_PORT			2
#define REGISTER_NOTIFICATION	3
#define UNREGISTER_NOTIFICATION	4

#define CF_DIST_SIZE	32
#define CF_QUEUE_SIZE	32

typedef struct __CFDistNotification {
  CFHashCode hash;
  CFHashCode object;
  CFIndex count;
} __CFDistNotification;

typedef struct __CFQueueRecord {
  CFStringRef name;
  const void *object; // will be a CFStringRef...
  const void *observer;
  CFDictionaryRef userInfo;
  CFNotificationCallback callback;
} __CFQueueRecord;

typedef struct __CFDistributedCenterInfo {
  CFMessagePortRef local;
  CFMessagePortRef remote;
  long session;
  CFHashCode uid;
  CFRunLoopSourceRef rls;
  CFIndex count;
  CFIndex capacity;
  __CFDistNotification *nots;
  CFIndex queueCount;
  CFIndex queueCapacity;
  __CFQueueRecord *queue;
} __CFDistributedCenterInfo;

static __CFDistributedCenterInfo __CFDistInfo = { NULL, NULL, 0, 0, NULL, 0, 0, NULL, 0, 0, NULL };

// these structures come from the ddistnoted project -- beter keep their definitions synced
typedef struct dndNotReg {
  CFHashCode uid;
  CFHashCode name;
  CFHashCode object;
} dndNotReg;

typedef struct dndNotHeader {
  long session;
  CFHashCode name;
  CFHashCode object;
  CFIndex flags;
} dndNotHeader;

#if DEPLOYMENT_TARGET_MACOSX
#include <notify.h>
#include <CoreFoundation/CFMachPort.h>
#endif
/*
 *	Darwin notifications
 *
 *	There are two ways we could organise recieving notify messages via Mach ports. The
 *	method we are using here is to use a single port for all messages, with an int token
 *	in the message header used to identify the notification name.
 *
 *	The alternative, which we may have to consider if the number of notifications in
 *	general use swamps a single port's message queue, is to allocate one Mach port per
 *	notification name.
 */
#define CF_DARWIN_SIZE 32

typedef struct __CFDarwinNotifications {
  //CFStringRef name;
  CFHashCode hash;
  int token;
  CFIndex count;
} __CFDarwinNotifications;

typedef struct __CFDarwinCenterInfo {	
#if defined(__MACH__)
  CFMachPortRef port;
#endif
  CFRunLoopSourceRef rls;
  CFIndex count;
  CFIndex capacity;
  __CFDarwinNotifications *nots;
} __CFDarwinCenterInfo;

#if defined(__MACH__)
static __CFDarwinCenterInfo __CFDarwinInfo = { NULL, NULL, 0, 0, NULL };
#else
static __CFDarwinCenterInfo __CFDarwinInfo = { NULL, 0, 0, NULL };
#endif

// the task's singleton centres
static CFNotificationCenterRef __CFLocalCenter = NULL;
static CFNotificationCenterRef __CFDistributedCenter = NULL;
static CFNotificationCenterRef __CFDarwinCenter = NULL;

static CFMutableDictionaryRef __CFHashStore = NULL;


// these control access to the Get functions. access to individual structure are
// embeded within those structures
static CFSpinLock_t __CFLocalCenterLock = CFLockInit;
static CFSpinLock_t __CFDistributedCenterLock = CFLockInit;
static CFSpinLock_t __CFDarwinCenterLock = CFLockInit;

static CFSpinLock_t __CFHashStoreLock = CFLockInit;

// store for our typeID
static CFTypeID __kCFNotificationCenterTypeID = _kCFRuntimeIDCFNotificationCenter;

// life-cycle stuff can wait for now
const CFRuntimeClass __CFNotificationCenterClass = {
  0,	// version
  "CFNotificationCenter",
  NULL,	// init
  NULL,	// copy
  NULL,	// __CFDataDeallocate,
  NULL,	// __CFDataEqual,
  NULL,	// __CFDataHash,
  NULL,	// __CFCopyFormattingDescription
  NULL,	// __CFDataCopyDescription
};

__private_extern__ void __CFNotificationCenterInitialize(void)
{
  __kCFNotificationCenterTypeID = _CFRuntimeRegisterClass(&__CFNotificationCenterClass);
  __CFHashStore = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, NULL);
}

CFTypeID CFNotificationCenterGetTypeID(void) {
  return _kCFRuntimeIDCFNotificationCenter;
}

/*
 *	The __CFAdd and Remove functions take an optional callback of this type which is called once
 *	for each observer added or removed. It runs under the current spinlock and gets over the
 *	problem of returning a list of notification to remove from the RemoveEvery function
 */
typedef void (*__CFAdderCallBack)(CFStringRef name, CFHashCode hash, CFHashCode object);
typedef void (*__CFRemoverCallBack)(CFHashCode name, CFHashCode object);


/*
 *	Declaration of functions internal to this file
 */
CFNotificationCenterRef __CFCreateCenter(CFIndex type);

void __CFAddObserver(CFNotificationCenterRef center, const void *observer, CFNotificationCallback callBack, CFStringRef name, const void *object, CFNotificationSuspensionBehavior suspensionBehavior, __CFAdderCallBack cb);
void __CFRemoveObserver(CFNotificationCenterRef center, const void *observer, CFHashCode name, const void *object, __CFRemoverCallBack cb );
void __CFRemoveEveryObserver(CFNotificationCenterRef center, const void *observer, __CFRemoverCallBack cb);
void __CFInvokeCallBacks(CFNotificationCenterRef center, CFHashCode name, CFStringRef nameReturn, const void *object, const void *objectReturn, CFDictionaryRef userInfo, Boolean deliverNow);

//void __PFPostLocalNotification( PFNotificationCenterRef center, CFStringRef name, const void *object, CFDictionaryRef userInfo );
void __CFPostDistributedNotification(CFNotificationCenterRef center, CFStringRef name, CFStringRef object, CFDictionaryRef userInfom, CFOptionFlags options);
void __CFPostDarwinNotification(CFNotificationCenterRef center, CFStringRef name);

void __CFAddQueue(CFStringRef name, const void *object, const void *observer, CFDictionaryRef userInfo, CFNotificationCallback callback, Boolean coalesce);
void __CFDeliverQueue(void);

Boolean _CFNotificationCenterIsSuspended(CFNotificationCenterRef center);
void _CFNotificationCenterSetSuspended(CFNotificationCenterRef center, Boolean suspended);

#if DEPLOYMENT_TARGET_MACOSX
void __CFDarwinCallBack(CFMachPortRef port, void *msg, CFIndex size, void *info);
#endif

/*
 *	Manage the message queue, which is used to store distributed notifications
 *	when delivery has been suspended.
 */
void __CFAddQueue(CFStringRef name, const void *object, const void *observer, CFDictionaryRef userInfo, CFNotificationCallback callback, Boolean coalesce) {
  CFRetain(userInfo);
  __CFQueueRecord *queue = __CFDistInfo.queue;
  CFIndex count = __CFDistInfo.queueCount;
	
  if (coalesce) { // do we check for this notification in the queue?
    while( count-- ) {
      // we're looking for exactl matches on name, object, observer and callback
      if ((queue->name == name) && (queue->object == object) 
          && (queue->observer == observer) && (queue->callback == callback)) {
        CFRelease(queue->userInfo);
        queue->userInfo = userInfo;
        break;
      }
      queue++;
    }
  }
	
  // either we're not coalescing or this notification wasn't already enqueued
  if (__CFDistInfo.count == __CFDistInfo.capacity) {
    __CFDistInfo.capacity += CF_QUEUE_SIZE;
    __CFDistInfo.queue = (__CFQueueRecord*)realloc(__CFDistInfo.queue, (CF_QUEUE_SIZE * sizeof(__CFQueueRecord)));
    if (__CFDistInfo.queue == NULL)
      return;
  }

  queue = __CFDistInfo.queue + __CFDistInfo.queueCount;
	
  queue->name = name;
  queue->object = object;
  queue->observer = observer;
  queue->callback = callback;
  queue->userInfo = userInfo;
	
  __CFDistInfo.queueCount++;
}

void __CFDeliverQueue(void) {
  CFIndex count = __CFDistInfo.queueCount;
  __CFQueueRecord *queue = __CFDistInfo.queue;
	
  while (count--) {
    queue->callback((CFNotificationCenterRef)__CFDistributedCenter, (void*)queue->observer, queue->name, queue->object, queue->userInfo);
    CFRelease(queue->userInfo);
		
    queue->name = NULL;
    queue->object = NULL;
    queue->observer = NULL;
    queue->callback = NULL;
    queue->userInfo = NULL;
  }
	
  __CFDistInfo.queueCount = 0;
}


/*
 *	Set the suspended condition of the distributed notification centre (only). At the
 *	moment these will be left as no-ops, to be activated when we write the 
 *	NSDitributedNotificationCenter class (which provides -setSuspended: and -suspended
 *	methods).
 *
 *	The docs suggested that these functions existed, and running nm over CoreFoundation
 *	revealed their names. I'm just guessing their prototypes at the moment, and hoping
 *	that nothing tries to call them directly.
 */
Boolean _CFNotificationCenterIsSuspended(CFNotificationCenterRef center) {
  return center->suspended;
}

void _CFNotificationCenterSetSuspended(CFNotificationCenterRef center, Boolean suspended) {
  if (center->type == CF_DIST_CENTER) { // only suspendable type
    __CFLock(&center->lock);
    if (center->suspended != suspended) { // changing state?
      center->suspended = suspended;
      // have we just un-suspended and are there notifications to deliver?
      if (!suspended && (__CFDistInfo.queueCount != 0)) {
        __CFDeliverQueue();
      }
    }
    __CFUnlock(&center->lock);
  }
}

/*
 *	Strings (names for all notifications, and objects from distributed observers) are
 *	stored as hashes in the look-up tables, with strings stored in the __CFHashStore
 *	dictionary
 *
 *	Strings are copied into the dictionary. At present, they are never removed.
 */
CFHashCode __CFNCHash(CFStringRef string);
CFStringRef __CFNCUnhash(CFHashCode hash);

// this should maybe be called "hashAndStore" - use CFHash() for just the hash
CFHashCode __CFNCHash(CFStringRef string) {
  if (string == NULL) {
    return 0;
  }
  CFHashCode hash = CFHash(string);
  __CFLock(&__CFHashStoreLock);
  if (!CFDictionaryContainsKey(__CFHashStore, (const void *)hash)) {
    CFDictionaryAddValue(__CFHashStore, (const void *)hash, CFStringCreateCopy( kCFAllocatorDefault, string));
  }
  __CFUnlock(&__CFHashStoreLock);
  return hash;
}

CFStringRef __CFNCUnhash(CFHashCode hash) {
  CFStringRef string;
  __CFLock(&__CFHashStoreLock);
  if (hash == 0) {
    string = NULL;
  }
  else {
    string = (CFStringRef)CFDictionaryGetValue(__CFHashStore, (const void *)hash);
  }
  __CFUnlock(&__CFHashStoreLock);
  return string;
}

/*
 *	Basic diagnostic functions
 */
void __CFCenterDiag(CFNotificationCenterRef c);
void __CFObserverDiag(__CFObserver o);

void __CFCenterDiag(CFNotificationCenterRef c) {
  CFLog(kCFLogLevelDebug,
        CFSTR("centre: type = %d, observers = %d, capacity = %d, obs at 0x%X"),
        c->type, c->observers, c->capacity, c->obs);
}

void __CFObserverDiag(__CFObserver o) {
  CFLog(kCFLogLevelDebug,
        CFSTR("observer: hash = %u, object = 0x%X, observer = 0x%X, callback to 0x%X, sb = %d"),
        o.hash, o.object, o.observer, o.callback, o.sb);
}
// END DIAGNOSTIC FUNCTIONS


/*
 *	Add or remove a notification from the table of distributed notifications we are
 *	monitoring. When the first notification with a unique signature is added (or the
 *	last is removed) we make a call to the ddistnoted daemon to register (or unregister)
 *	for that notification.
 *
 *	When the first monitored notification is added (or the last is removed) we add the
 *	message port source to (or remove it from) the main runloop.
 */

#if DEPLOYMENT_TARGET_MACOSX
CFDataRef __CFDistRecieve(CFMessagePortRef local, SInt32 msgid, CFDataRef data, void *info);
#endif
void __CFDistAddNotification(CFStringRef name, CFHashCode hash, CFHashCode object);
void __CFDistRemoveNotification(CFHashCode hash, CFHashCode object);

#if DEPLOYMENT_TARGET_MACOSX
/*
 *	recieves messages from the ddistnoted daemon
 *
 *	In a later version we're going to have to take note of the centre's suspended
 *	state, queuing and coalescing messages as needed
 */
CFDataRef __CFDistRecieve(CFMessagePortRef local, SInt32 msgid, CFDataRef data, void *info) {
  // center hasn't been created at the time the callback's set, so just as easier to pull in the global
  CFNotificationCenterRef center = __CFDistributedCenter;
	
  CFIndex length = CFDataGetLength(data);
  if (length < sizeof(dndNotHeader)) {
    return NULL;
  }

  CFReadStreamRef rs = CFReadStreamCreateWithBytesNoCopy(kCFAllocatorDefault, CFDataGetBytePtr(data), length, NULL);
  CFReadStreamOpen(rs);

  dndNotHeader header;
  CFReadStreamRead(rs, (UInt8 *)&header, sizeof(dndNotHeader));

  //printf("\tmessage name = %u, object = %u, flags = %u\n", header.name, header.object, header.flags);

  // the rest of the data contains an array: [name, object, userInfo] with kCFBooleanFalse representing
  //	a missing object or userInfo
  CFPropertyListRef array = NULL;
  CFIndex format = kCFPropertyListBinaryFormat_v1_0;
  array = CFPropertyListCreateFromStream( kCFAllocatorDefault, rs, 0, kCFPropertyListImmutable, &format, NULL );
  if ((array == NULL) || (CFGetTypeID(array) != CFArrayGetTypeID())) {
    return NULL;
  }

  // now recover and set up the arguments to invoke callbacks. If either name or object hasn't been
  //	encountered (and hashed) before, add it to the hash store now, so that coalescing based on 
  //	pointers will work later. If it ever needs to.
  CFStringRef name = __CFNCUnhash(header.name);
  if (name == NULL) { // we haven't met this name before
    __CFNCHash(CFArrayGetValueAtIndex(array, 0));
    name = __CFNCUnhash(header.name);
  }

  CFStringRef object;
  if (header.object == 0) {
    object = NULL;
  }
  else {
    if ((object = __CFNCUnhash(header.object)) == NULL) {
      __CFNCHash(CFArrayGetValueAtIndex(array, 1));
      object = __CFNCUnhash(header.object);
    }
  }

  CFPropertyListRef userInfo = CFArrayGetValueAtIndex(array, 2);
  if (CFGetTypeID(userInfo) != CFDictionaryGetTypeID()) {
    userInfo = NULL;
  }
	
  // we deliver now if the centre isn't suspended or the messages header says we should
  Boolean deliverNow = header.flags | kCFNotificationDeliverImmediately;

  __CFInvokeCallBacks(center, header.name, name, (const void *)header.object, (const void *)object, userInfo, deliverNow);

  if (userInfo != NULL) {
    CFRelease(userInfo);
  }
  return NULL;
}
#endif

/*
 *	Add a notification to the table of registered notifications, optionally registering it with
 *	the ddistnoted daemon and adding the local message port's source to the main runloop
 *
 *	We can ignore name.
 */
void __CFDistAddNotification(CFStringRef name, CFHashCode hash, CFHashCode object) {
  //fprintf(stderr, "register distributed notification %8X, %8X\n", hash, object);

  CFIndex count = __CFDistInfo.count;
  __CFDistNotification *nots = __CFDistInfo.nots;
	
  while (count--) {
    while (nots->count == 0) nots++; {// count == 0 is the empty record marker
      if ((nots->hash == hash) && (nots->object == object)) {
        nots->count++;
        return;
      }
    }
    nots++;
  }
	
  // we need to register for this notification
  dndNotReg info = {__CFDistInfo.uid, hash, object};
  CFDataRef data = CFDataCreate(kCFAllocatorDefault, (const UInt8 *)&info, sizeof(dndNotReg));
#if DEPLOYMENT_TARGET_MACOSX
  SInt32 result = CFMessagePortSendRequest(__CFDistInfo.remote, REGISTER_NOTIFICATION, data, 1.0, 0.0, NULL, NULL);
#else
  SInt32 result = 0;
#endif
  CFRelease(data);
  if (result != kCFMessagePortSuccess) {
    return;
  }
  if (__CFDistInfo.count == __CFDistInfo.capacity) {
    fprintf(stderr, "Increasing capacity of dist notification list\n");
    __CFDistInfo.capacity += CF_DIST_SIZE;
    __CFDistInfo.nots = (__CFDistNotification*)realloc(__CFDistInfo.nots, (__CFDistInfo.capacity * sizeof(__CFDistNotification)));
    if (__CFDistInfo.nots == NULL) {
      return;
    }
    // because I'm unsure if realloc zeroes the new memory...
    nots = __CFDistInfo.nots + __CFDistInfo.count;
    for (int i = 0; i < CF_DIST_SIZE; i++) {
      (nots++)->count = 0;
    }
    nots = __CFDistInfo.nots + __CFDistInfo.count;
  }
  else {
    nots = __CFDistInfo.nots;
    while (nots->count != 0) {
      nots++;
    }
  }
	
  nots->hash = hash;
  nots->object = object;
  nots->count = 1;
	
  if (0 == __CFDistInfo.count++) {
    CFRunLoopAddSource(CFRunLoopGetMain(), __CFDistInfo.rls, kCFRunLoopCommonModes);
  }

  //fprintf(stderr, "added notification (no.%d) and leaving\n", __CFDistInfo.count);
}

void __CFDistRemoveNotification(CFHashCode hash, CFHashCode object) {
  //fprintf(stderr, "dist remove notification\n");

  CFIndex count = __CFDistInfo.count;
  __CFDistNotification *nots = __CFDistInfo.nots;
	
  while (count--) {
    while (nots->count == 0) nots++; // count == 0 is the empty record marker
    if ((nots->hash == hash) && (nots->object == object)) {
      if (0 == --nots->count) {
        dndNotReg info = {__CFDistInfo.uid, hash, object};
        CFDataRef data = CFDataCreate(kCFAllocatorDefault, (const UInt8 *)&info, sizeof(dndNotReg));
        if (data != NULL) {
#if DEPLOYMENT_TARGET_MACOSX
          CFMessagePortSendRequest(__CFDistInfo.remote, UNREGISTER_NOTIFICATION, data, 1.0, 1.0, NULL, NULL);
#endif
          CFRelease(data);
        }
        nots->hash = 0;
        nots->object = 0;
        if( 0 == --__CFDistInfo.count ) {
          CFRunLoopRemoveSource(CFRunLoopGetMain(), __CFDistInfo.rls, kCFRunLoopCommonModes);
        }
      }
      return;
    }		
    nots++;
  }

  //fprintf(stderr, "dist remove notification done\n");
}


/*
 *	Functions used to add and remove notifications to the list we are monitoring and register
 *	with notifyd to recieve them. We track how many times each is added and removed, so we can 
 *	unregister for notifications when they're no-longer needed. As above, assumes the structure 
 *	is spinlocked.
 */
void __CFDarwinAddNotification(CFStringRef name, CFHashCode hash, CFHashCode ignored);
void __CFDarwinRemoveNotification(CFHashCode hash, CFHashCode ignored);

void __CFDarwinAddNotification(CFStringRef name, CFHashCode hash, CFHashCode ignored) {
  //CFHashCode hash = CFHash(name);
  CFIndex count = __CFDarwinInfo.count;
  __CFDarwinNotifications *nots = __CFDarwinInfo.nots;
	
  while( count-- ) {
    while( nots->hash == 0 ) {
      nots++;
    }
    if (nots->hash == hash) { // already registered for this notification
      nots->count++;
      return;
    }
    nots++;
  }
	
  // haven't registered for this notification yet
  CFIndex length = CFStringGetLength(name);
  STACK_BUFFER_DECL(char, buffer, ++length);
  CFStringGetCString(name, buffer, length, kCFStringEncodingASCII);
  int token;
#if DEPLOYMENT_TARGET_MACOSX
  mach_port_t port = CFMachPortGetPort(__CFDarwinInfo.port);
	
  if (0 != notify_register_mach_port(buffer, &port, NOTIFY_REUSE, &token)) {
    return;
  }
#endif
  if (__CFDarwinInfo.count == __CFDarwinInfo.capacity) {
      __CFDarwinInfo.capacity += CF_DARWIN_SIZE;
      __CFDarwinInfo.nots = (__CFDarwinNotifications*)realloc(__CFDarwinInfo.nots, (__CFDarwinInfo.capacity * sizeof(__CFDarwinNotifications)));
      if (__CFDarwinInfo.nots == NULL) {
        return;
      }
      // because I'm unsure if realloc zeroes the new memory...
      nots = __CFDarwinInfo.nots + __CFDarwinInfo.count;
      for (int i = 0; i < CF_DARWIN_SIZE; i++) {
        (nots++)->hash = 0;
      }
      nots = __CFDarwinInfo.nots + __CFDarwinInfo.count;
    }
  else {
    nots = __CFDarwinInfo.nots;
    while (nots->hash != 0) {
      nots++;
    }
  }
	
  nots->hash = hash;
  //nots->name = name;
  nots->token = token;
  nots->count = 1;
	
  if (0 == __CFDarwinInfo.count++) {
    CFRunLoopAddSource(CFRunLoopGetMain(), __CFDarwinInfo.rls, kCFRunLoopCommonModes);
  }
}

void __CFDarwinRemoveNotification(CFHashCode hash, CFHashCode ignored) {
  //CFHashCode hash = CFHash(name);
  CFIndex count = __CFDarwinInfo.count;
  __CFDarwinNotifications *nots = __CFDarwinInfo.nots;
	
  while (count--) {
    while( nots->hash == 0 ) {nots++;}
		
    if( nots->hash == hash ) {
      if( nots->count-- > 1 ) { // still want to recieve the notification
        return;}
#if defined(__MACH__)
      notify_cancel(nots->token);
#endif
      nots->hash = 0;
      //nots->name = NULL;
      nots->token = 0;
      nots->count = 0;
      if( --__CFDarwinInfo.count == 0 ) {
        CFRunLoopRemoveSource( CFRunLoopGetMain(), __CFDarwinInfo.rls, kCFRunLoopCommonModes );
      }
      return;
    }
    nots++;
  }
}


/*
 *	Add the observer info into the table of observers for the notification center, growing the
 *	table if need be. Duplicate observers with identical signatures are allowed.
 */
void __CFAddObserver(CFNotificationCenterRef center, const void *observer, CFNotificationCallback callBack, CFStringRef name, const void *object, CFNotificationSuspensionBehavior suspensionBehavior, __CFAdderCallBack cb) {
  __CFObserver *obs;
	
  __CFLock(&center->lock);
	
  if (center->observers == center->capacity) {
    //fprintf(stderr, "increasing size of observer records for center type %d\n", center->type);
    center->capacity += CF_OBS_SIZE;
    center->obs = (__CFObserver*)realloc(center->obs, (center->capacity * sizeof(__CFObserver)));
    if (center->obs == NULL) {
      fprintf(stderr, "Couldn't realloc observer records for notification center type %ld\n", center->type);
      __CFUnlock(&center->lock);
      return; 
    }
    obs = center->obs + center->observers;
    // because I'm unsure if realloc zeroes the new memory...
    for( int i = 0; i < CF_OBS_SIZE; i++ ) (obs++)->callback = NULL;
    obs = center->obs + center->observers;
  }
  else {
    obs = center->obs;
    while (obs->callback != NULL) obs++;
  }
	
  // hash and store the name
  CFHashCode hash = __CFNCHash(name);
	
  //obs->name = name;
  obs->hash = hash;
  obs->object = object;
  obs->observer = observer;
  obs->callback = callBack;
  obs->sb = suspensionBehavior;
	
  center->observers++;
	
  if( cb != NULL ) cb(name, hash, (CFHashCode)object);
	
  __CFUnlock(&center->lock);
}

/*
 *	Remove the observer with the given signature from the notification center's table.
 */
void __CFRemoveObserver(CFNotificationCenterRef center, const void *observer, CFHashCode name, const void *object, __CFRemoverCallBack cb) {
  __CFLock(&center->lock);
	
  //CFHashCode hash = (name == NULL) ? 0 : CFHash(name);
  CFIndex count = center->observers;
  __CFObserver *obs = center->obs;
	
  while (count--) {
    while (obs->callback == NULL) {
      obs++;
    }
    if ((obs->observer == observer)
        && /* match name hash */ ((name == 0) || (name == obs->hash))
        && /* match object */((object == NULL) || (object == obs->object))) {
      //obs->name = NULL;
      obs->hash = 0;
      obs->object = NULL;
      obs->observer = NULL;
      obs->callback = NULL;
      obs->sb = 0;
      center->observers--;
			
      if( cb != NULL ) {
        cb(name, (CFHashCode)object);
      }
    }
    obs++;
  }

  __CFUnlock(&center->lock);
}

/*
 *	Remove every instance of the observer from the notification centre's table.
 */
void __CFRemoveEveryObserver(CFNotificationCenterRef center, const void *observer, __CFRemoverCallBack cb) {
  __CFLock(&center->lock);
	
  CFIndex count = center->observers;	
  __CFObserver *obs = center->obs;
	
  while (count--) {
    while( obs->callback == NULL ) {
      obs++;
    }
		
    if (obs->observer == observer) {
      if (cb != NULL) {
        cb(obs->hash, (CFHashCode)obs->object);
      }
      //obs->name = NULL;
      obs->hash = 0;
      obs->object = NULL;
      obs->observer = NULL;
      obs->callback = NULL;
      obs->sb = 0;
      center->observers--;
    }
		
    obs++;
  }

  __CFUnlock(&center->lock);	
}

/*
 *	Invoke the callback functions for the observers whose signature match the arguments.
 *
 *	This is a general routine which handles the special suspension behaviour of the
 *	distributed centre at the cost of extra un-needed checks while processing local
 *	and Darwin centre notifications.
 *
 *	I'm not entirely sure whether notifications sent with kCFNotificationDeliverImmediately
 *	should behave like notifications delivered to suspended observers with the deliver
 *	immediately behaviour and flush the notification queue... so at the moment it just
 *	jumps the queue and is delivered on its own.
 *
 *	The name and object arguments are used to find matching observers, while the nameReturn
 *	and objectReturn are passed to the observer's callbacks or queued.
 *		Local:		object == objectReturn
 *		Distributed:	object == hash, objectReturn == CFStringRef
 *		Darwin:		object == objectReturn == NULL
 */
void __CFInvokeCallBacks(CFNotificationCenterRef center, CFHashCode name, CFStringRef nameReturn, const void *object, const void *objectReturn, CFDictionaryRef userInfo, Boolean deliverNow) {
  __CFLock(&center->lock);
		
  CFIndex count = center->observers;
  __CFObserver *obs = center->obs;
	
  //printf("A\n");
  //__CFCenterDiag(center);
	
  // process each observer in the table
  while (count--) {
    //printf("B\n");
		
    // find a record with a non-NULL callback field
    while (obs->callback == NULL) {
      obs++;
    }
		
    //printf("C\n");
    //__CFObserverDiag (*obs);
		
    //printf("observer: 0x%X\n");
		
    // for an observer to qualify to recieve a notification, it need to match
    // both name and object, taking into account the NULL-case "match any name
    // or object"
    if (((obs->hash == 0) || (obs->hash == name)) /* match name hash */
        && ((obs->object == NULL) || (obs->object == object)) /* match object */) {
      // found a match, now do we deliver the notification?
      if (deliverNow /* non-dist short-circuit */ || !center->suspended) {
        // CFMachPort source suggested unlocking before invoking callbacks
        __CFUnlock(&center->lock);
        obs->callback((CFNotificationCenterRef)center, (void*)obs->observer, nameReturn, objectReturn, userInfo);
        __CFLock(&center->lock);
      }
      else switch (obs->sb) {
        case CFNotificationSuspensionBehaviorDrop: break;
        case CFNotificationSuspensionBehaviorCoalesce:
          __CFAddQueue(nameReturn, objectReturn, obs->observer, userInfo, obs->callback, TRUE);
          break;
        case CFNotificationSuspensionBehaviorHold:
          __CFAddQueue(nameReturn, objectReturn, obs->observer, userInfo, obs->callback, FALSE);
          break;
        case CFNotificationSuspensionBehaviorDeliverImmediately:
          if (__CFDistInfo.queueCount != 0) {
            __CFDeliverQueue();
          }
          obs->callback((CFNotificationCenterRef)center, (void*)obs->observer, nameReturn, objectReturn, userInfo);
          break;
        }
    }
		
    obs++;
  }
	
  __CFUnlock(&center->lock);
}


#if defined(__MACH__)
/*
 *	The CFMachPortCallBack invoked when a message arrives at the runloop from notifyd. The
 *	Darwin notification centre is passed in as the info... just because.
 */
void __CFDarwinCallBack(CFMachPortRef port, void *msg, CFIndex size, void *info) {
  //printf("Got a message from a darwin port!\n");

  // first we retrieve the token associated with the notification
  int token = ((mach_msg_header_t *)msg)->msgh_id;

  // then we look for the matching record
  CFIndex count = __CFDarwinInfo.count;
  __CFDarwinNotifications *nots = __CFDarwinInfo.nots;
	
  while (count--) {
    while( nots->hash == 0 ) {
      nots++;
    }
    if (nots->token == token) { // found it
      count = -1;
      break;
    }
    nots++;
  }
	
  if (count != -1) { // couldn't find the matching notification
    return;
  }

  // then we send the notification to all the matching observers
  __CFInvokeCallBacks(__CFDarwinCenter, nots->hash, __CFNCUnhash(nots->hash), NULL, NULL, NULL, TRUE);
}
#endif

// shared creation method
CFNotificationCenterRef __CFCreateCenter(CFIndex type) {
  // allocate the memory
  CFIndex size = sizeof(struct __CFNotificationCenter) - sizeof(CFRuntimeBase);
  struct __CFNotificationCenter *memory;

  __CFHashStore = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, NULL);
  
  memory = (CFNotificationCenterRef)_CFRuntimeCreateInstance(kCFAllocatorDefault,
                                                             __kCFNotificationCenterTypeID,
                                                             size, NULL);
  if (NULL == memory) {
    return NULL;
  }
	
  memory->suspended = FALSE;
  memory->type = type;
  memory->lock = CFLockInit;
  // allocate storage and set counters
  memory->observers = 0;
  memory->capacity = CF_OBS_SIZE;
  // IMPORTANT: after calloc, we assume memory is zeroed
  memory->obs = (__CFObserver*)calloc(CF_OBS_SIZE, sizeof(__CFObserver));
	
  if (memory->obs == NULL) {
    CFAllocatorDeallocate(kCFAllocatorDefault, memory);
    memory = NULL;
  }
  return memory;
}

/*
 *	The local notification center is used for synchronous intra-task communication and
 *	can always be created.
 */
CFNotificationCenterRef CFNotificationCenterGetLocalCenter(void) {
  __CFLock(&__CFLocalCenterLock);
  if( __CFLocalCenter == NULL ) {
    __CFLocalCenter = __CFCreateCenter(CF_LOCAL_CENTER);
  }
  __CFUnlock(&__CFLocalCenterLock);
  return __CFLocalCenter;
}

/*
 *	The distributed center relies on the presence of a daemon (our ddistnoted on
 *	Darwin) to deliver inter-task notifications. This implementation tries to contact 
 *	it via CFMessagePort, and fails if a connection cannot be made.
 */
CFNotificationCenterRef CFNotificationCenterGetDistributedCenter(void) {
  //fprintf(stderr, "Entering CFNotificationCenterGetDistributedCenter()\n");
  __CFLock(&__CFDistributedCenterLock);
  if (__CFDistributedCenter == NULL) {
    // generate a 'unique' port name for the current task
    char uname[128];
    //sprintf(uname, "ddistnoted-%s-%u", getprogname(), getpid());
    //printf("unique string is '%s'\n", uname);
    CFStringRef name = CFStringCreateWithCString(kCFAllocatorDefault, uname, kCFStringEncodingASCII);

    // create the local port now, because the daemon will look for it
    CFMessagePortContext context = { 0, NULL, NULL, NULL, NULL };
#if defined(__MACH__)
    CFMessagePortRef local = CFMessagePortCreateLocal(kCFAllocatorDefault, name, __CFDistRecieve, &context, NULL);
		
    if (local == NULL) {
      CFLog(kCFLogLevelError, CFSTR("CFNoticationCenter: Couldn't create a local message port."));
      __CFUnlock(&__CFDistributedCenterLock);
      return NULL;
    }
#else
    CFMessagePortRef local = 0;
#endif
		
    //CFRunLoopSourceRef rls = 
    //CFRunLoopAddSource( CFRunLoopGetMain(), rls, kCFRunLoopCommonModes );
		
#if defined(DEPLOYMENT_TARGET_MACOSX)
    // create the remote port
    CFMessagePortRef remote = CFMessagePortCreateRemote( kCFAllocatorDefault, CFSTR("org.puredarwin.ddistnoted") );
		
    if (remote == NULL) {
      CFLog(kCFLogLevelError, CFSTR("CFNoticationCenter: Couldn't create a local message port."));
      __CFUnlock(&__CFDistributedCenterLock);
      return NULL;
    }
#else
    CFMessagePortRef remote = 0;
#endif

    // squeeze our unique name, as ASCII, into a data object...
    CFIndex length = CFStringGetLength(name);
    STACK_BUFFER_DECL(UInt8, data, (++length + sizeof(long)));

    /*	Security sessions come via one of the security components, although
        I'm not sure which. Once we get everything working we may be able to
        actually get this working properly. */
		
    // if this isn't set -- and on other platforms -- we could maybe use userIds
#if DEPLOYMENT_TARGET_MACOSX || DEPLOYMENT_TARGET_LINUX
    long session = getuid();
#else
    long session = 0;
#endif
		
    if( session == 0 ) session = 1;
		
    //session = strtol( getenv("SECURITYSESSIONID"), NULL, 16 );
    *(long *)data = session;
    //printf("session id = %d\n", *(long *)data);
		
    // getsid() returns the same as getpid()...
    //printf("and getsid() reports %u\n", getsid(0));
		
    CFStringGetCString(name, (char *)(data + sizeof(long)), length, kCFStringEncodingASCII);
    CFDataRef dataOut = CFDataCreate(kCFAllocatorDefault, (const UInt8 *)data, (length + sizeof(long)));
    //printf("'unique' name: '%s'\n", data);
		

    // ...send the register message...
    CFDataRef dataIn = NULL;
#if DEPLOYMENT_TARGET_MACOSX
    CFMessagePortSendRequest(remote, REGISTER_PORT, dataOut, 1.0, 1.0, kCFRunLoopDefaultMode, &dataIn);
#endif
		
    CFRelease(name);
    CFRelease(dataOut);

    if ((dataIn == NULL) || (CFDataGetLength(dataIn) == 0)) {
      return NULL;
    }
		
    CFHashCode hash;
    CFRange range = { 0, sizeof(CFHashCode) };
    CFDataGetBytes(dataIn, range, (UInt8 *)&hash);
		
    //if( h2 == -1 ) return NULL;

    //printf("Worked. Our hash = %u, returned hash = %u\n", h1, h2);
		
    // that seemed to work, so we'll try to allocate the centre object
    __CFDistributedCenter = __CFCreateCenter(CF_DIST_CENTER);
    if (__CFDistributedCenter == NULL) {
      return NULL;
    }
    __CFDistInfo.nots = (__CFDistNotification*)calloc(CF_DIST_SIZE, sizeof(__CFDistNotification));
    if (__CFDistInfo.nots == NULL) {
      return NULL;
    }
    __CFDistInfo.queue = (__CFQueueRecord*)calloc(CF_QUEUE_SIZE, sizeof(__CFQueueRecord));
    if (__CFDistInfo.queue == NULL) {
      return NULL;
    }

    __CFDistInfo.local = local;
    __CFDistInfo.remote = remote;
    __CFDistInfo.session = session;
    __CFDistInfo.uid = hash;
#if defined(DEPLOYMENT_TARGET_MACOSX)
    __CFDistInfo.rls = CFMessagePortCreateRunLoopSource(kCFAllocatorDefault, local, 0);
    // do we need an "added to runloop" flag?
#endif
    //__PFDistInfo.count = 0;
    __CFDistInfo.capacity = CF_DIST_SIZE;
    //__PFDistInfo.count = 0;
    __CFDistInfo.capacity = CF_QUEUE_SIZE;
  }
  __CFUnlock(&__CFDistributedCenterLock);

  //fprintf(stderr, "Leaving CFNotificationCenterGetDistributedCenter()\n");

  return __CFDistributedCenter;
}

/*
 *	The Darwin notification center passes inter-task notifications via the notifyd 
 *	daemon, with which it comunicates using the functions in <notify.h> for sending
 *	and a runloop-attached Mach port for recieving. I think this is Darwin-specific,
 *	altough other BSDs may have a similar set-up.
 *
 *	We create the CFMachPort and its runloop source used for recieving messages here 
 *	so that they're available when observers are added.
 */
CFNotificationCenterRef CFNotificationCenterGetDarwinNotifyCenter(void) {
  __CFLock(&__CFDarwinCenterLock);
  if (__CFDarwinCenter == NULL) {
    __CFDarwinCenter = __CFCreateCenter(CF_DARWIN_CENTER);

#if DEPLOYMENT_TARGET_MACOSX
    CFMachPortContext context = { 0, (void *)__CFDarwinCenter, NULL, NULL, NULL };
    __CFDarwinInfo.port = CFMachPortCreate(kCFAllocatorDefault, __CFDarwinCallBack, &context, NULL);
    __CFDarwinInfo.rls = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, __CFDarwinInfo.port, 0);
#endif
    __CFDarwinInfo.nots = (__CFDarwinNotifications*)calloc(CF_DARWIN_SIZE, sizeof(__CFDarwinNotifications));
    __CFDarwinInfo.count = 0;
    __CFDarwinInfo.capacity = CF_DARWIN_SIZE;
  }
  __CFUnlock(&__CFDarwinCenterLock);
  return __CFDarwinCenter;
}



/*
 *	Add an observer to the notification centre. In the local case at least, the CF
 *	behaviour is to allow multiple indentical observers.
 */
void CFNotificationCenterAddObserver(CFNotificationCenterRef center, const void *observer, CFNotificationCallback callBack, CFStringRef name, const void *object, CFNotificationSuspensionBehavior suspensionBehavior) {
  // common causes of failure
  if ((center == NULL) || (CFGetTypeID(center) != __kCFNotificationCenterTypeID)
      || (callBack == NULL) || ((name == NULL) && (object == NULL))) {
    return;
  }

  switch (center->type)
    {
    case CF_LOCAL_CENTER:
      __CFAddObserver(center, observer, callBack, name, object, 0, NULL);
      break;
    case CF_DIST_CENTER:
      // For distributed centres, object should always be a string. We hash the string and use
      //	this value for all comparisons until notifications are delivered
      if(object != NULL) {
        if( CFGetTypeID((CFTypeRef)object) != CFStringGetTypeID() ) {
          return;
        }
        object = (const void *)__CFNCHash((CFStringRef)object);
      }
      __CFAddObserver(center, observer, callBack, name, object, suspensionBehavior, __CFDistAddNotification);
      break;
    case CF_DARWIN_CENTER:
      if (name == NULL) {
        return;
      }
      __CFAddObserver(center, observer, callBack, name, NULL, 0, __CFDarwinAddNotification);
      break;
    }
}


/*
 *
 */
void CFNotificationCenterRemoveObserver(CFNotificationCenterRef center, const void *observer, CFStringRef name, const void *object) {
  if ((center == NULL) || (CFGetTypeID(center) != __kCFNotificationCenterTypeID)
      || (observer == NULL) || (center->observers == 0)) {
    CFLog(kCFLogLevelError,
          CFSTR("CFNotificationCenter: can't remove observer `%s`"),
          CFStringGetCStringPtr(name, CFStringGetSystemEncoding()));
    return;
  }

  CFHashCode hash = (name == NULL) ? 0 : CFHash(name);
	
  switch(center->type) 
    {
    case CF_DIST_CENTER:
      if (object != NULL) {
        if (CFGetTypeID(object) != CFStringGetTypeID()) {  // wouldn't have been added
          return;
        }
        object = (void *)CFHash(object);
      }
      if ((name == NULL) && (object == NULL))
        __CFRemoveEveryObserver(center, observer, __CFDistRemoveNotification);
      else
        __CFRemoveObserver(center, observer, hash, object, __CFDistRemoveNotification);
      break;
			
    case CF_LOCAL_CENTER:
      if ((name == NULL) && (object == NULL)) 
        __CFRemoveEveryObserver(center, observer, NULL);
      else
        __CFRemoveObserver(center, observer, hash, object, NULL);
      break;
			
    case CF_DARWIN_CENTER:
      if (name == NULL)
        __CFRemoveEveryObserver(center, observer, __CFDarwinRemoveNotification);
      else
        __CFRemoveObserver(center, observer, hash, NULL, __CFDarwinRemoveNotification);
      break;
    }
}


/*
 *
 */
void CFNotificationCenterRemoveEveryObserver(CFNotificationCenterRef center, const void *observer) {
  if ((center == NULL) || (CFGetTypeID(center) != __kCFNotificationCenterTypeID)
      || (observer == NULL) || (center->observers == 0)) {
    return;
  }
  switch(center->type) 
    {
    case CF_LOCAL_CENTER:
      __CFRemoveEveryObserver(center, observer, NULL);
      break;
    case CF_DIST_CENTER:
      __CFRemoveEveryObserver(center, observer, __CFDistRemoveNotification);
      break;
    case CF_DARWIN_CENTER:
      __CFRemoveEveryObserver(center, observer, __CFDarwinRemoveNotification);
      break;
    }
}



/*
 *	Type-specific notification posting functions
 */


/*
 *	Post a notification to the ddistnoted daemon which runs the distributed
 *	notification centre.
 *
 *	ddistnoted uses name and object hashes, along with session ids, to route
 *	distributions. The data object contains a 3-item array containing the name,
 *	object string and userInfo dictionary. We have to send the name and object
 *	because an observer may not have previously hashed and stored either string.
 */
void __CFPostDistributedNotification(CFNotificationCenterRef center, CFStringRef name, CFStringRef object, CFDictionaryRef userInfo, CFOptionFlags options) {
  CFPropertyListRef plist[3];
  plist[0] = name;
	
  // object must be a string when posting to a distributed centre
  CFHashCode objectHash;
  if(object == NULL) {
      objectHash = 0;
      plist[1] = kCFBooleanFalse; // used to signal a null entry
    }
  else {
    if(CFGetTypeID(object) != CFStringGetTypeID()) {
      return;
    }
      objectHash = __CFNCHash(object);
      plist[1] = object;
    }

  plist[2] = (userInfo == NULL) ? (CFDictionaryRef)kCFBooleanFalse : userInfo;
  CFArrayRef array = CFArrayCreate(kCFAllocatorDefault, (const void **)&plist, 3, NULL);
	
  // we don't need to store the strings these hashes represent
  CFHashCode nameHash = CFHash(name);
  dndNotHeader info = { __CFDistInfo.session, nameHash, objectHash, options };
	
  CFWriteStreamRef ws = CFWriteStreamCreateWithAllocatedBuffers(kCFAllocatorDefault, kCFAllocatorDefault);
  CFWriteStreamOpen(ws);
  CFWriteStreamWrite(ws, (const UInt8 *)&info, sizeof(dndNotHeader));

  // write the property list, but don't worry if an error occurs
  CFPropertyListWriteToStream(array, ws, kCFPropertyListBinaryFormat_v1_0, NULL);
	
  CFWriteStreamClose(ws);
  CFDataRef data = (CFDataRef)CFWriteStreamCopyProperty(ws, kCFStreamPropertyDataWritten);
  CFRelease(ws);
  CFRelease(array);
	
  if (data == NULL) {
    return;
  }
	
#if DEPLOYMENT_TARGET_MACOSX
  CFMessagePortSendRequest(__CFDistInfo.remote, NOTIFICATION, data, 1.0, 1.0, NULL, NULL);
#endif
}


/*
 *	All things considered, posting Darwin/notifyd notifications is fairly painless.
 */
void __CFPostDarwinNotification(CFNotificationCenterRef center, CFStringRef name) {
  CFIndex length = CFStringGetLength(name);
  if (length == 0) {
    return;
  }
  STACK_BUFFER_DECL(char, buffer, ++length);
  CFStringGetCString(name, buffer, length, kCFStringEncodingASCII);
#if defined(__MACH__)
  notify_post(buffer);
#endif
}


/*
 *	Post notification: Interprets the deliverImmediately flag and invokes the other
 *	post notification method.
 */
void CFNotificationCenterPostNotification(CFNotificationCenterRef center, CFStringRef name, const void *object, CFDictionaryRef userInfo, Boolean deliverImmediately) {
  CFOptionFlags options = deliverImmediately ? kCFNotificationDeliverImmediately : 0;
  return CFNotificationCenterPostNotificationWithOptions(center, name, object, userInfo, options);
}


/*
 *	Checks for some common reasons why posting a notification could fail, then invokes
 *	the centre-specific posting message with the required sub-set of arguments.
 */
void CFNotificationCenterPostNotificationWithOptions(CFNotificationCenterRef center, CFStringRef name, const void *object, CFDictionaryRef userInfo, CFOptionFlags options) {
  //fprintf(stderr, "Entering CFNotificationCenterPostNotificationWithOptions()\n");

  if ((center == NULL) || (CFGetTypeID(center) != __kCFNotificationCenterTypeID) || (name == NULL)) {
    return;
  }

  CFHashCode hash = (name == NULL) ? 0 : CFHash(name);
	
  if ((center->type == CF_LOCAL_CENTER) && (center->observers != 0)) {
    return __CFInvokeCallBacks(center, hash, name, object, object, userInfo, TRUE);
  }
  else if (center->type == CF_DIST_CENTER) {
    __CFPostDistributedNotification( center, name, (CFStringRef)object, userInfo, options );
    //fprintf(stderr, "Leaving CFNotificationCenterPostNotificationWithOptions()\n");
    return;
  }
  else if (center->type == CF_DARWIN_CENTER) {
    return __CFPostDarwinNotification(center, name);
  }
}

