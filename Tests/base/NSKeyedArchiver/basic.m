#import <Foundation/Foundation.h>
#import "ObjectTesting.h"
int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];

  test_alloc_only(@"NSKeyedArchiver");
  test_NSObject(@"NSKeyedArchiver", [NSArray arrayWithObject:
    AUTORELEASE([[NSKeyedArchiver alloc] initForWritingWithMutableData:
      [NSMutableData data]])]);
  test_alloc_only(@"NSKeyedUnarchiver");  
  test_NSObject(@"NSKeyedUnarchiver", [NSArray arrayWithObject:
    AUTORELEASE([[NSKeyedUnarchiver alloc] initForReadingWithData:
      [NSKeyedArchiver archivedDataWithRootObject: [NSData data]]])]);
  
  [arp release]; arp = nil;
  return 0;
}
