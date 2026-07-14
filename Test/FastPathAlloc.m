#if __clang_major__ < 18 || (__clang_major__ == 18 && __clang_minor__ < 1)
// Skip this test if clang is too old to support it.
int main(void)
{
	return 77;
}
#else
#include "Test.h"
#include <stdio.h>

static BOOL called;

typedef struct _NSZone NSZone;

@interface ShouldAlloc : Test @end
@interface ShouldAllocWithZone : Test @end
@interface ShouldInit : Test @end
@interface ShouldInit2 : Test @end

@interface NoAlloc : Test @end
@interface NoInit : Test @end
@interface NoInit2 : NoInit @end

@interface ShouldInitSubclassed : NoInit @end

@implementation ShouldAlloc
+ (instancetype)alloc
{
	called = YES;
	fprintf(stderr, "[%s %s] called\n", class_getName(object_getClass(self)), sel_getName(_cmd));
	return [super alloc];
}
@end
@implementation ShouldAllocWithZone
+ (instancetype)allocWithZone: (NSZone*)aZone
{
	called = YES;
	fprintf(stderr, "[%s %s] called\n", class_getName(object_getClass(self)), sel_getName(_cmd));
	return [super alloc];
}
@end
@implementation ShouldInit
- (instancetype)init
{
	called = YES;
	fprintf(stderr, "[%s %s] called\n", class_getName(object_getClass(self)), sel_getName(_cmd));
	return self;
}
@end
@implementation ShouldInit2
+ (instancetype)alloc
{
	fprintf(stderr, "[%s %s] called\n", class_getName(object_getClass(self)), sel_getName(_cmd));
	return [super alloc];
}
- (instancetype)init
{
	called = YES;
	fprintf(stderr, "[%s %s] called\n", class_getName(object_getClass(self)), sel_getName(_cmd));
	return self;
}
@end

@implementation NoAlloc
+ (void)_TrivialAllocInit{}
+ (instancetype)alloc
{
	called = YES;
	fprintf(stderr, "[%s %s] called\n", class_getName(object_getClass(self)), sel_getName(_cmd));
	return [super alloc];
}
+ (instancetype)allocWithZone: (NSZone*)aZone
{
	called = YES;
	fprintf(stderr, "[%s %s] called\n", class_getName(object_getClass(self)), sel_getName(_cmd));
	return [super alloc];
}
@end
@implementation NoInit
+ (void)_TrivialAllocInit{}
- (instancetype)init
{
	called = YES;
	fprintf(stderr, "[%s %s] called\n", class_getName(object_getClass(self)), sel_getName(_cmd));
	return self;
}
@end
@implementation NoInit2
+ (instancetype)alloc
{
	fprintf(stderr, "[%s %s] called\n", class_getName(object_getClass(self)), sel_getName(_cmd));
	return [super alloc];
}
@end

@implementation ShouldInitSubclassed
+ (instancetype) alloc
{
	return [ShouldInit alloc];
}
@end

Class getClassNamed(char *name)
{
	return nil;
}

int main(void)
{
	called = NO;
	[ShouldAlloc alloc];
	assert(called);

	[ShouldAllocWithZone allocWithZone: NULL];
	assert(called);
	called = NO;

	called = NO;
	[[ShouldInit alloc] init];
	assert(called);

	called = NO;
	[[ShouldInit2 alloc] init];
	assert(called);

	called = NO;
	[[ShouldInitSubclassed alloc] init];
	assert(called);

	called = NO;
	[NoAlloc alloc];
	assert(!called);

	[NoAlloc allocWithZone: NULL];
	assert(!called);
	called = NO;

	called = NO;
	[[NoInit alloc] init];
	assert(!called);

	called = NO;
	[[NoInit2 alloc] init];
	assert(!called);

	// Look up a non-existing class to test if fast-path
	// implementations can handle receivers that are nil
	[getClassNamed("flibble") alloc];
	[[getClassNamed("flibble") alloc] init];
}

#endif
