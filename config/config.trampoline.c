/* Trampoline test */

/*
 * Copyright 1995-1999, 2001-2002, 2004-2006 Bruno Haible, <bruno@clisp.org>
 *
 * This is free software distributed under the GNU General Public Licence
 * described in the file COPYING. Contact the author if you don't have this
 * or can't live with it. There is ABSOLUTELY NO WARRANTY, explicit or implied,
 * on this software.
 */

#include <stdio.h>
#include <stdlib.h>

#include "trampoline_r.h"

#define MAGIC1  0x9db9af42
#define MAGIC2  0x614a13c9
#define MAGIC3  0x7aff3cb4
#define MAGIC4  0xa2f9d045

#ifdef __cplusplus
typedef int (*function)(...);
#else
typedef int (*function)();
#endif

#if defined(__i386__)
int f (void* env, int x)
#else
int f (int x)
#endif
{
#ifdef __GNUC__
#ifdef __m68k__
#ifdef __NetBSD__
register void* env __asm__("a1");
#else
register void* env __asm__("a0");
#endif
#endif
#ifdef __mips__
register void* env __asm__("$2");
#endif
#ifdef __mips64
register void* env __asm__("$2");
#endif
#if defined(__sparc__) && !defined(__sparc64__)
register void* env __asm__("%g2");
#endif
#ifdef __sparc64__
register void* env __asm__("%g5");
#endif
#ifdef __alpha__
register void* env __asm__("$1");
#endif
#ifdef __hppa__
register void* env __asm__("%r29");
#endif
#ifdef __arm__
register void* env __asm__("r12");
#endif
#if defined(__powerpc__) || defined(__ppc__) || defined(__ppc64__)
#ifdef __NetBSD__
register void* env __asm__("r13");
#else
register void* env __asm__("r11");
#endif
#endif
#ifdef __m88k__
register void* env __asm__("r11");
#endif
#ifdef __convex__
register void* env __asm__("s0");
#endif
#ifdef __ia64__
register void* env __asm__("r15");
#endif
#ifdef __x86_64__
register void* env __asm__("r10");
#endif
#ifdef __s390__
register void* env __asm__("r0");
#endif

  return x + (int)((long*)env)[0] + (int)((long*)env)[1] + MAGIC3;
#else
  return x + MAGIC3;
#endif
}

int main ()
{
  function cf = alloc_trampoline_r((function)&f, (void*)MAGIC1, (void*)MAGIC2);
#ifdef __GNUC__
  if ((*cf)(MAGIC4) == MAGIC1+MAGIC2+MAGIC3+MAGIC4)
#else
  if ((*cf)(MAGIC4) == MAGIC3+MAGIC4)
#endif
    { free_trampoline_r(cf); printf("Works, test1 passed.\n"); exit(0); }
  else
    { printf("Doesn't work!\n"); exit(1); }
}
