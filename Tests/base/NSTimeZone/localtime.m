#import "ObjectTesting.h"
#include <Foundation/NSTimeZone.h>

#define PREFIX "./"

static void
testTZDB(NSString *fileName, const char *message, bool beyond2038)
{
   NSTimeZone *timeZone;
   NSDate *date;
   NSData *tzdata;

   /* Test using TZDB file known as being v1 */
   tzdata = [NSData dataWithContentsOfFile: fileName];
   PASS(tzdata != nil && [tzdata isKindOfClass: [NSData class]] && 
     [tzdata length] > 0, "Loading user-supplied %s works", message);

   timeZone =  [NSTimeZone timeZoneWithName: fileName data: tzdata];
   PASS(timeZone != nil && [timeZone isKindOfClass: [NSTimeZone class]],
       "+timeZoneWithName data works");

   /* Before last transition in TZDB v2+ file */
   date = [NSDate dateWithString: @"1981-01-16 23:59:59 -0100"];
   PASS([timeZone secondsFromGMTForDate: date] == 3600,
	"pre-1996 standard time offset vs UTC found for user-supplied %s", 
	message);

   date = [NSDate dateWithString: @"1981-08-16 23:59:59 -0200"];
   PASS([timeZone secondsFromGMTForDate: date] == 7200,
	"pre-1996 DST time offset vs UTC found for user-supplied %s",
	message);

   /* After last transition in TZDB v2+ file */
   date = [NSDate dateWithString: @"2021-01-16 23:59:59 -0100"];
   PASS([timeZone secondsFromGMTForDate: date] == 3600,
	"post-1996 standard time offset vs UTC found for user-supplied %s",
	message);

   date = [NSDate dateWithString: @"2021-08-16 23:59:59 -0200"];
   PASS([timeZone secondsFromGMTForDate: date] == 7200,
	"post-1996 DST time offset vs UTC found for user-supplied %s",
	message);

#if __LP64__
   /* After 32bit value seconds-since-1970 using TZDB v2+ file */
   if (beyond2038) {
     date = [NSDate dateWithString: @"2039-01-16 23:59:59 -0200"];
     PASS([timeZone secondsFromGMTForDate: date] == 3600,
	  "post-2038 standard time offset vs UTC found for user-supplied %s",
	  message);
   }
#endif

  return;
}

int main(void)
{
   NSAutoreleasePool   *arp = [NSAutoreleasePool new];
   NSTimeZone *timeZone;
   NSDate *date;

   timeZone =  [NSTimeZone timeZoneWithName: @"Europe/Paris"];
   PASS(timeZone != nil && [timeZone isKindOfClass: [NSTimeZone class]],
       "+timeZoneWithName works");

   /* Before last transition in TZDB v2+ file */
   date = [NSDate dateWithString: @"1981-01-16 23:59:59 -0100"];
   PASS([timeZone secondsFromGMTForDate: date] == 3600, 
	"pre-1996 standard time offset vs UTC found for System Europe/Paris");

   date = [NSDate dateWithString: @"1981-08-16 23:59:59 -0200"];
   PASS([timeZone secondsFromGMTForDate: date] == 7200,
	"pre-1996 DST time offset vs UTC found for System Europe/Paris");

   /* After last transition in TZDB v2+ file */
   date = [NSDate dateWithString: @"2021-01-16 23:59:59 -0100"];
   PASS([timeZone secondsFromGMTForDate: date] == 3600,
	"post-1996 standard time offset vs UTC found for System Europe/Paris");

   date = [NSDate dateWithString: @"2021-08-16 23:59:59 -0200"];
   PASS([timeZone secondsFromGMTForDate: date] == 7200,
	"post-1996 DST time offset vs UTC found for System Europe/Paris");

   testTZDB(@ PREFIX "ParisV1.tzdb", "Europe/Paris TZDB v1", false);
   testTZDB(@ PREFIX "ParisV2.tzdb", "Europe/Paris TZDB v2", true);
   testTZDB(@ PREFIX "ParisV1-noMagic.tzdb",
	    "buggy Europe/Paris TZDB v1 without magic", false);
   testTZDB(@ PREFIX "ParisV2-missingHeader.tzdb",
	    "buggy Europe/Paris TZDB v2 without v2 header", true);

   [arp release]; arp = nil;
   return 0;
}
