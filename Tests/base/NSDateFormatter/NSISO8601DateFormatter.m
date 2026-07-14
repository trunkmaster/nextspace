#import <Foundation/NSCalendar.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSISO8601DateFormatter.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSLocale.h>
#import <Foundation/NSTimeZone.h>
#import "Testing.h"

#if	defined(GS_USE_ICU)
#define	IS_SUPPORTED	GS_USE_ICU
#else
#define	IS_SUPPORTED	0
#endif

int main(void)
{
  NSTimeZone			*tz;
  NSISO8601DateFormatter	*fmt;
  NSDate			*date;
  NSString 			*estr;
  NSString 			*istr;
  NSString 			*ostr;
  
  START_SET("NSISO8601DateFormatter")
  if (!IS_SUPPORTED)
    SKIP("NSISO8601DateFormatter not supported\nThe ICU library was not available when GNUstep-base was built")

    tz = [NSTimeZone timeZoneWithName: @"GMT"];
    [NSTimeZone setDefaultTimeZone: tz];
    
    fmt = [[NSISO8601DateFormatter alloc] init];
    estr = @"2011-01-27T17:36:00Z";
    istr = @"2011-01-27T17:36:00+00:00";
    date = [fmt dateFromString: istr];
    RELEASE(fmt);

    fmt = [NSISO8601DateFormatter new];
    ostr = [fmt stringFromDate: date];
    RELEASE(fmt);

    PASS_EQUAL(ostr, estr, "date format matches for GMT")
    
    
    fmt = [[NSISO8601DateFormatter alloc] init];
    estr = @"2011-08-27T16:36:00Z";
    istr = @"2011-08-27T17:36:00+01:00";
    date = [fmt dateFromString: istr];
    RELEASE(fmt);

    tz = [NSTimeZone timeZoneWithName: @"AWST"];
    fmt = [NSISO8601DateFormatter new];
    [fmt setTimeZone: tz];
    ostr = [fmt stringFromDate: date];
    RELEASE(fmt);

    PASS_EQUAL(ostr, estr, "date format matches for AWST")
    
  END_SET("NSISO8601DateFormatter")

  return 0;
}

