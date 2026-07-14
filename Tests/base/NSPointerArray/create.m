#import "ObjectTesting.h"
#import <Foundation/NSPointerArray.h>
#import <Foundation/NSAutoreleasePool.h>

int main()
{
  ENTER_POOL
  NSString *val1, *val2, *val3;
  NSPointerArray *obj;
  id vals[3];
  
  val1 = @"Hello";
  val2 = @"Goodbye";
  val3 = @"Testing";
  
  vals[0] = val1;
  vals[1] = val2;
  vals[2] = val3;

  obj = AUTORELEASE([NSPointerArray new]);
  PASS(obj != nil
    && [obj isKindOfClass: [NSPointerArray class]]
    && [obj count] == 0,
    "+new creates an empty pointer array");
  
  [obj addPointer: (void*)@"hello"];
  PASS([obj count] == 1, "+addPointer: increments count");
  [obj addPointer: nil];
  PASS([obj count] == 2, "+addPointer: works with nil");
  [obj addPointer: nil];
  PASS([obj count] == 3, "+addPointer: respects duplicate values");

  [obj insertPointer: (void*)vals[0] atIndex: 0];
  [obj insertPointer: (void*)vals[1] atIndex: 0];
  [obj insertPointer: (void*)vals[2] atIndex: 0];
  PASS([obj count] == 6 && [obj pointerAtIndex: 2] == (void*)vals[0],
    "+insertPointer:atIndex: works");
  
  LEAVE_POOL

  ENTER_POOL
  NSPointerArray	*pa = [NSPointerArray weakObjectsPointerArray];
  NSMutableString	*ms = AUTORELEASE([@"hello" mutableCopy]);
  NSUInteger 		rc = [ms retainCount];

  [pa addPointer: ms];
  PASS(rc == [ms retainCount], "array with weak references doesn't retain")
  LEAVE_POOL

  return 0;
} 

