/* Mutable array proxies for GNUstep's KeyValueCoding
   Copyright (C) 2007 Free Software Foundation, Inc.

   Written by:  Chris Farber <chris@chrisfarber.net>

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

   $Date: 2007-06-08 04: 04: 14 -0400 (Fri, 08 Jun 2007) $ $Revision: 25230 $
   */

#import "common.h"
#import "Foundation/NSInvocation.h"
#import "Foundation/NSIndexSet.h"
#import "Foundation/NSKeyValueObserving.h"

@interface NSKeyValueMutableArray : NSMutableArray
{
  @protected
  id		object;
  NSString 	*key;
  NSMutableArray *array;
  BOOL otherChangeInProgress;
  BOOL notifiesObservers;
}

+ (NSKeyValueMutableArray *) arrayForKey: (NSString*)aKey
				ofObject: (id)anObject;
- (id) initWithKey: (NSString *)aKey ofObject: (id)anObject;

@end

@interface NSKeyValueFastMutableArray : NSKeyValueMutableArray 
{
  @private
  NSInvocation *insertObjectInvocation;
  NSInvocation *removeObjectInvocation;
  NSInvocation *replaceObjectInvocation;
}

+ (id) arrayForKey: (NSString *)aKey ofObject: (id)anObject
withCapitalizedKey: (const char *)capitalized;

- (id) initWithKey: (NSString *)aKey ofObject: (id)anObject
withCapitalizedKey: (const char *)capitalized;

@end

@interface NSKeyValueSlowMutableArray : NSKeyValueMutableArray
{
  @private
  NSInvocation *setArrayInvocation;
}

+ (id) arrayForKey: (NSString *)aKey ofObject: (id)anObject
withCapitalizedKey: (const char *)capitalized;

- (id) initWithKey: (NSString *)aKey ofObject: (id)anObject
withCapitalizedKey: (const char *)capitalized;

@end

@interface NSKeyValueIvarMutableArray : NSKeyValueMutableArray
{
  @private
}

+ (id) arrayForKey: (NSString *)aKey ofObject: (id)anObject;

- (id) initWithKey: (NSString *)aKey ofObject: (id)anObject;

@end


/* NB. For removal of objects we can remove multiple objects at the same
 * time and the notifications are sent with an NSIndexSet specifying the
 * indices which are being altered.  We therefore funnuel all the other
 * removal methods through the -removeObjectsAtIndexes: method so that
 * the subclasses only need to implement that one themselves.
 */
@implementation NSKeyValueMutableArray

+ (NSKeyValueMutableArray *) arrayForKey: (NSString *)aKey
                                ofObject: (id)anObject
{
  NSKeyValueMutableArray *proxy;
  unsigned size = [aKey maximumLengthOfBytesUsingEncoding: 
			  NSUTF8StringEncoding];
  char keybuf[size + 1];

  [aKey getCString: keybuf
         maxLength: size + 1
          encoding: NSUTF8StringEncoding];
  if (islower(*keybuf))
    {
      *keybuf = toupper(*keybuf);
    }

  proxy = [NSKeyValueFastMutableArray arrayForKey: aKey 
				         ofObject: anObject
			       withCapitalizedKey: keybuf];
  if (proxy == nil)
    {
      proxy = [NSKeyValueSlowMutableArray arrayForKey: aKey 
  					     ofObject: anObject
				   withCapitalizedKey: keybuf];

      if (proxy == nil)
	{
	  proxy = [NSKeyValueIvarMutableArray arrayForKey: aKey 
					         ofObject: anObject];
	}
    }
  return proxy;
}

- (id) initWithKey: (NSString *)aKey ofObject: (id)anObject
{
  if ((self = [super init]) != nil)
    {
      object = anObject;
      key = [aKey copy];
      otherChangeInProgress = NO;
      notifiesObservers
	= [[anObject class] automaticallyNotifiesObserversForKey: aKey];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(key);
  DEALLOC
}

- (NSUInteger) count
{
  if (array == nil)
    {
      array = [object valueForKey: key];
    }
  return [array count];
}

- (id) objectAtIndex: (NSUInteger)index
{
  if (array == nil)
    {
      array = [object valueForKey: key];
    }
  return [array objectAtIndex: index];
}

- (void) addObject: (id)anObject
{
  [self insertObject: anObject  atIndex: [self count]];
}

- (void) removeFirstObject
{
  NSUInteger count = [self count];

  if (0 == count)
    {
      return;
    }
  [self removeObjectAtIndex: 0];
}

- (void) removeLastObject
{
  NSUInteger count = [self count];

  if (0 == count)
    {
      return;
    }
  [self removeObjectAtIndex: (count - 1)];
}

- (void) removeObject: (id)anObject
{
  NSUInteger count = [self count];

  if (count > 0)
    {
      NSMutableIndexSet	*indexes = nil;

      while (count-- > 0)
	{
	  if ([[self objectAtIndex: count] isEqual: anObject])
	    {
	      if (nil == indexes)
		{
		  indexes = [NSMutableIndexSet indexSet];
		}
	      [indexes addIndex: count];
	    }
	}
      if (indexes)
	{
	  [self removeObjectsAtIndexes: indexes];
	}
    }  
}

- (void) removeObjectAtIndex: (NSUInteger)index
{
  if (index != NSNotFound)
    {
      [self removeObjectsAtIndexes: [NSIndexSet indexSetWithIndex: index]];
    }
}

- (void) removeObjectsFromIndices: (NSUInteger*)indices
                       numIndices: (NSUInteger)count
{
  if (count > 0)
    {
      NSMutableIndexSet	*indexes = nil;

      while (count-- > 0)
	{
	  if (indices[count] != NSNotFound)
	    {
	      if (nil == indexes)
		{
	          indexes = [NSMutableIndexSet indexSet];
		}
	      [indexes addIndex: indices[count]];
	    }
	}
      if (indexes)
	{
          [self removeObjectsAtIndexes: indexes];
	}
    }
}

@end

@implementation NSKeyValueFastMutableArray

+ (id) arrayForKey: (NSString *)aKey ofObject: (id)anObject
withCapitalizedKey: (const char *)capitalized
{
  return [[[self alloc] initWithKey: aKey ofObject: anObject
                 withCapitalizedKey: capitalized] autorelease];
}

- (id) initWithKey: (NSString *)aKey ofObject: (id)anObject
withCapitalizedKey: (const char *)capitalized
{
  SEL insert;
  SEL remove;
  SEL replace;

  insert = NSSelectorFromString
    ([NSString stringWithFormat: @"insertObject:in%sAtIndex:", capitalized]);
  remove = NSSelectorFromString
    ([NSString stringWithFormat: @"removeObjectFrom%sAtIndex:", capitalized]);
  if (!([anObject respondsToSelector: insert]
    && [anObject respondsToSelector: remove]))
    {
      DESTROY(self);
      return nil;
    }
  replace = NSSelectorFromString
    ([NSString stringWithFormat: @"replaceObjectIn%sAtIndex:withObject:",
    capitalized]);

  if ((self = [super initWithKey: aKey ofObject: anObject]) != nil)
    {
      insertObjectInvocation = [[NSInvocation invocationWithMethodSignature: 
        [anObject methodSignatureForSelector: insert]] retain];
      [insertObjectInvocation setTarget: anObject];
      [insertObjectInvocation setSelector: insert];
      removeObjectInvocation = [[NSInvocation invocationWithMethodSignature: 
        [anObject methodSignatureForSelector: remove]] retain];
      [removeObjectInvocation setTarget: anObject];
      [removeObjectInvocation setSelector: remove];
      if ([anObject respondsToSelector: replace])
        {
          replaceObjectInvocation
            = [[NSInvocation invocationWithMethodSignature: 
            [anObject methodSignatureForSelector: replace]] retain];
          [replaceObjectInvocation setTarget: anObject];
          [replaceObjectInvocation setSelector: replace];
        }
    }
  return self;
}

- (void) dealloc
{
  [insertObjectInvocation release];
  [removeObjectInvocation release];
  [replaceObjectInvocation release];
  [super dealloc];
}

- (void) removeObjectsAtIndexes: (NSIndexSet*)indexes
{
  NSUInteger	index = [indexes lastIndex];

  if (nil == indexes || NSNotFound == index)
    {
      return;
    }

  if (notifiesObservers && !otherChangeInProgress)
    {
      [object willChange: NSKeyValueChangeRemoval
         valuesAtIndexes: indexes
                  forKey: key];
    }
  [removeObjectInvocation setArgument: &index atIndex: 2];
  [removeObjectInvocation invoke];
  while ((index = [indexes indexLessThanIndex: index]) != NSNotFound)
    {
      [removeObjectInvocation setArgument: &index atIndex: 2];
      [removeObjectInvocation invoke];
    }
  if (notifiesObservers && !otherChangeInProgress)
    {
      [object didChange: NSKeyValueChangeRemoval
        valuesAtIndexes: indexes
                 forKey: key];
    }
}

- (void) insertObject: (id)anObject atIndex: (NSUInteger)index
{
  NSIndexSet *indexes = nil;

  if (notifiesObservers && !otherChangeInProgress)
    {
      indexes = [NSIndexSet indexSetWithIndex: index];
      [object willChange: NSKeyValueChangeInsertion
	 valuesAtIndexes: indexes
		  forKey: key];
    }
  [insertObjectInvocation setArgument: &anObject atIndex: 2];
  [insertObjectInvocation setArgument: &index atIndex: 3];
  [insertObjectInvocation invoke];
  if (notifiesObservers && !otherChangeInProgress)
    {
      [object didChange: NSKeyValueChangeInsertion
        valuesAtIndexes: indexes
                 forKey: key];
    }
}

- (void) replaceObjectAtIndex: (NSUInteger)index withObject: (id)anObject
{
  NSIndexSet *indexes = nil;

  if (notifiesObservers && !otherChangeInProgress)
    {
      otherChangeInProgress = YES;
      indexes = [NSIndexSet indexSetWithIndex: index];
      [object willChange: NSKeyValueChangeReplacement
         valuesAtIndexes: indexes
                  forKey: key];
    }
  if (replaceObjectInvocation)
    {
      [replaceObjectInvocation setArgument: &index atIndex: 2];
      [replaceObjectInvocation setArgument: &anObject atIndex: 3];
      [replaceObjectInvocation invoke];
    }
  else
    {
      [self removeObjectAtIndex: index];
      [self insertObject: anObject atIndex: index];
    }
  if (notifiesObservers && !otherChangeInProgress)
    {
      [object didChange: NSKeyValueChangeReplacement
	valuesAtIndexes: indexes
                 forKey: key];
      otherChangeInProgress = NO;
    }
}

@end

@implementation NSKeyValueSlowMutableArray

+ (id) arrayForKey: (NSString *)aKey ofObject: (id)anObject
withCapitalizedKey: (const char *)capitalized
{
  return [[[self alloc] initWithKey: aKey ofObject: anObject
                 withCapitalizedKey: capitalized] autorelease];
}

- (id) initWithKey: (NSString *)aKey
	  ofObject: (id)anObject
withCapitalizedKey: (const char *)capitalized
{
  SEL set = NSSelectorFromString([NSString stringWithFormat: 
    @"set%s:", capitalized]);

  if (![anObject respondsToSelector: set])
    {
      DESTROY(self);
      return nil;
    }

  if ((self = [super initWithKey: aKey ofObject: anObject]) != nil)
    {
      setArrayInvocation = [[NSInvocation invocationWithMethodSignature: 
        [anObject methodSignatureForSelector: set]] retain];
      [setArrayInvocation setSelector: set];
      [setArrayInvocation setTarget: anObject];
   }
  return self;
}

- (void) dealloc
{
  RELEASE(setArrayInvocation);
  DEALLOC
}

- (void) removeObjectsAtIndexes: (NSIndexSet*)indexes
{
  NSUInteger		index = [indexes lastIndex];
  NSMutableArray 	*temp;

  if (nil == indexes || NSNotFound == index)
    {
      return;
    }

  if (notifiesObservers && !otherChangeInProgress)
    {
      [object willChange: NSKeyValueChangeRemoval
         valuesAtIndexes: indexes
                  forKey: key];
    }
  
  temp = [NSMutableArray arrayWithArray: [object valueForKey: key]];
  [temp removeObjectAtIndex: index];
  while ((index = [indexes indexLessThanIndex: index]) != NSNotFound)
    {
      [temp removeObjectAtIndex: index];
    }

  [setArrayInvocation setArgument: &temp atIndex: 2];
  [setArrayInvocation invoke];

  if (notifiesObservers && !otherChangeInProgress)
    {
      [object didChange: NSKeyValueChangeRemoval
        valuesAtIndexes: indexes
                 forKey: key];
    }
}

- (void) insertObject: (id)anObject atIndex: (NSUInteger)index
{
  NSIndexSet	*indexes = nil;
  NSMutableArray *temp;

  if (notifiesObservers && !otherChangeInProgress)
    {
      indexes = [NSIndexSet indexSetWithIndex: index];
      [object willChange: NSKeyValueChangeInsertion
         valuesAtIndexes: indexes
                  forKey: key];
    }

  temp = [NSMutableArray arrayWithArray: [object valueForKey: key]];
  [temp insertObject: anObject atIndex: index];
  
  [setArrayInvocation setArgument: &temp atIndex: 2];
  [setArrayInvocation invoke];

  if (notifiesObservers && !otherChangeInProgress)
    {
      [object didChange: NSKeyValueChangeInsertion
        valuesAtIndexes: indexes
                 forKey: key];
    }
}

- (void) replaceObjectAtIndex: (NSUInteger)index withObject: (id)anObject
{
  NSIndexSet *indexes = nil;
  NSMutableArray *temp;

  if (notifiesObservers && !otherChangeInProgress)
    {
      indexes = [NSIndexSet indexSetWithIndex: index];
      [object willChange: NSKeyValueChangeReplacement
         valuesAtIndexes: indexes
                  forKey: key];
    }
  
  temp = [NSMutableArray arrayWithArray: [object valueForKey: key]];
  [temp removeObjectAtIndex: index];
  [temp insertObject: anObject atIndex: index];

  [setArrayInvocation setArgument: &temp atIndex: 2];
  [setArrayInvocation invoke];

  if (notifiesObservers && !otherChangeInProgress)
    {
      [object didChange: NSKeyValueChangeReplacement
        valuesAtIndexes: indexes
                 forKey: key];
    }
}

@end


@implementation NSKeyValueIvarMutableArray

+ (id) arrayForKey: (NSString *)aKey ofObject: (id)anObject
{
  return [[[self alloc] initWithKey: aKey ofObject: anObject] autorelease];
}

- (id) initWithKey: (NSString *)aKey ofObject: (id)anObject
{
  if ((self = [super initWithKey: aKey  ofObject: anObject]) != nil)
    {
      unsigned size = [aKey maximumLengthOfBytesUsingEncoding:
        NSUTF8StringEncoding];
      char cKey[size + 2];
      char *cKeyPtr = &cKey[0];
      const char *type = 0;
      BOOL found = NO;
      int offset;
      
      cKey[0] = '_';
      [aKey getCString: cKeyPtr + 1
             maxLength: size + 1
              encoding: NSUTF8StringEncoding];
      
      if (!GSObjCFindVariable(anObject, cKeyPtr, &type, &size, &offset))
        found = GSObjCFindVariable(anObject, ++cKeyPtr, &type, &size, &offset);
      if (found)
        {
          array = GSObjCGetVal(anObject, cKeyPtr, NULL, type, size, offset);
        }
      else
        {
          array = [object valueForKey: key];
        }
    }

  return self;
}

- (void) addObject: (id)anObject
{
  NSIndexSet *indexes = nil;

  if (notifiesObservers)
    {
      indexes = [NSIndexSet indexSetWithIndex: [array count]];
      [object willChange: NSKeyValueChangeInsertion
         valuesAtIndexes: indexes
                  forKey: key];
    }
  [array addObject: anObject];
  if (notifiesObservers)
    {
      [object didChange: NSKeyValueChangeInsertion
        valuesAtIndexes: indexes
                 forKey: key];
    }
}

- (void) removeObjectsAtIndexes: (NSIndexSet*)indexes
{
  NSUInteger	index = [indexes lastIndex];

  if (nil == indexes || NSNotFound == index)
    {
      return;
    }

  if (notifiesObservers)
    {
      indexes = [NSIndexSet indexSetWithIndex: index];
      [object willChange: NSKeyValueChangeRemoval
         valuesAtIndexes: indexes
                  forKey: key];
    }
  [array removeObjectAtIndex: index];
  while ((index = [indexes indexLessThanIndex: index]) != NSNotFound)
    {
      [array removeObjectAtIndex: index];
    }
  if (notifiesObservers)
    {
      [object didChange: NSKeyValueChangeRemoval
        valuesAtIndexes: indexes
                 forKey: key];
    }
}

- (void) insertObject: (id)anObject atIndex: (NSUInteger)index
{
  NSIndexSet *indexes = nil;

  if (notifiesObservers)
    {
      indexes = [NSIndexSet indexSetWithIndex: index];
      [object willChange: NSKeyValueChangeInsertion
         valuesAtIndexes: indexes
                  forKey: key];
    }
  [array insertObject: anObject atIndex: index];
  if (notifiesObservers)
    {
      [object didChange: NSKeyValueChangeInsertion
        valuesAtIndexes: indexes
                 forKey: key];
    }
}

- (void) removeLastObject
{
  NSIndexSet *indexes =  nil;
  NSUInteger count = [array count];

  if (0 == count)
    {
      return;
    }

  if (notifiesObservers)
    {
      indexes = [NSIndexSet indexSetWithIndex: count - 1];
      [object willChange: NSKeyValueChangeRemoval
         valuesAtIndexes: indexes
                  forKey: key];
    }
  [array removeObjectAtIndex: [indexes firstIndex]];
  if (notifiesObservers)
    {
      [object didChange: NSKeyValueChangeRemoval
        valuesAtIndexes: indexes
                 forKey: key];
    }
}

- (void) replaceObjectAtIndex: (NSUInteger)index withObject: (id)anObject
{
  NSIndexSet *indexes = nil;

  if (notifiesObservers)
    {
      indexes = [NSIndexSet indexSetWithIndex: index];
      [object willChange: NSKeyValueChangeReplacement
         valuesAtIndexes: indexes
                  forKey: key];
    }
  [array replaceObjectAtIndex: index withObject: anObject];
  if (notifiesObservers)
    {
      [object didChange: NSKeyValueChangeReplacement
        valuesAtIndexes: indexes
                 forKey: key];
    }
}


@end
