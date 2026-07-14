#include "Test.h"

#define POOL_SIZE (4096 / sizeof(void*))

static BOOL called;

@interface Canary : Test
@end
@implementation Canary
- (void)dealloc
{
	called = YES;
	[super dealloc];
}
@end

@interface Creator : Test
@end
@implementation Creator
- (void)dealloc
{
	// Add a new page of autorelease references to see if we can still release
	// the reference on the canary object.
	for (int i = 0; i < POOL_SIZE; i++)
		[[Test new] autorelease];
	[super dealloc];
}
@end

int main()
{
	called = NO;
	@autoreleasepool
	{
		[[Canary new] autorelease];
		[[Creator new] autorelease];
	}
	assert(called == YES);

	return 0;
}
