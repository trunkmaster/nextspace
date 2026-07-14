#import "Testing.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSObject.h>
/* Nicola Pero, Tue Dec 18 17:54:53 GMT 2001 */
@protocol DoingNothing
- (void) doNothing;
@end

@protocol DoingNothingCategory
- (void) doNothingCategory;
@end


@interface NicolaTest : NSObject <DoingNothing>
{
}
@end

@implementation NicolaTest
- (void) doNothing
{
  return;
}
@end

@interface NicolaTest (Category) <DoingNothingCategory>
@end

@implementation NicolaTest (Category)
- (void) doNothingCategory
{
  return;
}
@end


int main()
{
  ENTER_POOL
  id	instance = AUTORELEASE([NicolaTest new]);

  PASS([NicolaTest conformsToProtocol:@protocol(DoingNothing)],
       "+conformsToProtocol returns YES on an implemented protocol");
  PASS([NicolaTest conformsToProtocol:@protocol(DoingNothingCategory)],
       "+conformsToProtocol returns YES on a protocol implemented in a category");
  PASS(![NicolaTest conformsToProtocol:@protocol(NSCoding)],
       "+conformsToProtocol returns NO on an unimplemented protocol");
  PASS([instance conformsToProtocol:@protocol(DoingNothing)],
       "-conformsToProtocol returns YES on an implemented protocol");
  PASS([instance conformsToProtocol:@protocol(DoingNothingCategory)],
       "-conformsToProtocol returns YES on a protocol implemented in a category"); 
  PASS(![instance conformsToProtocol:@protocol(NSCoding)],
       "-conformsToProtocol returns NO on an unimplemented protocol");

  LEAVE_POOL
  return 0;
}
