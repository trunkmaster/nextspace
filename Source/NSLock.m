/** Control of executable units within a shared virtual memory space
   Copyright (C) 1996-2010 Free Software Foundation, Inc.

   Original Author:  David Chisnall <csdavec@swan.ac.uk>

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

   <title>NSLock class reference</title>
   <ignore> All autogsdoc markup is in the header
*/

#import "common.h"

#define	EXPOSE_NSLock_IVARS	1
#define	EXPOSE_NSRecursiveLock_IVARS	1
#define	EXPOSE_NSCondition_IVARS	1
#define	EXPOSE_NSConditionLock_IVARS	1

#define	gs_cond_public_t	gs_cond_t
#define	gs_cond_mutex_public_t	gs_cond_mutex_t
#define	gs_mutex_public_t	gs_mutex_t

#import "GSPrivate.h"
#import "GSPThread.h"
#include <math.h>
#include <stdlib.h>

#import "common.h"

#import "Foundation/NSLock.h"
#import "Foundation/NSException.h"
#import "Foundation/NSThread.h"

#define class_createInstance(C,E) NSAllocateObject(C,E,NSDefaultMallocZone())

static Class    baseConditionClass = Nil;
static Class    baseConditionLockClass = Nil;
static Class    baseLockClass = Nil;
static Class    baseRecursiveLockClass = Nil;

static Class    tracedConditionClass = Nil;
static Class    tracedConditionLockClass = Nil;
static Class    tracedLockClass = Nil;
static Class    tracedRecursiveLockClass = Nil;

static Class    untracedConditionClass = Nil;
static Class    untracedConditionLockClass = Nil;
static Class    untracedLockClass = Nil;
static Class    untracedRecursiveLockClass = Nil;

static BOOL     traceLocks = NO;

@implementation NSObject (GSTraceLocks)

+ (BOOL) shouldCreateTraceableLocks: (BOOL)shouldTrace
{
  BOOL  old = traceLocks;

  traceLocks = shouldTrace ? YES : NO;
  return old;
}

+ (NSCondition*) tracedCondition
{
  return AUTORELEASE([GSTracedCondition new]);
}

+ (NSConditionLock*) tracedConditionLockWithCondition: (NSInteger)value
{
  return AUTORELEASE([[GSTracedConditionLock alloc] initWithCondition: value]);
}

+ (NSLock*) tracedLock
{
  return AUTORELEASE([GSTracedLock new]);
}

+ (NSRecursiveLock*) tracedRecursiveLock
{
  return AUTORELEASE([GSTracedRecursiveLock new]);
}

@end

/* In untraced operations these macros do nothing.
 * When tracing they are defined to perform the trace methods of the thread.
 */
#define CHKT(T,X) 
#define CHK(X)

/*
 * Methods shared between NSLock, NSRecursiveLock, and NSCondition
 *
 * Note: These methods currently throw exceptions when locks are incorrectly
 * acquired.  This is compatible with earlier GNUstep behaviour.  In OS X 10.5
 * and later, these will just NSLog a warning instead.  Throwing an exception
 * is probably better behaviour, because it encourages developer to fix their
 * code.
 */

#define	MDEALLOC \
- (void) dealloc\
{\
  [self finalize];\
  [_name release];\
  [super dealloc];\
}

#if     defined(HAVE_PTHREAD_MUTEX_OWNER)

#define	MDESCRIPTION \
- (NSString*) description\
{\
  if (_mutex.__data.__owner)\
    {\
      if (_name == nil)\
        {\
          return [NSString stringWithFormat: @"%@ (locked by %llu)",\
            [super description], (unsigned long long)_mutex.__data.__owner];\
        }\
      return [NSString stringWithFormat: @"%@ '%@' (locked by %llu)",\
        [super description], _name, (unsigned long long)_mutex.__data.__owner];\
    }\
  else\
    {\
      if (_name == nil)\
        {\
          return [super description];\
        }\
      return [NSString stringWithFormat: @"%@ '%@'",\
        [super description], _name];\
    }\
}

#define	MISLOCKED \
- (BOOL) isLockedByCurrentThread\
{\
  if (GSPrivateThreadID() == (NSUInteger)_mutex.__data.__owner)\
    return YES;\
  else\
    return NO; \
}

#else

#define	MDESCRIPTION \
- (NSString*) description\
{\
  if (_name == nil)\
    {\
      return [super description];\
    }\
  return [NSString stringWithFormat: @"%@ '%@'",\
    [super description], _name];\
}

#define	MISLOCKED \
- (BOOL) isLockedByCurrentThread\
{\
  [NSException raise: NSGenericException format: @"Not supported"];\
  return NO;\
}

#endif

#define MFINALIZE \
- (void) finalize\
{\
  GS_MUTEX_DESTROY(_mutex);\
}

#define	MLOCK \
- (void) lock\
{\
  int err = GS_MUTEX_LOCK(_mutex);\
  if (EDEADLK == err)\
    {\
      (*_NSLock_error_handler)(self, _cmd, YES, @"deadlock");\
    }\
  else if (err != 0)\
    {\
      [NSException raise: NSLockException format: @"failed to lock mutex"];\
    }\
}

#define	MLOCKBEFOREDATE \
- (BOOL) lockBeforeDate: (NSDate*)limit\
{\
  do\
    {\
      int err = GS_MUTEX_TRYLOCK(_mutex);\
      if (0 == err)\
        {\
          CHK(Hold) \
          return YES;\
        }\
      GS_YIELD();\
    } while ([limit timeIntervalSinceNow] > 0);\
  return NO;\
}

#define MNAME \
- (void) setName: (NSString*)newName\
{\
  ASSIGNCOPY(_name, newName);\
}\
- (NSString*) name\
{\
  return _name;\
}

#define MSTACK \
- (GSStackTrace*) stack \
{ \
  return nil; \
}

#define	MTRYLOCK \
- (BOOL) tryLock\
{\
  int err = GS_MUTEX_TRYLOCK(_mutex);\
  if (0 == err) \
    { \
      CHK(Hold) \
      return YES; \
    } \
  else \
    { \
      return NO;\
    } \
}

#define	MUNLOCK \
- (void) unlock\
{\
  if (0 != GS_MUTEX_UNLOCK(_mutex))\
    {\
      if (GSPrivateDefaultsFlag(GSMacOSXCompatible))\
	{\
          NSLog(@"Failed to unlock mutex %@ at %@",\
	    self, [NSThread callStackSymbols]);\
	}\
      else \
	{\
          [NSException raise: NSLockException\
		      format: @"failed to unlock mutex %@", self];\
	}\
    }\
  CHK(Drop) \
}

static gs_mutex_t deadlock;
#if !GS_USE_WIN32_THREADS_AND_LOCKS
static pthread_mutexattr_t attr_normal;
static pthread_mutexattr_t attr_reporting;
static pthread_mutexattr_t attr_recursive;
#endif

/*
 * OS X 10.5 compatibility function to allow debugging deadlock conditions.
 */
void _NSLockError(id obj, SEL _cmd, BOOL stop, NSString *msg)
{
  NSLog(@"*** -[%@ %@]: %@ (%@)", [obj class], NSStringFromSelector(_cmd),
    msg, obj);
  NSLog(@"*** Break on _NSLockError() to debug.");
  if (YES == stop)
    GS_MUTEX_LOCK(deadlock);
}

NSLock_error_handler  *_NSLock_error_handler = _NSLockError;

// Exceptions

NSString *NSLockException = @"NSLockException";

@implementation NSLock

+ (id) allocWithZone: (NSZone*)z
{
  if (self == baseLockClass && YES == traceLocks)
    {
      return class_createInstance(tracedLockClass, 0);
    }
  return class_createInstance(self, 0);
}

+ (void) initialize
{
  static BOOL	beenHere = NO;

  if (beenHere == NO)
    {
      beenHere = YES;

#if !GS_USE_WIN32_THREADS_AND_LOCKS
      /* Initialise attributes for the different types of mutex.
       * We do it once, since attributes can be shared between multiple
       * mutexes.
       * If we had a pthread_mutexattr_t instance for each mutex, we would
       * either have to store it as an ivar of our NSLock (or similar), or
       * we would potentially leak instances as we couldn't destroy them
       * when destroying the NSLock.  I don't know if any implementation
       * of pthreads actually allocates memory when you call the
       * pthread_mutexattr_init function, but they are allowed to do so
       * (and deallocate the memory in pthread_mutexattr_destroy).
       */
      pthread_mutexattr_init(&attr_normal);
      pthread_mutexattr_settype(&attr_normal, PTHREAD_MUTEX_NORMAL);
      pthread_mutexattr_init(&attr_reporting);
      pthread_mutexattr_settype(&attr_reporting, PTHREAD_MUTEX_ERRORCHECK);
      pthread_mutexattr_init(&attr_recursive);
      pthread_mutexattr_settype(&attr_recursive, PTHREAD_MUTEX_RECURSIVE);
#endif

      /* To emulate OSX behavior, we need to be able both to detect deadlocks
       * (so we can log them), and also hang the thread when one occurs.
       * the simple way to do that is to set up a locked mutex we can
       * force a deadlock on.
       */
#if GS_USE_WIN32_THREADS_AND_LOCKS
      gs_mutex_init(&deadlock, gs_mutex_attr_normal);
#else
      pthread_mutex_init(&deadlock, &attr_normal);
#endif
      GS_MUTEX_LOCK(deadlock);

      baseConditionClass = [NSCondition class];
      baseConditionLockClass = [NSConditionLock class];
      baseLockClass = [NSLock class];
      baseRecursiveLockClass = [NSRecursiveLock class];

      tracedConditionClass = [GSTracedCondition class];
      tracedConditionLockClass = [GSTracedConditionLock class];
      tracedLockClass = [GSTracedLock class];
      tracedRecursiveLockClass = [GSTracedRecursiveLock class];

      untracedConditionClass = [GSUntracedCondition class];
      untracedConditionLockClass = [GSUntracedConditionLock class];
      untracedLockClass = [GSUntracedLock class];
      untracedRecursiveLockClass = [GSUntracedRecursiveLock class];
    }
}

MDEALLOC
MDESCRIPTION
MFINALIZE

/* Use an error-checking lock.  This is marginally slower, but lets us throw
 * exceptions when incorrect locking occurs.
 */
- (id) init
{
  if (nil != (self = [super init]))
    {
#if GS_USE_WIN32_THREADS_AND_LOCKS
      gs_mutex_init(&_mutex, gs_mutex_attr_errorcheck);
#else
      if (0 != pthread_mutex_init(&_mutex, &attr_reporting))
        {
          DESTROY(self);
        }
#endif
    }
  return self;
}

MISLOCKED
MLOCK

- (BOOL) lockBeforeDate: (NSDate*)limit
{
  do
    {
      int err = GS_MUTEX_TRYLOCK(_mutex);
      if (0 == err)
        {
          CHK(Hold)
          return YES;
        }
      if (EDEADLK == err)
        {
          (*_NSLock_error_handler)(self, _cmd, NO, @"deadlock");
        }
      GS_YIELD();
    } while ([limit timeIntervalSinceNow] > 0);
  return NO;
}

MNAME
MSTACK
MTRYLOCK
MUNLOCK

@end

@implementation NSRecursiveLock

+ (id) allocWithZone: (NSZone*)z
{
  if (self == baseRecursiveLockClass && YES == traceLocks)
    {
      return class_createInstance(tracedRecursiveLockClass, 0);
    }
  return class_createInstance(self, 0);
}

+ (void) initialize
{
  [NSLock class];	// Ensure mutex attributes are set up.
}

MDEALLOC
MDESCRIPTION
MFINALIZE

- (id) init
{
  if (nil != (self = [super init]))
    {
#if GS_USE_WIN32_THREADS_AND_LOCKS
      gs_mutex_init(&_mutex, gs_mutex_attr_recursive);
#else
      if (0 != pthread_mutex_init(&_mutex, &attr_recursive))
        {
          DESTROY(self);
        }
#endif
    }
  return self;
}

MISLOCKED
MLOCK
MLOCKBEFOREDATE
MNAME
MSTACK
MTRYLOCK
MUNLOCK
@end

@implementation NSCondition

+ (id) allocWithZone: (NSZone*)z
{
  if (self == baseConditionClass && YES == traceLocks)
    {
      return class_createInstance(tracedConditionClass, 0);
    }
  return class_createInstance(self, 0);
}

+ (void) initialize
{
  [NSLock class];	// Ensure mutex attributes are set up.
}

- (void) broadcast
{
  GS_COND_BROADCAST(_condition);
}

MDEALLOC
MDESCRIPTION

- (void) finalize
{
#if !GS_USE_WIN32_THREADS_AND_LOCKS
  pthread_cond_destroy(&_condition);
#endif
  GS_MUTEX_DESTROY(_mutex);
}

- (id) init
{
  if (nil != (self = [super init]))
    {
#if GS_USE_WIN32_THREADS_AND_LOCKS
      InitializeConditionVariable(&_condition);
      gs_mutex_init(&_mutex, gs_mutex_attr_errorcheck);
#else
      if (0 != pthread_cond_init(&_condition, NULL))
        {
          DESTROY(self);
        }
      else if (0 != pthread_mutex_init(&_mutex, &attr_reporting))
        {
          pthread_cond_destroy(&_condition);
          DESTROY(self);
        }
#endif
    }
  return self;
}

MISLOCKED
MLOCK
MLOCKBEFOREDATE
MNAME

- (void) signal
{
  GS_COND_SIGNAL(_condition);
}

MSTACK
MTRYLOCK
MUNLOCK

- (void) wait
{
  GS_COND_WAIT(&_condition, &_mutex);
}

- (BOOL) waitUntilDate: (NSDate*)limit
{
  int retVal = 0;

#if GS_USE_WIN32_THREADS_AND_LOCKS
  NSTimeInterval ti = [limit timeIntervalSinceNow];
  if (ti < 0) {
    ti = 0.0; // handle timeout in the past
  }

  retVal = gs_cond_timedwait(&_condition, &_mutex, ti * 1000.0);
#else
  NSTimeInterval ti = [limit timeIntervalSince1970];

  double secs, subsecs;
  struct timespec timeout;

  // Split the float into seconds and fractions of a second
  subsecs = modf(ti, &secs);
  timeout.tv_sec = secs;
  // Convert fractions of a second to nanoseconds
  timeout.tv_nsec = subsecs * 1e9;

  /* NB. On timeout the lock is still held even through condition is not met
   */

  retVal = pthread_cond_timedwait(&_condition, &_mutex, &timeout);
#endif /* GS_USE_WIN32_THREADS_AND_LOCKS */

  if (retVal == 0)
    {
      return YES;
    }
  if (retVal == ETIMEDOUT)
    {
      return NO;
    }

  NSLog(@"Error calling pthread_cond_timedwait: %d", retVal);
  return NO;
}

@end

@implementation NSConditionLock

+ (id) allocWithZone: (NSZone*)z
{
  if (self == baseConditionLockClass && YES == traceLocks)
    {
      return class_createInstance(tracedConditionLockClass, 0);
    }
  return class_createInstance(self, 0);
}

+ (void) initialize
{
  [NSLock class];	// Ensure mutex attributes are set up.
}

- (NSInteger) condition
{
  return _condition_value;
}

- (void) dealloc
{
  [_name release];
  [_condition release];
  [super dealloc];
}

- (id) init
{
  return [self initWithCondition: 0];
}

- (id) initWithCondition: (NSInteger)value
{
  if (nil != (self = [super init]))
    {
      if (nil == (_condition = [NSCondition new]))
	{
	  DESTROY(self);
	}
      else
	{
          _condition_value = value;
          [_condition setName:
            [NSString stringWithFormat: @"condition-for-lock-%p", self]];
	}
    }
  return self;
}

- (BOOL) isLockedByCurrentThread
{
  return [_condition isLockedByCurrentThread];
}

- (void) lock
{
  [_condition lock];
}

- (BOOL) lockBeforeDate: (NSDate*)limit
{
  return [_condition lockBeforeDate: limit];
}

- (void) lockWhenCondition: (NSInteger)value
{
  [_condition lock];
  while (value != _condition_value)
    {
      [_condition wait];
    }
}

- (BOOL) lockWhenCondition: (NSInteger)condition_to_meet
                beforeDate: (NSDate*)limitDate
{
  if (NO == [_condition lockBeforeDate: limitDate])
    {
      return NO;        // Not locked
    }
  if (condition_to_meet == _condition_value)
    {
      return YES;       // Keeping the lock
    }
  while ([_condition waitUntilDate: limitDate])
    {
      if (condition_to_meet == _condition_value)
	{
	  return YES;   // Keeping the lock
	}
    }
  [_condition unlock];
  return NO;            // Not locked
}

MNAME
MSTACK

- (BOOL) tryLock
{
  return [_condition tryLock];
}

- (BOOL) tryLockWhenCondition: (NSInteger)condition_to_meet
{
  if ([_condition tryLock])
    {
      if (condition_to_meet == _condition_value)
	{
	  return YES; // KEEP THE LOCK
	}
      else
	{
	  [_condition unlock];
	}
    }
  return NO;
}

- (void) unlock
{
  [_condition unlock];
}

- (void) unlockWithCondition: (NSInteger)value
{
  _condition_value = value;
  [_condition broadcast];
  [_condition unlock];
}

@end



/* Versions of the lock classes where the locking is unconditionally traced
 */

#undef CHKT
#define CHKT(T,X) \
{ \
  NSString *msg = [T mutex ## X: self]; \
  if (nil != msg) \
    { \
      (*_NSLock_error_handler)(self, _cmd, YES, msg); \
    } \
}
#undef CHK
#define CHK(X) CHKT(GSCurrentThread(), X)

#undef  MDEALLOC
#define	MDEALLOC \
- (void) dealloc \
{ \
  DESTROY(stack); \
  [super dealloc]; \
}

#undef MLOCK
#define	MLOCK \
- (void) lock\
{ \
  NSThread      *t = GSCurrentThread(); \
  int		err; \
  CHKT(t,Wait) \
  err = GS_MUTEX_LOCK(_mutex);\
  if (EDEADLK == err)\
    {\
      CHKT(t,Drop) \
      (*_NSLock_error_handler)(self, _cmd, YES, @"deadlock");\
    }\
  else if (err != 0)\
    {\
      CHKT(t,Drop) \
      [NSException raise: NSLockException format: @"failed to lock mutex"];\
    }\
  CHKT(t,Hold) \
}

#undef MSTACK
#define MSTACK \
- (GSStackTrace*) stack \
{ \
  if (nil == stack) \
    { \
      stack = [GSStackTrace new]; \
    } \
  return stack; \
}

@implementation GSTracedCondition
+ (id) allocWithZone: (NSZone*)z
{
  return class_createInstance(tracedConditionClass, 0);
}
MDEALLOC
MLOCK
MLOCKBEFOREDATE
MSTACK
MTRYLOCK

- (void) wait
{
  NSThread      *t = GSCurrentThread();
  CHKT(t,Drop)
  CHKT(t,Wait)
  GS_COND_WAIT(&_condition, &_mutex);
  CHKT(t,Hold)
}

- (BOOL) waitUntilDate: (NSDate*)limit
{
  int retVal = 0;
  NSThread *t = GSCurrentThread();
  
#if GS_USE_WIN32_THREADS_AND_LOCKS
  NSTimeInterval ti = [limit timeIntervalSinceNow];
  if (ti < 0) {
    ti = 0.0; // handle timeout in the past
  }

  CHKT(t,Drop)
  retVal = gs_cond_timedwait(&_condition, &_mutex, ti * 1000.0);
#else    
  NSTimeInterval ti = [limit timeIntervalSince1970];

  double secs, subsecs;
  struct timespec timeout;

  // Split the float into seconds and fractions of a second
  subsecs = modf(ti, &secs);
  timeout.tv_sec = secs;
  // Convert fractions of a second to nanoseconds
  timeout.tv_nsec = subsecs * 1e9;

  /* NB. On timeout the lock is still held even through condition is not met
   */

  CHKT(t,Drop)
  retVal = pthread_cond_timedwait(&_condition, &_mutex, &timeout);
#endif /* GS_USE_WIN32_THREADS_AND_LOCKS */

  if (retVal == 0)
    {
      CHKT(t,Hold)
      return YES;
    }
  if (retVal == ETIMEDOUT)
    {
      CHKT(t,Hold)
      return NO;
    }

  NSLog(@"Error calling pthread_cond_timedwait: %d", retVal);
  return NO;
}

MUNLOCK
@end
@implementation GSTracedConditionLock
+ (id) allocWithZone: (NSZone*)z
{
  return class_createInstance(tracedConditionLockClass, 0);
}
- (id) initWithCondition: (NSInteger)value
{
  if (nil != (self = [super init]))
    {
      if (nil == (_condition = [GSTracedCondition new]))
	{
	  DESTROY(self);
	}
      else
	{
          _condition_value = value;
          [_condition setName:
            [NSString stringWithFormat: @"condition-for-lock-%p", self]];
	}
    }
  return self;
}
@end
@implementation GSTracedLock
+ (id) allocWithZone: (NSZone*)z
{
  return class_createInstance(tracedLockClass, 0);
}
MDEALLOC
MLOCK
MLOCKBEFOREDATE
MSTACK
MTRYLOCK
MUNLOCK
@end
@implementation GSTracedRecursiveLock
+ (id) allocWithZone: (NSZone*)z
{
  return class_createInstance(tracedRecursiveLockClass, 0);
}
MDEALLOC
MLOCK
MLOCKBEFOREDATE
MSTACK
MTRYLOCK
MUNLOCK
@end


/* Versions of the lock classes where the locking is never traced
 */
@implementation GSUntracedCondition
+ (id) allocWithZone: (NSZone*)z
{
  return class_createInstance(baseConditionClass, 0);
}
@end
@implementation GSUntracedConditionLock
+ (id) allocWithZone: (NSZone*)z
{
  return class_createInstance(baseConditionLockClass, 0);
}
@end
@implementation GSUntracedLock
+ (id) allocWithZone: (NSZone*)z
{
  return class_createInstance(baseRecursiveLockClass, 0);
}
@end
@implementation GSUntracedRecursiveLock
+ (id) allocWithZone: (NSZone*)z
{
  return class_createInstance(baseRecursiveLockClass, 0);
}
@end

/* Return a global recursive lock
 */
NSRecursiveLock *
GSPrivateGlobalLock()
{
  static NSRecursiveLock	*lock = nil;

  if (nil == lock)
    {
      static gs_mutex_t	lockLock = GS_MUTEX_INIT_STATIC;

      GS_MUTEX_LOCK(lockLock);
      if (nil == lock)
	{
	  lock = [GSUntracedRecursiveLock new];
	}
      GS_MUTEX_UNLOCK(lockLock);
    }
  return lock;
}

/*
 * Pthread-like locking primitives using Windows SRWLock. Provides
 * normal, recursive, and error-checked locks.
 */
#if GS_USE_WIN32_THREADS_AND_LOCKS

void
gs_mutex_init(gs_mutex_t *mutex, gs_mutex_attr_t attr)
{
  memset(mutex, 0, sizeof(gs_mutex_t));
  InitializeSRWLock(&mutex->lock);
  mutex->attr = attr;
}

int
gs_mutex_lock(gs_mutex_t *mutex)
{
  DWORD thisThread = GetCurrentThreadId();
  DWORD ownerThread;

  // fast path if lock is not taken
  if (TryAcquireSRWLockExclusive(&mutex->lock))
    {
      assert(mutex->depth == 0);
      mutex->depth = 1;
      gs_atomic_store(&mutex->owner, thisThread);
      return 0;
    }

  // needs to be atomic because another thread can concurrently set it
  ownerThread = gs_atomic_load(&mutex->owner);
  if (ownerThread == thisThread)
    {
      // this thread already owns this lock
      switch (mutex->attr)
        {
          case gs_mutex_attr_normal:
            // deadlock
            assert(mutex->depth == 1);
            AcquireSRWLockExclusive(&mutex->lock);
            assert(false); // not reached
            return 0;
            
          case gs_mutex_attr_errorcheck:
            // return deadlock error
            assert(mutex->depth == 1);
            return EDEADLK;
          
          case gs_mutex_attr_recursive:
            // recursive lock
            mutex->depth++;
            return 0;
        }
  }

  // wait for another thread to release the lock
  AcquireSRWLockExclusive(&mutex->lock);
  assert(mutex->depth == 0);
  mutex->depth = 1;
  gs_atomic_store(&mutex->owner, thisThread);
  return 0;
}

int
gs_mutex_trylock(gs_mutex_t *mutex)
{
  DWORD thisThread = GetCurrentThreadId();
  DWORD ownerThread;

  if (TryAcquireSRWLockExclusive(&mutex->lock))
    {
      assert(mutex->depth == 0);
      mutex->depth = 1;
      gs_atomic_store(&mutex->owner, thisThread);
      return 0;
    }

  // needs to be atomic because another thread can concurrently set it
  ownerThread = gs_atomic_load(&mutex->owner);
  if (ownerThread == thisThread && mutex->attr == gs_mutex_attr_recursive)
    {
      // this thread already owns this lock and it's recursive
      assert(mutex->depth > 0);
      mutex->depth++;
      return 0;
    }

  // lock is taken
  return EBUSY;
}

int
gs_mutex_unlock(gs_mutex_t *mutex)
{
  switch (mutex->attr)
    {
      case gs_mutex_attr_normal:
        break;
      case gs_mutex_attr_errorcheck:
      case gs_mutex_attr_recursive: {
        // return error if lock is not held by this thread
        DWORD thisThread = GetCurrentThreadId();
        DWORD ownerThread = gs_atomic_load(&mutex->owner);
        if (ownerThread != thisThread) {
          return EPERM;
        }
        break;
      }
    }

  if (mutex->attr == gs_mutex_attr_recursive && mutex->depth > 1)
    {
      // recursive lock releasing inner lock
      mutex->depth--;
      return 0;
    }
  else
    {
      assert(mutex->depth == 1);
      mutex->depth = 0;
      gs_atomic_store(&mutex->owner, 0);
      ReleaseSRWLockExclusive(&mutex->lock);
      return 0;
    }
}

// NB: timeout specified in milliseconds relative to now
int
gs_cond_timedwait(gs_cond_t *cond, gs_mutex_t *mutex, DWORD millisecs)
{
  int retVal = 0;

  assert(mutex->depth == 1);
  mutex->depth = 0;
  gs_atomic_store(&mutex->owner, 0);

  if (!SleepConditionVariableSRW(cond, &mutex->lock, millisecs, 0))
    {
      DWORD lastError = GetLastError();
      if (lastError == ERROR_TIMEOUT) {
        retVal = ETIMEDOUT;
      } else {
        retVal = lastError;
      }
    }

  assert(mutex->depth == 0);
  mutex->depth = 1;
  gs_atomic_store(&mutex->owner, GetCurrentThreadId());

  return retVal;
}

inline int
gs_cond_wait(gs_cond_t *cond, gs_mutex_t *mutex)
{
  return gs_cond_timedwait(cond, mutex, INFINITE);
}

#endif /* GS_USE_WIN32_THREADS_AND_LOCKS */

/** </ignore>
 */

