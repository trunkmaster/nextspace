#import <Foundation/Foundation.h>
#import "ObjectTesting.h"
#import "../../../Source/GSFastEnumeration.h"

static SEL	add;
static SEL	set;
static SEL	key;

@implementation NSPointerArray (TestHelpers)
- (void) addObject: (id)anObject
{
  [self addPointer: anObject];
}
- (void) removeObject: (id)anObject
{
  int	i = [self count];

  while (i-- > 0)
    {
      if ([self pointerAtIndex: i] == (void*)anObject)
	{
	  [self removePointerAtIndex: i];
	}
    }
}
@end

void fast_enumeration_mutation_add(id mutableCollection)
{
  NSUInteger	i = 0;
  NSUInteger	c = [mutableCollection count]/2;

  FOR_IN(id, o, mutableCollection)
  if (i == c)
    {
      if ([mutableCollection respondsToSelector: set])
	{
	  [mutableCollection setObject: @"boom" forKey: @"boom"];
	}
      else
	{
	  [mutableCollection addObject: @"boom"];
	}
    }
  i++;
  END_FOR_IN(mutableCollection)
}

void fast_enumeration_mutation_remove(id mutableCollection)
{
  NSUInteger 	i = 0;
  NSUInteger	c = [mutableCollection count]/2;

  FOR_IN(id, o, mutableCollection)
  if (i == c)
    {
      if ([mutableCollection respondsToSelector: key])
        {
	  [mutableCollection removeObjectForKey: o];
	}
      else
	{
	  [mutableCollection removeObject: o];
	}
    }
  i++;
  END_FOR_IN(mutableCollection)
}

void test_fast_enumeration(id collection, NSArray *objects)
{
  NSMutableArray *returnedObjects = [NSMutableArray array];

  FOR_IN(id, o, collection)
  [returnedObjects addObject: o];
  END_FOR_IN(collection)
  if (!([collection isKindOfClass: [NSArray class]]
    || [collection isKindOfClass: [NSOrderedSet class]]))
    {
      [returnedObjects sortUsingSelector: @selector(compare:)];
    }
  PASS_EQUAL(returnedObjects, objects, "fast enumeration returns all objects")

  id mutableCollection;
  if ([collection respondsToSelector: @selector(mutableCopyWithZone:)])
    {
      mutableCollection = AUTORELEASE([collection mutableCopy]);
    }
  else if ([collection respondsToSelector: add]
    || [collection respondsToSelector: set])
    {
      mutableCollection = collection;	// It has a method to mutate it
    }
  else
    {
      return;				// No mutable version
    }
  PASS_EXCEPTION(
    fast_enumeration_mutation_add(mutableCollection),
    NSGenericException,
    "Fast enumeration mutation add properly calls @\"NSGenericException\"")
  PASS_EXCEPTION(
    fast_enumeration_mutation_remove(mutableCollection),
    NSGenericException,
    "Fast enumeration mutation remove properly calls @\"NSGenericException\"")
}

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSMutableArray 	*objects = [NSMutableArray array];
  int 			i;

  add = @selector(addObject:);
  set = @selector(setObject:forKey:);
  key = @selector(removeObjectForKey:);

  for (i = 0; i < 1000; i++)
    {
      [objects addObject: [NSString stringWithFormat: @"%.4d", i]];
    }
  
  START_SET("NSArray")
  id array = [NSArray arrayWithArray: objects];
  test_fast_enumeration(array, objects);
  END_SET("NSArray")
  
  START_SET("NSSet")
  id set = [NSSet setWithArray: objects];
  test_fast_enumeration(set, objects);
  END_SET("NSSet")
  
  START_SET("NSOrderedSet")
  id orderedSet = [NSOrderedSet orderedSetWithArray: objects];
  test_fast_enumeration(orderedSet, objects);
  END_SET("NSOrderedSet")
  
  START_SET("NSDictionary")
  id dict = [NSDictionary dictionaryWithObjects: objects forKeys: objects];
  test_fast_enumeration(dict, objects);
  END_SET("NSDictionary")
  
  START_SET("NSMapTable")
  id map = [NSMapTable strongToStrongObjectsMapTable];
  FOR_IN(id, o, objects)
  [map setObject: o forKey: o];
  END_FOR_IN(objects)
  test_fast_enumeration(map, objects);
  END_SET("NSMapTable")
  
  START_SET("NSHashTable")
  id table = [NSHashTable weakObjectsHashTable];
  FOR_IN(id, o, objects)
  [table addObject: o];
  END_FOR_IN(objects)
  test_fast_enumeration(table, objects);
  END_SET("NSHashTable")
  
  START_SET("NSPointerArray")
  id array = [NSPointerArray weakObjectsPointerArray];
  FOR_IN(id, o, objects)
  [array addPointer: o];
  END_FOR_IN(objects)
  test_fast_enumeration(array, objects);
  END_SET("NSPointerArray")
  
  [arp release]; arp = nil;
  return 0;
}
