/** Implementation for NSDate for GNUStep
   Copyright (C) 2024 Free Software Foundation, Inc.

   Written by:  Jeremy Bettis <jeremy@hksys.com>
   Rewritten by:  Scott Christley <scottc@net-community.com>
   Modifications by: Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Small Object Optimization by: Hugo Melder <hugo@algoriddim.com>
   Date: September 2024

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

   <title>NSDate class reference</title>
   $Date$ $Revision$
   */

#import "common.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSCalendarDate.h"
#import "Foundation/NSCharacterSet.h"
#import "Foundation/NSCoder.h"
#import "Foundation/NSDate.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSException.h"
#import "Foundation/NSPortCoder.h"
#import "Foundation/NSScanner.h"
#import "Foundation/NSTimeZone.h"
#import "Foundation/NSUserDefaults.h"
#import "Foundation/NSHashTable.h"
#import "GNUstepBase/GSObjCRuntime.h"

#import "GSPrivate.h"
#import "GSPThread.h"

#import "NSDatePrivate.h"

#include <math.h>

/* These constants seem to be what MacOS-X uses */
#define DISTANT_FUTURE	63113990400.0
#define DISTANT_PAST	-63113817600.0

/* On older Solaris we don't have NAN nor nan() */
#if defined(__sun) && defined(__SVR4) && !defined(NAN)
#define NAN 0x7fffffffffffffff
#endif

GS_DECLARE const NSTimeInterval NSTimeIntervalSince1970 = 978307200.0;

static BOOL	debug = NO;
static Class	abstractClass = nil;
static Class	concreteClass = nil;
static Class	calendarClass = nil;

static gs_mutex_t       classLock = GS_MUTEX_INIT_STATIC;

// Singleton instances for distantPast and distantFuture
static id _distantPast = nil;
static id _distantFuture = nil;

/**
 * Compression of IEEE 754 double-precision floating-point numbers
 *
 * libobjc2 just like Apple's Objective-C runtime implement small
 * object classes, or tagged pointers in the case of Apple's runtime,
 * to store a 60-bit payload and 4-bit metadata in a 64-bit pointer.
 * This avoids constructing a full object on the heap. 
 *
 * NSDate stores the time as a double-precision floating-point number
 * representing the number of seconds since the reference date, the
 * Cocoa epoch (2001-01-01 00:00:00 UTC). This is a 64-bit value.
 * This poses a problem for small object classes, as the time value
 * is too large to fit in the 60-bit payload.
 *
 * To solve this problem, we look at the range of values that we
 * need to acurately represent. Idealy, this would include dates
 * before distant past and beyond distant future.
 *
 * After poking around with __NSTaggedDate, here is the algorithm
 * for constructing its payload:
 *
 * Sign and mantissa are not touched. The exponent is compressed.
 * Compression:
 * 1. Take the 11-bit unsigned exponent and sign-extend it to a 64-bit signed integer.
 * 2. Subtract a new secondary bias of 0x3EF from the exponent.
 * 3. Truncate the result to a 7-bit signed integer.
 *
 * The order of operations is important. The biased exponent of a
 * double-precision floating-point number is in range [0, 2047] (including
 * special values).  Sign-extending and subtracting the secondary bias results
 * in a value in range [-1007, 1040]. Truncating this to a 7-bit signed integer
 * further reduces the range to [-64, 63].
 *
 * When unbiasing the compressed 7-bit signed exponent with 0x3EF, we
 * get a biased exponent in range [943, 1070]. We have effectively shifted
 * the value range in order to represent values from
 * (-1)^0 * 2^(943 - 1023) * 1.048576 = 8.673617379884035e-25
 * to (-1)^0 * 2^(1070 - 1023) * 1.048576 = 147573952589676.4
 *
 * This encodes all dates for a few million years beyond distantPast and
 * distantFuture, except within about 1e-25 second of the reference date.
 *
 * So how does decompression work?
 * 1. Sign extend the 7-bit signed exponent to a 64-bit signed integer.
 * 2. Add the secondary bias of 0x3EF to the exponent.
 * 3. Cast the result to an unsigned 11-bit integer.
 *
 * Note that we only use the least-significant 3-bits for the tag in
 * libobjc2, contrary to Apple's runtime which uses the most-significant
 * 4-bits.
 *
 * We'll thus use 8-bits for the exponent.
 */

#if USE_SMALL_DATE

// 1-5 are already used by NSNumber and GSString
#define SMALL_DATE_MASK 6
#define EXPONENT_BIAS 0x3EF

#define GET_INTERVAL(obj) decompressTimeInterval((uintptr_t)obj)
#define SET_INTERVAL(obj, interval) (obj = (id)(compressTimeInterval(interval) | SMALL_DATE_MASK))

#define IS_CONCRETE_CLASS(obj) isSmallDate(obj)

#define CREATE_SMALL_DATE(interval) (id)(compressTimeInterval(interval) | SMALL_DATE_MASK)

union CompressedDouble {
  uintptr_t data;
  struct {
    uintptr_t tag : 3; // placeholder for tag bits
    uintptr_t fraction : 52;
    intptr_t exponent : 8;  // signed!
    uintptr_t sign : 1;
  };
};

union DoubleBits {
  double val;
  struct {
    uintptr_t fraction : 52;
    uintptr_t exponent : 11;
    uintptr_t sign : 1;
  };
};

static __attribute__((always_inline)) uintptr_t
  compressTimeInterval(NSTimeInterval interval)
{
  union CompressedDouble c;
  union DoubleBits db;
  intptr_t exponent;

  db.val = interval;
  c.fraction = db.fraction;
  c.sign = db.sign;

  // 1. Cast 11-bit unsigned exponent to 64-bit signed
  exponent = db.exponent;
  // 2. Subtract secondary Bias first
  exponent -= EXPONENT_BIAS;
  // 3. Truncate to 8-bit signed
  c.exponent = exponent;
  c.tag = 0;

  return c.data;
}

static __attribute__((always_inline)) NSTimeInterval
  decompressTimeInterval(uintptr_t compressed)
{
  union CompressedDouble c;
  union DoubleBits d;
  intptr_t biased_exponent;

  c.data = compressed;
  d.fraction = c.fraction;
  d.sign = c.sign;

  // 1. Sign Extend 8-bit to 64-bit
  biased_exponent = c.exponent;
  // 2. Add secondary Bias
  biased_exponent += 0x3EF;
  // Cast to 11-bit unsigned exponent
  d.exponent = biased_exponent;

  return d.val;
}

static __attribute__((always_inline)) BOOL isSmallDate(id obj) {
  // Do a fast check if the object is also a small date.
  // libobjc2 guarantees that the classes are 16-byte (word) aligned.
  #pragma clang diagnostic push
  #pragma clang diagnostic ignored "-Wdeprecated-objc-pointer-introspection"
  return !!((uintptr_t)obj & SMALL_DATE_MASK);
  #pragma clang diagnostic pop
}

// Populated in +[GSSmallDate load]
static BOOL useSmallDate;


#else
#define GET_INTERVAL(obj) ((NSGDate*)obj)->_seconds_since_ref
#define SET_INTERVAL(obj, interval) (((NSGDate*)obj)->_seconds_since_ref = interval)

#define IS_CONCRETE_CLASS(obj) ([obj isKindOfClass: concreteClass])

@interface	GSDateSingle : NSGDate
@end

@interface	GSDatePast : GSDateSingle
@end

@interface	GSDateFuture : GSDateSingle
@end

#endif

@implementation DATE_CONCRETE_CLASS_NAME

#if USE_SMALL_DATE

+ (void) load
{
  useSmallDate = objc_registerSmallObjectClass_np(self, SMALL_DATE_MASK);
  /* If this fails, someone else has already registered
   * a small object class for this slot.
   */
  if (unlikely(useSmallDate == NO))
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"Failed to register GSSmallDate small object class"];
    }
}

// Overwrite default memory management methods

+ (id) alloc
{
  return (id)SMALL_DATE_MASK;
}

+ (id) allocWithZone: (NSZone*)aZone
{
  return (id)SMALL_DATE_MASK;
}

- (id) copy
{
  return self;
}

- (id) copyWithZone: (NSZone*)aZone
{
  return self;
}

- (id) retain
{
  return self;
}

- (NSUInteger) retainCount
{
  return UINT_MAX;
}

- (id) autorelease
{
  return self;
}

- (oneway void) release
{
  return;
}

// NSObject(MemoryFootprint) informal protocol

- (NSUInteger) sizeInBytesExcluding: (NSHashTable*)exclude
{
  if (0 == NSHashGet(exclude, self))
    {
      return 0;
    }
  return 8;
}

- (NSUInteger) sizeOfContentExcluding: (NSHashTable*)exclude
{
    return 0;
}

- (NSUInteger) sizeOfInstance
{
  return 0;
}

#else

+ (void) initialize
{
  if (self == [NSDate class])
    {
      [self setVersion: 1];
    }
}

#endif

// NSDate initialization

- (id) initWithTimeIntervalSinceReferenceDate: (NSTimeInterval)secs
{
  if (isnan(secs))
    {
      [NSException raise: NSInvalidArgumentException
	          format: @"[%@-%@] interval is not a number",
	NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }

#if	USE_SMALL_DATE == 0 && GS_SIZEOF_VOIDP == 4
  if (secs <= DISTANT_PAST)
    {
      secs = DISTANT_PAST;
    }
  else if (secs >= DISTANT_FUTURE)
    {
      secs = DISTANT_FUTURE;
    }
#endif

#if    USE_SMALL_DATE == 0
  _seconds_since_ref = secs;
  return self;
#else
  return CREATE_SMALL_DATE(secs);
#endif
}

- (id) initWithCoder: (NSCoder*)coder
{
  double secondsSinceRef;

  if ([coder allowsKeyedCoding])
    {
      secondsSinceRef = [coder decodeDoubleForKey: @"NS.time"];
    }
  else
    {
      [coder decodeValueOfObjCType: @encode(NSTimeInterval)
                                at: &secondsSinceRef];
    }

#if    USE_SMALL_DATE == 0
  _seconds_since_ref = secondsSinceRef;
  return self;
#else
  return CREATE_SMALL_DATE(secondsSinceRef);
#endif
}

// NSDate Hashing, Comparison and Equality

- (NSUInteger) hash
{
  #if USE_SMALL_DATE
  return (NSUInteger)self;
  #else
  return (NSUInteger)GET_INTERVAL(self);
  #endif
}

- (NSComparisonResult) compare: (NSDate*)otherDate
{
  double selfTime = GET_INTERVAL(self);
  double otherTime;
  
  if (otherDate == self)
    {
      return NSOrderedSame;
    }
  if (unlikely(otherDate == nil))
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"nil argument for compare:"];
    }

  if (IS_CONCRETE_CLASS(otherDate))
    {
      otherTime = GET_INTERVAL(otherDate);
    }
  else
    {
      otherTime = [otherDate timeIntervalSinceReferenceDate];
    }

  if (selfTime > otherTime)
    {
      return NSOrderedDescending;
    }
  if (selfTime < otherTime)
    {
      return NSOrderedAscending;
    }
  return NSOrderedSame;
}

- (BOOL) isEqual: (id)other
{
  double selfTime = GET_INTERVAL(self);
  double otherTime;

  if (other == self)
    {
      return YES;
    }

  if (IS_CONCRETE_CLASS(other))
    {
      otherTime = GET_INTERVAL(other);
    }
  else if ([other isKindOfClass: abstractClass])
    {
      otherTime = [other timeIntervalSinceReferenceDate];
    }
  else
    {
      return NO;
    }

  return selfTime == otherTime;
}

- (BOOL) isEqualToDate: (NSDate*)other
{
  return [self isEqual: other];
}

- (NSDate*) laterDate: (NSDate*)otherDate
{
  double selfTime;
  double otherTime;

  if (unlikely(otherDate == nil))
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"nil argument for laterDate:"];
    }

  selfTime = GET_INTERVAL(self);
  if (IS_CONCRETE_CLASS(otherDate))
    {
      otherTime = GET_INTERVAL(otherDate);
    }
  else
    {
      otherTime = [otherDate timeIntervalSinceReferenceDate];
    }

  /* If the receiver and anotherDate represent the same date,
   * returns the receiver.
   */
  if (selfTime < otherTime)
    {
      return otherDate;
    }

  return self;
}

- (NSDate*) earlierDate: (NSDate*)otherDate
{
  double selfTime;
  double otherTime;

  if (unlikely(otherDate == nil))
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"nil argument for earlierDate:"];
    }

  selfTime = GET_INTERVAL(self);
  if (IS_CONCRETE_CLASS(otherDate))
    {
      otherTime = GET_INTERVAL(otherDate);
    }
  else
    {
      otherTime = [otherDate timeIntervalSinceReferenceDate];
    }

  /* If the receiver and anotherDate represent the same date,
   * returns the receiver.
   */
  if (selfTime > otherTime)
    {
      return otherDate;
    }

  return self;
}

- (void) encodeWithCoder: (NSCoder*)coder
{
  double time = GET_INTERVAL(self);

  if ([coder allowsKeyedCoding])
    {
      [coder encodeDouble: time forKey:@"NS.time"];
    }
  else
    {
      [coder encodeValueOfObjCType: @encode(NSTimeInterval)
                                at: &time];
    }
}

// NSDate Accessors

- (NSTimeInterval) timeIntervalSince1970
{
  return GET_INTERVAL(self) + NSTimeIntervalSince1970;
}

- (NSTimeInterval) timeIntervalSinceDate: (NSDate*)otherDate
{
  double otherTime;

  if (unlikely(otherDate == nil))
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"nil argument for timeIntervalSinceDate:"];
    }

  if (IS_CONCRETE_CLASS(otherDate))
    {
      otherTime = GET_INTERVAL(otherDate);
    }
  else
    {
      otherTime = [otherDate timeIntervalSinceReferenceDate];
    }

  return GET_INTERVAL(self) - otherTime;
}

- (NSTimeInterval) timeIntervalSinceNow
{
  return GET_INTERVAL(self) - GSPrivateTimeNow();
}

- (NSTimeInterval) timeIntervalSinceReferenceDate
{
  return GET_INTERVAL(self);
}

@end

#if USE_SMALL_DATE == 0
/*
 *	This abstract class represents a date of which there can be only
 *	one instance.
 */
@implementation GSDateSingle

+ (void) initialize
{
  if (self == [GSDateSingle class])
    {
      [self setVersion: 1];
      GSObjCAddClassBehavior(self, [NSGDate class]);
    }
}

- (id) autorelease
{
  return self;
}

- (oneway void) release
{
}

- (id) retain
{
  return self;
}

+ (id) allocWithZone: (NSZone*)z
{
  [NSException raise: NSInternalInconsistencyException
	      format: @"Attempt to allocate fixed date"];
  return nil;
}

- (id) copyWithZone: (NSZone*)z
{
  return self;
}

- (void) dealloc
{
  [NSException raise: NSInternalInconsistencyException
	      format: @"Attempt to deallocate fixed date"];
  GSNOSUPERDEALLOC;
}

- (id) initWithTimeIntervalSinceReferenceDate: (NSTimeInterval)secs
{
  return self;
}

@end

@implementation GSDatePast

+ (id) allocWithZone: (NSZone*)z
{
  if (_distantPast == nil)
    {
      id	obj = NSAllocateObject(self, 0, NSDefaultMallocZone());

      _distantPast = [obj init];
    }
  return _distantPast;
}

- (id) initWithTimeIntervalSinceReferenceDate: (NSTimeInterval)secs
{
  SET_INTERVAL(self, DISTANT_PAST);
  return self;
}

@end


@implementation GSDateFuture

+ (id) allocWithZone: (NSZone*)z
{
  if (_distantFuture == nil)
    {
      id	obj = NSAllocateObject(self, 0, NSDefaultMallocZone());

      _distantFuture = [obj init];
    }
  return _distantFuture;
}

- (id) initWithTimeIntervalSinceReferenceDate: (NSTimeInterval)secs
{
  SET_INTERVAL(self, DISTANT_FUTURE);
  return self;
}

@end

#endif // USE_SMALL_DATE == 0

static NSString*
findInArray(NSArray *array, unsigned pos, NSString *str)
{
  unsigned	index;
  unsigned	limit = [array count];

  for (index = pos; index < limit; index++)
    {
      NSString	*item;

      item = [array objectAtIndex: index];
      if ([str caseInsensitiveCompare: item] == NSOrderedSame)
	return item;
    }
  return nil;
}

static inline NSTimeInterval
otherTime(NSDate* other)
{
  if (unlikely(other == nil))
    [NSException raise: NSInvalidArgumentException format: @"other time nil"];
  
  return [other timeIntervalSinceReferenceDate];
}

/**
 * An <code>NSDate</code> object encapsulates a constant date/time to a high
 * resolution represented by the <code>NSTimeInterval</code> typedef.
 * <code>NSDate</code> has methods relating to times and time differences in
 * the abstract, but not calendar dates or time zones. These features are
 * added in the [NSCalendarDate] subclass. The [NSTimeZone] class handles time
 * zone information.
 */
@implementation NSDate

+ (void) initialize
{
  if (self == [NSDate class])
    {
      [self setVersion: 1];
      abstractClass = self;
      concreteClass = [DATE_CONCRETE_CLASS_NAME class];
      calendarClass = [NSCalendarDate class];
    }
}

+ (id) alloc
{
  if (self == abstractClass)
    {
      #if USE_SMALL_DATE
      /* alloc is overridden to return a small object
       */
      return [DATE_CONCRETE_CLASS_NAME alloc];
      #else
      return NSAllocateObject(concreteClass, 0, NSDefaultMallocZone());
      #endif
    }
  return NSAllocateObject(self, 0, NSDefaultMallocZone());
}

+ (id) allocWithZone: (NSZone*)z
{
  if (self == abstractClass)
    {
      #if USE_SMALL_DATE
      /* alloc is overridden to return a small object
       */
      return [DATE_CONCRETE_CLASS_NAME alloc];
      #else
      return NSAllocateObject(concreteClass, 0, z);
      #endif
    }
  return NSAllocateObject(self, 0, z);
}

+ (instancetype) date
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
    initWithTimeIntervalSinceReferenceDate: GSPrivateTimeNow()]);
}

+ (instancetype) now
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
    initWithTimeIntervalSinceReferenceDate: GSPrivateTimeNow()]);
}

/**
 * Returns an autoreleased instance representing the date and time given
 * by string. The value of string may be a 'natural' specification as
 * specified by the preferences in the user defaults database, allowing
 * phrases like 'last tuesday'
 */
+ (instancetype) dateWithNaturalLanguageString: (NSString*)string
{
  return [self dateWithNaturalLanguageString: string
				      locale: nil];
}

+ (instancetype) dateWithNaturalLanguageString: (NSString*)string
                                        locale: (NSDictionary*)locale
{
  NSCharacterSet	*ws;
  NSCharacterSet	*digits;
  NSScanner		*scanner;
  NSString		*tmp;
  NSString		*dto;
  NSArray		*ymw;
  NSMutableArray	*words;
  unsigned		index;
  unsigned		length;
  NSCalendarDate	*theDate;
  BOOL			hadHour = NO;
  BOOL			hadMinute = NO;
  BOOL			hadSecond = NO;
  BOOL			hadDay = NO;
  BOOL			hadMonth = NO;
  BOOL			hadYear = NO;
  BOOL			hadWeekDay = NO;
  int			weekDay = 0;
  int			dayOfWeek = 0;
  int			modMonth = 0;
  int			modYear = 0;
  int			modDay = 0;
  int			D, M, Y;
  int			h = 12;
  int			m = 0;
  int			s = 0;
  unsigned		dtoIndex;

  if (locale == nil)
    {
      locale = GSPrivateDefaultLocale();
    }
  ws = [NSCharacterSet whitespaceAndNewlineCharacterSet];
  digits = [NSCharacterSet decimalDigitCharacterSet];
  scanner = [NSScanner scannerWithString: string];
  words = [NSMutableArray arrayWithCapacity: 10];

  theDate = (NSCalendarDate*)[calendarClass date];
  Y = [theDate yearOfCommonEra];
  M = [theDate monthOfYear];
  D = [theDate dayOfMonth];
  dayOfWeek = [theDate dayOfWeek];

  [scanner scanCharactersFromSet: ws intoString: 0];
  while ([scanner scanUpToCharactersFromSet: ws intoString: &tmp] == YES)
    {
      [words addObject: tmp];
      [scanner scanCharactersFromSet: ws intoString: 0];
    }

  /*
   *	Scan the array for day specifications and remove them.
   */
  if (hadDay == NO)
    {
      NSArray	*tdd = [locale objectForKey: NSThisDayDesignations];
      NSArray	*ndd = [locale objectForKey: NSNextDayDesignations];
      NSArray	*pdd = [locale objectForKey: NSPriorDayDesignations];
      NSArray	*nndd = [locale objectForKey: NSNextNextDayDesignations];

      for (index = 0; hadDay == NO && index < [words count]; index++)
	{
	  tmp = [words objectAtIndex: index];

	  if (findInArray(tdd, 0 ,tmp) != nil)
	    {
	      hadDay = YES;
	    }
	  else if (findInArray(ndd, 0 ,tmp) != nil)
	    {
	      modDay++;
	      hadDay = YES;
	    }
	  else if (findInArray(nndd, 0 ,tmp) != nil)
	    {
	      modDay += 2;
	      hadDay = YES;
	    }
	  else if (findInArray(pdd, 0 ,tmp) != nil)
	    {
	      modDay--;
	      hadDay = YES;
	    }
	  if (hadDay)
	    {
	      hadMonth = YES;
	      hadYear = YES;
	      [words removeObjectAtIndex: index];
	    }
	}
    }

  /*
   *	Scan the array for month specifications and remove them.
   */
  if (hadMonth == NO)
    {
      NSArray	*lm = [locale objectForKey: NSMonthNameArray];
      NSArray	*sm = [locale objectForKey: NSShortMonthNameArray];

      for (index = 0; hadMonth == NO && index < [words count]; index++)
	{
	  NSString	*mname;

	  tmp = [words objectAtIndex: index];

	  if ((mname = findInArray(lm, 0, tmp)) != nil)
	    {
	      M = [lm indexOfObjectIdenticalTo: mname] + 1;
	    }
	  else if ((mname = findInArray(sm, 0, tmp)) != nil)
	    {
	      M = [sm indexOfObjectIdenticalTo: mname] + 1;
	    }

	  if (mname != nil)
	    {
	      hadMonth = YES;
	      [words removeObjectAtIndex: index];
	    }
	}
    }

  /*
   *	Scan the array for weekday specifications and remove them.
   */
  if (hadWeekDay == NO)
    {
      NSArray	*lw = [locale objectForKey: NSWeekDayNameArray];
      NSArray	*sw = [locale objectForKey: NSShortWeekDayNameArray];

      for (index = 0; hadWeekDay == NO && index < [words count]; index++)
	{
	  NSString	*dname;

	  tmp = [words objectAtIndex: index];

	  if ((dname = findInArray(lw, 0, tmp)) != nil)
	    {
	      weekDay = [lw indexOfObjectIdenticalTo: dname];
	    }
	  else if ((dname = findInArray(sw, 0, tmp)) != nil)
	    {
	      weekDay = [sw indexOfObjectIdenticalTo: dname];
	    }

	  if (dname != nil)
	    {
	      hadWeekDay = YES;
	      [words removeObjectAtIndex: index];
	    }
	}
    }

  /*
   *	Scan the array for year month week modifiers and remove them.
   *	Going by the documentation, these modifiers adjust the date by
   *	plus or minus a week, month, or year.
   */
  ymw = [locale objectForKey: NSYearMonthWeekDesignations];
  if (ymw != nil && [ymw count] > 0)
    {
      unsigned	c = [ymw count];
      NSString	*yname = [ymw objectAtIndex: 0];
      NSString	*mname = c > 1 ? [ymw objectAtIndex: 1] : nil;
      NSArray	*early = [locale objectForKey: NSEarlierTimeDesignations];
      NSArray	*later = [locale objectForKey: NSLaterTimeDesignations];

      for (index = 0; index < [words count]; index++)
	{
	  tmp = [words objectAtIndex: index];

	  /*
           *	See if the current word is a year, month, or week.
	   */
	  if (findInArray(ymw, 0, tmp))
	    {
	      BOOL	hadAdjective = NO;
	      int	adjective = 0;
	      NSString	*adj = nil;

	      /*
	       *	See if there is a prefix adjective
	       */
	      if (index > 0)
		{
		  adj = [words objectAtIndex: index - 1];

		  if (findInArray(early, 0, adj))
		    {
		      hadAdjective = YES;
		      adjective = -1;
		    }
		  else if (findInArray(later, 0, adj))
		    {
		      hadAdjective = YES;
		      adjective = 1;
		    }
		  if (hadAdjective)
		    {
		      [words removeObjectAtIndex: --index];
		    }
		}
	      /*
	       *	See if there is a prefix adjective
	       */
	      if (hadAdjective == NO && index < [words count] - 1)
		{
		  NSString	*adj = [words objectAtIndex: index + 1];

		  if (findInArray(early, 0, adj))
		    {
		      hadAdjective = YES;
		      adjective = -1;
		    }
		  else if (findInArray(later, 0, adj))
		    {
		      hadAdjective = YES;
		      adjective = 1;
		    }
		  if (hadAdjective)
		    {
		      [words removeObjectAtIndex: index];
		    }
		}
	      /*
	       *	Record the adjective information.
	       */
	      if (hadAdjective)
		{
		  if ([tmp caseInsensitiveCompare: yname] == NSOrderedSame)
		    {
		      modYear += adjective;
		      hadYear = YES;
		    }
		  else if (mname != nil
		    && [tmp caseInsensitiveCompare: mname] == NSOrderedSame)
		    {
		      modMonth += adjective;
		      hadMonth = YES;
		    }
		  else
		    {
		      if (hadWeekDay)
			{
			  modDay += weekDay - dayOfWeek;
			}
		      modDay += 7*adjective;
		      hadDay = YES;
		      hadMonth = YES;
		      hadYear = YES;
		    }
		}
	      /*
	       *	Remove from list of words.
	       */
	      [words removeObjectAtIndex: index];
	    }
	}
    }

  /* Scan for hour of the day */
  if (hadHour == NO)
    {
      NSArray	*hours = [locale objectForKey: NSHourNameDesignations];
      unsigned	hLimit = [hours count];
      unsigned	hIndex;

      for (index = 0; hadHour == NO && index < [words count]; index++)
	{
	  tmp = [words objectAtIndex: index];

	  for (hIndex = 0; hadHour == NO && hIndex < hLimit; hIndex++)
	    {
	      NSArray	*names;

	      names = [hours objectAtIndex: hIndex];
	      if (findInArray(names, 1, tmp) != nil)
		{
		  h = [[names objectAtIndex: 0] intValue];
		  hadHour = YES;
		  hadMinute = YES;
		  hadSecond = YES;
		}
	    }
	}
    }

  /*
   *	Now re-scan the string for numeric information.
   */

  dto = [locale objectForKey: NSDateTimeOrdering];
  if (dto == nil)
    {
      if (debug)
	{
	  NSLog(@"no NSDateTimeOrdering - default to DMYH.");
	}
      dto = @"DMYH";
    }
  length = [dto length];
  if (length > 4)
    {
      if (debug)
	{
	  NSLog(@"too many characters in NSDateTimeOrdering - truncating.");
	}
      length = 4;
    }

  dtoIndex = 0;
  scanner = [NSScanner scannerWithString: string];
  [scanner setCaseSensitive: NO];
  // We don't care if there are non-digit characters ... skip if they are there
  (void)[scanner scanUpToCharactersFromSet: digits intoString: 0];
  while ([scanner scanCharactersFromSet: digits intoString: &tmp] == YES)
    {
      int	num = [tmp intValue];

      if ([scanner scanUpToCharactersFromSet: digits intoString: &tmp] == NO)
	{
	  tmp = nil;
	}
      /*
       *	Numbers separated by colons are a time specification.
       */
      if (tmp && ([tmp characterAtIndex: 0] == (unichar)':'))
	{
	  BOOL	done = NO;
	  BOOL	checkForAMPM = NO;

	  do
	    {
	      if (hadHour == NO)
		{
		  if (num > 23)
		    {
		      if (debug)
			{
			  NSLog(@"hour (%d) too large - ignored.", num);
			}
		      else
			{
			  return nil;
			}
		    }
		  else
		    {
		      h = num;
		      m = 0;
		      s = 0;
		      hadHour = YES;
		      checkForAMPM = YES;
		    }
		}
	      else if (hadMinute == NO)
		{
		  if (num > 59)
		    {
		      if (debug)
			{
			  NSLog(@"minute (%d) too large - ignored.", num);
			}
		      else
			{
			  return nil;
			}
		    }
		  else
		    {
		      m = num;
		      s = 0;
		      hadMinute = YES;
		    }
		}
	      else if (hadSecond == NO)
		{
		  if (num > 59)
		    {
		      if (debug)
			{
			  NSLog(@"second (%d) too large - ignored.", num);
			}
		      else
			{
			  return nil;
			}
		    }
		  else
		    {
		      s = num;
		      hadSecond = YES;
		    }
		}
	      else
		{
		  if (debug)
		    {
		      NSLog(@"odd time spec - excess numbers ignored.");
		    }
		}

	      done = YES;
	      if (tmp && ([tmp characterAtIndex: 0] == (unichar)':'))
		{
		  if ([scanner scanCharactersFromSet: digits intoString: &tmp])
		    {
		      num = [tmp intValue];
		      done = NO;
		      if ([scanner scanString: @":" intoString: &tmp] == NO)
			{
			  tmp = nil;
			}
		    }
		}
	    }
	  while (done == NO);

	  if (checkForAMPM)
	    {
	      NSArray	*ampm;

	      ampm = [locale objectForKey: NSAMPMDesignation];
	      if ([scanner scanString: [ampm objectAtIndex: 0]
			   intoString: NULL])
		{
		  if (h == 12) // 12 AM means midnight
		    h = 0;
		}
	      else if ([scanner scanString: [ampm objectAtIndex: 1]
				intoString: NULL])
		{
		  if (h < 12) // if PM add 12 to any hour less than 12
		    h += 12;
		}	  
	    }
	}
      else
	{
	  BOOL	mustSkip = YES;

	  while ((dtoIndex < length) && (mustSkip == YES))
	    {
	      switch ([dto characterAtIndex: dtoIndex])
		{
		  case 'D':
		    if (hadDay)
		      dtoIndex++;
		    else
		      mustSkip = NO;
		    break;

		  case 'M':
		    if (hadMonth)
		      dtoIndex++;
		    else
		      mustSkip = NO;
		    break;

		  case 'Y':
		    if (hadYear)
		      dtoIndex++;
		    else
		      mustSkip = NO;
		    break;

		  case 'H':
		    if (hadHour)
		      dtoIndex++;
		    else
		      mustSkip = NO;
		    break;

		  default:
		    if (debug)
		      {
			NSLog(@"odd char (unicode %d) in NSDateTimeOrdering.",
			  [dto characterAtIndex: dtoIndex]);
		      }
		    dtoIndex++;
		    break;
		}
	    }
	  if (dtoIndex >= length)
	    {
	      if (debug)
		{
		  NSLog(@"odd date specification - excess numbers ignored.");
		}
	      break;
	    }
	  switch ([dto characterAtIndex: dtoIndex])
	    {
	      case 'D':
		if (num < 1)
		  {
		    if (debug)
		      {
			NSLog(@"day (0) too small - ignored.");
		      }
		    else
		      {
			return nil;
		      }
		  }
		else if (num > 31)
		  {
		    if (debug)
		      {
			NSLog(@"day (%d) too large - ignored.", num);
		      }
		    else
		      {
			return nil;
		      }
		  }
		else
		  {
		    D = num;
		    hadDay = YES;
		  }
		break;
	      case 'M':
		if (num < 1)
		  {
		    if (debug)
		      {
			NSLog(@"month (0) too small - ignored.");
		      }
		    else
		      {
			return nil;
		      }
		  }
		else if (num > 12)
		  {
		    if (debug)
		      {
			NSLog(@"month (%d) too large - ignored.", num);
		      }
		    else
		      {
			return nil;
		      }
		  }
		else
		  {
		    M = num;
		    hadMonth = YES;
		  }
		break;
	      case 'Y':
		if (num < 100)
		  {
		    if (num < 70)
		      {
			Y = num + 2000;
		      }
		    else
		      {
			Y = num + 1900;
		      }
		    if (debug)
		      {
			NSLog(@"year (%d) adjusted to %d.", num, Y);
		      }
		  }
		else
		  {
		    Y = num;
		  }
		hadYear = YES;
		break;
	      case 'H':
		{
		  BOOL	shouldIgnore = NO;

		  /*
		   *	Check the next text to see if it is an am/pm
		   *	designation.
		   */
		  if (tmp)
		    {
		      NSArray	*ampm;
		      NSString	*mod;

		      ampm = [locale objectForKey: NSAMPMDesignation];
		      mod = findInArray(ampm, 0, tmp);
		      if (mod)
			{
			  if (num > 11)
			    {
			      if (debug)
				{
				  NSLog(@"hour (%d) too large - ignored.", num);
				}
			      else
				{
				  return nil;
				}
			      shouldIgnore = YES;
			    }
			  else if (mod == [ampm objectAtIndex: 1])
			    {
			      num += 12;
			    }
			}
		    }
		  if (shouldIgnore == NO)
		    {
		      if (num > 23)
			{
			  if (debug)
			    {
			      NSLog(@"hour (%d) too large - ignored.", num);
			    }
			  else
			    {
			      return nil;
			    }
			}
		      else
			{
			  hadHour = YES;
			  h = num;
			}
		    }
		  break;
		}
	      default:
		if (debug)
		  {
		    NSLog(@"unexpected char (unicode%d) in NSDateTimeOrdering.",
		      [dto characterAtIndex: dtoIndex]);
		  }
		break;
	    }
	}
    }

  /*
   *	If we had no date or time information - we give up, otherwise
   *	we can use reasonable defaults for any missing info.
   *	Missing date => today
   *	Missing time => 12: 00
   *	If we had a week/month/year modifier without a day, we assume today.
   *	If we had a day name without any more day detail - adjust to that
   *	day this week.
   */
  if (hadDay == NO && hadWeekDay == YES)
    {
      modDay += weekDay - dayOfWeek;
      hadDay = YES;
    }
  if (hadDay == NO && hadHour == NO)
    {
      if (modDay == NO && modMonth == NO && modYear == NO)
	{
	  return nil;
	}
    }

  /*
   *	Build a calendar date we can adjust easily.
   */
  theDate = [calendarClass dateWithYear: Y
				   month: M
				     day: D
				    hour: h
				  minute: m
				  second: s
				timeZone: [NSTimeZone defaultTimeZone]];

  /*
   *	Adjust the date by year month or days if necessary.
   */
  if (modYear || modMonth || modDay)
    {
      theDate = [theDate dateByAddingYears: modYear
				    months: modMonth
				      days: modDay
				     hours: 0
				   minutes: 0
				   seconds: 0];
    }
  if (hadWeekDay && [theDate dayOfWeek] != weekDay)
    {
      if (debug)
	{
	  NSLog(@"Date resulted in wrong day of week.");
	}
      return nil;
    }
  if (theDate == nil)
    {
      return theDate;
    }
  else
    {
      return [self dateWithTimeIntervalSinceReferenceDate: otherTime(theDate)];
    }
}

+ (instancetype) dateWithString: (NSString*)description
{
  return AUTORELEASE([[self alloc] initWithString: description]);
}

+ (instancetype) dateWithTimeInterval: (NSTimeInterval)seconds
                            sinceDate: (NSDate*)date
{
  return AUTORELEASE([[self alloc] initWithTimeInterval: seconds
                                              sinceDate: date]);
}

+ (instancetype) dateWithTimeIntervalSince1970: (NSTimeInterval)seconds
{
  return AUTORELEASE([[self alloc] initWithTimeIntervalSinceReferenceDate:
    seconds - NSTimeIntervalSince1970]);
}

+ (instancetype) dateWithTimeIntervalSinceNow: (NSTimeInterval)seconds
{
  return AUTORELEASE([[self alloc] initWithTimeIntervalSinceNow: seconds]);
}

+ (instancetype) dateWithTimeIntervalSinceReferenceDate: (NSTimeInterval)seconds
{
  return AUTORELEASE([[self alloc] initWithTimeIntervalSinceReferenceDate:
    seconds]);
}

+ (instancetype) distantPast
{
  if (_distantPast == nil)
    {
      GS_MUTEX_LOCK(classLock);
      if (_distantPast == nil)
      {
        #if USE_SMALL_DATE
        _distantPast = CREATE_SMALL_DATE(DISTANT_PAST);
        #else
        _distantPast = [GSDatePast allocWithZone: 0];
        #endif
      }
      GS_MUTEX_UNLOCK(classLock);
    }
  return _distantPast;
}

+ (instancetype) distantFuture
{
  if (_distantFuture == nil)
    {
      GS_MUTEX_LOCK(classLock);
      if (_distantFuture == nil)
      {
        #if USE_SMALL_DATE
        _distantFuture = CREATE_SMALL_DATE(DISTANT_FUTURE);
        #else
        _distantFuture = [GSDateFuture allocWithZone: 0];
        #endif
      }
      GS_MUTEX_UNLOCK(classLock);
    }
  return _distantFuture;
}

/**
 * Returns the time interval between the current date and the
 * reference date (1 January 2001, GMT).
 */
+ (NSTimeInterval) timeIntervalSinceReferenceDate
{
  return GSPrivateTimeNow();
}

- (instancetype) addTimeInterval: (NSTimeInterval)seconds
{
  return [self dateByAddingTimeInterval: seconds];
}

- (NSComparisonResult) compare: (NSDate*)otherDate
{
  if (otherDate == self)
    {
      return NSOrderedSame;
    }
  if (otherTime(self) > otherTime(otherDate))
    {
      return NSOrderedDescending;
    }
  if (otherTime(self) < otherTime(otherDate))
    {
      return NSOrderedAscending;
    }
  return NSOrderedSame;
}

- (id) copyWithZone: (NSZone*)zone
{
  if (NSShouldRetainWithZone(self, zone))
    {
      return RETAIN(self);
    }
  return NSCopyObject(self, 0, zone);
}

- (Class) classForCoder
{
  return abstractClass;
}

- (instancetype) dateByAddingTimeInterval: (NSTimeInterval)ti
{
  return [[self class] dateWithTimeIntervalSinceReferenceDate:
    otherTime(self) + ti];
}

- (NSCalendarDate *) dateWithCalendarFormat: (NSString*)formatString
				   timeZone: (NSTimeZone*)timeZone
{
  NSCalendarDate *d = [calendarClass alloc];

  d = [d initWithTimeIntervalSinceReferenceDate: otherTime(self)];
  [d setCalendarFormat: formatString];
  [d setTimeZone: timeZone];
  return AUTORELEASE(d);
}

- (NSString*) description
{
  // Easiest to just have NSCalendarDate do the work for us
  NSString *s;
  NSCalendarDate *d = [calendarClass alloc];

  d = [d initWithTimeIntervalSinceReferenceDate: otherTime(self)];
  s = [d description];
  RELEASE(d);
  return s;
}

- (NSString*) descriptionWithCalendarFormat: (NSString*)format
				   timeZone: (NSTimeZone*)aTimeZone
				     locale: (NSDictionary*)l
{
  // Easiest to just have NSCalendarDate do the work for us
  NSString *s;
  NSCalendarDate *d = [calendarClass alloc];
  id f;

  d = [d initWithTimeIntervalSinceReferenceDate: otherTime(self)];
  if (!format)
    {
      f = [d calendarFormat];
    }
  else
    {
      f = format;
    }
  if (aTimeZone)
    {
      [d setTimeZone: aTimeZone];
    }
  s = [d descriptionWithCalendarFormat: f locale: l];
  RELEASE(d);
  return s;
}

- (NSString *) descriptionWithLocale: (id)locale
{
  // Easiest to just have NSCalendarDate do the work for us
  NSString *s;
  NSCalendarDate *d = [calendarClass alloc];

  d = [d initWithTimeIntervalSinceReferenceDate: otherTime(self)];
  s = [d descriptionWithLocale: locale];
  RELEASE(d);
  return s;
}

- (NSDate*) earlierDate: (NSDate*)otherDate
{
  if (otherTime(self) > otherTime(otherDate))
    {
      return otherDate;
    }
  return self;
}

- (void) encodeWithCoder: (NSCoder*)coder
{
  NSTimeInterval	interval = [self timeIntervalSinceReferenceDate];

  if ([coder allowsKeyedCoding])
    {
      [coder encodeDouble: interval forKey: @"NS.time"];
    }
  [coder encodeValueOfObjCType: @encode(NSTimeInterval) at: &interval];
}

- (NSUInteger) hash
{
  return (NSUInteger)[self timeIntervalSinceReferenceDate];
}

- (instancetype) initWithCoder: (NSCoder*)coder
{
  NSTimeInterval	interval;
  id			o;

  if ([coder allowsKeyedCoding])
    {
      interval = [coder decodeDoubleForKey: @"NS.time"];
    }
  else
    {
      [coder decodeValueOfObjCType: @encode(NSTimeInterval) at: &interval];
    }
  if (interval == DISTANT_PAST)
    {
      o = RETAIN([abstractClass distantPast]);
    }
  else if (interval == DISTANT_FUTURE)
    {
      o = RETAIN([abstractClass distantFuture]);
    }
  else
    {
      o = [concreteClass allocWithZone: NSDefaultMallocZone()];
      o = [o initWithTimeIntervalSinceReferenceDate: interval];
    }
  DESTROY(self);
  return o;
}

- (instancetype) init
{
  return [self initWithTimeIntervalSinceReferenceDate: GSPrivateTimeNow()];
}

- (instancetype) initWithString: (NSString*)description
{
  // Easiest to just have NSCalendarDate do the work for us
  NSCalendarDate	*d = [calendarClass alloc];

  d = [d initWithString: description];
  if (nil == d)
    {
      DESTROY(self);
      return nil;
    }
  else
    {
      self = [self initWithTimeIntervalSinceReferenceDate: otherTime(d)];
      RELEASE(d);
      return self;
    }
}

- (instancetype) initWithTimeInterval: (NSTimeInterval)secsToBeAdded
                            sinceDate: (NSDate*)anotherDate
{
  if (anotherDate == nil)
    {
      NSLog(@"initWithTimeInterval:sinceDate: given nil date");
      DESTROY(self);
      return nil;
    }
  // Get the other date's time, add the secs and init thyself
  return [self initWithTimeIntervalSinceReferenceDate: otherTime(anotherDate) + secsToBeAdded];
}

- (instancetype) initWithTimeIntervalSince1970: (NSTimeInterval)seconds
{
  return [self initWithTimeIntervalSinceReferenceDate:
    seconds - NSTimeIntervalSince1970];
}

- (instancetype) initWithTimeIntervalSinceNow: (NSTimeInterval)secsToBeAdded
{
  // Get the current time, add the secs and init thyself
  return [self initWithTimeIntervalSinceReferenceDate:
    GSPrivateTimeNow() + secsToBeAdded];
}

- (instancetype) initWithTimeIntervalSinceReferenceDate: (NSTimeInterval)secs
{
  [self subclassResponsibility: _cmd];
  return self;
}

- (BOOL) isEqual: (id)other
{
  if (other == nil)
  {
    return NO;
  }

  if (self == other)
    {
      return YES;
    }

  if ([other isKindOfClass: abstractClass])
    {
      double selfTime = [self timeIntervalSinceReferenceDate];
      return selfTime == otherTime(other);
    }

  return NO;
}

- (BOOL) isEqualToDate: (NSDate*)other
{
  double selfTime;
  double otherTime;
  if (other == nil)
    {
      return NO;
    }

  selfTime = [self timeIntervalSinceReferenceDate];
  otherTime = [other timeIntervalSinceReferenceDate];
  if (selfTime == otherTime)
    {
      return YES;
    }

  return NO;
}

- (NSDate*) laterDate: (NSDate*)otherDate
{
  double selfTime;

  if (otherDate == nil)
    {
      return nil;
    }
  
  selfTime = [self timeIntervalSinceReferenceDate];
  if (selfTime < otherTime(otherDate))
    {
      return otherDate;
    }
  return self;
}

- (id) replacementObjectForPortCoder: (NSPortCoder*)aCoder
{
  if ([aCoder isByref] == NO)
    {
      return self;
    }
  return [super replacementObjectForPortCoder: aCoder];
}

- (NSTimeInterval) timeIntervalSince1970
{
  return otherTime(self) + NSTimeIntervalSince1970;
}

- (NSTimeInterval) timeIntervalSinceDate: (NSDate*)otherDate
{
  if (nil == otherDate)
    {
#ifndef NAN
      return nan("");
#else
      return NAN;
#endif
    }
  return [self timeIntervalSinceReferenceDate] - otherTime(otherDate);
}

- (NSTimeInterval) timeIntervalSinceNow
{
  return [self timeIntervalSinceReferenceDate] - GSPrivateTimeNow();
}

- (NSTimeInterval) timeIntervalSinceReferenceDate
{
  [self subclassResponsibility: _cmd];
  return 0;
}

@end
