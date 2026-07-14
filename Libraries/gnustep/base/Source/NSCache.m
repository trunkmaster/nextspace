/** Implementation for NSCache for GNUStep
   Copyright (C) 2009 Free Software Foundation, Inc.

   Written by:  David Chisnall <csdavec@swan.ac.uk>
   Created: 2009

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

#import "common.h"

#define	EXPOSE_NSCache_IVARS	1

#import "Foundation/NSArray.h"
#import "Foundation/NSCache.h"
#import "Foundation/NSMapTable.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSLock.h"

/**
 * _GSCachedObject is effectively used as a structure containing the various
 * things that need to be associated with objects stored in an NSCache.  It is
 * an NSObject subclass so that it can be used with OpenStep collection
 * classes.
 */
@interface _GSCachedObject : NSObject
{
  @public
  id object;
  NSString *key;
  int accessCount;
  NSUInteger cost;
  BOOL isEvictable;
}
@end

@interface NSCache (EvictionPolicy)
/** The method controlling eviction policy in an NSCache. */
- (void) _evictObjectsToMakeSpaceForObjectWithCost: (NSUInteger)cost;
@end

@implementation NSCache
- (id) init
{
  if (nil == (self = [super init]))
    {
      return nil;
    }
  ASSIGN(_objects, [NSMapTable strongToStrongObjectsMapTable]);
  _accesses = [NSMutableArray new];
  _lock = [NSRecursiveLock new];
  return self;
}

- (NSUInteger) countLimit
{
  return _countLimit;
}

- (id) delegate
{
  return _delegate;
}

- (BOOL) evictsObjectsWithDiscardedContent
{
  return _evictsObjectsWithDiscardedContent;
}

- (NSString*) name
{
  NSString	*n;

  [_lock lock];
  n = RETAIN(_name);
  [_lock unlock];
  return AUTORELEASE(n);
}

- (id) objectForKey: (id)key
{
  _GSCachedObject	*obj;
  id			value;

  [_lock lock];
  obj = [_objects objectForKey: key];
  if (nil == obj)
    {
      [_lock unlock];
      return nil;
    }
  if (obj->isEvictable)
    {
      // Move the object to the end of the access list.
      [_accesses removeObjectIdenticalTo: obj];
      [_accesses addObject: obj];
    }
  obj->accessCount++;
  _totalAccesses++;
  value = RETAIN(obj->object);
  [_lock unlock];
  return AUTORELEASE(value);
}

- (void) removeAllObjects
{
  NSEnumerator		*e;
  _GSCachedObject	*obj;

  [_lock lock];
  e = [_objects objectEnumerator];
  while (nil != (obj = [e nextObject]))
    {
      [_delegate cache: self willEvictObject: obj->object];
    }
  [_objects removeAllObjects];
  [_accesses removeAllObjects];
  _totalAccesses = 0;
  [_lock unlock];
}

- (void) removeObjectForKey: (id)key
{
  _GSCachedObject	*obj;

  [_lock lock];
  obj = [_objects objectForKey: key];
  if (nil != obj)
    {
      [_delegate cache: self willEvictObject: obj->object];
      _totalAccesses -= obj->accessCount;
      [_objects removeObjectForKey: key];
      [_accesses removeObjectIdenticalTo: obj];
    }
  [_lock unlock];
}

- (void) setCountLimit: (NSUInteger)lim
{
  _countLimit = lim;
}

- (void) setDelegate:(id)del
{
  _delegate = del;
}

- (void) setEvictsObjectsWithDiscardedContent:(BOOL)b
{
  _evictsObjectsWithDiscardedContent = b;
}

- (void) setName: (NSString*)cacheName
{
  [_lock lock];
  ASSIGN(_name, cacheName);
  [_lock unlock];
}

- (void) setObject: (id)obj forKey: (id)key cost: (NSUInteger)num
{
  _GSCachedObject *oldObject;
  _GSCachedObject *newObject;

  [_lock lock];
  oldObject = [_objects objectForKey: key];
  if (nil != oldObject)
    {
      [self removeObjectForKey: oldObject->key];
    }
  [self _evictObjectsToMakeSpaceForObjectWithCost: num];
  newObject = [_GSCachedObject new];
  // Retained here, released when obj is dealloc'd
  newObject->object = RETAIN(obj);
  newObject->key = RETAIN(key);
  newObject->cost = num;
  if ([obj conformsToProtocol: @protocol(NSDiscardableContent)])
    {
      newObject->isEvictable = YES;
      [_accesses addObject: newObject];
    }
  [_objects setObject: newObject forKey: key];
  RELEASE(newObject);
  _totalCost += num;
  [_lock unlock];
}

- (void) setObject: (id)obj forKey: (id)key
{
  [self setObject: obj forKey: key cost: 0];
}

- (void) setTotalCostLimit: (NSUInteger)lim
{
  _costLimit = lim;
}

- (NSUInteger) totalCostLimit
{
  return _costLimit;
}

/**
 * This method is the one that handles the eviction policy.  This
 * implementation uses a relatively simple LRU/LFU hybrid.  The NSCache
 * documentation from Apple makes it clear that the policy may change, so we
 * could in future have a class cluster with pluggable policies for different
 * caches or some other mechanism.
 */
- (void) _evictObjectsToMakeSpaceForObjectWithCost: (NSUInteger)cost
{
  NSUInteger spaceNeeded = 0;
  NSUInteger count;

  [_lock lock];
  count = [_objects count];
  if (_costLimit > 0 && _totalCost + cost > _costLimit)
    {
      spaceNeeded = _totalCost + cost - _costLimit;
    }

  // Only evict if we need the space.
  if (count > 0 && (spaceNeeded > 0 || count >= _countLimit))
    {
      NSMutableArray *evictedKeys = nil;
      // Round up slightly.
      NSUInteger averageAccesses = ((_totalAccesses / (double)count) * 0.2) + 1;
      NSEnumerator *e = [_accesses objectEnumerator];
      _GSCachedObject *obj;

      if (_evictsObjectsWithDiscardedContent)
	{
	  evictedKeys = [[NSMutableArray alloc] init];
	}
      while (nil != (obj = [e nextObject]))
	{
	  // Don't evict frequently accessed objects.
	  if (obj->accessCount < averageAccesses && obj->isEvictable)
	    {
	      [obj->object discardContentIfPossible];
	      if ([obj->object isContentDiscarded])
		{
		  NSUInteger cost = obj->cost;

		  // Evicted objects have no cost.
		  obj->cost = 0;
		  // Don't try evicting this again in future; it's gone already.
		  obj->isEvictable = NO;
		  // Remove this object as well as its contents if required
		  if (_evictsObjectsWithDiscardedContent)
		    {
		      [evictedKeys addObject: obj->key];
		    }
		  _totalCost -= cost;
		  // If we've freed enough space, give up
		  if (cost > spaceNeeded)
		    {
		      break;
		    }
		  spaceNeeded -= cost;
		}
	    }
	}
      // Evict all of the objects whose content we have discarded if required
      if (_evictsObjectsWithDiscardedContent)
	{
	  NSString *key;

	  e = [evictedKeys objectEnumerator];
	  while (nil != (key = [e nextObject]))
	    {
	      [self removeObjectForKey: key];
	    }
	}
      RELEASE(evictedKeys);
    }
  [_lock unlock];
}

- (void) dealloc
{
  RELEASE(_lock);
  RELEASE(_name);
  RELEASE(_objects);
  RELEASE(_accesses);
  DEALLOC
}
@end

@implementation _GSCachedObject
- (void) dealloc
{
  RELEASE(object);
  RELEASE(key);
  DEALLOC
}
@end
