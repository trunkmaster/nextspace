#import <Foundation/NSNotification.h>
#import <Foundation/NSAutoreleasePool.h>
#import "ObjectTesting.h"

@implementation NSNotification (Testing)
- (BOOL) isEqualForTestcase: (id)other
{
  if (NO == [other isKindOfClass: [NSNotification class]])
    return NO;
  if ([self name] != [other name]
    && NO == [[self name] isEqual: [other name]])
    return NO;
  if ([self object] != [other object]
    && NO == [[self object] isEqual: [other object]])
    return NO;
  if ([self userInfo] != [other userInfo]
    && NO == [[self userInfo] isEqual: [other userInfo]])
    return NO;
  return YES;
}
@end

int main()
{
  ENTER_POOL
  NSNotification 	*obj;
  NSMutableArray 	*testObjs = [NSMutableArray array];
  NSDictionary          *info = [NSDictionary dictionaryWithObjectsAndKeys:
    @"obj", @"key", nil];
  NSNotification        *o1 = [NSNotification notificationWithName: @"hello"
                                                            object: @"there"
                                                          userInfo: info]; 
  NSNotification        *o2 = [NSNotification notificationWithName: @"hello"
                                                            object: @"there"
                                                          userInfo: info]; 

  PASS([o1 hash] == [o2 hash], "equal notification hashes")
  PASS_EQUAL(o1, o2, "equal notifications")

  test_alloc(@"NSNotification"); 

  obj = AUTORELEASE([NSNotification new]);
  [testObjs addObject: obj];
  test_NSObject(@"NSNotification", testObjs);
  test_NSCoding(testObjs);
  test_keyed_NSCoding(testObjs);
  test_NSCopying(@"NSNotification",@"NSNotification",testObjs,NO,NO);
  
  LEAVE_POOL
  return 0;
}
