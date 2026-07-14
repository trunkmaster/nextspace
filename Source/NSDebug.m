/** Debugging utilities for GNUStep and OpenStep
   Copyright (C) 1997,1999,2000,2001 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: August 1997
   Extended by: Nicola Pero <n.pero@mi.flashnet.it>
   Date: December 2000, April 2001

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

   <title>NSDebug utilities reference</title>
   $Date$ $Revision$
   */

#import "common.h"
#include <stdio.h>
#import "GSPrivate.h"
#import "GSPThread.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSData.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSException.h"
#import "Foundation/NSLock.h"
#import "Foundation/NSNotification.h"
#import "Foundation/NSNotificationQueue.h"
#import "Foundation/NSThread.h"
#import "Foundation/NSValue.h"

#import "GSSorting.h"

#if     HAVE_EXECINFO_H
#include        <execinfo.h>
#endif

#ifdef HAVE_MALLOC_H
#include        <malloc.h>
#endif

typedef struct {
  Class		class;
  /* The following are used for statistical info */
  uint32_t	count;
  uint32_t	lastc;
  uint32_t	totalc;
  uint32_t   	peak;
  uint64_t	bytes;
  uint64_t	totalb;
  uint64_t	lastb;
  uint32_t	nominal_size;
  /* The following are used to record actual objects */
  BOOL  	is_recording;
  NSObject      *(*trace_function)(id);
  id    	*recorded_objects;
  id    	*recorded_tags;
  uint32_t   	num_recorded_objects;
  uint32_t   	stack_size;
} table_entry;

typedef struct {
  const char    *name;
  int           count;
  long		bytes;
} list_entry;

static NSInteger itemComp(id v0, id v1, void *ctxt)
{
  int i = strcmp(((list_entry*)v0)->name, ((list_entry *)v1)->name);
  if (i < 0) return NSOrderedAscending;
  if (i > 0) return NSOrderedDescending;
  return NSOrderedSame;
}

static	unsigned int	num_classes = 0;
static	unsigned int	table_size = 0;

static table_entry*	the_table = 0;

static BOOL	debug_allocation = NO;
static BOOL	debug_byte_size = NO;
BOOL NSDebugEnabled = NO;

static gs_mutex_t	uniqueLock;

static void     _GSDebugAllocationFetch(list_entry *items, BOOL difference);
static void     _GSDebugAllocationFetchAll(list_entry *items);

static void _GSDebugAllocationAdd(Class c, id o);
static void _GSDebugAllocationRemove(Class c, id o);

static void (*_GSDebugAllocationAddFunc)(Class c, id o)
  = _GSDebugAllocationAdd;
static void (*_GSDebugAllocationRemoveFunc)(Class c, id o)
  = _GSDebugAllocationRemove;

static NSObject*
_GSDebugAllocationTrace(id object)
{
  NSArray       *a = [NSThread callStackSymbols];
  NSUInteger    c = [a count];

  /* Remove uninteresting frames incide the allocation debug system
   */
  if (c > 3)
    {
      NSRange   r = NSMakeRange(3, c - 3);

      a = [a subarrayWithRange: r];
    }
  return [a description];
}

#define doLock() GS_MUTEX_LOCK(uniqueLock)
#define unLock() GS_MUTEX_UNLOCK(uniqueLock)

@interface GSDebugAlloc : NSObject
+ (void) initialize;
@end

@implementation GSDebugAlloc
+ (void) initialize
{
  GS_MUTEX_INIT_RECURSIVE(uniqueLock);
}
@end

void
GSSetDebugAllocationFunctions(void (*newAddObjectFunc)(Class c, id o),
  void (*newRemoveObjectFunc)(Class c, id o))
{
  doLock();

  if (newAddObjectFunc && newRemoveObjectFunc)
    {	   	
      _GSDebugAllocationAddFunc = newAddObjectFunc;
      _GSDebugAllocationRemoveFunc = newRemoveObjectFunc;
    }
  else
    {
      // Back to default
      _GSDebugAllocationAddFunc = _GSDebugAllocationAdd;
      _GSDebugAllocationRemoveFunc = _GSDebugAllocationRemove;
    }

  unLock();
}

BOOL
GSDebugAllocationActive(BOOL active)
{
  BOOL	old = debug_allocation;

  [GSDebugAlloc class];		/* Ensure thread support is working */
  debug_allocation = active ? YES : NO;
  return old;
}

BOOL
GSDebugAllocationBytes(BOOL active)
{
  BOOL	old = debug_byte_size;

  debug_byte_size = active ? YES : NO;
  return old;
}

BOOL
GSDebugAllocationRecordAndTrace(Class c, BOOL record,
  GSDebugAllocationTraceFunction traceFunction)
{
  BOOL wasRecording = NO;
  unsigned int i;

  if (record)
    {
      GSDebugAllocationActive(YES);
    }

  if (traceFunction == (NSObject *(*)(id))1)
    {
      traceFunction = _GSDebugAllocationTrace;
    }

  for (i = 0; i < num_classes; i++)
    {
      if (the_table[i].class == c)
	{
	  doLock();
          wasRecording = (YES == the_table[i].is_recording) ? YES : NO;
          if (record)
            {
              the_table[i].is_recording = YES;
              the_table[i].trace_function = traceFunction;
            }
          else if (wasRecording)
            {
              while (the_table[i].num_recorded_objects > 0)
                {
                  int   j = the_table[i].num_recorded_objects - 1;
                  id    o = the_table[i].recorded_objects[j];
                  id    t = the_table[i].recorded_tags[j];

                  the_table[i].recorded_objects[j] = nil;
                  the_table[i].recorded_tags[j] = nil;
                  the_table[i].num_recorded_objects = j;
                  RELEASE(o);
                  RELEASE(t);
                }
            }
	  unLock();
	  return wasRecording;
	}
    }
  if (record)
    {
      doLock();
      if (num_classes >= table_size)
        {
          int		more = table_size + 128;
          table_entry	*tmp;

          tmp = NSZoneMalloc(NSDefaultMallocZone(), more * sizeof(table_entry));

          if (tmp == 0)
            {
              unLock();
              return NO;
            }
          if (the_table)
            {
              memcpy(tmp, the_table, num_classes * sizeof(table_entry));
              NSZoneFree(NSDefaultMallocZone(), the_table);
            }
          the_table = tmp;
          table_size = more;
        }
      the_table[num_classes].class = c;
      the_table[num_classes].count = 0;
      the_table[num_classes].lastc = 0;
      the_table[num_classes].totalc = 0;
      the_table[num_classes].peak = 0;
      the_table[num_classes].bytes = 0;
      the_table[num_classes].lastb = 0;
      the_table[num_classes].totalb = 0;
      the_table[num_classes].nominal_size = class_getInstanceSize(c);
      the_table[num_classes].is_recording = YES;
      the_table[num_classes].trace_function = traceFunction;
      the_table[num_classes].recorded_objects = NULL;
      the_table[num_classes].recorded_tags = NULL;
      the_table[num_classes].num_recorded_objects = 0;
      the_table[num_classes].stack_size = 0;
      num_classes++;
      unLock();
    }
  return wasRecording;
}

BOOL
GSDebugAllocationRecordObjects(Class c, BOOL newState)
{
  return GSDebugAllocationRecordAndTrace(c, newState, NULL);
}

void
GSDebugAllocationActiveRecordingObjects(Class c)
{
  GSDebugAllocationRecordObjects(c, YES);
}

void
GSDebugAllocationAdd(Class c, id o)
{
  (*_GSDebugAllocationAddFunc)(c,o);
}

void
_GSDebugAllocationAdd(Class c, id o)
{
  if (debug_allocation)
    {
      unsigned int	i;
      unsigned		bytes;

      doLock();
      for (i = 0; i < num_classes; i++)
	{
	  if (the_table[i].class == c)
	    {
	      NSObject	*tag = nil;
	      BOOL	shouldRecord;

	      the_table[i].count++;
	      the_table[i].totalc++;
	      if (YES == debug_byte_size)
		{
		  bytes = [o sizeOfInstance];
		}
	      else
		{
		  bytes = the_table[i].nominal_size;
		}
	      the_table[i].bytes += bytes;
	      the_table[i].totalb += bytes;
	      if (the_table[i].count > the_table[i].peak)
		{
		  the_table[i].peak = the_table[i].count;
		}
	      shouldRecord = the_table[i].is_recording;
	      if (shouldRecord)
		{
		  NSObject  *(*trace)(id);

                  if ((trace = the_table[i].trace_function) != NULL)
		    {
                      /* Tracing means adding a stack trace as the tag of
                       * each recorded objct ... we don't want to have any
                       * recursion while doing that so we temporarily turn
                       * recording off.
                       */ 
                      the_table[i].is_recording = NO;
		      unLock();
		      ENTER_POOL
		      tag = RETAIN((*trace)(o));
		      LEAVE_POOL
		      doLock();
		      for (i = 0; i < num_classes; i++)
			{
			  if (the_table[i].class == c)
			    {
			      the_table[i].is_recording = YES;
			      break;
			    }
			}
		      if (i >= num_classes)
			{
			  DESTROY(tag);		// Can't record it
			}
		      if (nil == tag)
			{
			  shouldRecord = NO;	// Don't want to record
			}
		    }
		}
	      if (shouldRecord)
		{
		  if (the_table[i].num_recorded_objects
		    >= the_table[i].stack_size)
		    {
		      int	more = the_table[i].stack_size + 128;
		      id	*tmp;
		      id	*tmp1;

		      tmp = NSZoneMalloc(NSDefaultMallocZone(),
					 more * sizeof(id));
		      if (tmp == 0)
			{
			  unLock();
			  return;
			}

		      tmp1 = NSZoneMalloc(NSDefaultMallocZone(),
					 more * sizeof(id));
		      if (tmp1 == 0)
			{
			  NSZoneFree(NSDefaultMallocZone(),  tmp);
			  unLock();
			  return;
			}

		      if (the_table[i].recorded_objects != NULL)
			{
			  memcpy(tmp, the_table[i].recorded_objects,
				 the_table[i].num_recorded_objects
				 * sizeof(id));
			  NSZoneFree(NSDefaultMallocZone(),
				     the_table[i].recorded_objects);
			  memcpy(tmp1, the_table[i].recorded_tags,
				 the_table[i].num_recorded_objects
				 * sizeof(id));
			  NSZoneFree(NSDefaultMallocZone(),
				     the_table[i].recorded_tags);
			}
		      the_table[i].recorded_objects = tmp;
		      the_table[i].recorded_tags = tmp1;
		      the_table[i].stack_size = more;
		    }
		
		  (the_table[i].recorded_objects)
		    [the_table[i].num_recorded_objects] = o;
                  (the_table[i].recorded_tags)
                    [the_table[i].num_recorded_objects] = tag;
		  the_table[i].num_recorded_objects++;
		}
	      unLock();
	      return;
	    }
	}

      if (num_classes >= table_size)
	{
	  unsigned int	more = table_size + 128;
	  table_entry	*tmp;
	
	  tmp = NSZoneMalloc(NSDefaultMallocZone(), more * sizeof(table_entry));
	
	  if (tmp == 0)
	    {
	      unLock();
	      return;		/* Argh	*/
	    }
	  if (the_table)
	    {
	      memcpy(tmp, the_table, num_classes * sizeof(table_entry));
	      NSZoneFree(NSDefaultMallocZone(), the_table);
	    }
	  the_table = tmp;
	  table_size = more;
	}
      the_table[num_classes].class = c;
      the_table[num_classes].count = 1;
      the_table[num_classes].nominal_size = class_getInstanceSize(c);
      if (YES == debug_byte_size)
	{
	  bytes = [o sizeOfInstance];
	}
      else
	{
	  bytes = the_table[num_classes].nominal_size;
	}
      the_table[num_classes].bytes = bytes;
      the_table[num_classes].totalb = bytes;
      the_table[num_classes].lastb = 0;
      the_table[num_classes].lastc = 0;
      the_table[num_classes].totalc = 1;
      the_table[num_classes].peak = 1;
      the_table[num_classes].is_recording = NO;
      the_table[num_classes].trace_function = NULL;
      the_table[num_classes].recorded_objects = NULL;
      the_table[num_classes].recorded_tags = NULL;
      the_table[num_classes].num_recorded_objects = 0;
      the_table[num_classes].stack_size = 0;
      num_classes++;
      unLock();
    }
}

int
GSDebugAllocationCount(Class c)
{
  unsigned int	i;

  for (i = 0; i < num_classes; i++)
    {
      if (the_table[i].class == c)
	{
	  return the_table[i].count;
	}
    }
  return 0;
}

int
GSDebugAllocationTotal(Class c)
{
  unsigned int	i;

  for (i = 0; i < num_classes; i++)
    {
      if (the_table[i].class == c)
	{
	  return the_table[i].totalc;
	}
    }
  return 0;
}

int
GSDebugAllocationPeak(Class c)
{
  unsigned int	i;

  for (i = 0; i < num_classes; i++)
    {
      if (the_table[i].class == c)
	{
	  return the_table[i].peak;
	}
    }
  return 0;
}

Class *
GSDebugAllocationClassList()
{
  Class *ans;
  size_t siz;
  unsigned int	i;

  doLock();

  siz = sizeof(Class) * (num_classes + 1);
  ans = NSZoneMalloc(NSDefaultMallocZone(), siz);

  for (i = 0; i < num_classes; i++)
    {
      ans[i] = the_table[i].class;
    }
  ans[num_classes] = NULL;

  unLock();

  return ans;
}

const char*
GSDebugAllocationList(BOOL changeFlag)
{
  list_entry    *items;
  unsigned      size;

  if (debug_allocation == NO)
    {
      return "Debug allocation system is not active!\n";
    }

  doLock();
  size = num_classes;
  if (size > 0)
    {
      items = malloc(sizeof(list_entry) * size);
      _GSDebugAllocationFetch(items, changeFlag);
    }
  else
    {
      items = 0;
    }
  unLock();

  while (size > 0 && 0 == items[size - 1].name)
    {
      size--;
    }
  if (0 == size)
    {
      if (items != 0)
        {
          free(items);
        }
      if (changeFlag)
        {
          return "There are NO newly allocated or deallocated object!\n";
        }
      else
        {
          return "I can find NO allocated object!\n";
        }
    }
  else
    {
      NSMutableString   *result;
      id                order[size];
      unsigned          index;

      for (index = 0; index < size; index++)
        {
          order[index] = (id)&items[index];
        }
      GSSortUnstable(order, NSMakeRange(0,size), (id)itemComp,
        GSComparisonTypeFunction, 0);

      result = [NSMutableString stringWithCapacity: 1000];
      for (index = 0; index < size; index++)
        {
          list_entry    *item = (list_entry*)order[index];

	  if (YES == debug_byte_size)
	    {
	      [result appendFormat: @"%d\t%-32s\t%ld\n",
		item->count, item->name, item->bytes];
	    }
	  else
	    {
	      [result appendFormat: @"%d\t%s\n", item->count, item->name];
	    }
        }
      free(items);
      return [result UTF8String];
    }
}

const char*
GSDebugAllocationListAll()
{
  list_entry    *items;
  unsigned      size;

  if (debug_allocation == NO)
    {
      return "Debug allocation system is not active!\n";
    }

  doLock();
  size = num_classes;
  if (size > 0)
    {
      items = malloc(sizeof(list_entry) * size);
      _GSDebugAllocationFetchAll(items);
    }
  else
    {
      items = 0;
    }
  unLock();

  if (0 == items)
    {
      return "I can find NO allocated object!\n";
    }
  else
    {
      NSMutableString   *result;
      id                order[size];
      unsigned          index;

      for (index = 0; index < size; index++)
        {
          order[index] = (id)&items[index];
        }
      GSSortUnstable(order, NSMakeRange(0,size), (id)itemComp,
        GSComparisonTypeFunction, 0);

      result = [NSMutableString stringWithCapacity: 1000];
      for (index = 0; index < size; index++)
        {
          list_entry    *item = (list_entry*)order[index];

	  if (YES == debug_byte_size)
	    {
	      [result appendFormat: @"%d\t%-32s\t%ld\n",
		item->count, item->name, item->bytes];
	    }
	  else
	    {
	      [result appendFormat: @"%d\t%s\n", item->count, item->name];
	    }
        }
      free(items);
      return [result UTF8String];
    }
}

static void
_GSDebugAllocationFetch(list_entry *items, BOOL difference)
{
  unsigned      i;
  unsigned      pos;

  for (i = pos = 0; i < num_classes; i++)
    {
      int	count = the_table[i].count;
      long	bytes = the_table[i].bytes;

      if (difference)
	{
	  count -= the_table[i].lastc;
	  bytes -= the_table[i].lastb;
          the_table[i].lastc = the_table[i].count;
          the_table[i].lastb = the_table[i].bytes;
	}
      if (count || (bytes && debug_byte_size))
        {
          items[pos].name = class_getName(the_table[i].class);
          items[pos].count = count;
          items[pos].bytes = bytes;
          pos++;
        }
    }
  while (pos < num_classes)
    {
      items[pos].name = 0;
      items[pos].count = 0;
      items[pos].bytes = 0;
      pos++;
    }
}

static void
_GSDebugAllocationFetchAll(list_entry *items)
{
  unsigned      i;

  for (i = 0; i < num_classes; i++)
    {
      items[i].name = class_getName(the_table[i].class);
      items[i].count = the_table[i].totalc;
      items[i].bytes = the_table[i].totalb;
    }
}

void
GSDebugAllocationRemove(Class c, id o)
{
  (*_GSDebugAllocationRemoveFunc)(c,o);
}

void
_GSDebugAllocationRemove(Class c, id o)
{
  if (debug_allocation)
    {
      unsigned int	i;

      doLock();
      for (i = 0; i < num_classes; i++)
	{
	  if (the_table[i].class == c)
	    {
	      id	tag = nil;
	      unsigned	bytes;

	      if (YES == debug_byte_size)
		{
		  bytes = [o sizeOfInstance];
		}
	      else
		{
		  bytes = the_table[i].nominal_size;
		}
	      the_table[i].count--;
	      the_table[i].bytes -= bytes;
	      if (the_table[i].num_recorded_objects > 0)
		{
		  unsigned j, n;

		  /* Most objects have a brief lifespan.  It therefore
		   * makes sense to search from the end of the array back
		   * to the start to maximise the chance of finding an
		   * object quickly.
		   */
                  j = n = the_table[i].num_recorded_objects;
		  while (j-- > 0)
		    {
		      if ((the_table[i].recorded_objects)[j] == o)
			{
			  tag = (the_table[i].recorded_tags)[j];
			  while (++j < n)
			    {
			      (the_table[i].recorded_objects)[j - 1] =
				(the_table[i].recorded_objects)[j];
			      (the_table[i].recorded_tags)[j - 1] =
				(the_table[i].recorded_tags)[j];
			    }
			  the_table[i].num_recorded_objects--;
			  break;
			}
		    }
		}
	      unLock();
	      [tag release];
	      return;
	    }
	}
      unLock();
    }
}

id
GSDebugAllocationTagRecordedObject(id object, id tag)
{
  Class c = [object class];
  id	o = nil;
  int	i;
  int	j;

  if (debug_allocation == NO)
    {
      return nil;
    }
  doLock();

  for (i = 0; i < num_classes; i++)
    {
      if (the_table[i].class == c)
        {
	  break;
	}
    }

  if (i == num_classes
    || the_table[i].is_recording == NO
    || the_table[i].num_recorded_objects == 0)
    {
      unLock();
      return nil;
    }

  for (j = 0; j < the_table[i].num_recorded_objects; j++)
    {
      if (the_table[i].recorded_objects[j] == object)
	{
	  o = the_table[i].recorded_tags[j];
	  the_table[i].recorded_tags[j] = RETAIN(tag);
	  break;
	}
    }

  unLock();
  return AUTORELEASE(o);
}

NSArray *
GSDebugAllocationListRecordedObjects(Class c)
{
  NSArray *answer;
  unsigned int i, k, n;
  id *tmp;

  if (debug_allocation == NO)
    {
      return nil;
    }

  doLock();

  for (i = 0; i < num_classes; i++)
    {
      if (the_table[i].class == c)
	{
	  break;
	}
    }

  if (i == num_classes)
    {
      unLock();
      return nil;
    }

  if (the_table[i].is_recording == NO)
    {
      unLock();
      return nil;
    }

  if ((n = the_table[i].num_recorded_objects) == 0)
    {
      unLock();
      return [NSArray array];
    }

  tmp = NSZoneMalloc(NSDefaultMallocZone(), n * sizeof(id));
  if (tmp == 0)
    {
      unLock();
      return nil;
    }

  /* First, we copy the objects into a temporary buffer */
  memcpy(tmp, the_table[i].recorded_objects, n * sizeof(id));

  /* Retain all the objects - NB: if retaining one of the objects as a
   * side effect releases another one of them , we are broken ... */
  for (k = 0; k < n; k++)
    {
      [tmp[k] retain];
    }

  /* Then, we bravely unlock the lock */
  unLock();

  /* Only then we create an array with them - this is now safe as we
   * have copied the objects out, unlocked, and retained them. */
  answer = [NSArray arrayWithObjects: tmp count: n];

  /* Now we release all the objects to balance the retain */
  for (k = 0; k < n; k++)
    {
      [tmp[k] release];
    }

  /* And free the space used by them */
  NSZoneFree(NSDefaultMallocZone(), tmp);

  return answer;
}


NSMapTable *
GSDebugAllocationTaggedObjects(Class c)
{
  NSMapTable *answer;
  unsigned int i, j, n, t;

  if (debug_allocation == NO)
    {
      return nil;
    }

  /* Create the map table outside the locked region to minimise time
   * locked and to avoid deadlock.
   */
  answer = [NSMapTable strongToStrongObjectsMapTable];

  doLock();

  for (i = 0; i < num_classes; i++)
    {
      if (the_table[i].class == c)
	{
	  break;
	}
    }

  if (i == num_classes)
    {
      unLock();
      return nil;
    }

  if (the_table[i].is_recording == NO)
    {
      unLock();
      return nil;
    }

  if ((n = the_table[i].num_recorded_objects) == 0)
    {
      unLock();
      return nil;
    }

  for (j = t = 0; j < n; j++)
    {
      if (the_table[i].recorded_tags[j])
        {
          t++;
        }
    }
  if (0 == t)
    {
      unLock();
      return nil;
    }

  for (j = 0; j < n; j++)
    {
      if (the_table[i].recorded_tags[j])
        {
          [answer setObject: the_table[i].recorded_tags[j]
                     forKey: the_table[i].recorded_objects[j]];
        }
    }
  
  unLock();

  return answer;
}

const char *
_NSPrintForDebugger(id object)
{
  if (object && [object respondsToSelector: @selector(description)])
    return [[object description] UTF8String];

  return NULL;
}

NSString *
_NSNewStringFromCString(const char *cstring)
{
  NSString      *string;

  string = [NSString stringWithCString: cstring
			      encoding: [NSString defaultCStringEncoding]];
  if (nil == string)
    {
      string = [NSString stringWithUTF8String: cstring];
      if (nil == string)
        {
          string = [NSString stringWithCString: cstring
                                      encoding: NSISOLatin1StringEncoding];
        }
    }
  return string;
}

