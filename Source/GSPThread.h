/* GSPThread.h
   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   
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
#ifndef _GSPThread_h_
#define _GSPThread_h_

#if GS_USE_WIN32_THREADS_AND_LOCKS

#include <windows.h>
#include <process.h>
#include "GSAtomic.h"

typedef enum {
  gs_mutex_attr_normal = 0,
  gs_mutex_attr_errorcheck = 1,
  gs_mutex_attr_recursive = 2
} gs_mutex_attr_t;

typedef struct {
  SRWLOCK lock;
  _Atomic(DWORD) owner;
  DWORD depth;
  gs_mutex_attr_t attr;
} gs_mutex_t;

typedef SRWLOCK gs_cond_mutex_t;
typedef CONDITION_VARIABLE gs_cond_t;

/*
 * Locking primitives.
 */
#define GS_MUTEX_INIT_STATIC {.lock = SRWLOCK_INIT, .attr = gs_mutex_attr_normal}
#define GS_MUTEX_INIT(x) gs_mutex_init(&(x), gs_mutex_attr_normal)
#define GS_MUTEX_INIT_RECURSIVE(x) gs_mutex_init(&(x), gs_mutex_attr_recursive)

#define GS_MUTEX_LOCK(x) gs_mutex_lock(&(x))
#define GS_MUTEX_TRYLOCK(x) gs_mutex_trylock(&(x))
#define GS_MUTEX_UNLOCK(x) gs_mutex_unlock(&(x))
#define GS_MUTEX_DESTROY(x)

#define GS_COND_WAIT(cond, mutex) gs_cond_wait(cond, mutex)
#define GS_COND_SIGNAL(cond) WakeConditionVariable(&(cond))
#define GS_COND_BROADCAST(cond) WakeAllConditionVariable(&(cond))

/* Pthread-like locking primitives defined in NSLock.m */
#ifdef __cplusplus
extern "C" {
#endif
void gs_mutex_init(gs_mutex_t *l, gs_mutex_attr_t attr);
int gs_mutex_lock(gs_mutex_t *l);
int gs_mutex_trylock(gs_mutex_t *l);
int gs_mutex_unlock(gs_mutex_t *l);
int gs_cond_wait(gs_cond_t *cond, gs_mutex_t *mutex);
int gs_cond_timedwait(gs_cond_t *cond, gs_mutex_t *mutex, DWORD millisecs);
#ifdef __cplusplus
}
#endif

/*
 * Threading primitives.
 *
 * Use Fiber Local Storage (FLS), as in contrast to Thread Local Storage (TLS)
 * they provide a destructor callback and will just manipulate the FLS
 * associated with the current thread if fibers are not being used.
 */
#define GS_THREAD_KEY_INIT(key, dtor) \
  ((key = FlsAlloc(dtor)) != FLS_OUT_OF_INDEXES)
#define GS_THREAD_KEY_GET(key)        FlsGetValue(key)
#define GS_THREAD_KEY_SET(key, val)   FlsSetValue(key, val)

#define GS_THREAD_ID_SELF()           GetCurrentThreadId()

#define GS_YIELD() Sleep(0)

typedef DWORD gs_thread_key_t;
typedef DWORD gs_thread_id_t;

#else /* GS_USE_WIN32_THREADS_AND_LOCKS */

#include <pthread.h>

typedef pthread_mutex_t gs_mutex_t;
typedef pthread_mutex_t gs_cond_mutex_t;
typedef pthread_cond_t gs_cond_t;

/*
 * Locking primitives
 */
#define GS_MUTEX_INIT_STATIC PTHREAD_MUTEX_INITIALIZER
#define GS_MUTEX_INIT(x) pthread_mutex_init(&(x), NULL)

/*
 * Macro to initialize recursive mutexes in a portable way. Adopted from
 * libobjc2 (lock.h).
 */
# ifdef PTHREAD_RECURSIVE_MUTEX_INITIALIZER_NP
#   define GS_MUTEX_INIT_RECURSIVE(x) \
x = (pthread_mutex_t) PTHREAD_RECURSIVE_MUTEX_INITIALIZER_NP
# elif defined(PTHREAD_RECURSIVE_MUTEX_INITIALIZER)
#   define GS_MUTEX_INIT_RECURSIVE(x) \
x = (pthread_mutex_t) PTHREAD_RECURSIVE_MUTEX_INITIALIZER
# else
#   define GS_MUTEX_INIT_RECURSIVE(x) GSPThreadInitRecursiveMutex(&(x))

static inline void GSPThreadInitRecursiveMutex(pthread_mutex_t *x)
{
  pthread_mutexattr_t recursiveAttributes;
  pthread_mutexattr_init(&recursiveAttributes);
  pthread_mutexattr_settype(&recursiveAttributes, PTHREAD_MUTEX_RECURSIVE);
  pthread_mutex_init(x, &recursiveAttributes);
  pthread_mutexattr_destroy(&recursiveAttributes);
}
# endif // PTHREAD_RECURSIVE_MUTEX_INITIALIZER(_NP)

#define GS_MUTEX_LOCK(x) pthread_mutex_lock(&(x))
#define GS_MUTEX_TRYLOCK(x) pthread_mutex_trylock(&(x))
#define GS_MUTEX_UNLOCK(x) pthread_mutex_unlock(&(x))
#define GS_MUTEX_DESTROY(x) pthread_mutex_destroy(&(x))

#define GS_COND_WAIT(cond, mutex) pthread_cond_wait(cond, mutex)
#define GS_COND_SIGNAL(cond) pthread_cond_signal(&(cond))
#define GS_COND_BROADCAST(cond) pthread_cond_broadcast(&(cond))

/*
 * Threading primitives.
 */
#define GS_THREAD_KEY_INIT(key, dtor) (pthread_key_create(&(key), dtor) == 0)
#define GS_THREAD_KEY_GET(key)        pthread_getspecific(key)
#define GS_THREAD_KEY_SET(key, val)   pthread_setspecific(key, val)

#define GS_THREAD_ID_SELF()           pthread_self()

#define GS_YIELD() sched_yield()

typedef pthread_key_t gs_thread_key_t;
typedef pthread_t     gs_thread_id_t;

#endif /* GS_USE_WIN32_THREADS_AND_LOCKS */


#ifdef __OBJC__ /* Enables including file in autoconf check */

#import "Foundation/NSLock.h"

@class  GSStackTrace;
@class  NSArray;
@class  NSMapTable;

/* Class to obtain/encapsulate a stack trace for exception reporting and/or
 * lock tracing.
 */
@interface GSStackTrace : NSObject
{
  NSArray	        *symbols;
  NSArray	        *addresses;
@public
  NSUInteger            recursion;      // Recursion count for lock trace
  NSUInteger	        *returns;       // The return addresses on the stack
  int                   numReturns;     // Number of return addresses
}
- (NSArray*) addresses; // Return addresses from last trace
- (NSArray*) symbols;   // Return symbols from last trace
- (void) trace;         // Populate with new stack trace
@end

/* Versions of the lock classes where the locking is never traced
 */
@interface      GSUntracedCondition : NSCondition
@end
@interface      GSUntracedConditionLock : NSConditionLock
@end
@interface      GSUntracedLock : NSLock
@end
@interface      GSUntracedRecursiveLock : NSRecursiveLock
@end

/* Versions of the lock classes where the locking is traced
 */
@interface      GSTracedCondition : NSCondition
{
  GSStackTrace  *stack;
}
- (GSStackTrace*) stack;
@end

@interface      GSTracedConditionLock : NSConditionLock
@end

@interface      GSTracedLock : NSLock
{
  GSStackTrace  *stack;
}
- (GSStackTrace*) stack;
@end

@interface      GSTracedRecursiveLock : NSRecursiveLock
{
  GSStackTrace  *stack;
}
- (GSStackTrace*) stack;
@end

#endif // __OBJC__

#endif // _GSPThread_h_
