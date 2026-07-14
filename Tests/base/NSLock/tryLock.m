#import <Foundation/Foundation.h>
#import "Testing.h"

int main()
{
  NSAutoreleasePool   	*arp = [NSAutoreleasePool new];
  BOOL 			ret;
  id			lock = nil;
  
  lock = AUTORELEASE([NSLock new]);
  ret = [lock tryLock];
  if (ret)
    [lock unlock];
  PASS(ret, "NSLock with tryLock, then unlocking");
 
  lock =  AUTORELEASE([NSLock new]);
  [lock tryLock];
  ret = [lock tryLock];
  if (ret)
    [lock unlock];
  PASS(ret == NO, "Recursive try lock with NSLock should return NO"); 
  
  lock =  AUTORELEASE([NSConditionLock new]);
  [lock lock];
  ret = [lock tryLock];
  if (ret)
    [lock unlock];
  PASS(ret == NO, "Recursive try lock with NSConditionLock should return NO"); 
  
  ret = [lock tryLockWhenCondition: 42];
  if (ret)
    [lock unlock];
  PASS(ret == NO, "Recursive tryLockWhenCondition: with NSConditionLock (1) should return NO"); 
  [lock unlockWithCondition: 42];
  [lock lock];
  ret = [lock tryLockWhenCondition: 42];
  if (ret)
    [lock unlock];
  PASS(ret == NO, "Recursive tryLockWhenCondition: with NSConditionLock (2) should return NO"); 
  
  lock = AUTORELEASE([NSRecursiveLock new]);
  [lock tryLock];
  ret = [lock tryLock];
  if (ret)
    [lock unlock];
  PASS(ret == YES, "Recursive try lock with NSRecursiveLock should return YES"); 
  
  lock = AUTORELEASE([NSLock new]);
  ret = [lock lockBeforeDate: [NSDate dateWithTimeIntervalSinceNow: 1]];
  if (ret)
    [lock unlock];
  PASS(ret, "NSLock lockBeforeDate: works");
  
  lock = AUTORELEASE([NSLock new]);
  [lock tryLock];
  ret = [lock lockBeforeDate: [NSDate dateWithTimeIntervalSinceNow: 1]];
  if (ret)
    [lock unlock];
  PASS(ret == NO, "Recursive lockBeforeDate: with NSLock returns NO");
  
  lock = AUTORELEASE([NSConditionLock new]);
  [lock tryLock];
  ret = [lock lockBeforeDate: [NSDate dateWithTimeIntervalSinceNow: 1]];
  if (ret)
    [lock unlock];
  PASS(ret == NO, "Recursive lockBeforeDate: with NSConditionLock returns NO");
  
  lock = AUTORELEASE([NSRecursiveLock new]);
  [lock tryLock];
  ret = [lock lockBeforeDate: [NSDate dateWithTimeIntervalSinceNow: 1]];
  if (ret)
    [lock unlock];
  PASS(ret == YES, "Recursive lockBeforeDate: with NSRecursiveLock returns YES");
  
  [arp release]; arp = nil;
  return 0;
}

