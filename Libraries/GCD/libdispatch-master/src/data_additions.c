/*
 * Copyright (c) 2012 Nick Hutchinson <nshutchinson@gmail.com>.
 * All rights reserved.
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

#include "internal.h"

void
_dispatch_data_destructor_free_f(void *context DISPATCH_UNUSED)
{
	DISPATCH_CRASH("free destructor called");  
}

dispatch_data_t
dispatch_data_create_f_np(const void *buffer, size_t size, dispatch_queue_t queue,
		void *destructor_context, dispatch_function_t destructor)
{
	dispatch_block_t blockDestructor;

	if (destructor == DISPATCH_DATA_DESTRUCTOR_FREE_F) {
		blockDestructor = DISPATCH_DATA_DESTRUCTOR_FREE;
	
	} else if (destructor == DISPATCH_DATA_DESTRUCTOR_DEFAULT) {
		blockDestructor = DISPATCH_DATA_DESTRUCTOR_DEFAULT;

	} else { 
		blockDestructor = ^{ destructor(destructor_context); };
	}

	return dispatch_data_create(buffer, size, queue, blockDestructor);
}

bool
dispatch_data_apply_f_np(dispatch_data_t data, void *context,
		dispatch_data_applier_function_t applier)
{
	return dispatch_data_apply(data,
		^(dispatch_data_t region, size_t offset, const void *buffer, size_t size) {
			return applier(region, offset, buffer, size, context);
		});
}
