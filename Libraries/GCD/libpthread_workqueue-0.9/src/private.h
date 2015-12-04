/*-
 * Copyright (c) 2011, Mark Heily <mark@heily.com>
 * Copyright (c) 2009, Stacey Son <sson@freebsd.org>
 * Copyright (c) 2000-2008, Apple Inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice unmodified, this list of conditions, and the following
 *    disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

#ifndef _PTWQ_PRIVATE_H
#define _PTWQ_PRIVATE_H 1

#include <errno.h>
#include <limits.h>
#include <signal.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#if defined(_WIN32)
# include "windows/platform.h"
#else
# include "posix/platform.h"
# if __linux__
#  include "linux/platform.h"
# endif
# if defined(__sun)
#  include "solaris/platform.h"
# endif
#endif

#include "pthread_workqueue.h"
#include "debug.h"

/* The maximum number of workqueues that can be created.
   This is based on libdispatch only needing 8 workqueues.
   */
#define PTHREAD_WORKQUEUE_MAX 31

/* The total number of priority levels. */
#define WORKQ_NUM_PRIOQUEUE 4

/* Signatures/magic numbers.  */
#define PTHREAD_WORKQUEUE_SIG       0xBEBEBEBE
#define PTHREAD_WORKQUEUE_ATTR_SIG  0xBEBEBEBE 

/* Whether to use real-time threads for the workers if available */

extern unsigned int PWQ_RT_THREADS;
extern unsigned int PWQ_SPIN_THREADS;

/* A limit of the number of cpu:s that we view as available, useful when e.g. using processor sets */
extern unsigned int PWQ_ACTIVE_CPU;

#if __GNUC__
#define fastpath(x)     ((__typeof__(x))__builtin_expect((long)(x), ~0l))
#define slowpath(x)     ((__typeof__(x))__builtin_expect((long)(x), 0l))
#else
#define fastpath(x) (x)
#define slowpath(x) (x)
#endif

#define CACHELINE_SIZE	64
#define ROUND_UP_TO_CACHELINE_SIZE(x)	(((x) + (CACHELINE_SIZE - 1)) & ~(CACHELINE_SIZE - 1))

/* We should perform a hardware pause when using the optional busy waiting, see: 
   http://software.intel.com/en-us/articles/ap949-using-spin-loops-on-intel-pentiumr-4-processor-and-intel-xeonr-processor/ 
 rep/nop / 0xf3+0x90 are the same as the symbolic 'pause' instruction
 */

#if defined(__i386__) || defined(__x86_64__) || defined(__i386) || defined(__amd64)

#if defined(__SUNPRO_CC)

#define _hardware_pause()  asm volatile("rep; nop\n");

#elif defined(__GNUC__)

#define _hardware_pause()  __asm__ __volatile__("pause");

#elif defined(_WIN32)

#define _hardware_pause() do { __asm{_emit 0xf3}; __asm {_emit 0x90}; } while (0)

#else

#define _hardware_pause() __asm__("pause")

#endif

/* XXX-FIXME this is a stub, need to research what ARM assembly to use */
#elif defined(__ARM_EABI__)

#define _hardware_pause() __asm__("")

#else

#error Need to define _hardware_pause() for this architure

#endif 

/*
 * The work item cache, has three different optional implementations:
 * 1. No cache, just normal malloc/free using the standard malloc library in use
 * 2. Libumem based object cache, requires linkage with libumem - for non-Solaris see http://labs.omniti.com/labs/portableumem
 *    this is the most balanced cache supporting migration across threads of allocated/freed witems
 * 3. TSD based cache, modelled on libdispatch continuation implementation, can lead to imbalance with assymetric 
 *    producer/consumer threads as allocated memory is cached by the thread freeing it
 */
#if defined(__sun)
#define WITEM_CACHE_TYPE 2 // Use libumem on Solaris by default
#else
#define WITEM_CACHE_TYPE 1 // Otherwise fallback to normal malloc/free - change specify witem cache implementation to use
#endif

struct work {
    STAILQ_ENTRY(work)   item_entry; 
    void               (*func)(void *);
    void                *func_arg;
    unsigned int         flags;
    unsigned int         gencount;
#if (WITEM_CACHE_TYPE == 3)
	struct work *volatile wi_next;
#endif
};

struct _pthread_workqueue {
    unsigned int         sig;    /* Unique signature for this structure */
    unsigned int         flags;
    int                  queueprio;
    int                  overcommit;
    unsigned int         wqlist_index;
    STAILQ_HEAD(,work)   item_listhead;
    pthread_spinlock_t   mtx;
#ifdef WORKQUEUE_PLATFORM_SPECIFIC
	WORKQUEUE_PLATFORM_SPECIFIC;
#endif
};

/* manager.c */
int manager_init(void);
unsigned long manager_peek(const char *);
void manager_suspend(void);
void manager_resume(void);
void manager_workqueue_create(struct _pthread_workqueue *);
void manager_workqueue_additem(struct _pthread_workqueue *, struct work *);

struct work *witem_alloc(void (*func)(void *), void *func_arg); // returns a properly initialized witem
void witem_free(struct work *wi);
int witem_cache_init(void);
void witem_cache_cleanup(void *value);

#endif  /* _PTWQ_PRIVATE_H */
