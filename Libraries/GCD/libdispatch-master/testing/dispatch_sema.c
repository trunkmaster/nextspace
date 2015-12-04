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

#include <config/config.h>
#include <dispatch/dispatch.h>
#include <pthread.h>
#include <stdio.h>
#include <assert.h>

#include <bsdtests.h>
#include "dispatch_test.h"

#define LAPS 10000

static void
test_sem()
{
	static size_t total;
	dispatch_semaphore_t dsema;
	dsema = dispatch_semaphore_create(1);
	assert(dsema);

	dispatch_apply(LAPS, dispatch_get_global_queue(0, 0), ^(size_t idx __attribute__((unused))) {
		dispatch_semaphore_wait(dsema, DISPATCH_TIME_FOREVER);
		total++;
		dispatch_semaphore_signal(dsema);
	});

	dispatch_release(dsema);

	test_long("count", total, LAPS);
}

static void
test_walltime()
{
	dispatch_semaphore_t sem = dispatch_semaphore_create(0);
	
	dispatch_time_t timeout = dispatch_walltime(NULL, 2 * NSEC_PER_SEC);
	uint64_t start = _dispatch_monotonic_time();

	printf("dispatch_semaphore_wait() for 2.0s (walltime)...\n");
	dispatch_semaphore_wait(sem, timeout);

	test_uint64("Waited for correct time", 
				(_dispatch_monotonic_time() - start) / NSEC_PER_SEC,
				2);
}

int
main(void)
{
	dispatch_test_start("Dispatch Semaphore");

	test_sem();
	test_walltime();
	test_stop();

	return 0;
}
