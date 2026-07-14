#import <Foundation/NSURLSession.h>
#import <Foundation/NSData.h>

@class URLManager;

typedef void (^URLManagerCheckBlock)(URLManager *);

@interface URLManager
  : NSObject <NSURLSessionDataDelegate, NSURLSessionTaskDelegate,
              NSURLSessionDelegate, NSURLSessionDownloadDelegate>
{
  URLManagerCheckBlock _checkBlock;

@public
  NSURLSession                   *currentSession;
  NSURLSessionResponseDisposition responseAnswer;

  NSInteger numberOfExpectedTasksBeforeCheck;

  NSInteger         didCreateTaskCount;
  NSURLSessionTask *didCreateTask;

  NSInteger didBecomeInvalidCount;
  NSError  *didBecomeInvalidError;

  NSInteger          httpRedirectionCount;
  NSURLSessionTask  *httpRedirectionTask;
  NSHTTPURLResponse *httpRedirectionResponse;
  NSURLRequest      *httpRedirectionRequest;

  NSInteger         didCompleteCount;
  NSURLSessionTask *didCompleteTask;
  NSError          *didCompleteError;

  NSInteger                 didWriteDataCount;
  NSURLSessionDownloadTask *didWriteDataTask;
  int64_t                   downloadBytesWritten;
  int64_t                   downloadTotalBytesWritten;
  int64_t                   downloadTotalBytesExpectedToWrite;

  NSInteger                 didFinishDownloadingCount;
  NSURLSessionDownloadTask *didFinishDownloadingTask;
  NSURL                    *didFinishDownloadingURL;

  NSInteger             didReceiveResponseCount;
  NSURLSessionDataTask *didReceiveResponseTask;
  NSURLResponse        *didReceiveResponse;

  NSInteger             didReceiveDataCount;
  NSURLSessionDataTask *didReceiveDataTask;
  NSMutableData        *accumulatedData;

  BOOL cancelRedirect;
}

- (void)setCheckBlock:(URLManagerCheckBlock)block;

@end

@implementation URLManager

- (instancetype)init
{
  self = [super init];
  if (self)
    {
      responseAnswer = NSURLSessionResponseAllow;
      accumulatedData = [[NSMutableData alloc] init];
    }

  return self;
}

- (void)setCheckBlock:(URLManagerCheckBlock)block
{
  _checkBlock = _Block_copy(block);
}

#pragma mark - Session Lifecycle

- (void)URLSession:(NSURLSession *)session
     didCreateTask:(NSURLSessionTask *)task
{
  ASSIGN(currentSession, session);

  didCreateTaskCount += 1;
  ASSIGN(didCreateTask, task);
}
- (void)URLSession:(NSURLSession *)session
  didBecomeInvalidWithError:(NSError *)error
{
  ASSIGN(currentSession, session);
  ASSIGN(didBecomeInvalidError, error);

  didBecomeInvalidCount += 1;
}

#pragma mark - Task Updates

- (void)URLSession:(NSURLSession *)session
                        task:(NSURLSessionTask *)task
  willPerformHTTPRedirection:(NSHTTPURLResponse *)response
                  newRequest:(NSURLRequest *)request
           completionHandler:(void (^)(NSURLRequest *))completionHandler
{
  ASSIGN(currentSession, session);
  ASSIGN(httpRedirectionTask, task);
  ASSIGN(httpRedirectionResponse, response);
  ASSIGN(httpRedirectionRequest, request);

  if (cancelRedirect)
    {
      completionHandler(NULL);
    }
  else
    {
      completionHandler(request);
    }

  httpRedirectionCount += 1;
}

- (void)URLSession:(NSURLSession *)session
                  task:(NSURLSessionTask *)task
  didCompleteWithError:(nullable NSError *)error
{
  ASSIGN(currentSession, session);
  ASSIGN(didCompleteTask, task);
  ASSIGN(didCompleteError, error);

  didCompleteCount += 1;
  if (didCompleteCount == numberOfExpectedTasksBeforeCheck
      && _checkBlock != NULL)
    {
      _checkBlock(self);
    }
}

#pragma mark - Data Updates

- (void)URLSession:(NSURLSession *)session
            dataTask:(NSURLSessionDataTask *)dataTask
  didReceiveResponse:(NSURLResponse *)response
   completionHandler:
     (void (^)(NSURLSessionResponseDisposition))completionHandler
{
  ASSIGN(currentSession, session);
  ASSIGN(didReceiveResponseTask, dataTask);
  ASSIGN(didReceiveResponse, response);

  didReceiveResponseCount += 1;

  completionHandler(responseAnswer);
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data
{
  ASSIGN(currentSession, session);
  ASSIGN(didReceiveResponseTask, dataTask);

  didReceiveDataCount += 1;

  [accumulatedData appendData:data];
}

#pragma mark - Download Updates

- (void)URLSession:(NSURLSession *)session
               downloadTask:(NSURLSessionDownloadTask *)downloadTask
               didWriteData:(int64_t)bytesWritten
          totalBytesWritten:(int64_t)totalBytesWritten
  totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
  ASSIGN(currentSession, session);

  didWriteDataCount += 1;
  downloadBytesWritten = bytesWritten;
  downloadTotalBytesExpectedToWrite = totalBytesExpectedToWrite;
  downloadTotalBytesExpectedToWrite = totalBytesExpectedToWrite;
}

- (void)URLSession:(NSURLSession *)session
               downloadTask:(NSURLSessionDownloadTask *)downloadTask
  didFinishDownloadingToURL:(NSURL *)location
{
  ASSIGN(currentSession, session);
  ASSIGN(didFinishDownloadingTask, downloadTask);
  ASSIGN(didFinishDownloadingURL, location);

  didFinishDownloadingCount += 1;
}

- (void)dealloc
{
  RELEASE(currentSession);

  RELEASE(didCreateTask);
  RELEASE(didBecomeInvalidError);

  RELEASE(httpRedirectionTask);
  RELEASE(httpRedirectionResponse);
  RELEASE(httpRedirectionRequest);

  RELEASE(didCompleteTask);
  RELEASE(didCompleteError);

  RELEASE(didWriteDataTask);

  RELEASE(didFinishDownloadingTask);
  RELEASE(didFinishDownloadingURL);

  RELEASE(didReceiveResponseTask);
  RELEASE(didReceiveResponse);

  RELEASE(didReceiveDataTask);
  RELEASE(accumulatedData);

  _Block_release(_checkBlock);
  [super dealloc];
}

@end
