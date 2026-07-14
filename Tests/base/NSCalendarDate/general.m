#import "Testing.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDate.h>

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  NSDate *cdate, *date1, *date2;
  NSComparisonResult comp;
  
  cdate = [NSCalendarDate date];
  
  comp = [cdate compare: [NSDate distantFuture]];
  PASS(comp == NSOrderedAscending, "+distantFuture is in the future");
  
  comp = [cdate compare: [NSDate distantPast]];
  PASS(comp == NSOrderedDescending, "+distantPast is in the past");
  
  date1 = [NSDate dateWithTimeIntervalSinceNow: -600];
  date2 = [cdate earlierDate: date1];
  PASS(date1 == date2, "-earlierDate works for different dates");
  
  date2 = [cdate laterDate: date1];
  PASS(cdate == date2, "-laterDate works for different dates");
  
  date1 = [NSDate dateWithTimeIntervalSinceReferenceDate:
    [cdate timeIntervalSinceReferenceDate]];

  date2 = [cdate earlierDate: date1];
  PASS(cdate == date2, "-earlierDate works for equal dates");

  date2 = [date1 earlierDate: cdate];
  PASS(date1 == date2, "-earlierDate works for equal dates swapped");
  
  date2 = [cdate laterDate: date1];
  PASS(cdate == date2, "-laterDate works for equal dates");

  date2 = [date1 laterDate: cdate];
  PASS(date1 == date2, "-laterDate works for equal dates swapped");
  
  date2 = [date1 addTimeInterval: 0];
  PASS ([date1 isEqualToDate:date2], "-isEqualToDate works");

  
  [arp release]; arp = nil;
  return 0;
}

