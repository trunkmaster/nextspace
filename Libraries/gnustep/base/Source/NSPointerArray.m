/**Implementation for NSPointerArray for GNUStep
   Copyright (C) 2009 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date:	2009
   
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
#import	"Foundation/NSPointerArray.h"
#import "GNUstepBase/GSObjCRuntime.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSException.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSKeyedArchiver.h"
#import "GSPrivate.h"
#import "NSConcretePointerFunctions.h"


static Class	abstractClass = Nil;
static Class	concreteClass = Nil;

@interface	NSConcretePointerArray : NSPointerArray
{
  PFInfo	_pf;
  NSUInteger	_count;
  void		**_contents;
  unsigned	_capacity;
  unsigned	_grow_factor;
  unsigned long	_version;
}
@end


@implementation NSPointerArray

+ (id) allocWithZone: (NSZone*)z
{
  if (abstractClass == self)
    {
      return NSAllocateObject(concreteClass, 0, z);
    }
  return [super allocWithZone: z];
}

+ (void) initialize
{
  if (abstractClass == Nil)
    {
      abstractClass = [NSPointerArray class];
      concreteClass = [NSConcretePointerArray class];
    }
}

+ (id) pointerArrayWithOptions: (NSPointerFunctionsOptions)options
{
  return AUTORELEASE([[self alloc] initWithOptions: options]);
}

+ (id) pointerArrayWithPointerFunctions: (NSPointerFunctions *)functions
{
  return AUTORELEASE([[self alloc] initWithPointerFunctions: functions]);
}
+ (id) strongObjectsPointerArray
{
 return [self pointerArrayWithOptions: NSPointerFunctionsObjectPersonality |
     NSPointerFunctionsStrongMemory];
}
+ (id) weakObjectsPointerArray
{
 return [self pointerArrayWithOptions: NSPointerFunctionsObjectPersonality |
     NSPointerFunctionsWeakMemory];
}


- (void) compact
{
  [self subclassResponsibility: _cmd];
}

- (id) copyWithZone: (NSZone*)zone
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (NSUInteger) count
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [self subclassResponsibility: _cmd];
}

- (id) init
{
  return [self initWithOptions: 0];
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (id) initWithOptions: (NSPointerFunctionsOptions)options
{
  NSPointerFunctions	*functions;

  functions = [NSPointerFunctions pointerFunctionsWithOptions: options];
  return [self initWithPointerFunctions: functions];
}

- (id) initWithPointerFunctions: (NSPointerFunctions*)functions
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (BOOL) isEqual: (id)other
{
  NSUInteger	count;

  if (other == self)
    {
      return YES;
    }
  if ([other isKindOfClass: abstractClass] == NO)
    {
      return NO;
    }
  if ([other hash] != [self hash])
    {
      return NO;
    }
  count = [self count];
  while (count-- > 0)
    {
// FIXME
    }
  return YES;
}

- (void) addPointer: (void*)pointer
{
  [self insertPointer: pointer atIndex: [self count]];
}

- (void) insertPointer: (void*)pointer atIndex: (NSUInteger)index
{
  [self subclassResponsibility: _cmd];
}

- (void*) pointerAtIndex: (NSUInteger)index
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (NSPointerFunctions*) pointerFunctions
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (void) removePointerAtIndex: (NSUInteger)index
{
  [self subclassResponsibility: _cmd];
}

- (void) replacePointerAtIndex: (NSUInteger)index withPointer: (void*)item
{
  [self subclassResponsibility: _cmd];
}

- (void) setCount: (NSUInteger)count
{
  [self subclassResponsibility: _cmd];
}

- (NSUInteger) countByEnumeratingWithState: (NSFastEnumerationState*)state
				   objects: (__unsafe_unretained id[])stackbuf
				     count: (NSUInteger)len
{
  NSInteger count;

  state->mutationsPtr = state->mutationsPtr;
  count = MIN(len, [self count] - state->state);
  if (count > 0)
    {
      IMP	imp = [self methodForSelector: @selector(pointerAtIndex:)];
      int	p = state->state;
      int	i;

      for (i = 0; i < count; i++, p++)
	{
	  stackbuf[i] = (*imp)(self, @selector(pointerAtIndex:), p);
	}
      state->state += count;
    }
  else
    {
      count = 0;
    }
  state->itemsPtr = stackbuf;
  return count;
}

@end

@implementation NSPointerArray (NSArrayConveniences)  

+ (id) pointerArrayWithStrongObjects
{               
  GSOnceMLog(@"Garbage Collection no longer supported."
    @"  Using +strongObjectsPointerArray");
  return [self strongObjectsPointerArray];
}  
                
+ (id) pointerArrayWithWeakObjects
{         
  GSOnceMLog(@"Garbage Collection no longer supported."
    @"  Using +weakObjectsPointerArray");
  return [self weakObjectsPointerArray];
}

- (NSArray*) allObjects
{
  [self subclassResponsibility: _cmd];
  return nil;
}

@end

@implementation NSConcretePointerArray

- (void) _raiseRangeExceptionWithIndex: (NSUInteger)index from: (SEL)sel
{
  NSDictionary *info;
  NSException  *exception;
  NSString     *reason;

  info = [NSDictionary dictionaryWithObjectsAndKeys:
    [NSNumber numberWithUnsignedInteger: index], @"Index",
    [NSNumber numberWithUnsignedInteger: _count], @"Count",
    self, @"Array", nil, nil];

  reason = [NSString stringWithFormat:
    @"Index %"PRIuPTR" is out of range %"PRIuPTR" (in '%@')",
    index, _count, NSStringFromSelector(sel)];

  exception = [NSException exceptionWithName: NSRangeException
		                      reason: reason
                                    userInfo: info];
  [exception raise];
}

- (NSArray*) allObjects
{
  NSUInteger	i;
  NSUInteger	c = 0;

  for (i = 0; i < _count; i++)
    {
      if (pointerFunctionsRead(&_pf, &_contents[i]) != 0)
	{
	  c++;
	}
    }

  if (0 == c)
    {
      return [NSArray array];
    }
  else
    {
      GSMutableArray	*a = [GSMutableArray arrayWithCapacity: c];

      for (i = 0; i < _count; i++)
        {
          id obj = pointerFunctionsRead(&_pf, &_contents[i]);
          if (obj != 0)
	    {
	      [a addObject: obj];
	    }
	}
      return GS_IMMUTABLE(a);
    }
}

- (void) compact
{
  NSUInteger	insert = 0;
  NSUInteger	i;

  _version++;

  /* We can't use memmove here for __weak pointers, because that would omit the
   * required read barriers.  We could use objc_memmoveCollectable() for strong
   * pointers, but we may as well use the same code path for everything
   */
  for (i = 0 ; i < _count; i++)
    {
      id obj = pointerFunctionsRead(&_pf, &_contents[i]);

      /* If this object is not nil, but at least one before it has been, then
       * move it back to the correct location.
       */
      if (nil != obj && i != insert)
        {
          pointerFunctionsAssign(&_pf, &_contents[insert++], obj);
        }
    }
  _count = insert;
  _version++;
}

- (id) copyWithZone: (NSZone*)zone
{
  NSConcretePointerArray	*c;
  unsigned			i;
  
  c = (NSConcretePointerArray*)NSCopyObject(self, 0, NSDefaultMallocZone());
  c->_capacity = c->_count;
  c->_grow_factor = c->_capacity/2;
  c->_contents = NSZoneCalloc([self zone], _count, sizeof(id));
  for (i = 0; i < _count; i++)
    {
      NSLog(@"Copying %d, %p", i, _contents[i]);
      pointerFunctionsAssign(&_pf, &c->_contents[i],
        pointerFunctionsAcquire(&_pf,
	  pointerFunctionsRead(&_pf, &_contents[i])));
    }
  return c;
}

- (NSUInteger) count
{
  return _count;
}

- (NSUInteger) countByEnumeratingWithState: (NSFastEnumerationState*)state
				   objects: (__unsafe_unretained id[])stackbuf
				     count: (NSUInteger)len
{
  state->mutationsPtr = &_version;
  return [super countByEnumeratingWithState: state
				    objects: stackbuf
				      count: len];
}

- (void) dealloc
{
  int   i;

  [self finalize];
  /* For weak memory, we must zero all of the elements, or the runtime will
   * keep pointers to them lying around.  For strong memory, we must release
   * things or they will leak.
   */
  for (i = 0; i < _count; i++)
    {
      pointerFunctionsRelinquish(&_pf, &_contents[i]);
    }
  if (_contents != 0)
    {
      NSZoneFree([self zone], _contents);
    }
  [super dealloc];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
/* FIXME ... how can we meaningfully encode the pointer functions???
 */
  [self notImplemented: _cmd];
  if ([aCoder allowsKeyedCoding])
    {
      [super encodeWithCoder: aCoder];
    }
  else
    {
      /* For performace we encode directly ... must exactly match the
       * superclass implemenation. */
      [aCoder encodeValueOfObjCType: @encode(NSUInteger)
				 at: &_count];
      if (_count > 0)
	{
	  [aCoder encodeArrayOfObjCType: @encode(id)
				  count: _count
				     at: _contents];
	}
    }
}

- (NSUInteger) hash
{
  return _count;
}

- (id) initWithCoder: (NSCoder*)aCoder
{
/* FIXME ... how can we meaningfully encode the pointer functions???
 */
  [self notImplemented: _cmd];
  if ([aCoder allowsKeyedCoding])
    {
      self = [super initWithCoder: aCoder];
    }
  else
    {
      /* for performance, we decode directly into memory rather than
       * using the superclass method. Must exactly match superclass. */
      [aCoder decodeValueOfObjCType: @encode(NSUInteger)
				 at: &_count];
      if (_count > 0)
	{
	  _contents = NSZoneCalloc([self zone], _count, sizeof(id));
	  if (_contents == 0)
	    {
	      [NSException raise: NSMallocException
			  format: @"Unable to make array"];
	    }
	  [aCoder decodeArrayOfObjCType: @encode(id)
				  count: _count
				     at: _contents];
	}
    }
  return self;
}

- (id) initWithOptions: (NSPointerFunctionsOptions)options
{
  NSConcretePointerFunctions	*f;

  f = [[NSConcretePointerFunctions alloc] initWithOptions: options];
  self = [self initWithPointerFunctions: f];
  [f release];
  return self;
}

- (id) initWithPointerFunctions: (NSPointerFunctions*)functions
{
  if (![functions isKindOfClass: [NSConcretePointerFunctions class]])
    {
      static NSConcretePointerFunctions	*defaultFunctions = nil;

      if (defaultFunctions == nil)
	{
          defaultFunctions
	    = [[NSConcretePointerFunctions alloc] initWithOptions: 0];
	}
      functions = defaultFunctions;
    }
  memcpy(&_pf, &((NSConcretePointerFunctions*)functions)->_x, sizeof(_pf));
  return self;
}

- (void) insertPointer: (void*)pointer atIndex: (NSUInteger)index
{
  NSUInteger	i;

  if (index > _count)
    {
      [self _raiseRangeExceptionWithIndex: index from: _cmd];
    }
  i = _count;
  [self setCount: _count + 1];
  while (i > index)
    {
      pointerFunctionsMove(&_pf, _contents+i, _contents + i-1);
      i--;
    }
  pointerFunctionsAssign(&_pf, &_contents[index],
    pointerFunctionsAcquire(&_pf, pointer));
}

- (BOOL) isEqual: (id)other
{
  NSUInteger	count;

  if (other == self)
    {
      return YES;
    }
  if ([other isKindOfClass: abstractClass] == NO)
    {
      return NO;
    }
  if ([other hash] != [self hash])
    {
      return NO;
    }
  count = [self count];
  while (count-- > 0)
    {
      if (pointerFunctionsEqual(&_pf,
	pointerFunctionsRead(&_pf, &_contents[count]),
	[other pointerAtIndex: count]) == NO)
	{
	  return NO;
	}
    }
  return YES;
}

- (void*) pointerAtIndex: (NSUInteger)index
{
  if (index >= _count)
    {
      [self _raiseRangeExceptionWithIndex: index from: _cmd];
    }
  return pointerFunctionsRead(&_pf, &_contents[index]);
}

- (NSPointerFunctions*) pointerFunctions
{
  NSConcretePointerFunctions	*pf = [NSConcretePointerFunctions new];

  pf->_x = _pf;
  return [pf autorelease];
}

- (void) removePointerAtIndex: (NSUInteger)index
{
  _version++;
  if (index >= _count)
    {
      [self _raiseRangeExceptionWithIndex: index from: _cmd];
    }
  pointerFunctionsRelinquish(&_pf, &_contents[index]);
  while (++index < _count)
    {
      pointerFunctionsMove(&_pf, &_contents[index-1], &_contents[index]);
    }
  _contents[--_count] = NULL;
  _version++;
}

- (void) replacePointerAtIndex: (NSUInteger)index withPointer: (void*)item
{
  _version++;
  if (index >= _count)
    {
      [self _raiseRangeExceptionWithIndex: index from: _cmd];
    }
  pointerFunctionsReplace(&_pf, &_contents[index], item);
  _version++;
}


#define	ZEROING 0

- (void) setCount: (NSUInteger)count
{
  _version++;
  if (count > _count)
    {
#if ZEROING
      NSUInteger	index = _count;
#endif

      _count = count;
      if (_count >= _capacity)
	{
	  void		**ptr;
	  size_t	size;
	  size_t	new_cap = _capacity;
	  size_t	new_gf = _grow_factor ? _grow_factor : 2;

	  while (new_cap + new_gf < _count)
	    {
	      new_cap += new_gf;
	      new_gf = new_cap/2;
	    }
	  size = (new_cap + new_gf)*sizeof(void*);
	  new_cap += new_gf;
	  new_gf = new_cap / 2;
#if ZEROING
	  /* The objc2 API for zeroing weak references passes the addresses of
	   * pointers, so an implementation could zero the reference when the
	   * associated object is deallocated.  This can potentially cause an
	   * issue if a chunk of memory cntaining a weak reference is returned
	   * to the heap and the runtime zeros part of it after it has been
	   * re-used.  To be safe in that case we must move the weak references
	   * explicitly before returning memry to the heap.
	   */
          ptr = NSZoneMalloc([self zone], size);
	  if (0 == ptr)
	    {
	      [NSException raise: NSMallocException
			  format: @"Unable to grow array"];
	    }
	  memset(ptr, '\0', size);
	  if (_contents)
	    {
	      while (index-- > 0)
		{
		  pointerFunctionsMove(&_pf, ptr + index, _contents + index);
		} 
	      NSZoneFree([self zone], _contents);
	    }
#else
	  /* The gnustep libobjc2 implementation of the weak reference methods
	   * does not zero the memory location until/unless something tries to
	   * load a weakly referenced object from it, so it is safe to simply
           * copy the array.
	   */
	  ptr = NSZoneRealloc([self zone], _contents, size);
	  if (0 == ptr)
	    {
	      [NSException raise: NSMallocException
			  format: @"Unable to grow array"];
	    }
	  memset(ptr + _capacity, '\0',
	    (new_cap - _capacity) * sizeof(void*));
#endif
	  _contents = ptr;
	  _capacity = new_cap;
	  _grow_factor = new_gf;
	}
    }
  else
    {
      while (count < _count)
	{
	  _count--;
	  pointerFunctionsRelinquish(&_pf, &_contents[_count]);
	}
    }
  _version++;
}

@end

