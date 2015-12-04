/*
 * Copyright (c) 2008-2011 Apple Inc. All rights reserved.
 *
 * @APPLE_APACHE_LICENSE_HEADER_START@
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * @APPLE_APACHE_LICENSE_HEADER_END@
 */

#ifndef __DISPATCH_TESTS_SHIMS_TIME__
#define __DISPATCH_TESTS_SHIMS_TIME__

#include <config/config.h>

#include <assert.h>
#if HAVE_MACH
#include <mach/mach.h>
#include <mach/mach_time.h>
#else
#include <time.h>
#endif

#ifndef NSEC_PER_SEC
#define NSEC_PER_SEC 1000000000ull
#endif

static inline uint64_t
_dispatch_monotonic_time()
{
#if HAVE_MACH
	return mach_absolute_time();
#else
	clockid_t clockID;
	#ifdef CLOCK_MONOTONIC_RAW
		clockID = CLOCK_MONOTONIC_RAW;
	#else
		clockID = CLOCK_MONOTONIC;
	#endif
	struct timespec ts;
	int status = clock_gettime(clockID, &ts);
	assert(0 == status);
	return (uint64_t)ts.tv_nsec + NSEC_PER_SEC * ts.tv_sec;
#endif
}

#endif  /* __DISPATCH_TESTS_SHIMS_TIME__ */
