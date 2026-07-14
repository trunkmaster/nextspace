/**
 * NSURLSessionPrivate.h
 *
 * Copyright (C) 2017-2024 Free Software Foundation, Inc.
 *
 * Written by: Hugo Melder <hugo@algoriddim.com>
 * Date: May 2024
 * Author: Hugo Melder <hugo@algoriddim.com>
 *
 * This file is part of GNUStep-base
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * If you are interested in a warranty or support for this source code,
 * contact Scott Christley <scottc@net-community.com> for more information.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free
 * Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
 */

#import "common.h"

#import "Foundation/NSURLSession.h"
#import "Foundation/NSDictionary.h"
#import <curl/curl.h>
#import <dispatch/dispatch.h>

extern NSString * GS_NSURLSESSION_DEBUG_KEY;

/* libcurl may request a full-duplex socket configuration with
 * CURL_POLL_INOUT, but libdispatch distinguishes between a read and write
 * socket source.
 *
 * We thus need to keep track of two dispatch sources. One may be set to NULL
 * if not used.
 */
struct SourceInfo
{
  dispatch_source_t readSocket;
  dispatch_source_t writeSocket;
};

typedef NS_ENUM(NSInteger, GSURLSessionProperties)
{
  GSURLSessionStoresDataInMemory = (1 << 0),
  GSURLSessionWritesDataToFile = (1 << 1),
  GSURLSessionUpdatesDelegate = (1 << 2),
  GSURLSessionHasCompletionHandler = (1 << 3),
  GSURLSessionHasInputStream = (1 << 4)
};

@interface
  NSURLSession(Private)

- (dispatch_queue_t)_workQueue;

-(NSData *)_certificateBlob;
-(NSString *)_certificatePath;

/* Adds the internal easy handle to the multi handle.
 * Modifications are performed on the workQueue.
 */
-(void)_resumeTask: (NSURLSessionTask *)task;

/* The following methods must only be called from within callbacks dispatched on
 * the workQueue.*/
-(void)_setTimer: (NSInteger)timeout;
-(void)_suspendTimer;

/* Required for manual redirects.
 */
-(void)_addHandle: (CURL *)easy;
-(void)_removeHandle: (CURL *)easy;

-(void)_removeSocket: (struct SourceInfo *)sources;
-(int)_addSocket: (curl_socket_t)socket easyHandle: (CURL *)easy what: (int)what;
-(int)_setSocket: (curl_socket_t)socket
 sources: (struct SourceInfo *)sources
 what: (int)what;

@end
