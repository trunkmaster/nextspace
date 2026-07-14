#include <atomic>
#include <stdlib.h>
#include <stdio.h>
#include <windows.h>
#include "dwarf_eh.h"
#include "objcxx_eh_private.h"
#include "objcxx_eh.h"
#include "objc/runtime.h"
#include "objc/objc-arc.h"
#include "objc/objc-exception.h"
#include "objc/hooks.h"

namespace __cxxabiv1
{
	struct __cxa_refcounted_exception
	{
		int referenceCount;
	};
}

using namespace __cxxabiv1;

extern "C" __cxa_refcounted_exception* __cxa_init_primary_exception(void *obj, std::type_info *tinfo, void (*dest) (void *));

static void eh_cleanup(void *exception)
{
	DEBUG_LOG("eh_cleanup: Releasing 0x%x\n", *(id*)exception);
	objc_release(*(id*)exception);
}

/**
 * Flag indicating that we've already inspected a C++ exception and found all
 * of the offsets.
 */
std::atomic<bool> done_setup;

/**
 * The size of the `_Unwind_Exception` (including padding) in a
 * `__cxa_exception`.
 */
std::atomic<size_t> exception_struct_size;

extern "C"
OBJC_PUBLIC
void objc_exception_throw(id object)
{
	// Don't bother with a mutex here.  It doesn't matter if two threads set
	// these values at the same time.
	if (!done_setup)
	{
		DEBUG_LOG("objc_exception_throw: Doing initial setup\n");
		MagicValueHolder *magicExc = (MagicValueHolder *)__cxa_allocate_exception(sizeof(MagicValueHolder));
		MagicValueHolder x;
		*magicExc = x;

		__cxa_refcounted_exception *header =
			__cxa_init_primary_exception(magicExc, & __objc_id_type_info, NULL);
		exception_struct_size = find_forwards(header, MagicValueHolder::magic);
		__cxa_free_exception(magicExc);

		DEBUG_LOG("objc_exception_throw: exception_struct_size: 0x%x\n", unsigned(exception_struct_size));

		done_setup = true;
	}

	id *exc = (id *)__cxa_allocate_exception(sizeof(id));
	*exc = object;
	objc_retain(object);
	DEBUG_LOG("objc_exception_throw: Throwing 0x%x\n", *exc);

	__cxa_eh_globals *globals = __cxa_get_globals ();
	globals->uncaughtExceptions += 1;
	__cxa_refcounted_exception *header =
		__cxa_init_primary_exception(exc, & __objc_id_type_info, eh_cleanup);
	header->referenceCount = 1;

	_Unwind_Exception *unwindHeader = pointer_add<_Unwind_Exception>(header, exception_struct_size - sizeof(_Unwind_Exception));
	_Unwind_Reason_Code err = _Unwind_RaiseException (unwindHeader);

	if (_URC_END_OF_STACK == err && 0 != _objc_unexpected_exception)
	{
		DEBUG_LOG("Invoking _objc_unexpected_exception\n");
		_objc_unexpected_exception(object);
	}
	DEBUG_LOG("Throw returned %d\n",(int) err);
	abort();
}

OBJC_PUBLIC extern objc_uncaught_exception_handler objc_setUncaughtExceptionHandler(objc_uncaught_exception_handler handler)
{
	return __atomic_exchange_n(&_objc_unexpected_exception, handler, __ATOMIC_SEQ_CST);
}

extern "C" void* __cxa_begin_catch(void *object);

extern "C"
OBJC_PUBLIC
void* objc_begin_catch(void* object)
{
	return __cxa_begin_catch(object);
}

extern "C" void __cxa_end_catch();

extern "C"
OBJC_PUBLIC
void objc_end_catch()
{
	__cxa_end_catch();
}

extern "C" void __cxa_rethrow();

extern "C"
OBJC_PUBLIC
void objc_exception_rethrow()
{
	__cxa_rethrow();
}

extern "C" EXCEPTION_DISPOSITION __gxx_personality_seh0(PEXCEPTION_RECORD ms_exc,
														void *this_frame,
														PCONTEXT ms_orig_context,
														PDISPATCHER_CONTEXT ms_disp);

extern "C"
OBJC_PUBLIC
EXCEPTION_DISPOSITION __gnu_objc_personality_seh0(PEXCEPTION_RECORD ms_exc,
														void *this_frame,
														PCONTEXT ms_orig_context,
														PDISPATCHER_CONTEXT ms_disp)
{
  return __gxx_personality_seh0(ms_exc, this_frame, ms_orig_context, ms_disp);
}
