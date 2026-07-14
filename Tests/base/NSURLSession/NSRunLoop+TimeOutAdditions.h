#import <Foundation/NSDate.h>
#import <Foundation/NSRunLoop.h>

@interface
NSRunLoop (TimeOutAdditions)
- (void)runForSeconds:(NSTimeInterval)seconds conditionBlock:(BOOL (^)())block;
@end

@implementation
NSRunLoop (TimeOutAdditions)
- (void)runForSeconds:(NSTimeInterval)seconds conditionBlock:(BOOL (^)())block
{
  NSDate        *startDate = [NSDate date];
  NSTimeInterval endTime = [startDate timeIntervalSince1970] + seconds;
  NSTimeInterval interval = 0.1; // Interval to check the condition

  while (block() && [[NSDate date] timeIntervalSince1970] < endTime)
    {
      @autoreleasepool
      {
        [[NSRunLoop currentRunLoop]
          runUntilDate:[NSDate dateWithTimeIntervalSinceNow:interval]];
      }
    }
}
@end