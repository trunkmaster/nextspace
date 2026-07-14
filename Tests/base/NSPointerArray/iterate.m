#import "ObjectTesting.h"
#import <Foundation/NSPointerArray.h>
#import <Foundation/NSAutoreleasePool.h>

#if defined(__clang__)

int main()
{
  ENTER_POOL
  NSPointerArray *obj = AUTORELEASE([NSPointerArray new]);
  NSString *str = @"test";
  NSString *str2 = @"string";

  // Fast iteration over empty pointer array
  for (id ptr in obj) {
    PASS(0, "No element returned by fast iteration");
  }

  [obj addPointer: str];
  [obj addPointer: str2];
  [obj addPointer: nil];
  [obj addPointer: nil];
  
  int count = 0;
  for (id ptr in obj) {
    count += 1;
    switch (count) {
        case 1:
            PASS(ptr == str, "first obj returned is pointer to 'test'");
            break;
        case 2:
            PASS(ptr == str2, "second obj returned is pointer to 'string'");
            break;
        case 3:
        case 4:
            PASS(ptr == nil, "third and fourth pointers are nil");
            break;
        default:
            PASS(0, "unexpected count of pointers");
    }
  }
  PASS(count == 4, "got 4 pointers in fast iteration");

  LEAVE_POOL

  return 0;
} 

#else

int main()
{
  return 0;
}

#endif

