/**
 * NSURLSessionTask.m
 *
 * Copyright (C) 2017-2024 Free Software Foundation, Inc.
 *
 * Written by: Hugo Melder <hugo@algoriddim.com>
 * Date: May 2024
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

#import "NSURLSessionPrivate.h"
#include <curl/curl.h>
#include <dispatch/dispatch.h>
#import "NSURLSessionTaskPrivate.h"

#import "Foundation/NSOperation.h"
#import "Foundation/NSPathUtilities.h"
#import "Foundation/NSFileManager.h"
#import "Foundation/NSFileHandle.h"
#import "Foundation/NSCharacterSet.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSError.h"
#import "Foundation/NSData.h"
#import "Foundation/NSUUID.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSURL.h"
#import "Foundation/NSURLError.h"
#import "Foundation/NSURLResponse.h"
#import "Foundation/NSHTTPCookie.h"
#import "Foundation/NSStream.h"

#import "GNUstepBase/NSDebug+GNUstepBase.h"  /* For NSDebugMLLog */
#import "GNUstepBase/NSObject+GNUstepBase.h" /* For -[NSObject notImplemented] */

#import "GSURLPrivate.h"

@interface _GSInsensitiveDictionary : NSDictionary
@end

@interface _GSMutableInsensitiveDictionary : NSMutableDictionary
@end

GS_DECLARE const float NSURLSessionTaskPriorityDefault = 0.5;
GS_DECLARE const float NSURLSessionTaskPriorityLow = 0.0;
GS_DECLARE const float NSURLSessionTaskPriorityHigh = 1.0;

GS_DECLARE const int64_t NSURLSessionTransferSizeUnknown = -1;

/* Initialised in +[NSURLSessionTask initialize] */
static Class dataTaskClass;
static Class downloadTaskClass;
static SEL didReceiveDataSel;
static SEL didReceiveResponseSel;
static SEL didCompleteWithErrorSel;
static SEL didFinishDownloadingToURLSel;
static SEL didWriteDataSel;
static SEL needNewBodyStreamSel;
static SEL willPerformHTTPRedirectionSel;

static NSString *taskTransferDataKey = @"transferData";
static NSString *taskTemporaryFileLocationKey = @"tempFileLocation";
static NSString *taskTemporaryFileHandleKey = @"tempFileHandle";
static NSString *taskInputStreamKey = @"inputStream";
static NSString *taskUploadData = @"uploadData";

/* Translate WinSock2 Error Codes */
#ifdef _WIN32
static inline NSInteger
translateWinSockToPOSIXError(NSInteger err)
{
  switch (err)
    {
      case WSAEADDRINUSE:
        err = EADDRINUSE;
        break;
      case WSAEADDRNOTAVAIL:
        err = EADDRNOTAVAIL;
        break;
      case WSAEINPROGRESS:
        err = EINPROGRESS;
        break;
      case WSAECONNRESET:
        err = ECONNRESET;
        break;
      case WSAECONNABORTED:
        err = ECONNABORTED;
        break;
      case WSAECONNREFUSED:
        err = ECONNREFUSED;
        break;
      case WSAEHOSTUNREACH:
        err = EHOSTUNREACH;
        break;
      case WSAENETUNREACH:
        err = ENETUNREACH;
        break;
      case WSAETIMEDOUT:
        err = ETIMEDOUT;
        break;
      default:
        break;
    } /* switch */

  return err;
} /* translateWinSockToPOSIXError */
#endif /* ifdef _WIN32 */

static inline NSError *
errorForCURLcode(CURL *handle, CURLcode code, char errorBuffer[CURL_ERROR_SIZE])
{
  NSString	*curlErrorString;
  NSString	*errorString;
  NSDictionary	*userInfo;
  NSError	*error;
  NSInteger 	urlError = NSURLErrorUnknown;
  NSInteger 	posixError;
  NSInteger 	osError = 0;

  if (NULL == handle || CURLE_OK == code)
    {
      return NULL;
    }

  errorString = [NSString stringWithCString: errorBuffer];
  curlErrorString = [NSString stringWithCString: curl_easy_strerror(code)];

  /* Get errno number from the last connect failure.
   *
   * libcurl errors that may have saved errno are:
   * - CURLE_COULDNT_CONNECT
   * - CURLE_FAILED_INIT
   * - CURLE_INTERFACE_FAILED
   * - CURLE_OPERATION_TIMEDOUT
   * - CURLE_RECV_ERROR
   * - CURLE_SEND_ERROR
   */
  curl_easy_getinfo(handle, CURLINFO_OS_ERRNO, &osError);
#ifdef _WIN32
  posixError = translateWinSockToPOSIXError(osError);
#else
  posixError = osError;
#endif

  /* Translate libcurl to NSURLError codes */
  switch (code)
    {
      case CURLE_UNSUPPORTED_PROTOCOL:
        urlError = NSURLErrorUnsupportedURL;
        break;
      case CURLE_URL_MALFORMAT:
        urlError = NSURLErrorBadURL;
        break;

      /* Connection Errors */
      case CURLE_COULDNT_RESOLVE_PROXY:
      case CURLE_COULDNT_RESOLVE_HOST:
        urlError = NSURLErrorDNSLookupFailed;
        break;
      case CURLE_QUIC_CONNECT_ERROR:
      case CURLE_COULDNT_CONNECT:
        urlError = NSURLErrorCannotConnectToHost;
        break;
      case CURLE_OPERATION_TIMEDOUT:
        urlError = NSURLErrorTimedOut;
        break;
      case CURLE_FILESIZE_EXCEEDED:
        urlError = NSURLErrorDataLengthExceedsMaximum;
        break;
      case CURLE_LOGIN_DENIED:
        urlError = NSURLErrorUserAuthenticationRequired;
        break;

      /* Response Errors */
      case CURLE_WEIRD_SERVER_REPLY:
        urlError = NSURLErrorBadServerResponse;
        break;
      case CURLE_REMOTE_ACCESS_DENIED:
        urlError = NSURLErrorNoPermissionsToReadFile;
        break;
      case CURLE_GOT_NOTHING:
        urlError = NSURLErrorZeroByteResource;
        break;
      case CURLE_RECV_ERROR:
        urlError = NSURLErrorResourceUnavailable;
        break;

      /* Callback Errors */
      case CURLE_ABORTED_BY_CALLBACK:
      case CURLE_WRITE_ERROR:
        errorString = @"Transfer aborted by user";
        urlError = NSURLErrorCancelled;
        break;

      /* SSL Errors */
      case CURLE_SSL_CACERT_BADFILE:
      case CURLE_SSL_PINNEDPUBKEYNOTMATCH:
      case CURLE_SSL_CONNECT_ERROR:
        urlError = NSURLErrorSecureConnectionFailed;
        break;
      case CURLE_SSL_CERTPROBLEM:
        urlError = NSURLErrorClientCertificateRejected;
        break;
      case CURLE_SSL_INVALIDCERTSTATUS:
      case CURLE_SSL_ISSUER_ERROR:
        urlError = NSURLErrorServerCertificateUntrusted;
        break;

      default:
        urlError = NSURLErrorUnknown;
        break;
    } /* switch */

  /* Adjust error based on underlying OS error if available */
  if (code == CURLE_COULDNT_CONNECT || code == CURLE_RECV_ERROR
      || code == CURLE_SEND_ERROR)
    {
      switch (posixError)
        {
          case EADDRINUSE:
            urlError = NSURLErrorCannotConnectToHost;
            break;
          case EADDRNOTAVAIL:
            urlError = NSURLErrorCannotFindHost;
            break;
          case ECONNREFUSED:
            urlError = NSURLErrorCannotConnectToHost;
            break;
          case ENETUNREACH:
            urlError = NSURLErrorDNSLookupFailed;
            break;
          case ETIMEDOUT:
            urlError = NSURLErrorTimedOut;
            break;
          default: /* Do not alter urlError if we have no match */
            break;
        }
    }

  userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
    [NSNumber numberWithInteger: code], @"_curlErrorCode",
    curlErrorString, @"_curlErrorString",
    /* This is the raw POSIX error or WinSock2 Error Code depending on OS */
    [NSNumber numberWithInteger: osError], @"_errno",
    errorString, NSLocalizedDescriptionKey,
    nil];

  error = [NSError errorWithDomain: NSURLErrorDomain
                              code: urlError
                          userInfo: userInfo];

  return error;
} /* errorForCURLcode */

/* CURLOPT_PROGRESSFUNCTION: progress reports by libcurl */
static int
progress_callback(void *clientp, curl_off_t dltotal, curl_off_t dlnow,
  curl_off_t ultotal, curl_off_t ulnow)
{
  NSURLSessionTask	*task = clientp;

  /* Returning -1 from this callback makes libcurl abort the transfer and return
   * CURLE_ABORTED_BY_CALLBACK.
   */
  if (YES == [task _shouldStopTransfer])
    {
      return -1;
    }

  [task _setCountOfBytesReceived: dlnow];
  [task _setCountOfBytesSent: ulnow];
  [task _setCountOfBytesExpectedToSend: ultotal];
  [task _setCountOfBytesExpectedToReceive: dltotal];

  return 0;
}

/* CURLOPT_HEADERFUNCTION: callback for received headers
 *
 * This function is called for each header line and is called
 * again when a redirect or authentication occurs.
 *
 * libcurl does not unfold HTTP "folded headers" (deprecated since RFC 7230).
 */
static size_t
header_callback(char *ptr, size_t size, size_t nitems, void *userdata)
{
  NSURLSessionTask	*task;
  NSMutableDictionary	*taskData;
  NSMutableDictionary	*headerFields;
  NSString 		*headerLine;
  NSInteger 		headerCallbackCount;
  NSRange 		range;
  NSCharacterSet 	*set;

  task = (NSURLSessionTask *)userdata;
  taskData = [task _taskData];
  headerFields = [taskData objectForKey: @"headers"];
  headerCallbackCount = [task _headerCallbackCount] + 1;
  set = [NSCharacterSet whitespaceAndNewlineCharacterSet];

  [task _setHeaderCallbackCount: headerCallbackCount];

  if (nil == headerFields)
    {
      NSDebugLLog(
        GS_NSURLSESSION_DEBUG_KEY,
        @"task=%@ Could not find 'headers' key in taskData",
        task);
      return 0;
    }

  headerLine = AUTORELEASE([[NSString alloc]
    initWithBytes: ptr
    length: nitems
    encoding: NSUTF8StringEncoding]);

  // First line is the HTTP Version
  if (1 == headerCallbackCount)
    {
      [taskData setObject: headerLine forKey: @"version"];

      return size * nitems;
    }

  /* Header fields can be extended over multiple lines by preceding
   * each extra line with at least one SP or HT (RFC 2616).
   *
   * This is known as line folding. We append the value to the
   * previous header's value.
   */
  if ((ptr[0] == ' ') || (ptr[0] == '\t'))
    {
      NSString	*key;

      if (nil != (key = [taskData objectForKey: @"lastHeaderKey"]))
        {
          NSString	*value;
          NSString	*trimmedLine;

          value = [headerFields objectForKey: key];
          if (!value)
            {
              NSError	*error;
              NSString	*errorDescription;

              errorDescription = [NSString
                                  stringWithFormat:
                                  @"Header is line folded but previous header "
                                  @"key '%@' does not have an entry",
                                  key];
              error = [NSError errorWithDomain: NSURLErrorDomain
					  code: NSURLErrorCancelled
				      userInfo:
		[NSDictionary dictionaryWithObjectsAndKeys:
                  errorDescription, NSLocalizedDescriptionKey,
		  nil]];

              [taskData setObject: error forKey: NSUnderlyingErrorKey];

              return 0;
            }

          trimmedLine = [headerLine stringByTrimmingCharactersInSet: set];
          value = [value stringByAppendingString: trimmedLine];

          [headerFields setObject: value forKey: key];
        }

      return size * nitems;
    }

  range = [headerLine rangeOfString: @":"];
  if (NSNotFound != range.location)
    {
      NSString	*key;
      NSString 	*value;

      key = [headerLine substringToIndex: range.location];
      value = [headerLine substringFromIndex: range.location + 1];

      /* Remove LWS from key and value */
      key = [key stringByTrimmingCharactersInSet: set];
      value = [value stringByTrimmingCharactersInSet: set];

      [headerFields setObject: value forKey: key];
      /* Used for line unfolding */
      [taskData setObject: key forKey: @"lastHeaderKey"];

      return size * nitems;
    }

  /* Final Header Line:
   *
   * If this is the initial request (not a redirect) and delegate updates are
   * enabled, notify the delegate about the initial response.
   */
  if (nitems > 1 && (ptr[0] == '\r') && (ptr[1] == '\n'))
    {
      NSURLSession	*session;
      id 		delegate;
      NSHTTPURLResponse *response;
      NSString		*version;
      NSString 		*urlString;
      NSURL 		*url;
      CURL 		*handle;
      char 		*effURL;
      NSDictionary 	*fields;
      NSInteger 	numberOfRedirects = 0;
      NSInteger 	statusCode = 0;

      session = [task _session];
      delegate = [task delegate];
      handle = [task _easyHandle];
      numberOfRedirects = [task _numberOfRedirects] + 1;

      [task _setNumberOfRedirects: numberOfRedirects];
      [task _setHeaderCallbackCount: 0];

      curl_easy_getinfo(handle, CURLINFO_RESPONSE_CODE, &statusCode);
      curl_easy_getinfo(handle, CURLINFO_EFFECTIVE_URL, &effURL);

      if (nil == (version = [taskData objectForKey: @"version"]))
        {
          /* Default to HTTP/1.0 if no data is available */
          version = @"HTTP/1.0";
        }

      NSDebugLLog(
        GS_NSURLSESSION_DEBUG_KEY,
        @"task=%@ version=%@ status=%ld found %ld headers",
        task,
        version,
        statusCode,
        [headerFields count]);

      urlString = [NSString stringWithCString: effURL];
      url = [NSURL URLWithString: urlString];
      fields = [headerFields copy];
      response = [[NSHTTPURLResponse alloc] initWithURL: url
                                             statusCode: statusCode
                                            HTTPVersion: version
                                           headerFields: fields];
      AUTORELEASE(response);
      RELEASE(fields);

      [task _setCookiesFromHeaders: headerFields];
      [task _setResponse: response];

      /* URL redirection handling for 3xx status codes, if delegate updates are
       * enabled.
       *
       * NOTE: The URLSession API does not provide a way to limit redirection
       * attempts.
       */
      if ([task _properties] & GSURLSessionUpdatesDelegate && statusCode >= 300
        && statusCode < 400)
        {
          NSString	*location;

          /*
           * RFC 7231: 7.1.2  Location [Header]
           * Location = URI-reference
           *
           * The field value consists of a single URI-reference.  When it has
           * the form of a relative reference ([RFC3986], Section 4.2), the
           * final value is computed by resolving it against the effective
           * request URI
           * ([RFC3986], Section 5).
           */
          location = [headerFields objectForKey: @"Location"];
          if (nil != location)
            {
              NSURL			*redirectURL;
              NSMutableURLRequest 	*newRequest;

              /* baseURL is only used, if location is a relative reference */
              redirectURL = [NSURL URLWithString: location relativeToURL: url];
              newRequest = AUTORELEASE([[task originalRequest] mutableCopy]);
              [newRequest setURL: redirectURL];

              NSDebugLLog(
                GS_NSURLSESSION_DEBUG_KEY,
                @"task=%@ status=%ld has Location header. Prepare "
                @"for redirection with url=%@",
                task,
                statusCode,
                redirectURL);

              if ([delegate respondsToSelector: willPerformHTTPRedirectionSel])
                {
                  NSDebugLLog(
                    GS_NSURLSESSION_DEBUG_KEY,
                    @"task=%@ ask delegate for redirection "
                    @"permission. Pausing handle.",
                    task);

                  curl_easy_pause(handle, CURLPAUSE_ALL);

                  [[session delegateQueue] addOperationWithBlock:^{
                     void (^completionHandler)(NSURLRequest *) = ^(
                       NSURLRequest *userRequest) {
                       /* Changes are dispatched onto workqueue */
                       dispatch_async(
                         [session _workQueue],
                         ^{
                           if (NULL == userRequest)
                           {
                             curl_easy_pause(handle, CURLPAUSE_CONT);
                             [task _setShouldStopTransfer: YES];
                             NSDebugLLog(
                               GS_NSURLSESSION_DEBUG_KEY,
                               @"task=%@ willPerformHTTPRedirection "
                               @"completionHandler called with nil "
                               @"request",
                               task);
                           }
                           else
                           {
                             NSString	*newURLString;

                             newURLString = [[userRequest URL] absoluteString];

                             NSDebugLLog(
                               GS_NSURLSESSION_DEBUG_KEY,
                               @"task=%@ willPerformHTTPRedirection "
                               @"delegate completionHandler called "
                               @"with new URL %@",
                               task,
                               newURLString);

                             /* Remove handle for reconfiguration */
                             [session _removeHandle: handle];

                             /* Reset statistics */
                             [task _setCountOfBytesReceived: 0];
                             [task _setCountOfBytesSent: 0];
                             [task _setCountOfBytesExpectedToReceive: 0];
                             [task _setCountOfBytesExpectedToSend: 0];

                             [task _setCurrentRequest: userRequest];

                             /* Update URL in easy handle */
                             curl_easy_setopt(
                               handle,
                               CURLOPT_URL,
                               [newURLString UTF8String]);
                             curl_easy_pause(handle, CURLPAUSE_CONT);

                             [session _addHandle: handle];
                           }
                         });
                     };

                     [delegate URLSession: session
                                            task: task
                      willPerformHTTPRedirection: response
                                      newRequest: newRequest
                               completionHandler: completionHandler];
                   }];

                  [headerFields removeAllObjects];
                  return size * nitems;
                }
              else
                {
                  NSDebugLLog(
                    GS_NSURLSESSION_DEBUG_KEY,
                    @"task=%@ status=%ld has Location header but "
                    @"delegate does not respond to "
                    @"willPerformHTTPRedirection:. Redirecting to Location %@",
                    task,
                    statusCode,
                    redirectURL);

                  /* Remove handle for reconfiguration */
                  [session _removeHandle: handle];

                  curl_easy_setopt(
                    handle,
                    CURLOPT_URL,
                    [[redirectURL absoluteString] UTF8String]);

                  /* Reset statistics */
                  [task _setCountOfBytesReceived: 0];
                  [task _setCountOfBytesSent: 0];
                  [task _setCountOfBytesExpectedToReceive: 0];
                  [task _setCountOfBytesExpectedToSend: 0];

                  [task _setCurrentRequest: newRequest];

                  /* Re-add handle to session */
                  [session _addHandle: handle];
                }

              [headerFields removeAllObjects];
              return size * nitems;
            }
          else
            {
              NSError	*error;
              NSString	*errorString;

              errorString = [NSString
                             stringWithFormat:
                             @"task=%@ status=%ld has no Location header",
                             task, statusCode];
              error = [NSError errorWithDomain: NSURLErrorDomain
					  code: NSURLErrorBadServerResponse
				      userInfo:
		[NSDictionary dictionaryWithObjectsAndKeys:
		  errorString, NSLocalizedDescriptionKey,
		  nil]];

              NSDebugLLog(GS_NSURLSESSION_DEBUG_KEY, @"%@", errorString);

              [taskData setObject: error forKey: NSUnderlyingErrorKey];

              return 0;
            }
        }

      [headerFields removeAllObjects];

      /* URLSession:dataTask:didReceiveResponse:completionHandler:
       * is called *after* all potential redirections are handled.
       *
       * FIXME: Enforce this and implement a custom redirect system
       */
      if ([task _properties] & GSURLSessionUpdatesDelegate
	&& [task isKindOfClass: dataTaskClass]
	&& [delegate respondsToSelector: didReceiveResponseSel])
        {
          dispatch_queue_t queue;

          queue = [session _workQueue];
          /* Pause until the completion handler is called */
          curl_easy_pause(handle, CURLPAUSE_ALL);

          [[session delegateQueue] addOperationWithBlock:^{
             [delegate URLSession: session
                         dataTask: (NSURLSessionDataTask *)task
               didReceiveResponse: response
                completionHandler:^(
                NSURLSessionResponseDisposition disposition) {
                /* FIXME: Implement NSURLSessionResponseBecomeDownload */
                if (disposition == NSURLSessionResponseCancel)
		  {
		    [task _setShouldStopTransfer: YES];
		  }

                /* Unpause easy handle */
                dispatch_async(
                  queue,
                  ^{
                    curl_easy_pause(handle, CURLPAUSE_CONT);
                  });
              }];
           }];
        }
    }

  return size * nitems;
} /* header_callback */

/* CURLOPT_READFUNCTION: read callback for data uploads */
static size_t
read_callback(char *buffer, size_t size, size_t nitems, void *userdata)
{
  NSURLSession 		*session;
  NSURLSessionTask 	*task;
  NSMutableDictionary	*taskData;
  NSInputStream		*stream;
  NSInteger 		bytesWritten;

  task = (NSURLSessionTask *)userdata;
  session = [task _session];
  taskData = [task _taskData];
  stream = [taskData objectForKey: taskInputStreamKey];

  if (nil == stream)
    {
      id<NSURLSessionTaskDelegate> delegate = [task delegate];

      NSDebugLLog(
        GS_NSURLSESSION_DEBUG_KEY,
        @"task=%@ requesting new body stream from delegate",
        task);

      if ([delegate respondsToSelector: needNewBodyStreamSel])
        {
          [[[task _session] delegateQueue] addOperationWithBlock:^{
             [delegate URLSession: session
                             task: task
                needNewBodyStream:^(NSInputStream *bodyStream) {
                /* Add input stream to task data */
                [taskData setObject: bodyStream forKey: taskInputStreamKey];
                /* Continue with the transfer */
                curl_easy_pause([task _easyHandle], CURLPAUSE_CONT);
              }];
           }];

          return CURL_READFUNC_PAUSE;
        }
      else
        {
          NSDebugLLog(
            GS_NSURLSESSION_DEBUG_KEY,
            @"task=%@ no input stream was given and delegate does "
            @"not respond to URLSession:task:needNewBodyStream:",
            task);

          return CURL_READFUNC_ABORT;
        }
    }

  bytesWritten = [stream read: (uint8_t *)buffer maxLength: (size * nitems)];
  /* An error occured while reading from the inputStream */
  if (bytesWritten < 0)
    {
      NSError	*error;

      error = [NSError errorWithDomain: NSURLErrorDomain
				  code: NSURLErrorCancelled
			      userInfo:
	[NSDictionary dictionaryWithObjectsAndKeys:
	  @"An error occured while reading from the body stream",
          NSLocalizedDescriptionKey,
	 [stream streamError],
	 NSUnderlyingErrorKey,
	 nil]];

      [taskData setObject: error forKey: NSUnderlyingErrorKey];
      return CURL_READFUNC_ABORT;
    }

  return bytesWritten;
} /* read_callback */

/* CURLOPT_WRITEFUNCTION: callback for writing received data from easy handle */
static size_t
write_callback(char *ptr, size_t size, size_t nmemb, void *userdata)
{
  NSURLSessionTask	*task;
  NSURLSession 		*session;
  NSMutableDictionary 	*taskData;
  NSData 		*dataFragment;
  NSInteger 		properties;

  task = (NSURLSessionTask *)userdata;
  session = [task _session];
  taskData = [task _taskData];
  dataFragment = [[NSData alloc] initWithBytes: ptr length: (size * nmemb)];
  properties = [task _properties];

  if (properties & GSURLSessionStoresDataInMemory)
    {
      NSMutableData	*data;

      data = [taskData objectForKey: taskTransferDataKey];
      if (!data)
        {
          data = [[NSMutableData alloc] init];
          /* Strong reference maintained by taskData */
          [taskData setObject: data forKey: taskTransferDataKey];
          [data release];
        }

      [data appendData: dataFragment];
    }
  else if (properties & GSURLSessionWritesDataToFile)
    {
      NSFileHandle	*handle;
      NSError 		*error = NULL;

      // Get a temporary file path and create a file handle
      if (nil == (handle = [taskData objectForKey: taskTemporaryFileHandleKey]))
        {
          handle = [task _createTemporaryFileHandleWithError: &error];

          /* We add the error to taskData as an underlying error */
          if (NULL != error)
            {
              [taskData setObject: error forKey: NSUnderlyingErrorKey];
              [dataFragment release];
              return 0;
            }
        }

      [handle writeData: dataFragment];
    }

  /* Notify delegate */
  if (properties & GSURLSessionUpdatesDelegate)
    {
      id delegate = [task delegate];

      if ([task isKindOfClass: dataTaskClass] &&
          [delegate respondsToSelector: didReceiveDataSel])
        {
          [[session delegateQueue] addOperationWithBlock:^{
             [delegate URLSession: session
                         dataTask: (NSURLSessionDataTask *)task
                   didReceiveData: dataFragment];
           }];
        }

      /* Notify delegate about the download process */
      if ([task isKindOfClass: downloadTaskClass] &&
          [delegate respondsToSelector: didWriteDataSel])
        {
          NSURLSessionDownloadTask	*downloadTask;
          int64_t bytesWritten;
          int64_t totalBytesWritten;
          int64_t totalBytesExpectedToReceive;

          downloadTask = (NSURLSessionDownloadTask *)task;
          bytesWritten = [dataFragment length];

          [downloadTask _updateCountOfBytesWritten: bytesWritten];

          totalBytesWritten = [downloadTask _countOfBytesWritten];
          totalBytesExpectedToReceive =
            [downloadTask countOfBytesExpectedToReceive];

          [[session delegateQueue] addOperationWithBlock:^{
             [delegate URLSession: session
                           downloadTask: downloadTask
                           didWriteData: bytesWritten
                      totalBytesWritten: totalBytesWritten
              totalBytesExpectedToWrite: totalBytesExpectedToReceive];
           }];
        }
    }

  [dataFragment release];
  return size * nmemb;
} /* write_callback */

@implementation NSURLSessionTask
{
  _Atomic(BOOL) _shouldStopTransfer;

  /* Opaque value for storing task specific properties */
  NSInteger _properties;

  /* Internal task data */
  NSMutableDictionary	*_taskData;
  NSInteger 		_numberOfRedirects;
  NSInteger 		_headerCallbackCount;
  NSUInteger 		_suspendCount;

  char _curlErrorBuffer[CURL_ERROR_SIZE];
  struct curl_slist	*_headerList;

  CURL			*_easyHandle;
  NSURLSession 		*_session;
}

+ (void) initialize
{
  dataTaskClass = [NSURLSessionDataTask class];
  downloadTaskClass = [NSURLSessionDownloadTask class];
  didReceiveDataSel = @selector(URLSession:dataTask:didReceiveData:);
  didReceiveResponseSel =
    @selector(URLSession:dataTask:didReceiveResponse:completionHandler:);
  didCompleteWithErrorSel = @selector(URLSession:task:didCompleteWithError:);
  didFinishDownloadingToURLSel =
    @selector(URLSession:downloadTask:didFinishDownloadingToURL:);
  didWriteDataSel = @selector
    (URLSession:
     downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:);
  needNewBodyStreamSel = @selector(URLSession:task:needNewBodyStream:);
  willPerformHTTPRedirectionSel = @selector
    (URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:);
}

- (instancetype) initWithSession: (NSURLSession *)session
  request: (NSURLRequest *)request
  taskIdentifier: (NSUInteger)identifier
{
  self = [super init];

  if (self)
    {
      ENTER_POOL
      NSString			*httpMethod;
      NSData 			*certificateBlob;
      NSURL 			*url;
      NSDictionary 		*immConfigHeaders;
      NSURLSessionConfiguration *configuration;
      NSHTTPCookieStorage 	*storage;

      _GSMutableInsensitiveDictionary	*requestHeaders = nil;
      _GSMutableInsensitiveDictionary	*configHeaders = nil;

      _taskIdentifier = identifier;
      _taskData = [[NSMutableDictionary alloc] init];
      _shouldStopTransfer = NO;
      _numberOfRedirects = -1;
      _headerCallbackCount = 0;

      ASSIGNCOPY(_originalRequest, request);
      ASSIGNCOPY(_currentRequest, request);

      httpMethod = [[_originalRequest HTTPMethod] lowercaseString];
      url = [_originalRequest URL];
      requestHeaders
	= AUTORELEASE([[_originalRequest _insensitiveHeaders] mutableCopy]);
      configuration = [session configuration];

      /* Only retain the session once the -resume method is called
       * and release the session as the last thing done once the
       * task has completed. This avoids a retain loop causing
       * session and tasks to be leaked.
       */
      _session = session;
      _suspendCount = 0;
      _state = NSURLSessionTaskStateSuspended;
      _curlErrorBuffer[0] = '\0';

      /* Configure initial task data
       */
      [_taskData setObject: [NSMutableDictionary dictionary]
		    forKey: @"headers"];

      /* Easy Handle Configuration
       */
      _easyHandle = curl_easy_init();

      if ([@"head" isEqualToString: httpMethod])
        {
          curl_easy_setopt(_easyHandle, CURLOPT_NOBODY, 1L);
        }

      /* Setup upload data if a HTTPBody or HTTPBodyStream is present in the
       * URLRequest
       */
      if (nil != [_originalRequest HTTPBody])
        {
          NSData	*body = [_originalRequest HTTPBody];

          curl_easy_setopt(_easyHandle, CURLOPT_UPLOAD, 1L);
          curl_easy_setopt(
            _easyHandle,
            CURLOPT_POSTFIELDSIZE_LARGE,
            [body length]);
          curl_easy_setopt(_easyHandle, CURLOPT_POSTFIELDS, [body bytes]);
        }
      else if (nil != [_originalRequest HTTPBodyStream])
        {
          NSInputStream	*stream = [_originalRequest HTTPBodyStream];

          [_taskData setObject: stream forKey: taskInputStreamKey];

          curl_easy_setopt(_easyHandle, CURLOPT_READFUNCTION, read_callback);
          curl_easy_setopt(_easyHandle, CURLOPT_READDATA, self);

          curl_easy_setopt(_easyHandle, CURLOPT_UPLOAD, 1L);
          curl_easy_setopt(_easyHandle, CURLOPT_POSTFIELDSIZE, -1);
        }

      /* Configure HTTP method and URL */
      curl_easy_setopt(
        _easyHandle,
        CURLOPT_CUSTOMREQUEST,
        [[_originalRequest HTTPMethod] UTF8String]);

      curl_easy_setopt(
        _easyHandle,
        CURLOPT_URL,
        [[url absoluteString] UTF8String]);

      /* This callback function gets called by libcurl as soon as there is data
       * received that needs to be saved. For most transfers, this callback gets
       * called many times and each invoke delivers another chunk of data.
       *
       * This is directly mapped to -[NSURLSessionDataDelegate
       * URLSession:dataTask:didReceiveData:].
       */
      curl_easy_setopt(_easyHandle, CURLOPT_WRITEFUNCTION, write_callback);
      curl_easy_setopt(_easyHandle, CURLOPT_WRITEDATA, self);

      /* Retrieve the header data
       *
       * If the delegate conforms to the NSURLSessionDataDelegate
       * - URLSession:dataTask:didReceiveResponse:completionHandler:
       * we can notify it about the header response.
       */
      curl_easy_setopt(_easyHandle, CURLOPT_HEADERFUNCTION, header_callback);
      curl_easy_setopt(_easyHandle, CURLOPT_HEADERDATA, self);

      curl_easy_setopt(_easyHandle, CURLOPT_ERRORBUFFER, _curlErrorBuffer);

      /* The task is now associated with the easy handle and can be accessed
       * using curl_easy_getinfo with CURLINFO_PRIVATE.
       */
      curl_easy_setopt(_easyHandle, CURLOPT_PRIVATE, self);

      /* Disable libcurl's build-in progress reporting */
      curl_easy_setopt(_easyHandle, CURLOPT_NOPROGRESS, 0L);
      /* Specifiy our own progress function with the user pointer being the
       * current object
       */
      curl_easy_setopt(
        _easyHandle,
        CURLOPT_XFERINFOFUNCTION,
        progress_callback);
      curl_easy_setopt(_easyHandle, CURLOPT_XFERINFODATA, self);

      /* Do not Follow redirects by default
       *
       * libcurl does not provide a direct interface
       * for redirect notification. We have implemented our own redirection
       * system in header_callback.
       */
      curl_easy_setopt(_easyHandle, CURLOPT_FOLLOWLOCATION, 0L);

      /* Set timeout in connect phase */
      curl_easy_setopt(
        _easyHandle,
        CURLOPT_CONNECTTIMEOUT,
        (NSInteger)[request timeoutInterval]);

      /* Set overall timeout */
      curl_easy_setopt(
        _easyHandle,
        CURLOPT_TIMEOUT,
        [configuration timeoutIntervalForResource]);

      /* Set to HTTP/3 if requested */
      if ([request assumesHTTP3Capable])
        {
          curl_easy_setopt(
            _easyHandle,
            CURLOPT_HTTP_VERSION,
            CURL_HTTP_VERSION_3);
        }

      /* Configure the custom CA certificate if available */
      if (nil != (certificateBlob = [_session _certificateBlob]))
        {
// CURLOPT_CAINFO_BLOB was added in 7.77.0
#if LIBCURL_VERSION_NUM >= 0x074D00
          struct curl_blob blob;

          blob.data = (void *)[certificateBlob bytes];
          blob.len = [certificateBlob length];
          /* Session becomes a strong reference when task is resumed until the
           * end of transfer. */
          blob.flags = CURL_BLOB_NOCOPY;

          curl_easy_setopt(_easyHandle, CURLOPT_CAINFO_BLOB, &blob);
#else
          curl_easy_setopt(
            _easyHandle,
            CURLOPT_CAINFO,
            [_session _certificatePath]);
#endif
        }

      /* Process config headers */
      immConfigHeaders = [configuration HTTPAdditionalHeaders];
      if (nil != immConfigHeaders)
        {
          configHeaders = AUTORELEASE([[_GSMutableInsensitiveDictionary alloc]
                           initWithDictionary: immConfigHeaders
                                    copyItems: NO]);

          /* Merge Headers.
           *
           * If the same header appears in both the configuration's
           * HTTPAdditionalHeaders and the request object (where applicable),
           * the request object’s value takes precedence.
           */
          [configHeaders
           addEntriesFromDictionary: (NSDictionary *)requestHeaders];
          requestHeaders = configHeaders;
        }

      /* Use stored cookies is instructed to do so
       */
      storage = [configuration HTTPCookieStorage];
      if (nil != storage && [configuration HTTPShouldSetCookies])
        {
          NSDictionary			*cookieHeaders;
          NSArray<NSHTTPCookie*>	*cookies;

          /* No headers were set */
          if (nil == requestHeaders)
            {
              requestHeaders = [_GSMutableInsensitiveDictionary dictionary];
            }

          cookies = [storage cookiesForURL: url];
          if ([cookies count] > 0)
            {
              cookieHeaders =
                [NSHTTPCookie requestHeaderFieldsWithCookies: cookies];
              [requestHeaders addEntriesFromDictionary: cookieHeaders];
            }
        }

      /* Append Headers to the libcurl header list
       */
      for (id key in requestHeaders)
	{
          NSString	*headerLine;
	  id 		object = [requestHeaders objectForKey: key];

          headerLine = [NSString stringWithFormat: @"%@: %@", key, object];

          /* We have removed all reserved headers in NSURLRequest */
          _headerList = curl_slist_append(_headerList, [headerLine UTF8String]);
        }
      curl_easy_setopt(_easyHandle, CURLOPT_HTTPHEADER, _headerList);
      LEAVE_POOL
    }

  return self;
} /* initWithSession */

- (void) _enableAutomaticRedirects: (BOOL)flag
{
  curl_easy_setopt(_easyHandle, CURLOPT_FOLLOWLOCATION, flag ? 1L : 0L);
}

- (void) _enableUploadWithData: (NSData *)data
{
  curl_easy_setopt(_easyHandle, CURLOPT_UPLOAD, 1L);

  /* Retain data */
  [_taskData setObject: data forKey: taskUploadData];

  curl_easy_setopt(_easyHandle, CURLOPT_POSTFIELDSIZE_LARGE, [data length]);
  curl_easy_setopt(_easyHandle, CURLOPT_POSTFIELDS, [data bytes]);

  /* The method is overwritten by CURLOPT_UPLOAD. Change it back. */
  curl_easy_setopt(
    _easyHandle,
    CURLOPT_CUSTOMREQUEST,
    [[_originalRequest HTTPMethod] UTF8String]);
}

- (void) _enableUploadWithSize: (NSInteger)size
{
  curl_easy_setopt(_easyHandle, CURLOPT_UPLOAD, 1L);

  curl_easy_setopt(_easyHandle, CURLOPT_READFUNCTION, read_callback);
  curl_easy_setopt(_easyHandle, CURLOPT_READDATA, self);

  if (size > 0)
    {
      curl_easy_setopt(_easyHandle, CURLOPT_POSTFIELDSIZE_LARGE, size);
    }
  else
    {
      curl_easy_setopt(_easyHandle, CURLOPT_POSTFIELDSIZE, -1);
    }

  /* The method is overwritten by CURLOPT_UPLOAD. Change it back. */
  curl_easy_setopt(
    _easyHandle,
    CURLOPT_CUSTOMREQUEST,
    [[_originalRequest HTTPMethod] UTF8String]);
} /* _enableUploadWithSize */

- (CURL *) _easyHandle
{
  return _easyHandle;
}

- (void) _setVerbose: (BOOL)flag
{
  dispatch_async(
    [_session _workQueue],
    ^{
    curl_easy_setopt(_easyHandle, CURLOPT_VERBOSE, flag ? 1L : 0L);
  });
}

- (void) _setBodyStream: (NSInputStream *)stream
{
  [_taskData setObject: stream forKey: taskInputStreamKey];
}

- (void) _setOriginalRequest: (NSURLRequest *)request
{
  ASSIGNCOPY(_originalRequest, request);
}

- (void) _setCurrentRequest: (NSURLRequest *)request
{
  ASSIGNCOPY(_currentRequest, request);
}

- (void) _setResponse: (NSURLResponse *)response
{
  NSURLResponse	*oldResponse = _response;

  _response = [response retain];
  [oldResponse release];
}

- (void) _setCountOfBytesSent: (int64_t)count
{
  _countOfBytesSent = count;
}
- (void) _setCountOfBytesReceived: (int64_t)count
{
  _countOfBytesReceived = count;
}
- (void) _setCountOfBytesExpectedToSend: (int64_t)count
{
  _countOfBytesExpectedToSend = count;
}
- (void) _setCountOfBytesExpectedToReceive: (int64_t)count
{
  _countOfBytesExpectedToReceive = count;
}

- (NSMutableDictionary *) _taskData
{
  return _taskData;
}

- (NSInteger) _properties
{
  return _properties;
}
- (void) _setProperties: (NSInteger)properties
{
  _properties = properties;
}

- (NSURLSession *) _session
{
  return _session;
}

- (BOOL) _shouldStopTransfer
{
  return _shouldStopTransfer;
}

- (void) _setShouldStopTransfer: (BOOL)flag
{
  _shouldStopTransfer = flag;
}

- (NSInteger) _numberOfRedirects
{
  return _numberOfRedirects;
}
- (void) _setNumberOfRedirects: (NSInteger)redirects
{
  _numberOfRedirects = redirects;
}

- (NSInteger) _headerCallbackCount
{
  return _headerCallbackCount;
}
- (void) _setHeaderCallbackCount: (NSInteger)count
{
  _headerCallbackCount = count;
}

/* Creates a temporary file and opens a file handle for writing */
- (NSFileHandle *) _createTemporaryFileHandleWithError: (NSError **)error
{
  NSFileManager	*mgr;
  NSFileHandle	*handle;
  NSString	*path;
  NSURL		*url;

  mgr = [NSFileManager defaultManager];
  path = NSTemporaryDirectory();
  path = [path stringByAppendingPathComponent: [[NSUUID UUID] UUIDString]];

  url = [NSURL fileURLWithPath: path];
  [_taskData setObject: url forKey: taskTemporaryFileLocationKey];

  if (![mgr createFileAtPath: path contents: nil attributes: nil])
    {
      if (error)
        {
          NSString	*errorDescription = [NSString stringWithFormat:
	    @"Failed to create temporary file at path %@", path];

          *error = [NSError errorWithDomain: NSCocoaErrorDomain
				       code: NSURLErrorCannotCreateFile
				   userInfo:
	    [NSDictionary dictionaryWithObjectsAndKeys:
	      errorDescription, NSLocalizedDescriptionKey,
	      nil]];
        }

      return nil;
    }

  handle = [NSFileHandle fileHandleForWritingAtPath: path];
  [_taskData setObject: handle forKey: taskTemporaryFileHandleKey];

  return handle;
} /* _createTemporaryFileHandleWithError */

/* Called in _checkForCompletion */
- (void) _transferFinishedWithCode: (CURLcode)code
{
  NSError	*error = errorForCURLcode(_easyHandle, code, _curlErrorBuffer);

  if (_properties & GSURLSessionWritesDataToFile)
    {
      NSFileHandle	*handle;

      if (nil !=
          (handle = [_taskData objectForKey: taskTemporaryFileHandleKey]))
        {
          [handle closeFile];
        }
    }

  if (_properties & GSURLSessionUpdatesDelegate)
    {
      if (_properties & GSURLSessionWritesDataToFile
	&& [_delegate respondsToSelector: didFinishDownloadingToURLSel])
        {
          NSURL	*url = [_taskData objectForKey: taskTemporaryFileLocationKey];

          [[_session delegateQueue] addOperationWithBlock:^{
             [(id<NSURLSessionDownloadDelegate>) _delegate
              URLSession: _session
                           downloadTask: (NSURLSessionDownloadTask *)self
              didFinishDownloadingToURL: url];
           }];
        }

      if ([_delegate respondsToSelector: didCompleteWithErrorSel])
        {
          [[_session delegateQueue] addOperationWithBlock:^{
             [_delegate URLSession: _session
                              task: self
              didCompleteWithError: error];
           }];
        }
    }

  /* NSURLSessionUploadTask is a subclass of a NSURLSessionDataTask with the
   * same completion handler signature. It thus follows the same code path.
   */
  if ((_properties & GSURLSessionStoresDataInMemory)
    && (_properties & GSURLSessionHasCompletionHandler)
    && [self isKindOfClass: dataTaskClass])
    {
      NSURLSessionDataTask	*dataTask;
      NSData 			*data;

      dataTask = (NSURLSessionDataTask *)self;
      data = [_taskData objectForKey: taskTransferDataKey];

      [[_session delegateQueue] addOperationWithBlock:^{
         [dataTask _completionHandler](data, _response, error);
       }];
    }
  else if ((_properties & GSURLSessionWritesDataToFile)
    && (_properties & GSURLSessionHasCompletionHandler)
    && [self isKindOfClass: downloadTaskClass])
    {
      NSURLSessionDownloadTask	*downloadTask;
      NSURL			*tempFile;

      downloadTask = (NSURLSessionDownloadTask *)self;
      tempFile = [_taskData objectForKey: taskTemporaryFileLocationKey];

      [[_session delegateQueue] addOperationWithBlock:^{
         [downloadTask _completionHandler](tempFile, _response, error);
       }];
    }

  RELEASE(_session);
} /* _transferFinishedWithCode */

/* Called in header_callback */
- (void) _setCookiesFromHeaders: (NSDictionary *)headers
{
  NSURL				*url;
  NSArray 			*cookies;
  NSURLSessionConfiguration 	*config;

  config = [_session configuration];
  url = [_currentRequest URL];

  /* FIXME: Implement NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain */
  if (NSHTTPCookieAcceptPolicyNever != [config HTTPCookieAcceptPolicy]
      && nil != [config HTTPCookieStorage])
    {
      cookies = [NSHTTPCookie cookiesWithResponseHeaderFields: headers
                                                       forURL: url];
      if ([cookies count] > 0)
        {
          [[config HTTPCookieStorage] setCookies: cookies
                                          forURL: url
                                 mainDocumentURL: nil];
        }
    }
} /* _setCookiesFromHeaders */

#pragma mark - Public Methods

- (void) suspend
{
  _suspendCount += 1;
  if (_suspendCount == 1)
    {
      /* If there is an active transfer associated with this task, it will be
       * aborted in the next libcurl progress_callback.
       *
       * TODO: Pause the easy handle put do not abort the full transfer!
       * .     What if the handle is currently paused?
       */
      _shouldStopTransfer = YES;
    }
}
- (void) resume
{
  /* Only resume a transfer if the task is not suspended and in suspended state
   */
  if (_suspendCount == 0 && [self state] == NSURLSessionTaskStateSuspended)
    {
      /*
       * Properly retain the session to keep a reference
       * to the task. This ensures correct API behaviour.
       */
      RETAIN(_session);

      _state = NSURLSessionTaskStateRunning;
      [_session _resumeTask: self];
      return;
    }
  _suspendCount -= 1;
}
- (void) cancel
{
  /* Transfer is aborted in the next libcurl progress_callback
   *
   * If a NSURLSessionTask delegate is set and this is not a convenience task,
   * URLSession:task:didCompleteWithError: is called after receiving
   * CURLMSG_DONE in -[NSURLSessionTask _checkForCompletion].
   */
  dispatch_async(
    [_session _workQueue],
    ^{
    /* Unpause the easy handle if previously paused */
    curl_easy_pause(_easyHandle, CURLPAUSE_CONT);

    _shouldStopTransfer = YES;
    _state = NSURLSessionTaskStateCanceling;
  });
}

- (float) priority
{
  return _priority;
}
- (void) setPriority: (float)priority
{
  _priority = priority;
}

- (id) copyWithZone: (NSZone *)zone
{
  NSURLSessionTask	*copy = [[[self class] alloc] init];

  if (copy)
    {
      copy->_originalRequest = [_originalRequest copyWithZone: zone];
      copy->_currentRequest = [_currentRequest copyWithZone: zone];
      copy->_response = [_response copyWithZone: zone];
      /* FIXME: Seems like copyWithZone: is not implemented for NSProgress */
      copy->_progress = [_progress copy];
      copy->_earliestBeginDate = [_earliestBeginDate copyWithZone: zone];
      copy->_taskDescription = [_taskDescription copyWithZone: zone];
      copy->_taskData = [_taskData copyWithZone: zone];
      copy->_easyHandle = curl_easy_duphandle(_easyHandle);
    }

  return copy;
}

#pragma mark - Getter and Setter

- (NSUInteger) taskIdentifier
{
  return _taskIdentifier;
}

- (NSURLRequest *) originalRequest
{
  return AUTORELEASE([_originalRequest copy]);
}

- (NSURLRequest *) currentRequest
{
  return AUTORELEASE([_currentRequest copy]);
}

- (NSURLResponse *) response
{
  return AUTORELEASE([_response copy]);
}

- (NSURLSessionTaskState) state
{
  return _state;
}

- (NSProgress *) progress
{
  return _progress;
}

- (NSError *) error
{
  return _error;
}

- (id<NSURLSessionTaskDelegate>) delegate
{
  return _delegate;
}

- (void) setDelegate: (id<NSURLSessionTaskDelegate>)delegate
{
  id<NSURLSessionTaskDelegate> oldDelegate = _delegate;

  _delegate = RETAIN(delegate);
  RELEASE(oldDelegate);
}

- (NSDate *) earliestBeginDate
{
  return _earliestBeginDate;
}

- (void) setEarliestBeginDate: (NSDate *)date
{
  NSDate	*oldDate = _earliestBeginDate;

  _earliestBeginDate = RETAIN(date);
  RELEASE(oldDate);
}

- (int64_t) countOfBytesClientExpectsToSend
{
  return _countOfBytesClientExpectsToSend;
}
- (int64_t) countOfBytesClientExpectsToReceive
{
  return _countOfBytesClientExpectsToReceive;
}
- (int64_t) countOfBytesSent
{
  return _countOfBytesSent;
}
- (int64_t) countOfBytesReceived
{
  return _countOfBytesReceived;
}
- (int64_t) countOfBytesExpectedToSend
{
  return _countOfBytesExpectedToSend;
}
- (int64_t) countOfBytesExpectedToReceive
{
  return _countOfBytesExpectedToReceive;
}

- (NSString *) taskDescription
{
  return _taskDescription;
}

- (void) setTaskDescription: (NSString *)description
{
  NSString	*oldDescription = _taskDescription;

  _taskDescription = [description copy];
  RELEASE(oldDescription);
}

- (void) dealloc
{
  /* The session retains this task until the transfer is complete and the easy
   * handle removed from the multi handle.
   *
   * It is save to release the curl handle here.
   */
  curl_easy_cleanup(_easyHandle);
  curl_slist_free_all(_headerList);

  RELEASE(_originalRequest);
  RELEASE(_currentRequest);
  RELEASE(_response);
  RELEASE(_progress);
  RELEASE(_earliestBeginDate);
  RELEASE(_taskDescription);
  RELEASE(_taskData);

  [super dealloc];
}

@end /* NSURLSessionTask */

@implementation NSURLSessionDataTask

- (GSNSURLSessionDataCompletionHandler) _completionHandler
{
  return _completionHandler;
}

- (void) _setCompletionHandler: (GSNSURLSessionDataCompletionHandler)handler
{
  _completionHandler = _Block_copy(handler);
}

- (void) dealloc
{
  _Block_release(_completionHandler);
  [super dealloc];
}

@end

@implementation NSURLSessionUploadTask
@end

@implementation NSURLSessionDownloadTask

- (GSNSURLSessionDownloadCompletionHandler) _completionHandler
{
  return _completionHandler;
}

- (void) _setCompletionHandler: (GSNSURLSessionDownloadCompletionHandler)handler
{
  _completionHandler = _Block_copy(handler);
}

- (int64_t) _countOfBytesWritten
{
  return _countOfBytesWritten;
};

- (void) _updateCountOfBytesWritten: (int64_t)count
{
  _countOfBytesWritten += count;
}

- (void) dealloc
{
  _Block_release(_completionHandler);
  [super dealloc];
}

@end

@implementation NSURLSessionStreamTask
@end
