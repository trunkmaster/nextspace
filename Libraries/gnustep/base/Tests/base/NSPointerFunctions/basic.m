#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSPointerFunctions.h>

int main()
{
  NSAutoreleasePool     *arp = [NSAutoreleasePool new];
  NSPointerFunctions    *testObj;
  NSPointerFunctions    *aCopy;

  testObj = [[NSPointerFunctions new] autorelease];
  test_alloc(@"NSPointerFunctions");

  testObj = [NSPointerFunctions pointerFunctionsWithOptions:
    NSPointerFunctionsCStringPersonality];
  aCopy = AUTORELEASE([testObj copy]);
  PASS ([aCopy acquireFunction] == [testObj acquireFunction],
    "acquireFunction is copied");
  PASS ([aCopy descriptionFunction] == [testObj descriptionFunction],
    "descriptionFunction is copied");
  PASS ([aCopy hashFunction] == [testObj hashFunction],
    "hashFunction is copied");
  PASS ([aCopy isEqualFunction] == [testObj isEqualFunction],
    "isEqualFunction is copied");
  PASS ([aCopy relinquishFunction] == [testObj relinquishFunction],
    "relinquishFunction is copied");
  PASS ([aCopy sizeFunction] == [testObj sizeFunction],
    "sizeFunction is copied");
  
  [arp release]; arp = nil;
  return 0;
}
