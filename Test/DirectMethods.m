#include "Test.h"

#if !__has_attribute(objc_direct)
int main()
{
	return 77;
}
#else

static BOOL initializeCalled;
static BOOL directMethodCalled;

@interface HasDirect : Test
+ (void)clsDirect __attribute__((objc_direct));
- (int)instanceDirect __attribute__((objc_direct));
@end
@implementation HasDirect
+ (void)initialize
{
	initializeCalled = YES;
}
+ (void)clsDirect
{
	directMethodCalled = YES;
}
- (int)instanceDirect
{
	return 42;
}
@end

int main(void)
{
	[HasDirect clsDirect];
	assert(directMethodCalled);
	assert(initializeCalled);
	HasDirect *obj = [HasDirect new];
	assert([obj instanceDirect] == 42);
	obj = nil;
	assert([obj instanceDirect] == 0);
	return 0;
}


#endif
