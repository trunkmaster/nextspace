/** Interface for NSOrderedSet, NSMutableOrderedSet for GNUStep
   Copyright (C) 2019 Free Software Foundation, Inc.

   Written by: Gregory John Casamento <greg.casamento@gmail.com>
   Created: May 17 2019

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

#ifndef _NSOrderedSet_h_GNUSTEP_BASE_INCLUDE
#define _NSOrderedSet_h_GNUSTEP_BASE_INCLUDE

#if OS_API_VERSION(MAC_OS_X_VERSION_10_7,GS_API_LATEST)

#import <GNUstepBase/GSVersionMacros.h>
#import <GNUstepBase/GSBlocks.h>

#import <Foundation/NSObject.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSIndexSet.h>
#import <Foundation/NSKeyedArchiver.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class GS_GENERIC_CLASS(NSArray, ElementT);
@class GS_GENERIC_CLASS(NSEnumerator, ElementT);
@class GS_GENERIC_CLASS(NSSet, ElementT);
@class GS_GENERIC_CLASS(NSDictionary, KeyT:id<NSCopying>, ValT);
@class NSString;
@class NSPredicate;

/**
 * This class provides an ordered set, a set where the order of the elements matters and
 * is preserved.  Once created the set cannot be modified.  NSMutableOrderedSet can be
 * modified.
 */
GS_EXPORT_CLASS
@interface GS_GENERIC_CLASS(NSOrderedSet, __covariant ElementT) : NSObject <NSCoding,
  NSCopying,
  NSMutableCopying,
  NSFastEnumeration>

// class methods
/**
 * Create and return an empty ordered set.
 */
+ (instancetype) orderedSet;

/**
 * Create and return an empty ordered set with the provided NSArray instance.
 */
+ (instancetype) orderedSetWithArray: (GS_GENERIC_CLASS(NSArray, ElementT)*)objects;

/**
 * Create and return an empty ordered set with the provided NSArray instance.
 * Use the range to determine which elements to use.  If flag is YES copy the
 * elements.
 */
+ (instancetype) orderedSetWithArray: (GS_GENERIC_CLASS(NSArray, ElementT)*)objects
			       range: (NSRange)range
			   copyItems: (BOOL)flag;

/**
 * Create and return an ordered set with anObject as the sole member.
 */
+ (instancetype) orderedSetWithObject: (GS_GENERIC_TYPE(ElementT))anObject;

/**
 * Create and return an ordered set with list of arguments starting with
 * firstObject and terminated with nil.
 */
+ (instancetype) orderedSetWithObjects: (GS_GENERIC_TYPE(ElementT))firstObject, ...;

/**
 * Create and return an ordered set using the C array of objects with count.
 */
+ (instancetype) orderedSetWithObjects: (const GS_GENERIC_TYPE(ElementT)[])objects
				 count: (NSUInteger) count;

/**
 * Create and return an ordered set with the provided ordered set aSet.
 */
+ (instancetype) orderedSetWithOrderedSet: (GS_GENERIC_CLASS(NSOrderedSet, ElementT)*)aSet;

/**
 * Create and return an ordered set with set aSet.
 */
+ (instancetype) orderedSetWithSet: (GS_GENERIC_CLASS(NSSet, ElementT)*)aSet;

/**
 * Create and return an ordered set with the elements in aSet.  If flag is YES,
 * copy the elements.
 */
+ (instancetype) orderedSetWithSet: (GS_GENERIC_CLASS(NSSet, ElementT)*)aSet
			 copyItems: (BOOL)flag;

// instance methods
/**
 * Initialize and return an empty ordered set with the provided NSArray instance.
 */
- (instancetype) initWithArray: (GS_GENERIC_CLASS(NSArray, ElementT)*)array;

/**
 * Initialize and return an empty ordered set with the provided NSArray instance.
 * If flag is YES copy the elements.
 */
- (instancetype) initWithArray: (GS_GENERIC_CLASS(NSArray, ElementT)*)array copyItems: (BOOL)flag;

/**
 * Initialize and return an empty ordered set with the provided NSArray instance.
 * Use the range to determine which elements to use.  If flag is YES copy the
 * elements.
 */
- (instancetype) initWithArray: (GS_GENERIC_CLASS(NSArray, ElementT)*)array
			 range: (NSRange)range
		     copyItems: (BOOL)flag;

/**
 * Initialize and return an ordered set with anObject as the sole member.
 */
- (instancetype) initWithObject: (id)object;

/**
 * Initialize and return an ordered set with list of arguments starting with
 * firstObject and terminated with nil.
 */
- (instancetype) initWithObjects: (GS_GENERIC_TYPE(ElementT))firstObject, ...;
- (instancetype) initWithObjects: (const GS_GENERIC_TYPE(ElementT)[])objects
			   count: (NSUInteger)count;

/**
 * Initialize and return an ordered set using the C array of objects with count.
 */
- (instancetype) initWithOrderedSet: (GS_GENERIC_CLASS(NSOrderedSet, ElementT)*)aSet;

/**
 * Initialize and return an ordered set with the elements in aSet.  If flag is YES,
 * copy the elements.
 */
- (instancetype) initWithOrderedSet: (GS_GENERIC_CLASS(NSOrderedSet, ElementT)*)aSet
			  copyItems: (BOOL)flag;

/**
 * Initialize and return an empty ordered set with the provided NSArray instance.
 * Use the range to determine which elements to use.  If flag is YES copy the
 * elements.
 */
- (instancetype) initWithOrderedSet: (GS_GENERIC_CLASS(NSOrderedSet, ElementT)*)aSet
			      range: (NSRange)range
			  copyItems: (BOOL)flag;

/**
 * Initialize and return an ordered set with set aSet.
 */
- (instancetype) initWithSet: (GS_GENERIC_CLASS(NSSet, ElementT)*)aSet;

/**
 * Initialize and return an ordered set with set aSet. If flag is YES, then copy the elements.
 */
- (instancetype) initWithSet: (GS_GENERIC_CLASS(NSSet, ElementT)*)aSet copyItems:(BOOL)flag;

/**
 * Initialize an empty ordered set.
 */
- (instancetype) init;

/**
 * Return the number of elements in the receiver.
 */
- (NSUInteger) count;

/**
 * Returns YES if the receiver contains anObject.
 */
- (BOOL)containsObject: (GS_GENERIC_TYPE(ElementT))anObject;

/**
 * Enumerate over the objects whose indexes are contained in indexSet, with the opts provided
 * using aBlock.
 */
- (void) enumerateObjectsAtIndexes: (NSIndexSet *)indexSet
			   options: (NSEnumerationOptions)opts
			usingBlock: (GSEnumeratorBlock)aBlock;

/**
 * Enumerate over all objects in the receiver using aBlock.
 */
- (void) enumerateObjectsUsingBlock: (GSEnumeratorBlock)aBlock;

/**
 * Enumerate over all objects in the receiver with aBlock utilizing the options specified by opts.
 */
- (void) enumerateObjectsWithOptions: (NSEnumerationOptions)opts
			  usingBlock: (GSEnumeratorBlock)aBlock;

/**
 * First object in the receiver.
 */
- (GS_GENERIC_TYPE(ElementT)) firstObject;

/**
 * Last object in the receiver.
 */
- (GS_GENERIC_TYPE(ElementT)) lastObject;

/**
 * Returns the object at index in the receiver.
 */
- (GS_GENERIC_TYPE(ElementT)) objectAtIndex: (NSUInteger)index;

/**
 * Returns the object at index in the receiver.
 */
- (GS_GENERIC_TYPE(ElementT)) objectAtIndexedSubscript: (NSUInteger)index;

/**
 * Returns objects at the indexes specified in the receiver.
 */
- (GS_GENERIC_CLASS(NSArray, ElementT)*) objectsAtIndexes: (NSIndexSet *)indexes;

/**
 * Returns the index of anObject in the receiver.
 */
- (NSUInteger) indexOfObject: (GS_GENERIC_TYPE(ElementT))anObject;

/**
 * Returns the index of object key, contained within range, using options, and the provided comparator.
 */
- (NSUInteger) indexOfObject: (id)key
	       inSortedRange: (NSRange)range
		     options: (NSBinarySearchingOptions)options
	     usingComparator: (NSComparator)comparator;

/**
 * Returns the index of objects at indexSet that pass the test in predicate with enumeration options opts.
 */
- (NSUInteger) indexOfObjectAtIndexes: (NSIndexSet *)indexSet
			      options: (NSEnumerationOptions)opts
			  passingTest: (GSPredicateBlock)predicate;

/**
 * Returns the index of the first object passing test predicate.
 */
- (NSUInteger) indexOfObjectPassingTest: (GSPredicateBlock)predicate;

/**
 * Returns the index of the first object passing test predicate using enumeration options opts.
 */
- (NSUInteger) indexOfObjectWithOptions: (NSEnumerationOptions)opts
			    passingTest: (GSPredicateBlock)predicate;

/**
 * Returns an NSIndexSet containing indexes of object at indexes in indexSet matching predicate
 * with enumeration  options opts.
 */
- (NSIndexSet *) indexesOfObjectsAtIndexes: (NSIndexSet *)indexSet
			      options: (NSEnumerationOptions)opts
			  passingTest: (GSPredicateBlock)predicate;

/**
 * Returns an NSIndexSet containing indexes that match predicate.
 */
- (NSIndexSet *) indexesOfObjectsPassingTest: (GSPredicateBlock)predicate;

/**
 * Returns an NSIndexSet containing indexes that match predicate using opts.
 */
- (NSIndexSet *) indexesOfObjectsWithOptions: (NSEnumerationOptions)opts
			    passingTest: (GSPredicateBlock)predicate;

/**
 * Returns an NSEnumerator to iterate over each object in the receiver.
 */
- (GS_GENERIC_CLASS(NSEnumerator, ElementT)*) objectEnumerator;

/**
 * Returns an NSEnumerator to iterate over each object in the receiver in reverse order.
 */
- (GS_GENERIC_CLASS(NSEnumerator, ElementT)*) reverseObjectEnumerator;

/**
 * Returns an NSOrderedSet that contains the same objects as the receiver, but in reverse order.
 */
- (NSOrderedSet *)reversedOrderedSet;

/**
 * Returns a C array of objects in aBuffer at indexes specified by aRange.
 */
- (void) getObjects: (__unsafe_unretained GS_GENERIC_TYPE(ElementT)[])aBuffer
	      range: (NSRange)aRange;

// Key value coding support

/**
 * Set value for key.
 */
- (void) setValue: (id)value forKey: (NSString*)key;

/**
 * Returns the value for a given key.
 */
- (id) valueForKey: (NSString*)key;

// Comparing Sets

/**
 * Returns YES if the receiver is equal to aSet.
 */
- (BOOL) isEqualToOrderedSet: (NSOrderedSet *)aSet;

// Set operations

/**
 * Returns YES if the receiver intersects with ordered set aSet.
 */
- (BOOL) intersectsOrderedSet: (NSOrderedSet *)aSet;

/**
 * Returns YES if the receiver intersects with set aSet.
 */
- (BOOL) intersectsSet: (NSSet *)aSet;

/**
 * Returns YES if the receiver is a subset of ordered set aSet.
 */
- (BOOL) isSubsetOfOrderedSet: (NSOrderedSet *)aSet;

/**
 * Returns YES if the receiver is a subset of set aSet.
 */
- (BOOL) isSubsetOfSet:(NSSet *)aSet;

// Creating a Sorted Array

/**
 * Returns an NSArray instance containing the elements from the receiver sorted using sortDescriptors.
 */
- (GS_GENERIC_CLASS(NSArray, ElementT) *) sortedArrayUsingDescriptors: (NSArray *)sortDescriptors;

/**
 * Returns an NSArray instance containing the elements from the receiver sorted using comparator.
 */
- (GS_GENERIC_CLASS(NSArray, ElementT) *) sortedArrayUsingComparator:
    (NSComparator)comparator;

/**
 * Returns an NSArray instance containing the elements from the receiver using options, sorted
 * using comparator.
 */
- (GS_GENERIC_CLASS(NSArray, ElementT) *)
    sortedArrayWithOptions: (NSSortOptions)options
	   usingComparator: (NSComparator)comparator;

// Filtering Ordered Sets
/**
 * Returns an NSOrderedSet instance containing elements filtered using predicate.
 */
- (NSOrderedSet *) filteredOrderedSetUsingPredicate: (NSPredicate *)predicate;

// Describing a set

/**
 * Description of this NSOrderedSet.
 */
- (NSString *) description;

/**
 * Localized description of this NSOrderedSet.
 */
- (NSString *) descriptionWithLocale: (NSLocale *)locale;

/**
 * Localized description, indented if flag is YES.
 */
- (NSString *) descriptionWithLocale: (NSLocale *)locale indent: (BOOL)flag;

// Convert to other types
/**
 * Returns an NSArray instance with the objects contained in the receiver.
 */
- (GS_GENERIC_CLASS(NSArray, ElementT) *) array;

/**
 * Returns an NSSet instance with the objects contained in the receiver.
 */
- (GS_GENERIC_CLASS(NSSet, ElementT) *) set;
@end

// Mutable Ordered Set
/**
 * This class provides a mutable ordered set.
 */
GS_EXPORT_CLASS
@interface GS_GENERIC_CLASS(NSMutableOrderedSet, ElementT) : GS_GENERIC_CLASS(NSOrderedSet, ElementT)
// Creating a Mutable Ordered Set

/**
 * Returns an ordered set with capacity.
 */
+ (instancetype) orderedSetWithCapacity: (NSUInteger)capacity;

/**
 * Initializes an ordered set with capacity.
 */
- (instancetype) initWithCapacity: (NSUInteger)capacity;

/**
 * Initializes an empty ordered set.
 */
- (instancetype) init;

/**
 * Adds an object to the receiver.
 */
- (void) addObject: (GS_GENERIC_TYPE(ElementT))anObject;

/**
 * Adds items in the C array whose length is indicated by count to the receiver.
 */
- (void) addObjects: (const GS_GENERIC_TYPE(ElementT)[])objects count: (NSUInteger)count;

/**
 * Adds objects from otherArray to the receiver.
 */
- (void) addObjectsFromArray: (GS_GENERIC_CLASS(NSArray, ElementT)*)otherArray;

/**
 * Inserts object into the receiver at index.
 */
- (void) insertObject: (GS_GENERIC_TYPE(ElementT))object atIndex: (NSUInteger)index;

/**
 * Sets the object at index/
 */
- (void) setObject: (GS_GENERIC_TYPE(ElementT))object atIndexedSubscript: (NSUInteger)index;

/**
 * Inserts objects at indexes from array.  The number of elements in indexes must be the same as the number of
 * elements in array.
 */
- (void) insertObjects: (GS_GENERIC_CLASS(NSArray, ElementT)*)array atIndexes: (NSIndexSet *)indexes;

/**
 * Remove object from receiver.
 */
- (void) removeObject: (GS_GENERIC_TYPE(ElementT))object;

/**
 * Remove object at index.
 */
- (void) removeObjectAtIndex: (NSUInteger)index;

/**
 * Remove objects at indexes.
 */
- (void) removeObjectsAtIndexes: (NSIndexSet *)indexes;

/**
 * Remove objects matching items in otherArray.
 */
- (void) removeObjectsInArray: (GS_GENERIC_CLASS(NSArray, ElementT)*)otherArray;

/**
 * Remove objects at indexes matching range.
 */
- (void) removeObjectsInRange: (NSRange)range;

/**
 * Remove all objects from the set.
 */
- (void) removeAllObjects;

/**
 * Replace the object at index with object.
 */
- (void) replaceObjectAtIndex: (NSUInteger)index
		   withObject: (GS_GENERIC_TYPE(ElementT))object;

/**
 * Replace objects at indexes with objects.  The number of objects must correspond to the number of indexes.
 */
- (void) replaceObjectsAtIndexes: (NSIndexSet *)indexes
		     withObjects: (GS_GENERIC_CLASS(NSArray, ElementT)*)objects;

/**
 * Replace objects in the given range with items from the C array objects.
 */
- (void) replaceObjectsInRange: (NSRange)range
		   withObjects: (const GS_GENERIC_TYPE(ElementT)[])objects
			 count: (NSUInteger)count;

/**
 * Set object at index.
 */
- (void) setObject: (GS_GENERIC_TYPE(ElementT))object atIndex: (NSUInteger)index;

/**
 * Move objects at indexes to index.
 */
- (void) moveObjectsAtIndexes: (NSIndexSet *)indexes toIndex: (NSUInteger)index;

/**
 * Exchange object at index with object at otherIndex.
 */
- (void) exchangeObjectAtIndex: (NSUInteger)index withObjectAtIndex: (NSUInteger)otherIndex;

/**
 * Filter objects using predicate.
 */
- (void) filterUsingPredicate: (NSPredicate *)predicate;

/**
 * Sort using descriptors.
 */
- (void) sortUsingDescriptors: (NSArray *)descriptors;

/**
 * Sort using comparator
 */
- (void) sortUsingComparator: (NSComparator)comparator;

/**
 * Sort with options and comparator.
 */
- (void) sortWithOptions: (NSSortOptions)options
	 usingComparator: (NSComparator)comparator;

/**
 * Sort the given range using options and comparator.
 */
- (void) sortRange: (NSRange)range
	   options: (NSSortOptions)options
   usingComparator: (NSComparator)comparator;

/**
 * This method leaves only objects that interesect with ordered set aSet in the receiver.
 */
- (void) intersectOrderedSet: (GS_GENERIC_CLASS(NSOrderedSet, ElementT)*)aSet;

/**
 * This method leaves only objects that intersect with set aSet in the receiver.
 */
- (void) intersectSet: (GS_GENERIC_CLASS(NSSet, ElementT)*)aSet;

/**
 * Receiver contains itself minus those elements in ordered set aSet.
 */
- (void) minusOrderedSet: (GS_GENERIC_CLASS(NSOrderedSet, ElementT)*)aSet;

/**
 * Receiver contains itself minus those elements in aSet.
 */
- (void) minusSet: (GS_GENERIC_CLASS(NSSet, ElementT)*)aSet;

/**
 * Receiver contains the union of itself and ordered set aSet.
 */
- (void) unionOrderedSet: (GS_GENERIC_CLASS(NSOrderedSet, ElementT)*)aSet;

/**
 * Receiver contains the union of itself and aSet.
 */
- (void) unionSet: (GS_GENERIC_CLASS(NSSet, ElementT)*)aSet;

/**
 * Implementation of NSCopying protocol.
 */
- (instancetype) initWithCoder: (NSCoder *)coder;
@end

#if	defined(__cplusplus)
}
#endif

#endif /* OS_API_VERSION check */

#endif /* _NSOrderedSet_h_GNUSTEP_BASE_INCLUDE */
