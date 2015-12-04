/*
 * Copyright (c) 2012, Mark Heily <mark@heily.com>
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

#ifndef _LIBPWQ_LINUX_PLATFORM_H
#define _LIBPWQ_LINUX_PLATFORM_H

/*
 * Platform-specific functions for Linux
 */

unsigned int linux_get_runqueue_length(void);

/* 
 * Android does not provide spinlocks.
 * See: http://code.google.com/p/android/issues/detail?id=21622
 */
#if defined(__ANDROID__)
#define pthread_spinlock_t     pthread_mutex_t
#define pthread_spin_lock      pthread_mutex_lock
#define pthread_spin_unlock    pthread_mutex_unlock
#define pthread_spin_init(a,b) pthread_mutex_init((a), NULL)
#define pthread_spin_destroy   pthread_mutex_destroy
#endif /* defined(__ANDROID__) */

#endif /* _LIBPWQ_LINUX_PLATFORM_H */
