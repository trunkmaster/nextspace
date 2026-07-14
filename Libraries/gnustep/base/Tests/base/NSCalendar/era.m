#import "Testing.h"
#import "ObjectTesting.h"
#import <Foundation/NSCalendar.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSLocale.h>
#import <Foundation/NSDateFormatter.h>
#import <Foundation/NSDate.h>
#include <stdio.h>

#if	defined(GS_USE_ICU)
#define	NSCALENDAR_SUPPORTED	GS_USE_ICU
#else
#define	NSCALENDAR_SUPPORTED	1 /* Assume Apple support */
#endif

int main()
{
  NSCalendar *cal;
  NSDate *date;
  NSDateFormatter *dateFormatter;
  NSInteger era = 0;
  NSInteger year = 0;
  NSInteger month = 0;
  NSInteger day = 0;
  NSInteger hour = 0;
  NSInteger min = 0;
  NSInteger sec = 0;
  NSInteger nano = 0;
  

  START_SET("NSCalendar getEra:year:month:day:fromDate and getHour:minute:second:nanosecond:fromDate tests");
  /* Test getEra:year:month:day:fromDate:
   */
  dateFormatter = AUTORELEASE([[NSDateFormatter alloc] init]);
  [dateFormatter setLocale: AUTORELEASE([[NSLocale alloc]
    initWithLocaleIdentifier: [NSLocale
      canonicalLocaleIdentifierFromString: @"en_US"]])];
  cal = [NSCalendar currentCalendar];
  [cal setTimeZone: [NSTimeZone timeZoneWithName: @"America/New_York"]];
  [dateFormatter setDateFormat: @"d MMM yyyy HH:mm:ss Z"];
  date = [dateFormatter dateFromString: @"22 Nov 1969 08:15:00 Z"];
  
  [cal getEra: &era year: &year month: &month day: &day fromDate: date];

  PASS(era == 1, "getEra:year:month:day:fromDate: returns correct era")
  PASS(year == 1969, "getEra:year:month:day:fromDate: returns correct year")
  PASS(month == 11, "getEra:year:month:day:fromDate: returns correct month")
  PASS(day == 22, "getEra:year:month:day:fromDate: returns correct day")
  
  /* Test getHour:minute:second:nanosecond:fromDate:
   */
  [cal getHour: &hour
	minute: &min
	second: &sec
    nanosecond: &nano
      fromDate: date];

  PASS(hour == 3, "getHour:minute:second:nanosecond:fromDate:"
    " returns correct hour")
  PASS(min == 15, "getHour:minute:second:nanosecond:fromDate:"
    " returns correct minute")
  PASS(sec == 0, "getHour:minute:second:nanosecond:fromDate:"
    " returns correct second")
  PASS(nano == 0, "getHour:minute:second:nanosecond:fromDate:"
    " returns correct nanosecond")
  
  END_SET("NSCalendar getEra:year:month:day:fromDate and getHour:minute:second:nanosecond:fromDate tests");
  return 0;
}
