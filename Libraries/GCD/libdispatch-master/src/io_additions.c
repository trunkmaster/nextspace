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
dispatch_read_f_np(dispatch_fd_t fd, size_t length, dispatch_queue_t queue,
		void *context,
		void (*handler)(dispatch_data_t data, int error, void *context))
{
	dispatch_read(fd, length, queue, ^(dispatch_data_t data, int error) {
		handler(data, error, context);
	});
}

void
dispatch_write_f_np(dispatch_fd_t fd, dispatch_data_t data, dispatch_queue_t queue,
		void *context, 
		void (*handler)(dispatch_data_t data, int error, void *context))
{
	dispatch_write(fd, data, queue, ^(dispatch_data_t data, int error) {
		handler(data, error, context);
	});
}

dispatch_io_t
dispatch_io_create_f_np(dispatch_io_type_t type, dispatch_fd_t fd,
		dispatch_queue_t queue, void *context,
		void(*cleanup_handler)(int error, void *context))
{
	return dispatch_io_create(type, fd, queue,
														^(int error){ cleanup_handler(error, context); });  
}

dispatch_io_t
dispatch_io_create_with_path_f_np(dispatch_io_type_t type, const char *path,
		int oflag, mode_t mode, dispatch_queue_t queue, void *context,
		void(*cleanup_handler)(int error, void *context))
{
	return dispatch_io_create_with_path(type, path, oflag, mode, queue, 
																			^(int error) {
																				cleanup_handler(error, context);
																			});
}

dispatch_io_t
dispatch_io_create_with_io_f_np(dispatch_io_type_t type, dispatch_io_t io,
		dispatch_queue_t queue, void *context,
		void(*cleanup_handler)(int error, void *context))
{
	return dispatch_io_create_with_io(type, io, queue, 
																		^(int error){
																			cleanup_handler(error, context);
																		});
}

void
dispatch_io_read_f_np(dispatch_io_t channel, off_t offset, size_t length,
		dispatch_queue_t queue, void *context, dispatch_io_function_t handler)
{
	dispatch_io_read(channel, offset, length, queue,
									 ^(bool done, dispatch_data_t data, int error) {
										 handler(done, data, error, context);
									 });
}

void
dispatch_io_write_f_np(dispatch_io_t channel, off_t offset, dispatch_data_t data,
		dispatch_queue_t queue, void *context, dispatch_io_function_t handler)
{
	dispatch_io_write(channel, offset, data, queue,
										^(bool done, dispatch_data_t data, int error) {
											handler(done, data, error, context);
										});
}

void
dispatch_io_barrier_f_np(dispatch_io_t channel, void *context, 
		dispatch_function_t barrier)
{
	dispatch_io_barrier(channel, ^{ barrier(context); });
}
