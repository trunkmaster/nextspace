/**
   NSURLSession.h

   Copyright (C) 2017-2024 Free Software Foundation, Inc.

   Written by: Hugo Melder <hugo@algoriddim.com>
   Date: May 2024

   This file is part of GNUStep-base

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   If you are interested in a warranty or support for this source code,
   contact Scott Christley <scottc@net-community.com> for more information.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
*/

#ifndef __NSURLSession_h_GNUSTEP_BASE_INCLUDE
#define __NSURLSession_h_GNUSTEP_BASE_INCLUDE

#import <Foundation/NSObject.h>
#import <Foundation/NSURLRequest.h>
#import <Foundation/NSHTTPCookieStorage.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSOperation.h>
#import <Foundation/NSProgress.h>
#import <Foundation/NSDate.h>

#if GS_HAVE_NSURLSESSION
#if OS_API_VERSION(MAC_OS_X_VERSION_10_9, GS_API_LATEST)

@protocol NSURLSessionDelegate;
@protocol NSURLSessionTaskDelegate;

@class NSError;
@class NSHTTPURLResponse;
@class NSOperationQueue;
@class NSURL;
@class NSURLAuthenticationChallenge;
@class NSURLCache;
@class NSURLCredential;
@class NSURLCredentialStorage;
@class NSURLRequest;
@class NSURLResponse;
@class NSURLSessionConfiguration;
@class NSURLSessionTask;
@class NSURLSessionDataTask;
@class NSURLSessionUploadTask;
@class NSURLSessionDownloadTask;

NS_ASSUME_NONNULL_BEGIN

typedef void (^GSNSURLSessionDataCompletionHandler)(
  NSData *_Nullable data, NSURLResponse *_Nullable response,
  NSError *_Nullable error);

typedef void (^GSNSURLSessionDownloadCompletionHandler)(
  NSURL *_Nullable location, NSURLResponse *_Nullable response,
  NSError *_Nullable error);

/**
 * NSURLSession is a replacement API for NSURLConnection.  It provides
 * options that affect the policy of, and various aspects of the
 * mechanism by which NSURLRequest objects are retrieved from the
 * network.<br />
 *
 * An NSURLSession may be bound to a delegate object.  The delegate is
 * invoked for certain events during the lifetime of a session.
 *
 * NSURLSession instances are threadsafe.
 *
 * An NSURLSession creates NSURLSessionTask objects which represent the
 * action of a resource being loaded.
 *
 * NSURLSessionTask objects are always created in a suspended state and
 * must be sent the -resume message before they will execute.
 *
 * Subclasses of NSURLSessionTask are used to syntactically
 * differentiate between data and file downloads.
 *
 * An NSURLSessionDataTask receives the resource as a series of calls to
 * the URLSession:dataTask:didReceiveData: delegate method.  This is type of
 * task most commonly associated with retrieving objects for immediate parsing
 * by the consumer.
 */
GS_EXPORT_CLASS
@interface NSURLSession : NSObject
{
@private
  NSOperationQueue          *_delegateQueue;
  id<NSURLSessionDelegate>   _delegate;
  NSURLSessionConfiguration *_configuration;

  NSString *_sessionDescription;
}

+ (NSURLSession *) sharedSession;

+ (NSURLSession *) sessionWithConfiguration:
  (NSURLSessionConfiguration *)configuration;

/**
 * Customization of NSURLSession occurs during creation of a new session.
 * If you do specify a delegate, the delegate will be retained until after
 * the delegate has been sent the URLSession:didBecomeInvalidWithError: message.
 */
+ (NSURLSession *) sessionWithConfiguration:
  (NSURLSessionConfiguration *)configuration
  delegate: (nullable id<NSURLSessionDelegate>)delegate
  delegateQueue: (nullable NSOperationQueue *)queue;

/** -finishTasksAndInvalidate returns immediately and existing tasks will be
 * allowed to run to completion.  New tasks may not be created.  The session
 * will continue to make delegate callbacks until
 * URLSession:didBecomeInvalidWithError: has been issued.
 *
 * When invalidating a background session, it is not safe to create another
 * background session with the same identifier until
 * URLSession:didBecomeInvalidWithError: has been issued.
 */
- (void) finishTasksAndInvalidate;

/** -invalidateAndCancel acts as -finishTasksAndInvalidate, but issues
 * -cancel to all outstanding tasks for this session.  Note task
 * cancellation is subject to the state of the task, and some tasks may
 * have already have completed at the time they are sent -cancel.
 */
- (void) invalidateAndCancel;

/*
 * NSURLSessionTask objects are always created in a suspended state and
 * must be sent the -resume message before they will execute.
 */

/** Creates a data task with the given request.
 * The request may have a body stream. */
- (NSURLSessionDataTask *) dataTaskWithRequest: (NSURLRequest *)request;

/** Creates a data task to retrieve the contents of the given URL. */
- (NSURLSessionDataTask *) dataTaskWithURL: (NSURL *)url;

- (NSURLSessionUploadTask *) uploadTaskWithRequest: (NSURLRequest *)request
                                          fromFile: (NSURL *)fileURL;

- (NSURLSessionUploadTask *) uploadTaskWithRequest: (NSURLRequest *)request
                                          fromData: (NSData *)bodyData;

- (NSURLSessionUploadTask *) uploadTaskWithStreamedRequest:
  (NSURLRequest *)request;

/* Creates a download task with the given request. */
- (NSURLSessionDownloadTask *) downloadTaskWithRequest: (NSURLRequest *)request;

/* Creates a download task to download the contents of the given URL. */
- (NSURLSessionDownloadTask *) downloadTaskWithURL: (NSURL *)url;

- (NSURLSessionDownloadTask *) downloadTaskWithResumeData: (NSData *)resumeData;

- (void) getTasksWithCompletionHandler:
  (void (^)(NSArray<NSURLSessionDataTask *> *dataTasks,
    NSArray<NSURLSessionUploadTask *> *uploadTasks,
    NSArray<NSURLSessionDownloadTask *> *downloadTasks)) completionHandler;

- (void) getAllTasksWithCompletionHandler:
  (void (^)(GS_GENERIC_CLASS(NSArray, __kindof NSURLSessionTask *) * tasks))
    completionHandler;

/**
 * This serial NSOperationQueue queue is used for dispatching delegate messages
 * and completion handlers.
 */
- (NSOperationQueue *) delegateQueue;

/**
 * The delegate for the session. This is the object to which delegate messages
 * will be sent.
 *
 * The session keeps a strong reference to the delegate.
 */
- (nullable id<NSURLSessionDelegate>) delegate;

/**
 * The configuration object used to create the session.
 *
 * A copy of the configuration object is made.
 * Changes to the configuration object after the session is created have no
 * effect.
 */
- (NSURLSessionConfiguration *) configuration;

/**
 * An App-specific description of the session.
 */
- (nullable NSString *) sessionDescription;

/**
 * Sets an app-specific description of the session.
 */
- (void) setSessionDescription: (NSString *)description;

@end

/**
 * NSURLSession convenience routines deliver results to
 * a completion handler block.  These convenience routines
 * are not available to NSURLSessions that are configured
 * as background sessions.
 *
 * Task objects are always created in a suspended state and
 * must be sent the -resume message before they will execute.
 */
@interface NSURLSession (NSURLSessionAsynchronousConvenience)
/*
 * data task convenience methods.  These methods create tasks that
 * bypass the normal delegate calls for response and data delivery,
 * and provide a simple cancelable asynchronous interface to receiving
 * data.  Errors will be returned in the NSURLErrorDomain,
 * see <Foundation/NSURLError.h>.  The delegate, if any, will still be
 * called for authentication challenges.
 */
- (NSURLSessionDataTask *) dataTaskWithRequest: (NSURLRequest *)request
  completionHandler: (GSNSURLSessionDataCompletionHandler)completionHandler;
- (NSURLSessionDataTask *) dataTaskWithURL: (NSURL *)url
  completionHandler: (GSNSURLSessionDataCompletionHandler)completionHandler;

- (NSURLSessionUploadTask *) uploadTaskWithRequest: (NSURLRequest *)request
  fromFile: (NSURL *)fileURL
  completionHandler: (GSNSURLSessionDataCompletionHandler)completionHandler;

- (NSURLSessionUploadTask *) uploadTaskWithRequest: (NSURLRequest *)request
  fromData: (NSData *)bodyData
  completionHandler: (GSNSURLSessionDataCompletionHandler)completionHandler;

/*
 * download task convenience methods.  When a download successfully
 * completes, the NSURL will point to a file that must be read or
 * copied during the invocation of the completion routine.  The file
 * will be removed automatically.
 */
- (NSURLSessionDownloadTask *) downloadTaskWithRequest: (NSURLRequest *)request
  completionHandler: (GSNSURLSessionDownloadCompletionHandler)completionHandler;
- (NSURLSessionDownloadTask *) downloadTaskWithURL: (NSURL *)url
  completionHandler: (GSNSURLSessionDownloadCompletionHandler)completionHandler;

- (NSURLSessionDownloadTask *) downloadTaskWithResumeData: (NSData *)resumeData
  completionHandler: (GSNSURLSessionDownloadCompletionHandler)completionHandler;

@end

typedef NS_ENUM(NSUInteger, NSURLSessionTaskState)
{
  /* The task is currently being serviced by the session */
  NSURLSessionTaskStateRunning = 0,
  NSURLSessionTaskStateSuspended = 1,
  /* The task has been told to cancel.
   * The session will receive URLSession:task:didCompleteWithError:. */
  NSURLSessionTaskStateCanceling = 2,
  /* The task has completed and the session will receive no more
   * delegate notifications */
  NSURLSessionTaskStateCompleted = 3,
};

GS_EXPORT const float NSURLSessionTaskPriorityDefault;
GS_EXPORT const float NSURLSessionTaskPriorityLow;
GS_EXPORT const float NSURLSessionTaskPriorityHigh;

GS_EXPORT const int64_t NSURLSessionTransferSizeUnknown;

/*
 * NSURLSessionTask - a cancelable object that refers to the lifetime
 * of processing a given request.
 */
GS_EXPORT_CLASS
@interface NSURLSessionTask : NSObject <NSCopying, NSProgressReporting>
{
  NSUInteger    _taskIdentifier;
  NSURLRequest *_originalRequest;

  id<NSURLSessionTaskDelegate> _delegate;
  NSURLSessionTaskState        _state;
  NSURLRequest                *_currentRequest;
  NSURLResponse               *_response;
  NSProgress                  *_progress;
  NSDate                      *_earliestBeginDate;

  _Atomic(int64_t) _countOfBytesClientExpectsToSend;
  _Atomic(int64_t) _countOfBytesClientExpectsToReceive;
  _Atomic(int64_t) _countOfBytesSent;
  _Atomic(int64_t) _countOfBytesReceived;
  _Atomic(int64_t) _countOfBytesExpectedToSend;
  _Atomic(int64_t) _countOfBytesExpectedToReceive;
  _Atomic(double)  _priority;

  NSString *_taskDescription;
  NSError  *_error;
}

/**
 * Cancels the task and the ongoing transfer.
 */
- (void) cancel;

- (int64_t) countOfBytesClientExpectsToReceive;
- (int64_t) countOfBytesClientExpectsToSend;
- (int64_t) countOfBytesReceived;
- (int64_t) countOfBytesSent;
- (int64_t) countOfBytesExpectedToReceive;
- (int64_t) countOfBytesExpectedToSend;

- (nullable NSURLRequest *) currentRequest;
- (nullable id<NSURLSessionTaskDelegate>) delegate;
- (nullable NSDate *) earliestBeginDate;
- (nullable NSError *) error;
- (nullable NSURLRequest *) originalRequest;
- (float) priority;
- (NSProgress *) progress;
- (nullable NSURLResponse *) response;
- (void) resume;

- (void) setDelegate: (nullable id<NSURLSessionTaskDelegate>)delegate;
- (void) setEarliestBeginDate: (nullable NSDate *)date;
- (void) setPriority: (float)priority;

/**
 * Sets an app-specific description of the task.
 */
- (void) setTaskDescription: (nullable NSString *)description;

- (NSURLSessionTaskState) state;
- (void) suspend;

/**
 * App-specific description of the task.
 */
- (nullable NSString *) taskDescription;

- (NSUInteger) taskIdentifier;

@end

GS_EXPORT_CLASS
@interface NSURLSessionDataTask : NSURLSessionTask
{
  void *_completionHandler;
}
@end

GS_EXPORT_CLASS
@interface NSURLSessionUploadTask : NSURLSessionDataTask
@end

GS_EXPORT_CLASS
@interface NSURLSessionDownloadTask : NSURLSessionTask
{
  void   *_completionHandler;
  int64_t _countOfBytesWritten;
}
@end

#if OS_API_VERSION(MAC_OS_X_VERSION_10_11, GS_API_LATEST)
GS_EXPORT_CLASS
@interface NSURLSessionStreamTask : NSURLSessionTask
@end
#endif

/*
 * Configuration options for an NSURLSession.  When a session is
 * created, a copy of the configuration object is made - you cannot
 * modify the configuration of a session after it has been created.
 */
GS_EXPORT_CLASS
@interface NSURLSessionConfiguration : NSObject <NSCopying>
{
  NSString                *_identifier;
  NSURLCache              *_URLCache;
  NSURLRequestCachePolicy  _requestCachePolicy;
  NSArray                 *_protocolClasses;
  NSInteger                _HTTPMaximumConnectionLifetime;
  NSInteger                _HTTPMaximumConnectionsPerHost;
  BOOL                     _HTTPShouldUsePipelining;
  NSHTTPCookieAcceptPolicy _HTTPCookieAcceptPolicy;
  NSHTTPCookieStorage     *_HTTPCookieStorage;
  NSURLCredentialStorage  *_URLCredentialStorage;
  BOOL                     _HTTPShouldSetCookies;
  NSDictionary            *_HTTPAdditionalHeaders;
  NSTimeInterval           _timeoutIntervalForRequest;
  NSTimeInterval           _timeoutIntervalForResource;
}

+ (NSURLSessionConfiguration *) backgroundSessionConfigurationWithIdentifier:
  (NSString *)identifier;
+ (NSURLSessionConfiguration *) defaultSessionConfiguration;
+ (NSURLSessionConfiguration *) ephemeralSessionConfiguration;

- (NSURLRequest *) configureRequest: (NSURLRequest *)request;

- (nullable NSDictionary *) HTTPAdditionalHeaders;
- (NSHTTPCookieAcceptPolicy) HTTPCookieAcceptPolicy;
- (nullable NSHTTPCookieStorage *) HTTPCookieStorage;
- (NSInteger) HTTPMaximumConnectionsPerHost;

- (nullable NSString *) identifier;

/**
 * Indicates whether the session should set cookies.
 *
 * This property controls whether tasks within sessions based on this
 * configuration should automatically include cookies from the shared cookie
 * store when making requests.
 *
 * If set to NO, you must manually provide cookies by adding a Cookie header
 * through the session's HTTPAdditionalHeaders property or on a per-request
 * basis using a custom NSURLRequest object.
 *
 * The default value is YES.
 *
 * See Also:
 * - HTTPCookieAcceptPolicy
 * - HTTPCookieStorage
 * - NSHTTPCookieStorage
 * - NSHTTPCookie
 */
- (BOOL) HTTPShouldSetCookies;

/**
 * HTTP/1.1 pipelining is not implemented. This flag is ignored.
 */
- (BOOL) HTTPShouldUsePipelining;

- (nullable NSArray *) protocolClasses;

- (NSURLRequestCachePolicy) requestCachePolicy;

- (void) setHTTPAdditionalHeaders: (NSDictionary *)headers;
- (void) setHTTPCookieAcceptPolicy: (NSHTTPCookieAcceptPolicy)policy;
- (void) setHTTPCookieStorage: (NSHTTPCookieStorage *)storage;
- (void) setHTTPMaximumConnectionsPerHost: (NSInteger)n;

/**
 * Sets whether the session should set cookies.
 *
 * This method controls whether tasks within sessions based on this
 * configuration should automatically include cookies from the shared cookie
 * store when making requests.
 *
 * If set to NO, you must manually provide cookies by adding a Cookie header
 * through the session's HTTPAdditionalHeaders property or on a per-request
 * basis using a custom NSURLRequest object.
 *
 * The default value is YES.
 *
 * See Also:
 * - HTTPCookieAcceptPolicy
 * - HTTPCookieStorage
 * - NSHTTPCookieStorage
 * - NSHTTPCookie
 */
- (void) setHTTPShouldSetCookies: (BOOL)flag;

- (void) setHTTPShouldUsePipelining: (BOOL)flag;

- (void) setRequestCachePolicy: (NSURLRequestCachePolicy)policy;

/**
 * Sets the timeout interval to use when waiting for additional data to arrive.
 */
- (void) setTimeoutIntervalForRequest: (NSTimeInterval)interval;

/**
 * Sets the maximum amount of time that a resource request should be allowed to
 * take.
 */
- (void) setTimeoutIntervalForResource: (NSTimeInterval)interval;

- (void) setURLCache: (NSURLCache *)cache;
- (void) setURLCredentialStorage: (NSURLCredentialStorage *)storage;

/**
 * Gets the timeout interval to use when waiting for additional data to arrive.
 * The request timeout interval controls how long (in seconds) a task should
 * wait for additional data to arrive before giving up. The timer is reset
 * whenever new data arrives. When the request timer reaches the specified
 * interval without receiving any new data, it triggers a timeout.
 *
 * Currently not used by NSURLSession.
 */
- (NSTimeInterval) timeoutIntervalForRequest;

/**
 * Gets the maximum amount of time that a resource request should be allowed to
 * take. The resource timeout interval controls how long (in seconds) to wait
 * for an entire resource to transfer before giving up. The resource timer
 * starts when the request is initiated and counts until either the request
 * completes or this timeout interval is reached, whichever comes first.
 */
- (NSTimeInterval) timeoutIntervalForResource;


- (nullable NSURLCache *) URLCache;
- (nullable NSURLCredentialStorage *) URLCredentialStorage;

#if !NO_GNUSTEP
/** Permits a session to be configured so that older connections are reused.
 * A value of zero or less uses the default behavior where connections are
 * reused as long as they are not older than 118 seconds, which is reasonable
 * for the vast majority if situations.
 */
- (NSInteger) HTTPMaximumConnectionLifetime;
- (void) setHTTPMaximumConnectionLifetime: (NSInteger)n;
#endif

@end

typedef NS_ENUM(NSInteger, NSURLSessionAuthChallengeDisposition) {
  NSURLSessionAuthChallengeUseCredential = 0,
  NSURLSessionAuthChallengePerformDefaultHandling = 1,
  NSURLSessionAuthChallengeCancelAuthenticationChallenge = 2,
  NSURLSessionAuthChallengeRejectProtectionSpace = 3
};

typedef NS_ENUM(NSInteger, NSURLSessionResponseDisposition) {
  NSURLSessionResponseCancel = 0,
  NSURLSessionResponseAllow = 1,
  NSURLSessionResponseBecomeDownload = 2,
  NSURLSessionResponseBecomeStream = 3
};

@protocol NSURLSessionDelegate <NSObject>
@optional
/* The last message a session receives.  A session will only become
 * invalid because of a systemic error or when it has been
 * explicitly invalidated, in which case the error parameter will be nil.
 */
- (void) URLSession: (NSURLSession *)session
  didBecomeInvalidWithError: (nullable NSError *)error;

/* Implementing this method permits a delegate to provide authentication
 * credentials in response to a challenge from the remote server.
 */
- (void) URLSession: (NSURLSession *)session
  didReceiveChallenge: (NSURLAuthenticationChallenge *)challenge
  completionHandler:
      (void (^)(NSURLSessionAuthChallengeDisposition disposition,
                NSURLCredential                     *credential))handler;

@end

@protocol NSURLSessionTaskDelegate <NSURLSessionDelegate>
@optional

#if OS_API_VERSION(MAC_OS_VERSION_13_0, GS_API_LATEST)
- (void) URLSession: (NSURLSession *)session
  didCreateTask: (NSURLSessionTask *)task;
#endif

/* Sent as the last message related to a specific task.  Error may be
 * nil, which implies that no error occurred and this task is complete.
 */
- (void) URLSession: (NSURLSession *)session
  task: (NSURLSessionTask *)task
  didCompleteWithError: (nullable NSError *)error;

/* Called to request authentication credentials from the delegate when
 * an authentication request is received from the server which is specific
 * to this task.
 */
- (void) URLSession: (NSURLSession *)session
  task: (NSURLSessionTask *)task
  didReceiveChallenge: (NSURLAuthenticationChallenge *)challenge
  completionHandler: (void (^)(NSURLSessionAuthChallengeDisposition disposition,
    NSURLCredential *credential))handler;

/* Periodically informs the delegate of the progress of sending body content
 * to the server.
 */
- (void) URLSession: (NSURLSession *)session
  task: (NSURLSessionTask *)task
  didSendBodyData: (int64_t)bytesSent
  totalBytesSent: (int64_t)totalBytesSent
  totalBytesExpectedToSend: (int64_t)totalBytesExpectedToSend;

/* An HTTP request is attempting to perform a redirection to a different
 * URL. You must invoke the completion routine to allow the
 * redirection, allow the redirection with a modified request, or
 * pass nil to the completionHandler to cause the body of the redirection
 * response to be delivered as the payload of this request. The default
 * is to follow redirections.
 *
 */
- (void) URLSession: (NSURLSession *)session
  task: (NSURLSessionTask *)task
  willPerformHTTPRedirection: (NSHTTPURLResponse *)response
  newRequest: (NSURLRequest *)request
  completionHandler: (void (^)(NSURLRequest *))completionHandler;

- (void) URLSession: (NSURLSession *)session
  task: (NSURLSessionTask *)task
  needNewBodyStream: (void (^)(NSInputStream *bodyStream))completionHandler;

@end

@protocol NSURLSessionDataDelegate <NSURLSessionTaskDelegate>
@optional
/* Sent when data is available for the delegate to consume.
 */
- (void) URLSession: (NSURLSession *)session
  dataTask: (NSURLSessionDataTask *)dataTask
  didReceiveData: (NSData *)data;

/** Informs the delegate of a response.  This message is sent when all the
 * response headers have arrived, before the body of the response arrives.
 */
- (void) URLSession: (NSURLSession *)session
  dataTask: (NSURLSessionDataTask *)dataTask
  didReceiveResponse: (NSURLResponse *)response
  completionHandler:
    (void (^)(NSURLSessionResponseDisposition disposition))completionHandler;

@end

@protocol NSURLSessionDownloadDelegate <NSURLSessionTaskDelegate>

/* Sent when a download task that has completed a download.  The delegate should
 * copy or move the file at the given location to a new location as it will be
 * removed when the delegate message returns.
 * URLSession:task:didCompleteWithError: will still be called.
 */
- (void) URLSession: (NSURLSession *)session
  downloadTask: (NSURLSessionDownloadTask *)downloadTask
  didFinishDownloadingToURL: (NSURL *)location;

@optional
/* Sent periodically to notify the delegate of download progress. */
- (void) URLSession: (NSURLSession *)session
  downloadTask: (NSURLSessionDownloadTask *)downloadTask
  didWriteData: (int64_t)bytesWritten
  totalBytesWritten: (int64_t)totalBytesWritten
  totalBytesExpectedToWrite: (int64_t)totalBytesExpectedToWrite;

/* Sent when a download has been resumed. If a download failed with an
 * error, the -userInfo dictionary of the error will contain an
 * NSURLSessionDownloadTaskResumeData key, whose value is the resume
 * data.
 */
- (void) URLSession: (NSURLSession *)session
  downloadTask: (NSURLSessionDownloadTask *)downloadTask
  didResumeAtOffset: (int64_t)fileOffset
  expectedTotalBytes: (int64_t)expectedTotalBytes;

@end

NS_ASSUME_NONNULL_END

#endif /* MAC_OS_X_VERSION_10_9 */
#endif /* GS_HAVE_NSURLSESSION */
#endif /* __NSURLSession_h_GNUSTEP_BASE_INCLUDE */
