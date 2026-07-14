/**
 * NSURLSessionTaskPrivate.h
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

#import "Foundation/NSDictionary.h"
#import "Foundation/NSFileHandle.h"
#import "Foundation/NSURLSession.h"
#import <curl/curl.h>

@interface
  NSURLSessionTask(Private)

- (instancetype)initWithSession: (NSURLSession *)session
 request: (NSURLRequest *)request
 taskIdentifier: (NSUInteger)identifier;

-(CURL *)_easyHandle;

/* Enable or disable libcurl verbose output. Disabled by default. */
-(void)_setVerbose: (BOOL)flag;

/* This method is called by -[NSURLSession _checkForCompletion]
 *
 * We release the session (previously retained in -[NSURLSessionTask resume])
 * here and inform the delegate about the transfer state.
 */
-(void)_transferFinishedWithCode: (CURLcode)code;

/* Explicitly enable data upload with an optional estimated size. Set to 0 if
 * not available.
 *
 * This may be used when a body stream is passed at a later stage
 * (see URLSession:task:needNewBodyStream:).
 */
-(void)_enableUploadWithSize: (NSInteger)size;
-(void)_setBodyStream: (NSInputStream *)stream;

-(void)_enableUploadWithData: (NSData *)data;
-(void)_enableAutomaticRedirects: (BOOL)flag;

/* Assign with copying */
-(void)_setOriginalRequest: (NSURLRequest *)request;
-(void)_setCurrentRequest: (NSURLRequest *)request;

-(void)_setResponse: (NSURLResponse *)response;
-(void)_setCookiesFromHeaders: (NSDictionary *)headers;

-(void)_setCountOfBytesSent: (int64_t)count;
-(void)_setCountOfBytesReceived: (int64_t)count;
-(void)_setCountOfBytesExpectedToSend: (int64_t)count;
-(void)_setCountOfBytesExpectedToReceive: (int64_t)count;

-(NSMutableDictionary *)_taskData;

-(NSURLSession *)_session;

/* Task specific properties.
 *
 * See GSURLSessionProperties in NSURLSessionPrivate.h.
 */
-(NSInteger)_properties;
-(void)_setProperties: (NSInteger)properties;

/* This value is periodically checked in progress_callback.
 * We then abort the transfer in the progress_callback if this flag is set.
 */
-(BOOL)_shouldStopTransfer;
-(void)_setShouldStopTransfer: (BOOL)flag;

-(NSInteger)_numberOfRedirects;
-(void)_setNumberOfRedirects: (NSInteger)redirects;

-(NSInteger)_headerCallbackCount;
-(void)_setHeaderCallbackCount: (NSInteger)count;

-(NSFileHandle *)_createTemporaryFileHandleWithError: (NSError **)error;

@end

@interface
  NSURLSessionDataTask(Private)

- (GSNSURLSessionDataCompletionHandler)_completionHandler;
-(void)_setCompletionHandler: (GSNSURLSessionDataCompletionHandler)handler;

@end

@interface
  NSURLSessionDownloadTask(Private)

- (GSNSURLSessionDownloadCompletionHandler)_completionHandler;

-(int64_t)_countOfBytesWritten;
-(void)_updateCountOfBytesWritten: (int64_t)count;
-(void)_setCompletionHandler: (GSNSURLSessionDownloadCompletionHandler)handler;

@end