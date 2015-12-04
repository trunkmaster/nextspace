#ifndef DISPATCH_FIXINCLUDES_UNISTD_H_
#define DISPATCH_FIXINCLUDES_UNISTD_H_
/* The use of __block in some unistd.h files causes Clang to report an error.
 * We work around the issue by forcibly undefining __block. See
 * https://bugzilla.redhat.com/show_bug.cgi?id=1009623 */

#if HAS_PROBLEMATIC_UNISTD_H
#pragma push_macro("__block")
#undef __block
#define __block my__block
#include_next <unistd.h>
#pragma pop_macro("__block")
#else
#include_next <unistd.h>
#endif

#endif // DISPATCH_FIXINCLUDES_UNISTD_H_
