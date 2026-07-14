/**
 * NSURLSession.m
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

#import "NSURLSessionPrivate.h"
#import "NSURLSessionTaskPrivate.h"
#import "Foundation/NSString.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSStream.h"
#import "Foundation/NSUserDefaults.h"
#import "Foundation/NSBundle.h"
#import "Foundation/NSData.h"

#import "GNUstepBase/NSDebug+GNUstepBase.h"  /* For NSDebugMLLog */
#import "GNUstepBase/NSObject+GNUstepBase.h" /* For -notImplemented */
#import "GSPThread.h"                        /* For nextSessionIdentifier() */
#import "GSDispatch.h"                       /* For dispatch compatibility */

NSString * GS_NSURLSESSION_DEBUG_KEY = @"NSURLSession";

/* We need a globably unique label for the NSURLSession workQueues.
 */
static NSUInteger
nextSessionIdentifier()
{
  static gs_mutex_t lock = GS_MUTEX_INIT_STATIC;
  static NSUInteger sessionCounter = 0;

  GS_MUTEX_LOCK(lock);
  sessionCounter += 1;
  GS_MUTEX_UNLOCK(lock);

  return sessionCounter;
}

#pragma mark - libcurl callbacks

/* CURLMOPT_TIMERFUNCTION: Callback to receive timer requests from libcurl */
static int
timer_callback(CURLM * multi,      /* multi handle */
               long timeout_ms,   /* timeout in number of ms */
               void * clientp)     /* private callback pointer */
{
  NSURLSession * session = (NSURLSession *)clientp;

  NSDebugLLog(
    GS_NSURLSESSION_DEBUG_KEY,
    @"Timer Callback for Session %@: multi=%p timeout_ms=%ld",
    session,
    multi,
    timeout_ms);

  /*
   * if timeout_ms is -1, just delete the timer
   *
   * For all other values of timeout_ms, this should set or *update* the timer
   * to the new value
   */
  if (timeout_ms == -1)
    [session _suspendTimer];
  else
    [session _setTimer: timeout_ms];
  return 0;
}

/* CURLMOPT_SOCKETFUNCTION: libcurl requests socket monitoring using this
 * callback */
static int
socket_callback(CURL * easy,           /* easy handle */
                curl_socket_t s,       /* socket */
                int what,              /* describes the socket */
                void * clientp,        /* private callback pointer */
                void * socketp)                /* private socket pointer */
{
  NSURLSession * session = clientp;
  const char * whatstr[] = { "none", "IN", "OUT", "INOUT", "REMOVE" };

  NSDebugLLog(
    GS_NSURLSESSION_DEBUG_KEY,
    @"Socket Callback for Session %@: socket=%d easy:%p what=%s",
    session,
    s,
    easy,
    whatstr[what]);

  if (NULL == socketp)
    {
      return [session _addSocket: s easyHandle: easy what: what];
    }
  else if (CURL_POLL_REMOVE == what)
    {
      [session _removeSocket: (struct SourceInfo *)socketp];
      return 0;
    }
  else
    {
      return [session _setSocket: s
                         sources: (struct SourceInfo *)socketp
                            what: what];
    }
} /* socket_callback */

#pragma mark - NSURLSession Implementation

@implementation NSURLSession
{
  /* The libcurl multi handle associated with this session.
   * We use the curl_multi_socket_action API as we utilise our
   * own event-handling system based on libdispatch.
   *
   * Event creation and deletion is driven by the various callbacks
   * registered during initialisation of the multi handle.
   */
  CURLM * _multiHandle;
  /* A serial work queue for timer and socket sources
   * created on libcurl's behalf.
   */
  dispatch_queue_t _workQueue;
  /* This timer is driven by libcurl and used by
   * libcurl's multi API.
   *
   * The handler notifies libcurl using curl_multi_socket_action
   * and checks for completed requests by calling
   * _checkForCompletion.
   *
   * See https://curl.se/libcurl/c/CURLMOPT_TIMERFUNCTION.html
   * and https://curl.se/libcurl/c/curl_multi_socket_action.html
   * respectively.
   */
  dispatch_source_t _timer;

  /* The timer may be suspended upon request by libcurl.
   */
  BOOL _isTimerSuspended;

  /* Only set when session originates from +[NSURLSession sharedSession] */
  BOOL _isSharedSession;
  BOOL _invalidated;

  /*
   * Number of currently running handles.
   * This number is updated by curl_multi_socket_action
   * in the socket source handlers.
   */
  int _stillRunning;

  /* List of active tasks. Access is synchronised via the _workQueue.
   */
  NSMutableArray<NSURLSessionTask *> * _tasks;

  /* PEM encoded blob of one or more certificates.
   *
   * See GSCACertificateFilePath in NSUserDefaults.h
   */
  NSData * _certificateBlob;
  /* Path to PEM encoded CA certificate file. */
  NSString * _certificatePath;

  /* The task identifier for the next task
   */
  _Atomic(NSInteger) _taskIdentifier;
  /* Lock for _taskIdentifier and _tasks
   */
  gs_mutex_t _taskLock;
}

+ (NSURLSession *) sharedSession
{
  static NSURLSession * session = nil;
  static dispatch_once_t predicate;

  dispatch_once(
    &predicate,
    ^{
    NSURLSessionConfiguration * configuration =
      [NSURLSessionConfiguration defaultSessionConfiguration];
    session = [[NSURLSession alloc] initWithConfiguration: configuration
                                                 delegate: nil
                                            delegateQueue: nil];
    [session _setSharedSession: YES];
  });

  return session;
}

+ (NSURLSession *) sessionWithConfiguration:
  (NSURLSessionConfiguration *)configuration
{
  NSURLSession * session;

  session = [[NSURLSession alloc] initWithConfiguration: configuration
                                               delegate: nil
                                          delegateQueue: nil];

  return AUTORELEASE(session);
}

+ (NSURLSession *) sessionWithConfiguration:
  (NSURLSessionConfiguration *)configuration
  delegate: (id<NSURLSessionDelegate>)delegate
  delegateQueue: (NSOperationQueue *)queue
{
  NSURLSession * session;

  session = [[NSURLSession alloc] initWithConfiguration: configuration
                                               delegate: delegate
                                          delegateQueue: queue];

  return AUTORELEASE(session);
}

- (instancetype) initWithConfiguration: (NSURLSessionConfiguration *)
  configuration
  delegate: (id<NSURLSessionDelegate>)delegate
  delegateQueue: (NSOperationQueue *)queue
{
  self = [super init];

  if (self)
    {
      NSString * queueLabel;
      NSString * caPath;
      NSUInteger sessionIdentifier;

      /* To avoid a retain cycle in blocks referencing this object */
      __block typeof(self) this = self;

      sessionIdentifier = nextSessionIdentifier();
      queueLabel = [[NSString alloc]
                    initWithFormat: @"org.gnustep.NSURLSession.WorkQueue%ld",
                    sessionIdentifier];
      ASSIGN(_delegate, delegate);
      ASSIGNCOPY(_configuration, configuration);

      _tasks = [[NSMutableArray alloc] init];
      GS_MUTEX_INIT(_taskLock);

      /* label is strdup'ed by libdispatch */
      _workQueue
        = dispatch_queue_create([queueLabel UTF8String], DISPATCH_QUEUE_SERIAL);
      [queueLabel release];
      if (!_workQueue)
        return nil;

      _isTimerSuspended = YES;
      _timer
        = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _workQueue);
      if (!_timer)
        {
          return nil;
        }

      dispatch_source_set_cancel_handler(
        _timer,
        ^{
      dispatch_release(this->_timer);
    });

      // Called after timeout set by libcurl is reached
      dispatch_source_set_event_handler(
        _timer,
        ^{
      // TODO: Check for return values
      curl_multi_socket_action(
        this->_multiHandle,
        CURL_SOCKET_TIMEOUT,
        0,
        &this->_stillRunning);
      [this _checkForCompletion];
    });

      /* Use the provided delegateQueue if available */
      if (queue)
        {
          _delegateQueue = queue;
        }
      else
        {
          /* This (serial) NSOperationQueue is only used for dispatching
           * delegate callbacks and is orthogonal to the workQueue.
           */
          _delegateQueue = [[NSOperationQueue alloc] init];
          [_delegateQueue setMaxConcurrentOperationCount: 1];
        }

      /* libcurl Configuration */
      curl_global_init(CURL_GLOBAL_SSL);

      _multiHandle = curl_multi_init();

      // Set up CURL multi callbacks
      curl_multi_setopt(_multiHandle, CURLMOPT_SOCKETFUNCTION, socket_callback);
      curl_multi_setopt(_multiHandle, CURLMOPT_SOCKETDATA, self);
      curl_multi_setopt(_multiHandle, CURLMOPT_TIMERFUNCTION, timer_callback);
      curl_multi_setopt(_multiHandle, CURLMOPT_TIMERDATA, self);

      // Configure Multi Handle
      curl_multi_setopt(
        _multiHandle,
        CURLMOPT_MAX_HOST_CONNECTIONS,
        [_configuration HTTPMaximumConnectionsPerHost]);

      /* Check if GSCACertificateFilePath is set */

      caPath = [[NSUserDefaults standardUserDefaults]
                objectForKey: GSCACertificateFilePath];
      if (caPath)
        {
          NSDebugMLLog(
            GS_NSURLSESSION_DEBUG_KEY,
            @"Found a GSCACertificateFilePath entry in UserDefaults");

          _certificateBlob = [[NSData alloc] initWithContentsOfFile: caPath];
          if (!_certificateBlob)
            {
              NSDebugMLLog(
                GS_NSURLSESSION_DEBUG_KEY,
                @"Could not open file at GSCACertificateFilePath=%@",
                caPath);
            }
          else
            {
              ASSIGN(_certificatePath, caPath);
            }
        }
    }

  return self;
} /* initWithConfiguration */

#pragma mark - Private Methods

- (NSData *) _certificateBlob
{
  return _certificateBlob;
}

- (NSString *) _certificatePath
{
  return _certificatePath;
}

- (void) _setSharedSession: (BOOL)flag
{
  _isSharedSession = flag;
}

- (NSInteger) _nextTaskIdentifier
{
  NSInteger identifier;

  GS_MUTEX_LOCK(_taskLock);
  identifier = _taskIdentifier;
  _taskIdentifier += 1;
  GS_MUTEX_UNLOCK(_taskLock);

  return identifier;
}

- (void) _resumeTask: (NSURLSessionTask *)task
{
  dispatch_async(
    _workQueue,
    ^{
    CURLMcode code;
    CURLM * multiHandle = _multiHandle;

    code = curl_multi_add_handle(multiHandle, [task _easyHandle]);

    NSDebugMLLog(
      GS_NSURLSESSION_DEBUG_KEY,
      @"Added task=%@ easy=%p to multi=%p with return value %d",
      task,
      [task _easyHandle],
      multiHandle,
      code);
  });
}

- (void) _addHandle: (CURL *)easy
{
  curl_multi_add_handle(_multiHandle, easy);
}
- (void) _removeHandle: (CURL *)easy
{
  curl_multi_remove_handle(_multiHandle, easy);
}

- (void) _setTimer: (NSInteger)timeoutMs
{
  dispatch_source_set_timer(
    _timer,
    dispatch_time(
      DISPATCH_TIME_NOW,
      timeoutMs * NSEC_PER_MSEC),
    DISPATCH_TIME_FOREVER,                         // don't repeat
    timeoutMs * 0.05);                             // 5% leeway

  if (_isTimerSuspended)
    {
      _isTimerSuspended = NO;
      dispatch_resume(_timer);
    }
}

- (void) _suspendTimer
{
  if (!_isTimerSuspended)
    {
      _isTimerSuspended = YES;
      dispatch_suspend(_timer);
    }
}

- (dispatch_queue_t) _workQueue
{
  return _workQueue;
}

/* This method is called when receiving CURL_POLL_REMOVE in socket_callback.
 * We cancel all active dispatch sources and release the SourceInfo structure
 * previously allocated in _addSocket: easyHandle: what:
 */
- (void) _removeSocket: (struct SourceInfo *)sources
{
  NSDebugMLLog(
    GS_NSURLSESSION_DEBUG_KEY,
    @"Remove socket with SourceInfo: %p",
    sources);

  if (sources->readSocket)
    {
      dispatch_source_cancel(sources->readSocket);
      dispatch_release(sources->readSocket);
    }
  if (sources->writeSocket)
    {
      dispatch_source_cancel(sources->writeSocket);
      dispatch_release(sources->writeSocket);
    }

  free(sources);
}

/* A socket needs to be configured and the private socket pointer
 * (socketp) in socket_callback is NULL, meaning we first need to
 * allocate our SourceInfo structure.
 */
- (int) _addSocket: (curl_socket_t)socket easyHandle: (CURL *)easy what: (int)
  what
{
  struct SourceInfo * info;

  NSDebugMLLog(
    GS_NSURLSESSION_DEBUG_KEY,
    @"Add Socket: %d easy: %p",
    socket,
    easy);

  /* Allocate a new SourceInfo structure on the heap */
  if (!(info = calloc(1, sizeof(struct SourceInfo))))
    {
      NSDebugMLLog(
        GS_NSURLSESSION_DEBUG_KEY,
        @"Failed to allocate SourceInfo structure!");
      return -1;
    }

  /* We can now configure the dispatch sources */
  if (-1 == [self _setSocket: socket sources: info what: what])
    {
      NSDebugMLLog(GS_NSURLSESSION_DEBUG_KEY, @"Failed to setup sockets!");
      return -1;
    }
  /* Assign the SourceInfo for access in subsequent socket_callback calls */
  curl_multi_assign(_multiHandle, socket, info);
  return 0;
} /* _addSocket */

- (int) _setSocket: (curl_socket_t)socket
  sources: (struct SourceInfo *)sources
  what: (int)what
{
  /* Create a Reading Dispatch Source that listens on socket */
  if (CURL_POLL_IN == what || CURL_POLL_INOUT == what)
    {
      /* Reset Dispatch Source if previously initialised */
      if (sources->readSocket)
        {
          dispatch_source_cancel(sources->readSocket);
          dispatch_release(sources->readSocket);
          sources->readSocket = NULL;
        }

      NSDebugMLLog(
        GS_NSURLSESSION_DEBUG_KEY,
        @"Creating a reading dispatch source: socket=%d sources=%p what=%d",
        socket,
        sources,
        what);

      sources->readSocket = dispatch_source_create(
        DISPATCH_SOURCE_TYPE_READ,
        socket,
        0,
        _workQueue);
      if (!sources->readSocket)
        {
          NSDebugMLLog(
            GS_NSURLSESSION_DEBUG_KEY,
            @"Unable to create dispatch source for read socket!");
          return -1;
        }
      dispatch_source_set_event_handler(
        sources->readSocket,
        ^{
      int action;

      action = CURL_CSELECT_IN;
      curl_multi_socket_action(_multiHandle, socket, action, &_stillRunning);

      /* Check if the transfer is complete */
      [self _checkForCompletion];
      /* When _stillRunning reaches zero, all transfers are complete/done */
      if (_stillRunning <= 0)
      {
        [self _suspendTimer];
      }
    });

      dispatch_resume(sources->readSocket);
    }

  /* Create a Writing Dispatch Source that listens on socket */
  if (CURL_POLL_OUT == what || CURL_POLL_INOUT == what)
    {
      /* Reset Dispatch Source if previously initialised */
      if (sources->writeSocket)
        {
          dispatch_source_cancel(sources->writeSocket);
          dispatch_release(sources->writeSocket);
          sources->writeSocket = NULL;
        }

      NSDebugMLLog(
        GS_NSURLSESSION_DEBUG_KEY,
        @"Creating a writing dispatch source: socket=%d sources=%p what=%d",
        socket,
        sources,
        what);

      sources->writeSocket = dispatch_source_create(
        DISPATCH_SOURCE_TYPE_WRITE,
        socket,
        0,
        _workQueue);
      if (!sources->writeSocket)
        {
          NSDebugMLLog(
            GS_NSURLSESSION_DEBUG_KEY,
            @"Unable to create dispatch source for write socket!");
          return -1;
        }

      dispatch_source_set_event_handler(
        sources->writeSocket,
        ^{
      int action;

      action = CURL_CSELECT_OUT;
      curl_multi_socket_action(_multiHandle, socket, action, &_stillRunning);

      /* Check if the tranfer is complete */
      [self _checkForCompletion];

      /* When _stillRunning reaches zero, all transfers are complete/done */
      if (_stillRunning <= 0)
      {
        [self _suspendTimer];
      }
    });

      dispatch_resume(sources->writeSocket);
    }

  return 0;
} /* _setSocket */

/* Called by a socket event handler or by a firing timer set by timer_callback.
 *
 * The socket event handler is executed on the _workQueue.
 */
- (void) _checkForCompletion
{
  CURLMsg * msg;
  int msgs_left;
  CURL * easyHandle;
  CURLcode res;
  char * eff_url = NULL;
  NSURLSessionTask * task = nil;

  /* Ask the multi handle if there are any messages from the individual
   * transfers.
   *
   * Remove the associated easy handle and release the task if the transfer is
   * done. This completes the life-cycle of a task added to NSURLSession.
   */
  while ((msg = curl_multi_info_read(_multiHandle, &msgs_left)))
    {
      if (msg->msg == CURLMSG_DONE)
        {
          CURLcode rc;
          easyHandle = msg->easy_handle;
          res = msg->data.result;

          /* Get the NSURLSessionTask instance */
          rc = curl_easy_getinfo(easyHandle, CURLINFO_PRIVATE, &task);
          if (CURLE_OK != rc)
            {
              NSDebugMLLog(
                GS_NSURLSESSION_DEBUG_KEY,
                @"Failed to retrieve task from easy handle %p using "
                @"CURLINFO_PRIVATE",
                easyHandle);
            }
          rc = curl_easy_getinfo(easyHandle, CURLINFO_EFFECTIVE_URL, &eff_url);
          if (CURLE_OK != rc)
            {
              NSDebugMLLog(
                GS_NSURLSESSION_DEBUG_KEY,
                @"Failed to retrieve effective URL from easy handle %p using "
                @"CURLINFO_PRIVATE",
                easyHandle);
            }

          NSDebugMLLog(
            GS_NSURLSESSION_DEBUG_KEY,
            @"Transfer finished for Task %@ with effective url %s "
            @"and CURLcode: %s",
            task,
            eff_url,
            curl_easy_strerror(res));

          curl_multi_remove_handle(_multiHandle, easyHandle);

          /* This session might be released in _transferFinishedWithCode. Better
           * retain it first. */
          RETAIN(self);

          RETAIN(task);
          [_tasks removeObject: task];
          [task _transferFinishedWithCode: res];
          RELEASE(task);

          /* Send URLSession: didBecomeInvalidWithError: to delegate if this
           * session was invalidated */
          if (_invalidated && [_tasks count] == 0 &&
              [_delegate respondsToSelector: @selector(URLSession:
                                                       didBecomeInvalidWithError
                                                       :)])
            {
              [_delegateQueue addOperationWithBlock:^{
                 /* We only support explicit Invalidation for now. Error is set
                  * to nil in this case. */
                 [_delegate URLSession: self didBecomeInvalidWithError: nil];
               }];
            }

          RELEASE(self);
        }
    }
} /* _checkForCompletion */

/* Adds task to _tasks and updates the delegate */
- (void) _didCreateTask: (NSURLSessionTask *)task
{
  dispatch_async(
    _workQueue,
    ^{
    [_tasks addObject: task];
  });

  if ([_delegate respondsToSelector: @selector(URLSession:didCreateTask:)])
    {
      [_delegateQueue addOperationWithBlock:^{
         [(id<NSURLSessionTaskDelegate>) _delegate URLSession: self
                                                didCreateTask  : task];
       }];
    }
}

#pragma mark - Public API

- (void) finishTasksAndInvalidate
{
  if (_isSharedSession)
    {
      return;
    }

  dispatch_async(
    _workQueue,
    ^{
    _invalidated = YES;
  });
}

- (void) invalidateAndCancel
{
  if (_isSharedSession)
    {
      return;
    }

  dispatch_async(
    _workQueue,
    ^{
    _invalidated = YES;

    /* Cancel all tasks */
    for (NSURLSessionTask * task in _tasks)
    {
      [task cancel];
    }
  });
}

- (NSURLSessionDataTask *) dataTaskWithRequest: (NSURLRequest *)request
{
  NSURLSessionDataTask * task;
  NSInteger identifier;

  identifier = [self _nextTaskIdentifier];
  task = [[NSURLSessionDataTask alloc] initWithSession: self
                                               request: request
                                        taskIdentifier: identifier];

  /* We use the session delegate by default. NSURLSessionTaskDelegate
   * is a purely optional protocol.
   */
  [task setDelegate: (id<NSURLSessionTaskDelegate>)_delegate];

  [task _setProperties: GSURLSessionUpdatesDelegate];

  [self _didCreateTask: task];

  return AUTORELEASE(task);
}

- (NSURLSessionDataTask *) dataTaskWithURL: (NSURL *)url
{
  NSURLRequest * request;

  request = [NSURLRequest requestWithURL: url];
  return [self dataTaskWithRequest: request];
}

- (NSURLSessionUploadTask *) uploadTaskWithRequest: (NSURLRequest *)request
  fromFile: (NSURL *)fileURL
{
  NSURLSessionUploadTask * task;
  NSInputStream * stream;
  NSInteger identifier;

  identifier = [self _nextTaskIdentifier];
  stream = [NSInputStream inputStreamWithURL: fileURL];
  task = [[NSURLSessionUploadTask alloc] initWithSession: self
                                                 request: request
                                          taskIdentifier: identifier];

  /* We use the session delegate by default. NSURLSessionTaskDelegate
   * is a purely optional protocol.
   */
  [task setDelegate: (id<NSURLSessionTaskDelegate>)_delegate];
  [task
   _setProperties: GSURLSessionUpdatesDelegate | GSURLSessionHasInputStream];
  [task _setBodyStream: stream];
  [task _enableUploadWithSize: 0];

  [self _didCreateTask: task];

  return AUTORELEASE(task);
} /* uploadTaskWithRequest */

- (NSURLSessionUploadTask *) uploadTaskWithRequest: (NSURLRequest *)request
  fromData: (NSData *)bodyData
{
  NSURLSessionUploadTask * task;
  NSInteger identifier;

  identifier = [self _nextTaskIdentifier];
  task = [[NSURLSessionUploadTask alloc] initWithSession: self
                                                 request: request
                                          taskIdentifier: identifier];

  /* We use the session delegate by default. NSURLSessionTaskDelegate
   * is a purely optional protocol.
   */
  [task setDelegate: (id<NSURLSessionTaskDelegate>)_delegate];
  [task _setProperties: GSURLSessionUpdatesDelegate];
  [task _enableUploadWithData: bodyData];

  [self _didCreateTask: task];

  return AUTORELEASE(task);
}

- (NSURLSessionUploadTask *) uploadTaskWithStreamedRequest:
  (NSURLRequest *)request
{
  NSURLSessionUploadTask * task;
  NSInteger identifier;

  identifier = [self _nextTaskIdentifier];
  task = [[NSURLSessionUploadTask alloc] initWithSession: self
                                                 request: request
                                          taskIdentifier: identifier];

  /* We use the session delegate by default. NSURLSessionTaskDelegate
   * is a purely optional protocol.
   */
  [task setDelegate: (id<NSURLSessionTaskDelegate>)_delegate];
  [task
   _setProperties: GSURLSessionUpdatesDelegate | GSURLSessionHasInputStream];
  [task _enableUploadWithSize: 0];

  [self _didCreateTask: task];

  return AUTORELEASE(task);
}

- (NSURLSessionDownloadTask *) downloadTaskWithRequest: (NSURLRequest *)request
{
  NSURLSessionDownloadTask * task;
  NSInteger identifier;

  identifier = [self _nextTaskIdentifier];
  task = [[NSURLSessionDownloadTask alloc] initWithSession: self
                                                   request: request
                                            taskIdentifier: identifier];

  /* We use the session delegate by default. NSURLSessionTaskDelegate
   * is a purely optional protocol.
   */
  [task setDelegate: (id<NSURLSessionTaskDelegate>)_delegate];
  [task
   _setProperties: GSURLSessionWritesDataToFile | GSURLSessionUpdatesDelegate];

  [self _didCreateTask: task];

  return AUTORELEASE(task);
}

- (NSURLSessionDownloadTask *) downloadTaskWithURL: (NSURL *)url
{
  NSURLRequest * request;

  request = [NSURLRequest requestWithURL: url];
  return [self downloadTaskWithRequest: request];
}

- (NSURLSessionDownloadTask *) downloadTaskWithResumeData: (NSData *)resumeData
{
  return [self notImplemented: _cmd];
}

- (void) getTasksWithCompletionHandler:
  (void (^)(
     NSArray<NSURLSessionDataTask *> * dataTasks,
     NSArray<NSURLSessionUploadTask *> * uploadTasks,
     NSArray<NSURLSessionDownloadTask *> * downloadTasks))
  completionHandler
{
  dispatch_async(
    _workQueue,
    ^{
    NSMutableArray<NSURLSessionDataTask *> * dataTasks;
    NSMutableArray<NSURLSessionUploadTask *> * uploadTasks;
    NSMutableArray<NSURLSessionDownloadTask *> * downloadTasks;
    NSInteger numberOfTasks;

    Class dataTaskClass;
    Class uploadTaskClass;
    Class downloadTaskClass;

    numberOfTasks = [_tasks count];
    dataTasks = [NSMutableArray arrayWithCapacity: numberOfTasks / 2];
    uploadTasks = [NSMutableArray arrayWithCapacity: numberOfTasks / 2];
    downloadTasks = [NSMutableArray arrayWithCapacity: numberOfTasks / 2];

    dataTaskClass = [NSURLSessionDataTask class];
    uploadTaskClass = [NSURLSessionUploadTask class];
    downloadTaskClass = [NSURLSessionDownloadTask class];

    for (NSURLSessionTask * task in _tasks)
    {
      if ([task isKindOfClass: dataTaskClass])
      {
        [dataTasks addObject: (NSURLSessionDataTask *)task];
      }
      else if ([task isKindOfClass: uploadTaskClass])
      {
        [uploadTasks addObject: (NSURLSessionUploadTask *)task];
      }
      else if ([task isKindOfClass: downloadTaskClass])
      {
        [downloadTasks addObject: (NSURLSessionDownloadTask *)task];
      }
    }

    completionHandler(dataTasks, uploadTasks, downloadTasks);
  });
} /* getTasksWithCompletionHandler */

- (void) getAllTasksWithCompletionHandler:
  (void (^)(NSArray<__kindof NSURLSessionTask *> * tasks))completionHandler
{
  dispatch_async(
    _workQueue,
    ^{
    completionHandler(_tasks);
  });
}

#pragma mark - Getter and Setter

- (NSOperationQueue *) delegateQueue
{
  return _delegateQueue;
}

- (id<NSURLSessionDelegate>) delegate
{
  return _delegate;
}

- (NSURLSessionConfiguration *) configuration
{
  return AUTORELEASE([_configuration copy]);
}

- (NSString *) sessionDescription
{
  return _sessionDescription;
}

- (void) setSessionDescription: (NSString *)sessionDescription
{
  ASSIGNCOPY(_sessionDescription, sessionDescription);
}

- (void) dealloc
{
  RELEASE(_delegateQueue);
  RELEASE(_delegate);
  RELEASE(_configuration);
  RELEASE(_tasks);
  RELEASE(_certificateBlob);
  RELEASE(_certificatePath);

  curl_multi_cleanup(_multiHandle);

#if     defined(HAVE_DISPATCH_CANCEL)
  dispatch_cancel(_timer);
#else
  dispatch_source_cancel(_timer);
#endif
  dispatch_release(_workQueue);

  [super dealloc];
}

@end

@implementation
NSURLSession (NSURLSessionAsynchronousConvenience)

- (NSURLSessionDataTask *)
  dataTaskWithRequest: (NSURLRequest *)request
  completionHandler: (GSNSURLSessionDataCompletionHandler)completionHandler
{
  NSURLSessionDataTask * task;
  NSInteger identifier;

  identifier = [self _nextTaskIdentifier];
  task = [[NSURLSessionDataTask alloc] initWithSession: self
                                               request: request
                                        taskIdentifier: identifier];
  [task setDelegate: (id<NSURLSessionTaskDelegate>)_delegate];
  [task _setCompletionHandler: completionHandler];
  [task _enableAutomaticRedirects: YES];
  [task _setProperties: GSURLSessionStoresDataInMemory |
   GSURLSessionHasCompletionHandler];

  [self _didCreateTask: task];

  return AUTORELEASE(task);
}

- (NSURLSessionDataTask *) dataTaskWithURL: (NSURL *)url
  completionHandler:
  (GSNSURLSessionDataCompletionHandler)completionHandler
{
  NSURLRequest * request = [NSURLRequest requestWithURL: url];

  return [self dataTaskWithRequest: request completionHandler: completionHandler];
}

- (NSURLSessionUploadTask *)
  uploadTaskWithRequest: (NSURLRequest *)request
  fromFile: (NSURL *)fileURL
  completionHandler: (GSNSURLSessionDataCompletionHandler)completionHandler
{
  NSURLSessionUploadTask * task;
  NSInputStream * stream;
  NSInteger identifier;

  identifier = [self _nextTaskIdentifier];
  stream = [NSInputStream inputStreamWithURL: fileURL];
  task = [[NSURLSessionUploadTask alloc] initWithSession: self
                                                 request: request
                                          taskIdentifier: identifier];
  [task setDelegate: (id<NSURLSessionTaskDelegate>)_delegate];

  [task _setProperties: GSURLSessionStoresDataInMemory
   | GSURLSessionHasInputStream |
   GSURLSessionHasCompletionHandler];
  [task _setCompletionHandler: completionHandler];
  [task _enableAutomaticRedirects: YES];
  [task _setBodyStream: stream];
  [task _enableUploadWithSize: 0];

  [self _didCreateTask: task];

  return AUTORELEASE(task);
} /* uploadTaskWithRequest */

- (NSURLSessionUploadTask *)
  uploadTaskWithRequest: (NSURLRequest *)request
  fromData: (NSData *)bodyData
  completionHandler: (GSNSURLSessionDataCompletionHandler)completionHandler
{
  NSURLSessionUploadTask * task;
  NSInteger identifier;

  identifier = [self _nextTaskIdentifier];
  task = [[NSURLSessionUploadTask alloc] initWithSession: self
                                                 request: request
                                          taskIdentifier: identifier];
  [task setDelegate: (id<NSURLSessionTaskDelegate>)_delegate];

  [task _setProperties: GSURLSessionStoresDataInMemory |
   GSURLSessionHasCompletionHandler];
  [task _setCompletionHandler: completionHandler];
  [task _enableAutomaticRedirects: YES];
  [task _enableUploadWithData: bodyData];

  [self _didCreateTask: task];

  return AUTORELEASE(task);
}

- (NSURLSessionDownloadTask *) downloadTaskWithRequest: (NSURLRequest *)request
  completionHandler:
  (GSNSURLSessionDownloadCompletionHandler)
  completionHandler
{
  NSURLSessionDownloadTask * task;
  NSInteger identifier;

  identifier = [self _nextTaskIdentifier];
  task = [[NSURLSessionDownloadTask alloc] initWithSession: self
                                                   request: request
                                            taskIdentifier: identifier];

  [task setDelegate: (id<NSURLSessionTaskDelegate>)_delegate];

  [task _setProperties: GSURLSessionWritesDataToFile |
   GSURLSessionHasCompletionHandler];
  [task _enableAutomaticRedirects: YES];
  [task _setCompletionHandler: completionHandler];

  [self _didCreateTask: task];

  return AUTORELEASE(task);
}

- (NSURLSessionDownloadTask *)
  downloadTaskWithURL: (NSURL *)url
  completionHandler: (GSNSURLSessionDownloadCompletionHandler)completionHandler
{
  NSURLRequest * request = [NSURLRequest requestWithURL: url];

  return [self downloadTaskWithRequest: request
                     completionHandler: completionHandler];
}

- (NSURLSessionDownloadTask *)
  downloadTaskWithResumeData: (NSData *)resumeData
  completionHandler:
  (GSNSURLSessionDownloadCompletionHandler)completionHandler
{
  return [self notImplemented: _cmd];
}

@end
