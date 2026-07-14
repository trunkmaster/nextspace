#if defined(__clang__) && !defined(__OBJC_RUNTIME_INTERNAL__)
#pragma clang system_header
#endif
#include "objc-visibility.h"

#ifndef __OBJC_EXCEPTION_INCLUDED__
#define __OBJC_EXCEPTION_INCLUDED__

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*objc_uncaught_exception_handler)(id exception);

/** 
 * Throw a runtime exception. Inserted by the compiler in place of @throw.
 */
OBJC_PUBLIC
void objc_exception_throw(id object);

/**
 * Installs handler for uncaught Objective-C exceptions.  If the unwind library
 * reaches the end of the stack without finding a handler then the handler is
 * called. Returns the previous handler.
 */
OBJC_PUBLIC
objc_uncaught_exception_handler objc_setUncaughtExceptionHandler(objc_uncaught_exception_handler handler);

#ifdef __cplusplus
}
#endif

#endif // __OBJC_EXCEPTION_INCLUDED__
