#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSException.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSData.h>
#import "Testing.h"
#import "ObjectTesting.h"

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  id 			obj;
  NSMutableData     	*data1;

  data1 = [NSMutableData dataWithLength: 0];
  obj = AUTORELEASE([[NSKeyedArchiver alloc]
    initForWritingWithMutableData: data1]);
  PASS((obj != nil && [obj isKindOfClass: [NSKeyedArchiver class]]),
    "-initForWritingWithMutableData seems ok")

  PASS_EXCEPTION(AUTORELEASE([[NSUnarchiver alloc]
    initForReadingWithData: nil]);, 
    @"NSInvalidArgumentException",
    "Creating an NSUnarchiver with nil data throws an exception")
  
  [arp release]; arp = nil;
  return 0; 
}
