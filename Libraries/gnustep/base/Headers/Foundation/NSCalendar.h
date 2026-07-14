/* NSCalendar.h

   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by: Stefan Bidigaray
   Date: December, 2010

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/> or write to the
   Free Software Foundation, 31 Milk Street #960789 Boston, MA 02196 USA.
*/

#ifndef __NSCalendar_h_GNUSTEP_BASE_INCLUDE
#define __NSCalendar_h_GNUSTEP_BASE_INCLUDE

#import <GNUstepBase/GSVersionMacros.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_4, GS_API_LATEST)

#include <Foundation/NSObject.h>
#include <Foundation/NSGeometry.h>

@class NSDate;
@class NSCalendar;
@class NSLocale;
@class NSString;
@class NSTimeZone;

#if	defined(__cplusplus)
extern "C" {
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
GS_EXPORT NSString *const NSCalendarIdentifierGregorian;
GS_EXPORT NSString *const NSCalendarIdentifierBuddhist;
GS_EXPORT NSString *const NSCalendarIdentifierChinese;
GS_EXPORT NSString *const NSCalendarIdentifierCoptic;
GS_EXPORT NSString *const NSCalendarIdentifierEthiopicAmeteMihret;
GS_EXPORT NSString *const NSCalendarIdentifierEthiopicAmeteAlem;
GS_EXPORT NSString *const NSCalendarIdentifierHebrew;
GS_EXPORT NSString *const NSCalendarIdentifierISO8601;
GS_EXPORT NSString *const NSCalendarIdentifierIndian;
GS_EXPORT NSString *const NSCalendarIdentifierIslamic;
GS_EXPORT NSString *const NSCalendarIdentifierIslamicCivil;
GS_EXPORT NSString *const NSCalendarIdentifierJapanese;
GS_EXPORT NSString *const NSCalendarIdentifierPersian;
GS_EXPORT NSString *const NSCalendarIdentifierRepublicOfChina;
#endif
#if OS_API_VERSION(MAC_OS_X_VERSION_10_10, GS_API_LATEST)
GS_EXPORT NSString *const NSCalendarIdentifierIslamicTabular;
GS_EXPORT NSString *const NSCalendarIdentifierIslamicUmmAlQura;
#endif

// NSCalendarOptions enum
// These values are currently NOT supported in this NSCalendar implementation.
#if OS_API_VERSION(MAC_OS_X_VERSION_10_9, GS_API_LATEST)
typedef NSUInteger NSCalendarOptions;
enum
{
  NSCalendarWrapComponents = (1UL << 0),

  NSCalendarMatchStrictly = (1ULL << 1),
  NSCalendarSearchBackwards = (1ULL << 2),

  NSCalendarMatchPreviousTimePreservingSmallerUnits = (1ULL << 8),
  NSCalendarMatchNextTimePreservingSmallerUnits = (1ULL << 9),
  NSCalendarMatchNextTime = (1ULL << 10),

  NSCalendarMatchFirst = (1ULL << 12),
  NSCalendarMatchLast = (1ULL << 13)
};
#endif

typedef NSUInteger NSCalendarUnit;

/* Old-style NSCalendarUnit declarations, deprecated */
enum
{
  NSEraCalendarUnit = (1UL << 1),
  NSYearCalendarUnit = (1UL << 2),
  NSMonthCalendarUnit = (1UL << 3),
  NSDayCalendarUnit = (1UL << 4),
  NSHourCalendarUnit = (1UL << 5),
  NSMinuteCalendarUnit = (1UL << 6),
  NSSecondCalendarUnit = (1UL << 7),
  NSWeekCalendarUnit = (1UL << 8),
  NSWeekdayCalendarUnit = (1UL << 9),
  NSWeekdayOrdinalCalendarUnit = (1UL << 10),
#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
  NSQuarterCalendarUnit = (1UL << 11),
#endif
#if OS_API_VERSION(MAC_OS_X_VERSION_10_7, GS_API_LATEST)
  NSWeekOfMonthCalendarUnit = (1UL << 12),
  NSWeekOfYearCalendarUnit = (1UL << 13),
  NSYearForWeekOfYearCalendarUnit = (1UL << 14),
#endif
};

/* New-style NSCalendarUnit declarations */
enum
{
#if OS_API_VERSION(MAC_OS_X_VERSION_10_9, GS_API_LATEST)
  NSCalendarUnitEra = (1UL << 1),
  NSCalendarUnitYear = (1UL << 2),
  NSCalendarUnitMonth = (1UL << 3),
  NSCalendarUnitDay = (1UL << 4),
  NSCalendarUnitHour = (1UL << 5),
  NSCalendarUnitMinute = (1UL << 6),
  NSCalendarUnitSecond = (1UL << 7),
  NSCalendarUnitWeekday = (1UL << 9),
  NSCalendarUnitWeekdayOrdinal = (1UL << 10),
#endif
#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
  NSCalendarUnitQuarter = (1UL << 11),
#endif
#if OS_API_VERSION(MAC_OS_X_VERSION_10_7, GS_API_LATEST)
  NSCalendarUnitWeekOfMonth = (1UL << 12),
  NSCalendarUnitWeekOfYear = (1UL << 13),
  NSCalendarUnitYearForWeekOfYear = (1UL << 14),
  NSCalendarUnitNanosecond = (1 << 15),
  NSCalendarUnitCalendar = (1 << 20), // FIXME: unimplemented
  NSCalendarUnitTimeZone = (1 << 21) // FIXME: unimplemented
#endif
};

enum
{
  NSWrapCalendarComponents = (1UL << 0)
};

enum
{
  NSDateComponentUndefined = NSIntegerMax,
  NSUndefinedDateComponent = NSDateComponentUndefined
};



GS_EXPORT_CLASS
@interface NSDateComponents : NSObject <NSCopying>
{
@private
  void  *_NSDateComponentsInternal;
/* FIXME ... remove dummy fields at next binary incompatible release
 */
  void  *_dummy1;
  void  *_dummy2;
  void  *_dummy3;
  void  *_dummy4;
  void  *_dummy5;
  void  *_dummy6;
  void  *_dummy7;
  void  *_dummy8;
  void  *_dummy9;
  void  *_dummy10;
  void  *_dummy11;
  void  *_dummy12;
}

- (NSInteger) day;
- (NSInteger) era;
- (NSInteger) hour;
- (NSInteger) minute;
- (NSInteger) month;
- (NSInteger) second;
- (NSInteger) week;
- (NSInteger) weekday;
- (NSInteger) weekdayOrdinal;
- (NSInteger) year;

- (void) setDay: (NSInteger) v;
- (void) setEra: (NSInteger) v;
- (void) setHour: (NSInteger) v;
- (void) setMinute: (NSInteger) v;
- (void) setMonth: (NSInteger) v;
- (void) setSecond: (NSInteger) v;
- (void) setWeek: (NSInteger) v;
- (void) setWeekday: (NSInteger) v;
- (void) setWeekdayOrdinal: (NSInteger) v;
- (void) setYear: (NSInteger) v;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
- (NSInteger) quarter;
- (void) setQuarter: (NSInteger) v;
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_7, GS_API_LATEST)
- (NSCalendar *) calendar;
- (NSTimeZone *) timeZone;
- (void) setCalendar: (NSCalendar *) cal;
- (void) setTimeZone: (NSTimeZone *) tz;

/**
 * <p>
 * Computes a date by using the components set in this NSDateComponents
 * instance.
 * </p>
 * <p>
 * A calendar (and optionally a time zone) must be set prior to
 * calling this method.
 * </p>
 */
- (NSDate *) date;

/** Returns the number of the week in this month. */
- (NSInteger) weekOfMonth;
/**
 * Returns the number of the week in this year.
 * Identical to calling <code>week</code>. */
- (NSInteger) weekOfYear;
/**
 * The year corresponding to the current week.
 * This value may differ from year around the end of the year.
 * 
 * For example, for 2012-12-31, the year number is 2012, but
 * yearForWeekOfYear is 2013, since it's already week 1 in 2013.
 */
- (NSInteger) yearForWeekOfYear;
- (NSInteger) nanosecond;

/** Sets the number of the week in this month. */
- (void) setWeekOfMonth: (NSInteger) v;

/**
 * Sets the number of the week in this year.
 * Identical to calling <code>-setWeek:</code>. */
- (void) setWeekOfYear: (NSInteger) v;

/**
 * Sets the year number for the current week.
 * See the explanation at <code>-yearForWeekOfYear</code>.
 */
- (void) setYearForWeekOfYear: (NSInteger) v;
- (void) setNanosecond: (NSInteger) v;

#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_8, GS_API_LATEST)
- (BOOL) leapMonth;
- (void) setLeapMonth: (BOOL) v;
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_9, GS_API_LATEST)
- (BOOL) isValidDate;
- (BOOL) isValidDateInCalendar: (NSCalendar *) calendar;
- (NSInteger) valueForComponent: (NSCalendarUnit) unit;
- (void) setValue: (NSInteger) value
     forComponent: (NSCalendarUnit) unit;
#endif
@end



GS_EXPORT_CLASS
@interface NSCalendar : NSObject <NSCoding, NSCopying>
{
@private
  void  *_NSCalendarInternal;
/* FIXME ... remove dummy fields at next binary incompatible release
 */
  void  *_dummy1;
  void  *_dummy2;
  void  *_dummy3;
}

/**
 * Returns the current calendar.
 */
+ (id) currentCalendar;

/**
 * Create a calendar with the given string as identifier.
 */
+ (id) calendarWithIdentifier: (NSString *) string;

/**
 * Instantiate a calendar with the given string as identifier.
 */
- (id) initWithCalendarIdentifier: (NSString *) string;

/**
 * Returns the calendar identifier for the receiver.
 */
- (NSString *) calendarIdentifier;

/**
 * Returns the calendar units specified by unitFlags for the given date object.
 */
- (NSDateComponents *) components: (NSUInteger) unitFlags
                         fromDate: (NSDate *) date;
/**
 * Compute the different between the specified components in the two dates.
 * Values are summed up as long as now higher-granularity unit is specified.
 * That means if you want to extract the year and the day from two dates
 * which are 13 months + 1 day apart, you will get 1 as the result for the year
 * but the rest of the difference in days. (29 &lt;= x &lt;= 32, depending
 * on the month). 
 *
 * Please note that the NSWrapCalendarComponents option that should affect the
 * calculations is not presently supported.
 */
- (NSDateComponents *) components: (NSUInteger) unitFlags
                         fromDate: (NSDate *) startingDate
                           toDate: (NSDate *) resultDate
                          options: (NSUInteger) opts;

/**
 * Returns a date object created by adding the NSDateComponents in comps to
 * to object date with the options specified by opts.
 */
- (NSDate *) dateByAddingComponents: (NSDateComponents *) comps
                             toDate: (NSDate *) date
                            options: (NSUInteger) opts;

/**
 * Creates an NSDate from NSDateComponents in comps.
 */
- (NSDate *) dateFromComponents: (NSDateComponents *) comps;

/**
 * Returns the locale of the receiver.
 */
- (NSLocale *) locale;

/**
 * Sets the locale of the receiver.
 */
- (void)setLocale: (NSLocale *) locale;

/**
 * Returns the integer value of the first weekday (0-6).
 */
- (NSUInteger) firstWeekday;

/**
 * Set the integer first weekday of the week (0-6).
 */
- (void) setFirstWeekday: (NSUInteger) weekday;

/**
 * Returns the minimum number of days in the first week of the receiver.
 */
- (NSUInteger) minimumDaysInFirstWeek;

/**
 * Sets the minimum number of days in the first week of the receiver.
 */
- (void) setMinimumDaysInFirstWeek: (NSUInteger) mdw;

/**
 * Returns the NSTimeZone associated with the receiver.
 */
- (NSTimeZone *) timeZone;

/**
 * Sets tz as the current NSTimeZone of the receiver.
 */
- (void) setTimeZone: (NSTimeZone *) tz;

/**
 * Returns the maximum range of unit.
 */
- (NSRange) maximumRangeOfUnit: (NSCalendarUnit) unit;

/**
 * Returns the minimum range of unit.
 */
- (NSRange) minimumRangeofUnit: (NSCalendarUnit) unit;

/**
 * Returns the ordinality of unit smaller within the
 * unit larger with the given date.
 */
- (NSUInteger) ordinalityOfUnit: (NSCalendarUnit) smaller
                         inUnit: (NSCalendarUnit) larger
                        forDate: (NSDate *) date;

/**
 * Returns the range of unit smaller in larger in date.
 */
- (NSRange) rangeOfUnit: (NSCalendarUnit) smaller
                 inUnit: (NSCalendarUnit) larger
                forDate: (NSDate *) date;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_5, GS_API_LATEST)
/**
 * A calendar that tracks changes to the user's calendar.
 */
+ (id) autoupdatingCurrentCalendar;

/**
 * Returns by referene the started time and duration of a given unit containing the given date.
 */ 
- (BOOL) rangeOfUnit: (NSCalendarUnit) unit
           startDate: (NSDate **) datep
            interval: (NSTimeInterval *)tip
             forDate: (NSDate *)date;
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_9, GS_API_LATEST)
/**
 * Returns by reference the era, year, month, and day from the given date.
 */
- (void) getEra: (NSInteger *)eraValuePointer
           year: (NSInteger *)yearValuePointer
          month: (NSInteger *)monthValuePointer
            day: (NSInteger *)dayValuePointer
       fromDate: (NSDate *)date;

/**
 * Returns by reference the hour, minute, second, and nanosecond from the given date.
 */
- (void) getHour: (NSInteger *)hourValuePointer
          minute: (NSInteger *)minuteValuePointer
          second: (NSInteger *)secondValuePointer
      nanosecond: (NSInteger *)nanosecondValuePointer
        fromDate: (NSDate *)date;

/**
 * Returns by reference the era, year, week of year, and weekday from the given date.
 */
- (void) getEra: (NSInteger *)eraValuePointer 
yearForWeekOfYear: (NSInteger *)yearValuePointer 
     weekOfYear: (NSInteger *)weekValuePointer 
        weekday: (NSInteger *)weekdayValuePointer 
       fromDate: (NSDate *)date;

/**
 * Returns the integer value of the specified unit from the given date.
 */
- (NSInteger) component: (NSCalendarUnit)unit 
               fromDate: (NSDate *)date;
#endif

@end

#if	defined(__cplusplus)
}
#endif

#endif /* OS_API_VERSION(MAC_OS_X_VERSION_10_4, GS_API_LATEST) */

#endif /* __NSCalendar_h_GNUSTEP_BASE_INCLUDE */
