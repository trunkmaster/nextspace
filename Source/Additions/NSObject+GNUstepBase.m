/* Implementation of extension methods to base additions

   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.

*/
#import "common.h"
#import "GSPThread.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSException.h"
#import "Foundation/NSHashTable.h"
#import "Foundation/NSLock.h"
#import "GNUstepBase/GSObjCRuntime.h"
#import "GNUstepBase/NSObject+GNUstepBase.h"
#import "GNUstepBase/NSDebug+GNUstepBase.h"
#import "GNUstepBase/NSThread+GNUstepBase.h"

#ifdef HAVE_MALLOC_H
#include	<malloc.h>
#endif

/* This file contains methods which nominally return an id but in fact
 * always rainse an exception and never return.
 * We need to suppress the compiler warning about that.
 */
#pragma GCC diagnostic ignored "-Wreturn-type"

/**
 * Extension methods for the NSObject class
 */
@implementation NSObject (GNUstepBase)

+ (id) notImplemented: (SEL)selector
{
  [NSException raise: NSGenericException
    format: @"method %@ not implemented in %@(class)",
    selector ? (id)NSStringFromSelector(selector) : (id)@"(null)",
    NSStringFromClass(self)];
  while (1) ;   // Does not return
}

- (NSComparisonResult) compare: (id)anObject
{
  NSLog(@"WARNING: The -compare: method for NSObject is deprecated.");

  if (anObject == self)
    {
      return NSOrderedSame;
    }
  if (anObject == nil)
    {
      [NSException raise: NSInvalidArgumentException
		   format: @"nil argument for compare:"];
    }
  if ([self isEqual: anObject])
    {
      return NSOrderedSame;
    }
  /*
   * Ordering objects by their address is pretty useless,
   * so subclasses should override this is some useful way.
   */
  if ((id)self > anObject)
    {
      return NSOrderedDescending;
    }
  else
    {
      return NSOrderedAscending;
    }
}

- (BOOL) isInstance
{
  GSOnceMLog(@"Warning, the -isInstance method is deprecated. "
    @"Use 'class_isMetaClass([self class]) ? NO : YES' instead");
  return class_isMetaClass([self class]) ? NO : YES;
}

- (BOOL) makeImmutable
{
  return NO;
}

- (id) makeImmutableCopyOnFail: (BOOL)force
{
  if (force == YES)
    {
      return AUTORELEASE([self copy]);
    }
  return self;
}

- (id) notImplemented: (SEL)aSel
{
  char	c = (class_isMetaClass(object_getClass(self)) ? '+' : '-');

  [NSException
    raise: NSInvalidArgumentException
    format: @"[%@%c%@] not implemented",
    NSStringFromClass([self class]), c,
    aSel ? (id)NSStringFromSelector(aSel) : (id)@"(null)"];
  while (1) ;   // Does not return
}

- (id) shouldNotImplement: (SEL)aSel
{
  char	c = (class_isMetaClass(object_getClass(self)) ? '+' : '-');

  [NSException
    raise: NSInvalidArgumentException
    format: @"[%@%c%@] should not be implemented",
    NSStringFromClass([self class]), c,
    aSel ? (id)NSStringFromSelector(aSel) : (id)@"(null)"];
  while (1) ;   // Does not return
}

- (id) subclassResponsibility: (SEL)aSel
{
  char	c = (class_isMetaClass(object_getClass(self)) ? '+' : '-');

  [NSException raise: NSInvalidArgumentException
    format: @"[%@%c%@] should be overridden by subclass",
    NSStringFromClass([self class]), c,
    aSel ? (id)NSStringFromSelector(aSel) : (id)@"(null)"];
  while (1) ;   // Does not return
}

@end

#if     defined(GNUSTEP)

@interface NSAutoreleasePool (NSThread)
+ (void) _endThread: (NSThread*)thread;
@end

struct exitLink {
  struct exitLink	*next;
  id			obj;	// Object to release or class for atExit
  SEL			sel;	// Selector for atExit or 0 if releasing
  id			*at;	// Address of static variable or NULL
};

static struct exitLink	*exited = 0;
static gs_mutex_t	exitLock = GS_MUTEX_INIT_STATIC;
static BOOL		enabled = NO;
static BOOL		shouldCleanUp = NO;
static BOOL		isExiting = NO;

struct trackLink {
  struct trackLink	*next;
  id			object;		// Instance or Class being tracked.
  IMP			dealloc;	// Original -dealloc implementation
  IMP			release;	// Original -release implementation
  IMP			retain;		// Original -retain implementation
  BOOL                  global;         // If all instance are tracked.
  BOOL			instance;	// If the object is an instance.
};

static struct trackLink	*tracked = 0;
static gs_mutex_t	trackLock = GS_MUTEX_INIT_STATIC;

static void
handleExit()
{
  BOOL  unknownThread;

  isExiting = YES;
  /* We turn off zombies during exiting so that we don't leak deallocated
   * objects during cleanup.
   */
//  NSZombieEnabled = NO;
  unknownThread = GSRegisterCurrentThread();
  ENTER_POOL

  while (exited != 0)
    {
      struct exitLink	*tmp = exited;

      exited = tmp->next;
      if (0 != tmp->sel)
	{
	  Method	method;
	  IMP		msg;

	  if (shouldCleanUp)
	    {
	      fprintf(stderr, "*** clean-up +[%s %s]\n",
		class_getName(tmp->obj), sel_getName(tmp->sel));
	    }
	  method = class_getClassMethod(tmp->obj, tmp->sel);
	  msg = method_getImplementation(method);
	  if (0 != msg)
	    {
	      (*msg)(tmp->obj, tmp->sel);
	    }
	}
      else if (shouldCleanUp)
	{
	  if (tmp->at)
	    {
	      if (tmp->obj != *(tmp->at))
		{
		  fprintf(stderr,
		    "*** clean-up kept value %p at %p changed to %p\n",
		    tmp->obj, (const void*)tmp->at, *(tmp->at));
	          tmp->obj = *(tmp->at);
		}
	      *(tmp->at) = nil;
	    }
	  fprintf(stderr, "*** clean-up -[%s release] %p %p\n",
	    class_getName(object_getClass(tmp->obj)),
	    tmp->obj, (const void*)tmp->at);
	  [tmp->obj release];
	}
      free(tmp);
    }
  LEAVE_POOL

  if (unknownThread == YES)
    {
      GSUnregisterCurrentThread();
    }
  else
    {
      [[NSAutoreleasePool currentPool] dealloc];
      [NSAutoreleasePool _endThread: GSCurrentThread()];
    }

  /* Exit/clean-up done ... we can get rid of tracking data too.
   */
  if (tracked)
    {
      GS_MUTEX_LOCK(trackLock);
      while (tracked)
	{
	  struct trackLink	*next = tracked->next;

	  if (tracked->instance)
	    {
	      fprintf(stderr, "Tracking ownership -[%p dealloc]"
		" not called by exit.\n", tracked->object);
	    }
	  free(tracked);
	  tracked = next;
	}
      GS_MUTEX_UNLOCK(trackLock);
    }

  isExiting = NO;
}

static inline void
enable()
{
  if (NO == enabled)
    {
      atexit(handleExit);
      enabled = YES;
    }
}

@implementation NSObject(GSCleanUp)

+ (BOOL) isExiting
{
  return isExiting;
}

+ (id) keep: (id)anObject at: (id*)anAddress
{
  struct exitLink	*l;

  if (isExiting)
    {
      if (anAddress)
	{
          [*anAddress release];
          *anAddress = nil;
	}
      return nil;
    }
  NSAssert([anObject isKindOfClass: [NSObject class]],
    NSInvalidArgumentException);
  NSAssert(anAddress != NULL, NSInvalidArgumentException);
  NSAssert(*anAddress == nil, NSInvalidArgumentException);

  GS_MUTEX_LOCK(exitLock);
  for (l = exited; l != NULL; l = l->next)
    {
      if (l->at == anAddress)
	{
	  GS_MUTEX_UNLOCK(exitLock);
	  [NSException raise: NSInvalidArgumentException
		      format: @"Repeated use of leak address %p", anAddress];
	}
      if (anObject != nil && anObject == l->obj)
	{
	  GS_MUTEX_UNLOCK(exitLock);
	  [NSException raise: NSInvalidArgumentException
		      format: @"Repeated use of leak object %p", anObject];
	}
    }
  ASSIGN(*anAddress, anObject);
  l = (struct exitLink*)malloc(sizeof(struct exitLink));
  l->at = anAddress;
  l->obj = anObject;
  l->sel = 0;
  l->next = exited;
  exited = l;
  enable();
  GS_MUTEX_UNLOCK(exitLock);
  return l->obj;
}

+ (id) leakAt: (id*)anAddress
{
  struct exitLink       *l;

  l = (struct exitLink*)malloc(sizeof(struct exitLink));
  l->at = anAddress;
  l->obj = [*anAddress retain];
  l->sel = 0;
  GS_MUTEX_LOCK(exitLock);
  l->next = exited;
  exited = l;
  enable();
  GS_MUTEX_UNLOCK(exitLock);
  return l->obj;
}

+ (id) leak: (id)anObject
{
  struct exitLink	*l;

  if (nil == anObject || isExiting)
    {
      return nil;
    }
  GS_MUTEX_LOCK(exitLock);
  for (l = exited; l != NULL; l = l->next)
    {
      if (l->obj == anObject || (l->at != NULL && *l->at == anObject))
	{
	  GS_MUTEX_UNLOCK(exitLock);
	  [NSException raise: NSInvalidArgumentException
		      format: @"Repeated use of leak object %p", anObject];
	}
    }
  l = (struct exitLink*)malloc(sizeof(struct exitLink));
  l->at = 0;
  l->obj = [anObject retain];
  l->sel = 0;
  l->next = exited;
  exited = l;
  enable();
  GS_MUTEX_UNLOCK(exitLock);
  return l->obj;
}

+ (BOOL) registerAtExit
{
  return [self registerAtExit: @selector(atExit)];
}

+ (BOOL) registerAtExit: (SEL)sel
{
  Method		m;
  Class			s;
  struct exitLink	*l;

  if (0 == sel)
    {
      sel = @selector(atExit);
    }

  m = class_getClassMethod(self, sel);
  if (0 == m)
    {
      return NO;	// method not implemented.
    }

  s = class_getSuperclass(self);
  if (0 != s && class_getClassMethod(s, sel) == m)
    {
      return NO;	// method not implemented in this class
    }

  GS_MUTEX_LOCK(exitLock);
  for (l = exited; l != 0; l = l->next)
    {
      if (l->obj == self)
	{
	  if (sel_isEqual(l->sel, sel))
	    {
	      fprintf(stderr,
		"*** +[%s registerAtExit: %s] already registered for %s.\n",
		class_getName(self), sel_getName(sel), sel_getName(l->sel));
	      GS_MUTEX_UNLOCK(exitLock);
	      return NO;	// Already registered
	    }
	}
    }
  l = (struct exitLink*)malloc(sizeof(struct exitLink));
  l->obj = self;
  l->sel = sel;
  l->at = 0;
  l->next = exited;
  exited = l;
  enable();
  GS_MUTEX_UNLOCK(exitLock);
  return YES;
}

+ (void) setShouldCleanUp: (BOOL)aFlag
{
  if (YES == aFlag)
    {
      if (NO == enabled)
	{
	  GS_MUTEX_LOCK(exitLock);
	  enable();
	  GS_MUTEX_UNLOCK(exitLock);
	}
      shouldCleanUp = YES;
    }
  else
    {
      shouldCleanUp = NO;
    }
}

+ (BOOL) shouldCleanUp
{
  return shouldCleanUp;
}


static inline const char *
stackTrace(unsigned skip)
{
  NSArray       *a = [NSThread callStackSymbols];

  if ([a count] > skip)
    {
      a = [a subarrayWithRange: NSMakeRange(skip, [a count] - skip)];
    }
  return [[a description] UTF8String];
}


static inline struct trackLink *
find(id o)
{
  struct trackLink      *l = tracked;

  while (l)
    {
      if (l->object == o)
	{
	  return l;
	}
      l = l->next;
    }
  return NULL;
}

static inline struct trackLink *
findSuper(Class c)
{
  while ((c = class_getSuperclass(c)) != Nil)
    {
      struct trackLink      *l = find((id)c);

      if (l)
	{
	  return l;
	}
    }
  return NULL;
}

/* Lookup the object in the tracking list.
 * If found as a tracked instance or found as an instance of a class for which
 * all instances are tracked, return YES.  Otherwise return NO (should not log).
 */
static BOOL
findMethods(id o, IMP *dea, IMP *rel, IMP *ret)
{
  struct trackLink	*l;
  Class                 c;

  GS_MUTEX_LOCK(trackLock);
  l = find(o);
  if (l)
    {
      *dea = l->dealloc;
      *rel = l->release;
      *ret = l->retain;
      GS_MUTEX_UNLOCK(trackLock);
      return YES;
    }
  c = object_getClass(o);
  l = find((id)c);
  if (0 == l)
    {
      Class	s = c;

      while (0 == l && (s = class_getSuperclass(s)))
	{
	  l = find((id)s);
	}
    }
  if (l)
    {
      BOOL      all;

      *dea = l->dealloc;
      *rel = l->release;
      *ret = l->retain;
      all = l->global;
      GS_MUTEX_UNLOCK(trackLock);
      return all;
    }
  GS_MUTEX_UNLOCK(trackLock);
  fprintf(stderr, "Tracking ownership - unable to find entry for"
    " instance %p of '%s'.\n", o, class_getName(c));
  fprintf(stderr, "Tracking ownership %p problem at %s.\n",
    o, stackTrace(1));

  /* Should never happen because we don't remove class entries, but I suppose
   * someone could call the replacement methods directly.  The best we can do
   * is return the superclass implementation.
   */
  *dea = [class_getSuperclass(c) instanceMethodForSelector: @selector(dealloc)];
  *rel = [class_getSuperclass(c) instanceMethodForSelector: @selector(release)];
  *ret = [class_getSuperclass(c) instanceMethodForSelector: @selector(retain)];
  return NO;
}

- (void) _replacementDealloc
{
  IMP	dealloc = 0;
  IMP	retain = 0;
  IMP	release = 0;

  if (findMethods(self, &dealloc, &release, &retain) == NO)
    {
      /* Not a tracked instance ... dealloc without logging.
       */
      (*dealloc)(self, _cmd);
    }
  else
    {
      struct trackLink	*l;

      /* If there's a link for tracking this specific instance, remove it.
       */
      GS_MUTEX_LOCK(trackLock);
      if ((l = tracked) != 0)
        {
          if (YES == l->instance && l->object == self)
            {
              tracked = l->next;
              free(l);
            }
          else
            {
              struct trackLink  *n;

              while ((n = l->next) != 0)
                {
                  if (YES == n->instance && n->object == self)
                    {
                      l->next = n->next;
                      free(n);
                      break;
                    }
                  l = n;
                }
            }
        }
      GS_MUTEX_UNLOCK(trackLock);
      fprintf(stderr, "Tracking ownership -[%p dealloc] at %s.\n",
        self, stackTrace(2));
      (*dealloc)(self, _cmd);
    }
}
- (void) _replacementRelease
{
  IMP	dealloc = 0;
  IMP	retain = 0;
  IMP	release = 0;

  if (findMethods(self, &dealloc, &release, &retain) == NO)
    {
      /* Not a tracked instance ... release without logging.
       */
      (*release)(self, _cmd);
    }
  else
    {
      unsigned		rc;

      rc = (unsigned)[self retainCount];
      fprintf(stderr, "Tracking ownership -[%p release] %u->%u at %s.\n",
        self, rc, rc-1, stackTrace(2));
      (*release)(self, _cmd);
    }
}
- (id) _replacementRetain
{
  IMP	dealloc = 0;
  IMP	retain = 0;
  IMP	release = 0;
  id	result;

  if (findMethods(self, &dealloc, &release, &retain) == NO)
    {
      /* Not a tracked instance ... retain without logging.
       */
      result = (*retain)(self, _cmd);
    }
  else
    {
      unsigned		rc;

      rc = (unsigned)[self retainCount];
      result = (*retain)(self, _cmd);
      fprintf(stderr, "Tracking ownership -[%p retain] %u->%u at %s.\n",
        self, rc, (unsigned)[self retainCount], stackTrace(2));
    }
  return result;
}

static struct trackLink*
makeLinkForClass(Class c)
{
  Method 		replacementDealloc;
  Method 		replacementRelease;
  Method 		replacementRetain;
  IMP			idea;
  IMP			irel;
  IMP			iret;
  const char		*tdea;
  const char		*trel;
  const char		*tret;
  struct trackLink      *l;
  struct trackLink      *s = findSuper(c);

  replacementDealloc = class_getInstanceMethod([NSObject class],
    @selector(_replacementDealloc));
  replacementRelease = class_getInstanceMethod([NSObject class],
    @selector(_replacementRelease));
  replacementRetain = class_getInstanceMethod([NSObject class],
    @selector(_replacementRetain));
  idea = method_getImplementation(replacementDealloc);
  irel = method_getImplementation(replacementRelease);
  iret = method_getImplementation(replacementRetain);
  tdea = method_getTypeEncoding(replacementDealloc);
  trel = method_getTypeEncoding(replacementRelease);
  tret = method_getTypeEncoding(replacementRetain);

  l = (struct trackLink*)malloc(sizeof(struct trackLink));
  l->object = c;
  l->instance = NO;
  l->global = NO;

  /* The new methods must be *added* to the specific class unless it already
   * implementes them, in which case we can just change the implementation.
   */
  l->dealloc = class_getMethodImplementation(c, @selector(dealloc));
  if (l->dealloc != idea)
    {
      if (!class_addMethod(c, @selector(dealloc), idea, tdea))
	{
	  method_setImplementation(
	    class_getInstanceMethod(c, @selector(dealloc)), idea);
	}
    }
  else
    {
      l->dealloc = s->dealloc;	// Already overridden in superclass
    }
  l->release = class_getMethodImplementation(c, @selector(release));
  if (l->release != irel)
    {
      if (!class_addMethod(c, @selector(release), irel, trel))
	{
	  method_setImplementation(
	    class_getInstanceMethod(c, @selector(release)), irel);
	}
    }
  else
    {
      l->release = s->release;	// Already overridden in superclass
    }
  l->retain = class_getMethodImplementation(c, @selector(retain));
  if (l->retain != iret)
    {
      if (!class_addMethod(c, @selector(retain), iret, tret))
	{
	  method_setImplementation(
	    class_getInstanceMethod(c, @selector(retain)), iret);
	}
    }
  else
    {
      l->retain = s->retain;	// Already overridden in superclass
    }
/*
  fprintf(stderr, "Tracking ownership add class %p %s %p->%p, %p->%p, %p->%p\n",
    c, class_getName(c), l->dealloc, idea, l->release, irel, l->retain, iret);
*/
  return l;
}

+ (void) trackOwnership
{
  Class			c = self;
  struct trackLink	*l;

  NSAssert(NO == class_isMetaClass(object_getClass(self)),
    NSInternalInconsistencyException);

  GS_MUTEX_LOCK(trackLock);
  if ((l = find((id)c)) != 0)
    {
      /* Class already tracked.  Set it so all instances are logged.
       */
      l->global = YES;
      GS_MUTEX_UNLOCK(trackLock);
      return;
    }

  l = makeLinkForClass(c);
  l->global = YES;
  l->next = tracked;
  tracked = l;
  GS_MUTEX_UNLOCK(trackLock);
  fprintf(stderr, "Tracking ownership started for class %p at %s.\n",
    self, stackTrace(1));
}

- (void) trackOwnership
{
  Class			c = object_getClass(self);
  struct trackLink	*l;
  struct trackLink	*lc;
  struct trackLink	*li;

  NSAssert(NO == class_isMetaClass(c), NSInternalInconsistencyException);

  /* If we are tracking allocation and deallocation, we want to log
   * the existence of tracked instances at exit so we need to have
   * exit handling turned on.
   */
  if (NO == enabled)
    {
      GS_MUTEX_LOCK(exitLock);
      enable();
      GS_MUTEX_UNLOCK(exitLock);
    }

  GS_MUTEX_LOCK(trackLock);
  if ((l = find(self)) != 0)
    {
      /* Instance already tracked.
       */
      GS_MUTEX_UNLOCK(trackLock);
      return;
    }

  if ((l = find(c)) != 0)
    {
      /* The class already has tracking set up.
       */
      if (l->global)
        {
          /* All instances are logged, so we have nothing to do.
           */
          GS_MUTEX_UNLOCK(trackLock);
          return;
        }
      lc = l;
    }
  else
    {
      /* Set this class up for tracking individual instances.
       */
      lc = makeLinkForClass(c);
      lc->global = NO;
      lc->next = tracked;
      tracked = lc;
    }

  /* Now set up a record to track this one instance.
   */
  li = (struct trackLink*)malloc(sizeof(struct trackLink));
  li->object = self;
  li->instance = YES;
  li->global = NO;
  li->dealloc = lc->dealloc;
  li->release = lc->release;
  li->retain = lc->retain;
  li->next = tracked;
  tracked = li;
  GS_MUTEX_UNLOCK(trackLock);
  fprintf(stderr, "Tracking ownership started for instance %p at %s.\n",
    self, stackTrace(1));
}

@end

#else

@implementation NSObject (MemoryFootprint)
+ (NSUInteger) contentSizeOf: (NSObject*)obj
		   excluding: (NSHashTable*)exclude
{
  Class		cls = object_getClass(obj);
  NSUInteger	size = 0;

  while (cls != Nil)
    {
      unsigned	count;
      Ivar	*vars;

      if (0 != (vars = class_copyIvarList(cls, &count)))
	{
	  while (count-- > 0)
	    {
	      const char	*type = ivar_getTypeEncoding(vars[count]);

	      type = GSSkipTypeQualifierAndLayoutInfo(type);
	      if ('@' == *type)
		{
		  NSObject	*content = object_getIvar(obj, vars[count]);
	    
		  if (content != nil)
		    {
		      size += [content sizeInBytesExcluding: exclude];
		    }
		}
	    }
	  free(vars);
	}
      cls = class_getSuperclass(cls);
    }
  return size;
}
+ (NSUInteger) sizeInBytes
{
  return 0;
}
+ (NSUInteger) sizeInBytesExcluding: (NSHashTable*)exclude
{
  return 0;
}
+ (NSUInteger) sizeOfContentExcluding: (NSHashTable*)exclude
{
  return 0;
}
+ (NSUInteger) sizeOfInstance
{
  return 0;
}
- (NSUInteger) sizeInBytes
{
  NSUInteger	bytes;
  NSHashTable	*exclude;
 
  exclude = NSCreateHashTable(NSNonOwnedPointerHashCallBacks, 0);
  bytes = [self sizeInBytesExcluding: exclude];
  NSFreeHashTable(exclude);
  return bytes;
}
- (NSUInteger) sizeInBytesExcluding: (NSHashTable*)exclude
{
  if (0 == NSHashGet(exclude, self))
    {
      NSUInteger        size = [self sizeOfInstance];

      NSHashInsert(exclude, self);
      if (size > 0)
        {
	  size += [self sizeOfContentExcluding: exclude];
        }
      return size;
    }
  return 0;
}
- (NSUInteger) sizeOfContentExcluding: (NSHashTable*)exclude
{
  return 0;
}
- (NSUInteger) sizeOfInstance
{
  NSUInteger    size;

#if     GS_SIZEOF_VOIDP > 4
  NSUInteger	xxx = (NSUInteger)(void*)self;

  if (xxx & 0x07)
    {
      return 0; // Small object has no size
    }
#endif

#if 	HAVE_MALLOC_USABLE_SIZE
  size = malloc_usable_size((void*)self - sizeof(intptr_t));
#else
  size = class_getInstanceSize(object_getClass(self));
#endif

  return size;
}

@end

/* Dummy implementation
 */
@implementation NSObject(GSCleanUp)

+ (id) keep: (id)anObject at: (id*)anAddress
{
  ASSIGN(*anAddress, anObject);
  return *anAddress;
}

+ (id) leakAt: (id*)anAddress
{
  [*anAddress retain];
}

+ (id) leak: (id)anObject
{
  return [anObject retain];
}

+ (BOOL) registerAtExit
{
  return [self registerAtExit: @selector(atExit)];
}

+ (BOOL) registerAtExit: (SEL)sel
{
  return NO;
}

+ (void) setShouldCleanUp: (BOOL)aFlag
{
  return;
}

+ (BOOL) shouldCleanUp
{
  return NO;
}

@end

#endif

