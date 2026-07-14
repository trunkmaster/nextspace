#include "Test.h"

void direct_saturation_test();

@interface TestWithDelloc : Test
@end

@implementation TestWithDelloc
- (void)dealloc
{
	id obj = nil;
	objc_storeStrong(&obj, self);
	assert(obj == self);
	assert(object_getRetainCount_np(obj) == 0);
	[super dealloc];
}
@end

int main()
{
	id obj = [Test new];
	assert(object_getRetainCount_np(obj) == 1);
	
	for (int i = 0; i < 2; i++)
	{
		size_t count = object_getRetainCount_np(obj);
		id ret = objc_retain_fast_np(obj);
		assert(ret == obj);
		assert(object_getRetainCount_np(obj) == ++count);
	}
	
	for (int i = 0; i < 2; i++)
	{
		size_t count = object_getRetainCount_np(obj);
		BOOL destroy = objc_release_fast_no_destroy_np(obj);
		assert(destroy == NO);
		assert(object_getRetainCount_np(obj) == --count);
	}
	
	{
		// Final release should prevent further retains and releases.
		assert(objc_release_fast_no_destroy_np(obj) == YES);
		assert(object_getRetainCount_np(obj) == 0);
		assert(objc_retain_fast_np(obj) == obj);
		assert(object_getRetainCount_np(obj) == 0);
		assert(objc_release_fast_no_destroy_np(obj) == NO);
		assert(object_getRetainCount_np(obj) == 0);
	}
	
	object_dispose(obj);
	obj = [Test new];
	
	{
		// Should not be able to delete weak refs until final release.
		id weak;
		assert(objc_initWeak(&weak, obj) == obj);
		assert(weak != nil);
		assert(objc_loadWeakRetained(&weak) == obj);
		assert(objc_release_fast_no_destroy_np(obj) == NO);
		// Assumes a return of NO means no effect on obj at all.
		assert(objc_delete_weak_refs(obj) == NO);
		assert(objc_loadWeakRetained(&weak) == obj);
		assert(objc_release_fast_no_destroy_np(obj) == NO);
		// This will also call objc_delete_weak_refs() and succeed.
		assert(objc_release_fast_no_destroy_np(obj) == YES);
		objc_destroyWeak(&weak);
		// Check what happens when the weak refs were already deleted.
		assert(objc_delete_weak_refs(obj) == YES);
	}
	
	object_dispose(obj);
	// Check we can use strong references inside a dealloc method.
	obj = [TestWithDelloc new];
	[obj release];
	obj = nil;
	
	direct_saturation_test();
	return 0;
}


// ----------------
// This test has knowledge of the implementation details of the ARC
// reference counting and may need modification if the details change.

const long refcount_shift = 1;
const size_t weak_mask = ((size_t)1)<<((sizeof(size_t)*8)-refcount_shift);
const size_t refcount_mask = ~weak_mask;
const size_t refcount_max = refcount_mask - 1;

size_t get_refcount(id obj)
{
	size_t *refCount = ((size_t*)obj) - 1;
	return *refCount & refcount_mask;
}

void set_refcount(id obj, size_t count)
{
	size_t *refCount = ((size_t*)obj) - 1;
	*refCount = (*refCount & weak_mask) | (count & refcount_mask);
}

void direct_saturation_test()
{
	{
		id obj = [Test new];
		// sanity check
		objc_retain_fast_np(obj);
		assert(object_getRetainCount_np(obj) == 2);
		assert(get_refcount(obj) == 1);
		
		// Check the behaviour close to the maximum refcount.
		set_refcount(obj, refcount_max - 3);
		assert(object_getRetainCount_np(obj) == refcount_max - 2);
		
		assert(objc_retain_fast_np(obj) == obj);
		assert(object_getRetainCount_np(obj) == refcount_max - 1);
		
		id weak;
		assert(objc_initWeak(&weak, obj) == obj);
		assert(weak != nil);
		assert(objc_loadWeakRetained(&weak) == obj);
		assert(object_getRetainCount_np(obj) == refcount_max);
		
		// This retain should cause the count to saturate.
		assert(objc_retain_fast_np(obj) == obj);
		assert(object_getRetainCount_np(obj) == refcount_max + 1);
		
		// A saturated count is no longer affected by retains or releases.
		assert(objc_release_fast_no_destroy_np(obj) == NO);
		assert(object_getRetainCount_np(obj) == refcount_max + 1);
		assert(objc_retain_fast_np(obj) == obj);
		assert(object_getRetainCount_np(obj) == refcount_max + 1);
		
		// Nor should any weak refs be deleted.
		assert(objc_delete_weak_refs(obj) == NO);
		assert(objc_loadWeakRetained(&weak) == obj);
		assert(object_getRetainCount_np(obj) == refcount_max + 1);
		
		// Cleanup (can skip this if it becomes an issue)
		objc_destroyWeak(&weak);
		set_refcount(obj, 0);
		objc_release_fast_no_destroy_np(obj);
		object_dispose(obj);
	}
	
	{
		id obj = [Test new];
		set_refcount(obj, refcount_max - 2);
		assert(objc_retain_fast_np(obj) == obj);
		assert(objc_retain_fast_np(obj) == obj);
		assert(object_getRetainCount_np(obj) == refcount_max + 1);
		
		// Check we can init a weak ref to an object with a saturated count.
		id weak;
		assert(objc_initWeak(&weak, obj) == obj);
		assert(weak != nil);
		assert(objc_loadWeakRetained(&weak) == obj);
		assert(object_getRetainCount_np(obj) == refcount_max + 1);
		
		// Cleanup (can skip this if it becomes an issue)
		objc_destroyWeak(&weak);
		set_refcount(obj, 0);
		objc_release_fast_no_destroy_np(obj);
		object_dispose(obj);
	}
}
