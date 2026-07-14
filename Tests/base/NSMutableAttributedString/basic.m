#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSAttributedString.h>
#import "ObjectTesting.h"
int main()
{
  ENTER_POOL
  NSArray *arr;
  
  arr = [NSArray arrayWithObject: AUTORELEASE([NSMutableAttributedString new])];
  test_alloc(@"NSMutableAttributedString");
  test_NSObject(@"NSMutableAttributedString", arr);
  test_NSCoding(arr);
  test_keyed_NSCoding(arr);
  test_NSCopying(@"NSAttributedString",@"NSMutableAttributedString",arr,NO, NO);
  test_NSMutableCopying(@"NSAttributedString",@"NSMutableAttributedString",arr);

  LEAVE_POOL
  return 0;
}

