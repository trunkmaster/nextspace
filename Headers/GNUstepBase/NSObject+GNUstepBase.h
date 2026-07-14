/** Declaration of extension methods for base additions

   Copyright (C) 2003-2010 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   and:         Adam Fedor <fedor@gnu.org>

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

#ifndef	INCLUDED_NSObject_GNUstepBase_h
#define	INCLUDED_NSObject_GNUstepBase_h

#import <GNUstepBase/GSVersionMacros.h>
#import <Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif

#if	OS_API_VERSION(GS_API_NONE,GS_API_LATEST)

@class  NSHashTable;

@interface NSObject (GNUstepBase)

/**
  WARNING: The -compare: method for NSObject is deprecated
           due to subclasses declaring the same selector with 
	   conflicting signatures.
           Comparision of arbitrary objects is not just meaningless
           but also dangerous as most concrete implementations
           expect comparable objects as arguments often accessing
	   instance variables directly.
	   This method will be removed in a future release.
*/
- (NSComparisonResult) compare: (id)anObject;

/** For backward compatibility only ... use "class_isMetaClass()" on the
 * class of the receiver instead.
 */
- (BOOL) isInstance;

/** DEPRECATED ... do not use.
 * Transmutes the receiver into an immutable version of the same object
 * and returns the result.<br />
 * If the receiver is not a mutable object or cannot be simply transmuted,
 * then this method either returns the receiver unchanged or,
 * if the force flag is set to YES, returns an autoreleased copy of the
 * receiver.<br />
 * Mutable classes should override this default implementation.<br />
 * This method is used in methods which are declared to return immutable
 * objects (eg. an NSArray), but which create and build mutable ones
 * internally.
 */
- (id) makeImmutableCopyOnFail: (BOOL)force;

/** Transmutes the receiver into an immutable version of the same object.
 * Returns YES if the receiver has become immutable, NO otherwise.<br />
 * The default implementation returns NO.<br />
 * Mutable classes which have an immutable counterpart they can efficiently
 * change into, should override to transmute themselves and return YES.<br />
 * Immutable classes should override this to simply return YES with no
 * further action.<br />
 * This method is used in methods which are declared to return immutable
 * objects (eg. an NSArray), but which create and build mutable ones
 * internally.
 */
- (BOOL) makeImmutable;

/**
 * Message sent when an implementation wants to explicitly exclude a method
 * (but cannot due to compiler constraint), and wants to make sure it is not
 * called by mistake.  Default implementation raises an exception at runtime.
 */
- (id) notImplemented: (SEL)aSel GS_NORETURN_METHOD;

/**
 * Message sent when an implementation wants to explicitly require a subclass
 * to implement a method (but cannot at compile time since there is no
 * <code>abstract</code> keyword in Objective-C).  Default implementation
 * raises an exception at runtime to alert developer that he/she forgot to
 * override a method.
 */
- (id) subclassResponsibility: (SEL)aSel GS_NORETURN_METHOD;

/**
 * Message sent when an implementation wants to explicitly exclude a method
 * (but cannot due to compiler constraint) and forbid that subclasses
 * implement it.  Default implementation raises an exception at runtime.  If a
 * subclass <em>does</em> implement this method, however, the superclass's
 * implementation will not be called, so this is not a perfect mechanism.
 */
- (id) shouldNotImplement: (SEL)aSel GS_NORETURN_METHOD;

@end

/** This is an informal protocol; classes may implement the
 * +contentSizeOf:excluding: method to report how much memory
 * is used by any objects/pointers it acts as a container for.<br />
 * Code may call the -sizeInBytesExcluding: or -sizeInBytes method to
 * determine how much heap memory an object (and its content) occupies.
 */
@interface      NSObject(MemoryFootprint)
/** This method returns the size of the memory used by the object instance
 * variables of the target object (excluding any in the specified set).<br />
 * This is not the memory occupied by instance variable pointers.
 * It is the memory referenced by any objects inside the target.<br />
 * This method is not intended to be overridden, rather it is provided for
 * use as a helper for the -sizeOfContentExcluding: method.<br />
 * This method must not be called for a mutable object unless it is protected
 * by a locking mechanism to prevent mutation while it is examining the 
 * instance variables of the object.
 * <example>
 * @interface	foo : bar
 * {
 *   id	a;		// Some object
 *   id b;		// More storage
 *   unsigned capacity;	// Buffer size
 *   char *p;		// The buffer
 * }
 * @end
 * @implementation foo
 * - (NSUInteger) sizeOfContentExcluding: (NSHashTable*)exclude
 *{ 
 *  NSUInteger	size;
 *
 *  // get the size of the objects (a and b)
 *  size = [NSObject contentSizeOf: self
 *			 excluding: exclude];
 *  // add the memory pointed to by p
 *  size += capacity * sizeof(char);
 *  return size;
 *}
 *@end
 * </example>
 */
+ (NSUInteger) contentSizeOf: (NSObject*)obj
                   excluding: (NSHashTable*)exclude;

/** This method returns the memory usage of the receiver, excluding any
 * objects already present in the exclude table.<br />
 * The argument is a hash table configured to hold non-retained pointer
 * objects and is used to inform the receiver that its size should not
 * be counted again if it's already in the table.<br />
 * The NSObject implementation returns zero if the receiver is in the
 * table, but otherwise adds itself to the table and returns its memory
 * footprint (the sum of all of its instance variables, plus the result
 * of calling -sizeOfContentExcluding: for the instance).<br />
 * Classes should not override this method, instead they should implement
 * -sizeOfContentExcluding: to return the extra memory usage
 * of the pointer/object instance variables (heap memory) they add to
 * their superclass.<br />
 * NB. mutable objects must either prevent mutation while calculating
 * their content size, or must override -sizeOfContentExcluding: to refrain
 * from dealing with content which might change.
 */
- (NSUInteger) sizeInBytesExcluding: (NSHashTable*)exclude;

/** Convenience method calling -sizeInBytesExcluding: with a newly created
 * exclusion hash table, and destroying the table once the size is calculated.
 */
- (NSUInteger) sizeInBytes;

/** This method is called by -sizeInBytesExcluding: to calculate the size of
 * any objects or heap memory contained by the receiver.<br />
 * The base class implementation simply returns zero (as it is not possible
 * to safely calculate content sizes of mutable objects), but subclasses should
 * override it to provide correct information where possible (eg if the object
 * is immutable or if locking is used to prevent mutation while calculating
 * content size).<br />
 * Subclasses may use the +contentSizeOf:excluding: method as a convenience
 * to provide the sizes of object instance variables.
 */
- (NSUInteger) sizeOfContentExcluding: (NSHashTable*)exclude;

/** Helper method called by -sizeInBytesExcluding: to return the size of
 * the instance excluding any contents (things referenced by pointers).
 */
- (NSUInteger) sizeOfInstance;
@end

/** This is an informal protocol ... classes may implement the method and
 * register themselves to have it called on process exit.
 */
@interface NSObject(GSAtExit)
/** This method is called on exit for any class which implements it and which
 * has called +registerAtExit to register it to be called.<br />
 * The order in which methods for different classes is called is the reverse
 * of the order in which the classes were registered, but it's best to assume
 * the method can not depend on any other class being in a usable state
 * at the point when the method is called (rather like +load).<br />
 * Typical use would be to release memory occupied by class data structures
 * so that memory usage analysis software will not think the memory has
 * been leaked.
 */
+ (void) atExit;
@end

/** Category for methods handling leaked memory clean-up on exit of process
 * (for use when debugging memory leaks).<br />
 * You enable this by calling the +setShouldCleanUp: method (done implicitly
 * by gnustep-base if the GNUSTEP_SHOULD_CLEAN_UP environment variable is
 * set to YES).<br />
 * Your class then has two options for performing clean-up when the process
 * ends:
 * <p>1. Use the +keep:at: method to register static/global variables whose
 * contents are to be retained for the lifetime of the program (up to exit)
 * and either ignored or released depending on the clean-up setting in force
 * when the program exits.<br />
 * This mechanism is simple and should be sufficient for many classes.
 * </p>
 * <p>2. Implement an +atExit method to be run when the process ends and,
 * within your +initialize implementation, +registerAtExit to have your
 * +atExit method called when the process exits.  Within the +atExit method
 * you may call +shouldCleanUp to determine whether celan up has been
 * requested.
 * </p>
 * <p>The order in which 'leaked' objects are released and +atExit methods
 * are called on process exist is the reverse of the order in which they
 * werse set up using this API.
 * </p>
 */
@interface NSObject(GSCleanUp)

/** Returns YES if the process is exiting (and perhaps performing clean-up).
 */
+ (BOOL) isExiting;

/** This method stores anObject at anAddress (which should be a static or
 * global variable) and retains it. The code notes that the object should
 * persist until the process exits.  If clean-up is enabled the object will
 *  be released (and the address content zeroed out) upon process exit.
 * If this method is called while the process is already exiting it
 * simply zeros out the memory location then returns nil, otherwise
 * it returns the object stored at the memory location.
 * Raises an exception if anObject is nil or anAddress is NULL or the old
 * value at anAddresss is not nil (unless the process is already exiting).
 */
+ (id) NS_RETURNS_RETAINED keep: (id)anObject at: (id*)anAddress;

/** DEPRECATED ... use +keep:at: instead.
 */
+ (id) NS_RETURNS_RETAINED leak: (id)anObject;

/** DEPRECATED ... use +keep:at: instead.
 */
+ (id) NS_RETURNS_RETAINED leakAt: (id*)anAddress;

/** Sets the receiver to have its +atExit method called at the point when
 * the process terminates.<br />
 * Returns YES on success and NO on failure (if the class does not implement
 * +atExit or if it is already registered to call it).<br />
 * Implemented as a call to +registerAtExit: with the selector for the +atExit
 * method as its argument.
 */
+ (BOOL) registerAtExit;

/** Sets the receiver to have the specified  method called at the point when
 * the process terminates.<br />
 * Returns YES on success and NO on failure (if the class does not implement
 * the method or if it is already registered to call a method at exit).
 */
+ (BOOL) registerAtExit: (SEL)aSelector;

/** Specifies the default clean-up behavior on process exit ... the value
 * returned by the NSObject implementation of the +shouldCleanUp method.<br />
 * Calling this method with a YES argument implicitly enables the support for
 * clean-up at exit.<br />
 * The GNUstep Base library calls this method with the value obtained from
 * the GNUSTEP_SHOULD_CLEAN_UP environment variable when NSObject is
 * initialised.
 */
+ (void) setShouldCleanUp: (BOOL)aFlag;

/** Returns a flag indicating whether the receiver should clean up
 * its data structures etc at process exit.<br />
 * The NSObject implementation returns the value set by the +setShouldCleanUp:
 * method but subclasses may override this.
 */
+ (BOOL) shouldCleanUp;

/** Turns on tracking of the ownership for all instances of the receiver.
 * This could have major performance impact and if possible you should not
 * call this class method but should use the instance method instead.
 * Using this method will will not work for NSObject itself or for classes
 * whose instances are expected to live forever (literal strings, tiny objects
 * etc).
 */
+ (void) trackOwnership;

/** Turns on tracking of ownership for the receiver.<br />
 * This works best in conjunction with leak detection (eg as provided by
 * AddressSanitizer/LeakSanitizer) which reports leaked memory at program
 * exit:  once you know where leaked memory was allocated, you can alter
 * the code to call -trackOwnership on the offending object, and can then
 * see a log of the object life cycle to work out why it is leaked.<br />
 * This operates by altering the class of the receiver by overriding the
 * -retain, -release, and -dealloc methods to report when they are called
 * for the instance.  The logs include the instance address and the stack
 * trace at which the method was called.<br />
 * This method also turns on atexit handing to report tracked instances
 * which have not been deallocated by the time the process exits.
 * All instances of a tracked class (and its subclasses) incur an overhead
 * when the overridden methods are executed, and that overhead scales with
 * the number of tracked instances (and classes) so tracking should be
 * used sparingly (probably never in production code).<br />
 * Using this method will will not work for an instance of the root class
 * or for most objects which are expected to live forever (literal strings,
 * tiny objects etc).
 */
- (void) trackOwnership;

@end

/* Macro to take an autoreleased object and either make it immutable or
 * create an autoreleased copy of the original.
 */
#define GS_IMMUTABLE(O) ([O makeImmutable] == YES ? O : AUTORELEASE([O copy]))

#endif	/* OS_API_VERSION */

#if	defined(__cplusplus)
}
#endif

#endif	/* INCLUDED_NSObject_GNUstepBase_h */

