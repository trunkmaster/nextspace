#include <atomic>
#include <stdlib.h>
#include <stdio.h>
#include "dwarf_eh.h"
#include "objcxx_eh_private.h"
#include "objcxx_eh.h"
#include "objc/objc-arc.h"

/**
 * Helper function that has a custom personality function.
 * This calls `cxx_throw` and has a destructor that must be run.  We intercept
 * the personality function calls and inspect the in-flight C++ exception.
 */
int eh_trampoline();

uint64_t cxx_exception_class;

using namespace __cxxabiv1;

namespace
{
/**
 * Helper needed by the unwind helper headers.
 */
inline _Unwind_Reason_Code continueUnwinding(struct _Unwind_Exception *ex,
                                                    struct _Unwind_Context *context)
{
#if defined(__arm__) && !defined(__ARM_DWARF_EH__)
	if (__gnu_unwind_frame(ex, context) != _URC_OK) { return _URC_FAILURE; }
#endif
	return _URC_CONTINUE_UNWIND;
}


/**
 * Flag indicating that we've already inspected a C++ exception and found all
 * of the offsets.
 */
std::atomic<bool> done_setup;
/**
 * The offset of the C++ type_info object in a thrown exception from the unwind
 * header in a `__cxa_exception`.
 */
std::atomic<ptrdiff_t> type_info_offset;
/**
 * The size of the `_Unwind_Exception` (including padding) in a
 * `__cxa_exception`.
 */
std::atomic<size_t> exception_struct_size;


/**
 * Exception cleanup function for C++ exceptions that wrap Objective-C
 * exceptions.
 */
void exception_cleanup(_Unwind_Reason_Code reason,
                       struct _Unwind_Exception *ex)
{
	// __cxa_exception takes a pointer to the end of the __cxa_exception
	// structure, and so we find that by adding the size of the generic
	// exception structure + padding to the pointer to the generic exception
	// structure field of the enclosing structure.
	auto *cxxEx = pointer_add<__cxa_exception>(ex, exception_struct_size);
	__cxa_free_exception(cxxEx);
}

}

using namespace std;


static BOOL isKindOfClass(Class thrown, Class type)
{
	do
	{
		if (thrown == type)
		{
			return YES;
		}
		thrown = class_getSuperclass(thrown);
	} while (Nil != thrown);

	return NO;
}




namespace gnustep
{
	namespace libobjc
	{
		__objc_type_info::__objc_type_info(const char *name) : type_info(name) {}

		bool __objc_type_info::__is_pointer_p() const { return true; }

		bool __objc_type_info::__is_function_p() const { return false; }

		bool __objc_type_info::__do_catch(const type_info *thrown_type,
			                        void **thrown_object,
			                        unsigned) const
		{
			assert(0);
			return false;
		};

		bool __objc_type_info::__do_upcast(
			                const __class_type_info *target,
			                void **thrown_object) const
		{
			return false;
		};
		
		
		/**
		 * The `id` type is mangled to `@id`, which is not a valid mangling
		 * of anything else.
		 */
		__objc_id_type_info::__objc_id_type_info() : __objc_type_info("@id") {};
	}

	static inline id dereference_thrown_object_pointer(void** obj) {
		/* libc++-abi does not have  __is_pointer_p and won't do the double dereference 
		 * required to get the object pointer. We need to do it ourselves if we have
		 * caught an exception with libc++'s exception class. */
#ifndef __MINGW32__
		 if (cxx_exception_class == llvm_cxx_exception_class) {
			 return **(id**)obj;
		 }
		 return *(id*)obj;
#else
#ifdef _LIBCPP_VERSION
		return **(id**)obj;
#else
		return *(id*)obj;
#endif // _LIBCPP_VERSION
#endif // __MINGW32__
	 }
};


static bool AppleCompatibleMode = true;
extern "C" int objc_set_apple_compatible_objcxx_exceptions(int newValue)
{
	bool old = AppleCompatibleMode;
	AppleCompatibleMode = newValue;
	return old;
}

gnustep::libobjc::__objc_class_type_info::~__objc_class_type_info() {}
gnustep::libobjc::__objc_id_type_info::~__objc_id_type_info() {}
bool gnustep::libobjc::__objc_class_type_info::__do_catch(const type_info *thrownType,
                                                          void **obj,
                                                          unsigned outer) const
{
	id thrown = nullptr;
	bool found = false;
	// Id throw matches any ObjC catch.  This may be a silly idea!
	if (dynamic_cast<const __objc_id_type_info*>(thrownType)
	    || (AppleCompatibleMode && 
	        dynamic_cast<const __objc_class_type_info*>(thrownType)))
	{
		thrown = dereference_thrown_object_pointer(obj);
		// nil only matches id catch handlers in Apple-compatible mode, or when thrown as an id
		if (0 == thrown)
		{
			return false;
		}
		// Check whether the real thrown object matches the catch type.
		found = isKindOfClass(object_getClass(thrown),
		                      (Class)objc_getClass(name()));
	}
	else if (dynamic_cast<const __objc_class_type_info*>(thrownType))
	{
		thrown = dereference_thrown_object_pointer(obj);
		found = isKindOfClass((Class)objc_getClass(thrownType->name()),
		                      (Class)objc_getClass(name()));
	}
	if (found)
	{
		*obj = (void*)thrown;
	}

	return found;
};

bool gnustep::libobjc::__objc_id_type_info::__do_catch(const type_info *thrownType,
                                                       void **obj,
                                                       unsigned outer) const
{
	// Id catch matches any ObjC throw
	if (dynamic_cast<const __objc_class_type_info*>(thrownType))
	{
		*obj = dereference_thrown_object_pointer(obj);
		DEBUG_LOG("gnustep::libobjc::__objc_id_type_info::__do_catch caught 0x%x\n", *obj);
		return true;
	}
	if (dynamic_cast<const __objc_id_type_info*>(thrownType))
	{
		*obj = dereference_thrown_object_pointer(obj);
		DEBUG_LOG("gnustep::libobjc::__objc_id_type_info::__do_catch caught 0x%x\n", *obj);
		return true;
	}
	DEBUG_LOG("gnustep::libobjc::__objc_id_type_info::__do_catch returning false\n");
	return false;
};

/**
 * Public interface to the Objective-C++ exception mechanism
 */
extern "C"
{
/**
 * The public symbol that the compiler uses to indicate the Objective-C id type.
 */
OBJC_PUBLIC gnustep::libobjc::__objc_id_type_info __objc_id_type_info;

struct _Unwind_Exception *objc_init_cxx_exception(id obj)
{
	id *newEx = static_cast<id*>(__cxa_allocate_exception(sizeof(id)));
	*newEx = obj;
	_Unwind_Exception *ex = pointer_add<_Unwind_Exception>(newEx, -exception_struct_size);
	*pointer_add<std::type_info*>(ex, type_info_offset) = &__objc_id_type_info;
	ex->exception_class = cxx_exception_class;
	ex->exception_cleanup = exception_cleanup;
	__cxa_get_globals()->uncaughtExceptions++;
	return ex;
}

void* objc_object_for_cxx_exception(void *thrown_exception, int *isValid)
{
	ptrdiff_t type_offset = type_info_offset;
	if (type_offset == 0)
	{
		*isValid = 0;
		return nullptr;
	}

	const std::type_info *thrownType = 
		*pointer_add<const std::type_info*>(thrown_exception, type_offset);

	if (!dynamic_cast<const gnustep::libobjc::__objc_id_type_info*>(thrownType) && 
	    !dynamic_cast<const gnustep::libobjc::__objc_class_type_info*>(thrownType))
	{
		*isValid = 0;
		return 0;
	}
	*isValid = 1;
	return *pointer_add<id>(thrown_exception, exception_struct_size);
}

} // extern "C"


MagicValueHolder::MagicValueHolder() { magic_value = magic; }

/**
 * Function that simply throws an instance of `MagicValueHolder`.
 */
PRIVATE void cxx_throw()
{
	MagicValueHolder x;
	throw x;
}

/**
 * Personality function that wraps the C++ personality and inspects the C++
 * exception structure on the way past.  This should be used only for the
 * `eh_trampoline` function.
 */
extern "C"
PRIVATE
BEGIN_PERSONALITY_FUNCTION(test_eh_personality)
	// Don't bother with a mutex here.  It doesn't matter if two threads set
	// these values at the same time.
	if (!done_setup)
	{
		uint64_t cls = __builtin_bswap64(exceptionClass);
		type_info_offset = find_backwards(exceptionObject, &typeid(MagicValueHolder));
		exception_struct_size = find_forwards(exceptionObject, MagicValueHolder::magic);
		cxx_exception_class = exceptionClass;
		done_setup = true;
	}
	return CALL_PERSONALITY_FUNCTION(__gxx_personality_v0);
}

/**
 * Probe the C++ exception handling implementation.  This throws a C++
 * exception through a function that uses `test_eh_personality` as its
 * personality function, allowing us to inspect a C++ exception that is in a
 * known state.
 */
#ifndef __MINGW32__
extern "C" void test_cxx_eh_implementation()
{
	if (done_setup)
	{
		return;
	}
	bool caught = false;
	try
	{
		eh_trampoline();
	}
	catch(MagicValueHolder)
	{
		caught = true;
	}
	assert(caught);
}
#endif
