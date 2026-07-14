#if defined(__clang__)
#pragma clang system_header
#endif
#include "objc-visibility.h"

#ifndef _OBJC_MESSAGE_H_
#define _OBJC_MESSAGE_H_

#if defined(__x86_64) || defined(__i386) || defined(__arm__) ||                \
    defined(__mips_n64) || defined(__mips_n32) ||                              \
    defined(__ARM_ARCH_ISA_A64) ||                                             \
    (defined(__riscv) && __riscv_xlen == 64 &&                                 \
     defined(__riscv_float_abi_double))

// Define __GNUSTEP_MSGSEND__ if available
#ifndef __GNUSTEP_MSGSEND__
#define __GNUSTEP_MSGSEND__
#endif

/**
 * Standard message sending function.  This function must be cast to the
 * correct types for the function before use.  The first argument is the
 * receiver and the second the selector.
 *
 * Note that this function is not available on all architectures.  For a more
 * portable solution to sending arbitrary messages, consider using
 * objc_msg_lookup_sender() and then calling the returned IMP directly.
 *
 * This version of the function is used for all messages that return either an
 * integer, a pointer, or a small structure value that is returned in
 * registers.  Be aware that calling conventions differ between operating
 * systems even within the same architecture, so take great care if using this
 * function for small (two integer) structures.
 */
OBJC_PUBLIC
id objc_msgSend(id self, SEL _cmd, ...);
/**
 * Standard message sending function.  This function must be cast to the
 * correct types for the function before use.  The first argument is the
 * receiver and the second the selector.
 *
 * Note that this function is not available on all architectures.  For a more
 * portable solution to sending arbitrary messages, consider using
 * objc_msg_lookup_sender() and then calling the returned IMP directly.
 *
 * This version of the function is used for all messages that return a
 * structure that is not returned in registers.  Be aware that calling
 * conventions differ between operating systems even within the same
 * architecture, so take great care if using this function for small (two
 * integer) structures.
 */
OBJC_PUBLIC
#ifdef __cplusplus
id objc_msgSend_stret(id self, SEL _cmd, ...);
#else
void objc_msgSend_stret(id self, SEL _cmd, ...);
#endif

/**
 * Standard message sending function.  This function must be cast to the
 * correct types for the function before use.  The first argument is the
 * receiver and the second the selector.
 *
 * Note that this function is only available on Windows ARM64. For a more
 * portable solution to sending arbitrary messages, consider using
 * objc_msg_lookup_sender() and then calling the returned IMP directly.
 *
 * This version of the function is used on Windows ARM64 for all messages
 * that return a non-trivial data types (e.g C++ classes or structures with
 * user-defined constructors) that is not returned in registers.
 * Be aware that calling conventions differ between operating systems even
 * within the same architecture, so take great care if using this function for
 * small (two integer) structures.
 *
 * Why does objc_msgSend_stret2 exist?
 * In AAPCS, an SRet is passed in x8, not x0 like a normal pointer parameter.
 * On Windows, this is only the case for POD (plain old data) types. Non trivial
 * types with constructors and destructors are passed in x0 on sret.
 */
OBJC_PUBLIC
#if defined(_WIN32) && defined(__ARM_ARCH_ISA_A64)
#   ifdef __cplusplus
id objc_msgSend_stret2(id self, SEL _cmd, ...);
#   else
void objc_msgSend_stret2(id self, SEL _cmd, ...);
#   endif
#endif
/**
 * Standard message sending function.  This function must be cast to the
 * correct types for the function before use.  The first argument is the
 * receiver and the second the selector.
 *
 * Note that this function is not available on all architectures.  For a more
 * portable solution to sending arbitrary messages, consider using
 * objc_msg_lookup_sender() and then calling the returned IMP directly.
 *
 * This version of the function is used for all messages that return floating
 * point values.
 */
OBJC_PUBLIC
long double objc_msgSend_fpret(id self, SEL _cmd, ...);

#endif

#endif //_OBJC_MESSAGE_H_
