#import <Foundation/NSProgress.h>
#import <Foundation/NSThread.h>
#import <Foundation/NSAutoreleasePool.h>
#import "ObjectTesting.h"

int main()
{
  ENTER_POOL
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];

  [dict setObject:@"value" forKey:@"key"];
  NSProgress *progress = AUTORELEASE([[NSProgress alloc] initWithParent: nil
							       userInfo: dict]);
  PASS(progress != nil,
    "[NSProgress initWithParent:userInfo:] returns instance");
  
  PASS_EQUAL([progress userInfo], dict,
    "[NSProgress userInfo] returns correct user info");
  
  [progress setUserInfoObject:@"new value" forKey:@"key"];
  PASS_EQUAL([[progress userInfo] objectForKey:@"key"], @"new value",
    "[NSProgress setUserInfoObject:forKey:] updates user info");
  
  progress = [NSProgress discreteProgressWithTotalUnitCount:100];
  PASS(progress != nil,
    "[NSProgress discreteProgressWithTotalUnitCount:] returns instance");
  
  progress = [NSProgress progressWithTotalUnitCount:100];
  PASS(progress != nil,
    "[NSProgress progressWithTotalUnitCount:] returns instance");
  
  progress = [NSProgress progressWithTotalUnitCount:100
                                             parent:progress
                                   pendingUnitCount:50];
  PASS(progress != nil,
    "[NSProgress progressWithTotalUnitCount:] returns instance");
  
  [progress becomeCurrentWithPendingUnitCount:50];
  NSProgress *currentProgress = [NSProgress currentProgress];
  PASS(currentProgress == progress,
    "Correct progress object associated with current thread");
  
  NSProgress *new_progress = [NSProgress progressWithTotalUnitCount:100
                                                             parent:progress
                                                   pendingUnitCount:50];
  [new_progress addChild: AUTORELEASE([[NSProgress alloc]
    initWithParent: nil userInfo: nil]) withPendingUnitCount:50];
  
  [currentProgress resignCurrent];

  PASS([NSProgress currentProgress] == nil,
    "Current progress is nil after resign current");

  LEAVE_POOL
  return 0;
}
