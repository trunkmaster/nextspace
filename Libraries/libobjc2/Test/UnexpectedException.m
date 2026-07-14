#include "Test.h"
#include "../objc/hooks.h"
#include "../objc/objc-exception.h"

#include <stdlib.h>

#ifdef _WIN32
#include <Windows.h>
#endif

id expectedExceptionObj = @"ExpectedException";
id unexpectedExceptionObj = @"UnexpectedException";

void _UncaughtExceptionHandler(id exception)
{
	assert(exception == unexpectedExceptionObj);
#if defined(_WIN32) && !defined(__MINGW32__)
	// on Windows we will exit in _UnhandledExceptionFilter() below
#else
	exit(0);
#endif
}

#if defined(_WIN32) && !defined(__MINGW32__)
LONG WINAPI _UnhandledExceptionFilter(struct _EXCEPTION_POINTERS* exceptionInfo)
{
	assert(exceptionInfo != NULL);
	exit(0);
}
#endif

int main(void)
{
#if !(defined(__arm__) || defined(__ARM_ARCH_ISA_A64)) && !defined(__powerpc__)
#if defined(_WIN32) && !defined(__MINGW32__)
	// also verify that an existing handler still gets called after we set ours
	SetUnhandledExceptionFilter(&_UnhandledExceptionFilter);
#endif
	@try
	{
		@throw expectedExceptionObj;
	}
	@catch(id exception)
	{
		assert(exception == expectedExceptionObj);
	}

	objc_setUncaughtExceptionHandler(_UncaughtExceptionHandler);
	@throw unexpectedExceptionObj;
	assert(0 && "should not be reached!");

	return -1;
#endif
	// FIXME: Test currently fails on ARM and AArch64
	return 77; // Skip test
}
