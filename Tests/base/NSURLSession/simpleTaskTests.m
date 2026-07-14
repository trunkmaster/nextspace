#import <Foundation/Foundation.h>

#if defined(__OBJC__) && defined(__clang__) && defined(_MSC_VER)
id __work_around_clang_bug2 = @"__unused__";
#endif

#if GS_HAVE_NSURLSESSION

#import "Helpers/HTTPServer.h"
#import "NSRunLoop+TimeOutAdditions.h"
#import "URLManager.h"
#import "Testing.h"

/* Timeout in Seconds */
static NSInteger      testTimeOut = 60;
static NSTimeInterval expectedCountOfTasksToComplete = 0;

/* Accessed in delegate on different thread.
 */
static _Atomic(NSInteger) currentCountOfCompletedTasks = 0;
static NSLock            *countLock;

static NSDictionary *requestCookieProperties;

static NSArray<Route *> *
createRoutes(Class routeClass, NSURL *baseURL)
{
  Route *routeOKWithContent;
  Route *routeTmpRedirectToOK;
  Route *routeTmpRelativeRedirectToOK;
  Route *routeSetCookiesOK;
  Route *routeFoldedHeaders;
  Route *routeIncorrectlyFoldedHeaders;
  NSURL *routeOKWithContentURL;
  NSURL *routeTmpRedirectToOKURL;
  NSURL *routeTmpRelativeRedirectToOKURL;
  NSURL *routeSetCookiesOKURL;
  NSURL *routeFoldedHeadersURL;
  NSURL *routeIncorrectlyFoldedHeadersURL;

  routeOKWithContentURL = [NSURL URLWithString:@"/contentOK"];
  routeTmpRedirectToOKURL = [NSURL URLWithString:@"/tmpRedirectToOK"];
  routeTmpRelativeRedirectToOKURL =
    [NSURL URLWithString:@"/tmpRelativeRedirectToOK"];
  routeSetCookiesOKURL = [NSURL URLWithString:@"/setCookiesOK"];
  routeFoldedHeadersURL = [NSURL URLWithString:@"/foldedHeaders"];
  routeIncorrectlyFoldedHeadersURL =
    [NSURL URLWithString:@"/incorrectFoldedHeaders"];

  routeOKWithContent = [routeClass
    routeWithURL:routeOKWithContentURL
          method:@"GET"
         handler:^NSData *(NSURLRequest *req) {
           NSData *response;

           response =
             [@"HTTP/1.1 200 OK\r\nContent-Length: 12\r\n\r\nHello World!"
               dataUsingEncoding:NSASCIIStringEncoding];
           return response;
         }];

  routeTmpRedirectToOK = [routeClass
    routeWithURL:routeTmpRedirectToOKURL
          method:@"GET"
         handler:^NSData *(NSURLRequest *req) {
           NSData   *response;
           NSString *responseString;

           responseString = [NSString
             stringWithFormat:@"HTTP/1.1 307 Temporary Redirect\r\nLocation: "
                              @"%@\r\nContent-Length: 0\r\n\r\n",
                              [baseURL
                                URLByAppendingPathComponent:@"contentOK"]];

           response = [responseString dataUsingEncoding:NSASCIIStringEncoding];
           return response;
         }];

  routeTmpRelativeRedirectToOK = [routeClass
    routeWithURL:routeTmpRelativeRedirectToOKURL
          method:@"GET"
         handler:^NSData *(NSURLRequest *req) {
           NSData   *response;
           NSString *responseString;

           responseString = [NSString
             stringWithFormat:@"HTTP/1.1 307 Temporary Redirect\r\nLocation: "
                              @"contentOK\r\nContent-Length: 0\r\n\r\n"];

           response = [responseString dataUsingEncoding:NSASCIIStringEncoding];
           return response;
         }];

  routeSetCookiesOK = [routeClass
    routeWithURL:routeSetCookiesOKURL
          method:@"GET"
         handler:^NSData *(NSURLRequest *req) {
           NSData   *response;
           NSString *httpResponse;

           httpResponse = @"HTTP/1.1 200 OK\r\n"
                           "Content-Type: text/html; charset=UTF-8\r\n"
                           "Set-Cookie: sessionId=abc123; Expires=Wed, 09 Jun "
                           "2100 10:18:14 GMT; Path=/\r\n"
                           "Content-Length: 13\r\n"
                           "\r\n"
                           "Hello, world!";

           NSString *cookie = [req allHTTPHeaderFields][@"Cookie"];
           PASS(cookie != nil, "Cookie field is not nil");
           PASS([cookie containsString:@"RequestCookie=1234"],
                "cookie contains request cookie");

           response = [httpResponse dataUsingEncoding:NSASCIIStringEncoding];
           return response;
         }];

  routeFoldedHeaders = [routeClass
    routeWithURL:routeFoldedHeadersURL
          method:@"GET"
         handler:^NSData *(NSURLRequest *req) {
           NSData *response;

           response =
             [@"HTTP/1.1 200 OK\r\nContent-Length: 12\r\nFolded-Header-SP: "
              @"Test\r\n ing\r\nFolded-Header-TAB: Test\r\n\ting\r\n\r\nHello "
              @"World!" dataUsingEncoding:NSASCIIStringEncoding];
           return response;
         }];

  routeIncorrectlyFoldedHeaders = [routeClass
    routeWithURL:routeIncorrectlyFoldedHeadersURL
          method:@"GET"
         handler:^NSData *(NSURLRequest *req) {
           NSData *response;

           response = [@"HTTP/1.1 200 OK\r\n"
                       @" ing\r\nFolded-Header-TAB: Test\r\n\ting\r\n\r\nHello "
                       @"World!" dataUsingEncoding:NSASCIIStringEncoding];
           return response;
         }];

  return @[
    routeOKWithContent, routeTmpRedirectToOK, routeTmpRelativeRedirectToOK,
    routeSetCookiesOK, routeFoldedHeaders, routeIncorrectlyFoldedHeaders
  ];
}

/* Block needs to be released */
static URLManagerCheckBlock
downloadCheckBlock(const char *prefix, NSURLSession *session,
                   NSURLSessionTask *task)
{
  return _Block_copy(^(URLManager *mgr) {
    NSURL         *location;
    NSData        *data;
    NSString      *string;
    NSFileManager *fm;

    location = mgr->didFinishDownloadingURL;
    fm = [NSFileManager defaultManager];

    PASS_EQUAL(mgr->currentSession, session,
               "%s URLManager Session is equal to session", prefix);

    /* Check URLSession:didCreateTask: callback */
    PASS(mgr->didCreateTaskCount == 1, "%s didCreateTask: Count is correct",
         prefix);
    PASS_EQUAL(mgr->didCreateTask, task,
               "%s didCreateTask: task is equal to returned task", prefix);

    /* Check URLSession:task:didCompleteWithError: */
    PASS(nil == mgr->didCompleteError,
         "%s didCompleteWithError: No error occurred", prefix)
    PASS(mgr->didCompleteCount == 1,
         "%s didCompleteWithError: Count is correct", prefix);
    PASS_EQUAL(mgr->didCompleteTask, task,
               "%s didCompleteWithError: task is equal to returned task",
               prefix);

    /* Check Progress Reporting */
    PASS(mgr->didWriteDataCount == 1, "%s didWriteData: count is correct",
         prefix);
    PASS(mgr->downloadTotalBytesWritten
           == mgr->downloadTotalBytesExpectedToWrite,
         "%s didWriteData: Downloaded all expected data", prefix);
    PASS(nil != mgr->didFinishDownloadingURL,
         "%s didWriteData: Download location is not nil", prefix);
    PASS([location isFileURL], "%s location is a fileURL", prefix);

    data = [NSData dataWithContentsOfURL:location];
    PASS(nil != data, "%s dataWithContentsOfURL is not nil", prefix)

    string = [[NSString alloc] initWithData:data
                                   encoding:NSASCIIStringEncoding];
    PASS(nil != string, "%s string from data is not nil", prefix);
    PASS_EQUAL(string, @"Hello World!", "%s data is correct", prefix);

    [string release];

    /* Remove Downloaded Item */
    if (location)
      {
        [fm removeItemAtURL:location error:NULL];
      }

    [countLock lock];
    currentCountOfCompletedTasks += 1;
    [countLock unlock];
  });
}

static URLManagerCheckBlock
dataCheckBlock(const char *prefix, NSURLSession *session,
               NSURLSessionTask *task)
{
  return _Block_copy(^(URLManager *mgr) {
    PASS_EQUAL(mgr->currentSession, session,
               "%s URLManager Session is equal to session", prefix);

    /* Check URLSession:didCreateTask: callback */
    PASS(mgr->didCreateTaskCount == 1, "%s didCreateTask: Count is correct",
         prefix);
    PASS_EQUAL(mgr->didCreateTask, task,
               "%s didCreateTask: task is equal to returned task", prefix);

    /* Check URLSession:task:didCompleteWithError: */
    PASS(nil == mgr->didCompleteError,
         "%s didCompleteWithError: No error occurred", prefix)
    PASS(mgr->didCompleteCount == 1,
         "%s didCompleteWithError: Count is correct", prefix);
    PASS_EQUAL(mgr->didCompleteTask, task,
               "%s didCompleteWithError: task is equal to returned task",
               prefix);

    NSData *data = mgr->accumulatedData;
    PASS(mgr->didReceiveDataCount == 1, "%s didReceiveData: Count is correct",
         prefix);
    PASS(nil != data, "%s data in didReceiveData is not nil", prefix);

    NSString *string = [[NSString alloc] initWithData:data
                                             encoding:NSASCIIStringEncoding];
    PASS(nil != string, "%s string from data is not nil", prefix);
    PASS_EQUAL(string, @"Hello World!", "%s data is correct", prefix);

    [string release];

    [countLock lock];
    currentCountOfCompletedTasks += 1;
    [countLock unlock];
  });
}

/* Block needs to be released */
static URLManagerCheckBlock
dataCheckBlockFailedRequest(const char *prefix, NSURLSession *session,
                            NSURLSessionTask *task)
{
  return _Block_copy(^(URLManager *mgr) {
    PASS_EQUAL(mgr->currentSession, session,
               "%s URLManager Session is equal to session", prefix);

    /* Check URLSession:didCreateTask: callback */
    PASS(mgr->didCreateTaskCount == 1, "%s didCreateTask: Count is correct",
         prefix);
    PASS_EQUAL(mgr->didCreateTask, task,
               "%s didCreateTask: task is equal to returned task", prefix);

    /* Check URLSession:task:didCompleteWithError: */
    PASS(nil != mgr->didCompleteError,
         "%s didCompleteWithError: An error occurred", prefix)
    PASS(mgr->didCompleteCount == 1,
         "%s didCompleteWithError: Count is correct", prefix);
    PASS_EQUAL(mgr->didCompleteTask, task,
               "%s didCompleteWithError: task is equal to returned task",
               prefix);

    /* Check didReceiveResponse if not a canceled redirect */
    if (!mgr->cancelRedirect)
      {
        PASS(mgr->didReceiveResponseCount == 1,
             "%s didReceiveResponse: Count is correct", prefix);
        PASS(nil != mgr->didReceiveResponse, "%s didReceiveResponse is not nil",
             prefix);
        PASS_EQUAL(mgr->didReceiveResponseTask, task,
                   "%s didReceiveResponse: task is equal to returned task",
                   prefix);
      }
    else
      {
        PASS_EQUAL([mgr->didCompleteError code], NSURLErrorCancelled,
                   "%s didCompleteError is NSURLErrorCancelled", prefix);
      }

    [countLock lock];
    currentCountOfCompletedTasks += 1;
    [countLock unlock];
  });
}

/* Creates a downloadTaskWithURL: with the /contentOK route.
 *
 * Delegate callbacks are checked via the URLManager checkBlock.
 */
static URLManager *
testSimpleDownloadTransfer(NSURL *baseURL)
{
  NSURLSession              *session;
  NSURLSessionConfiguration *configuration;
  NSURLSessionDownloadTask  *task;
  URLManager                *mgr;
  URLManagerCheckBlock       block;
  const char                *prefix = "<DownloadTransfer>";

  NSURL *contentOKURL;

  /* URL Delegate Setup */
  mgr = [URLManager new];
  mgr->numberOfExpectedTasksBeforeCheck = 1;
  expectedCountOfTasksToComplete += 1;

  /* URL Setup */
  contentOKURL = [baseURL URLByAppendingPathComponent:@"contentOK"];

  configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
  session = [NSURLSession sessionWithConfiguration:configuration
                                          delegate:mgr
                                     delegateQueue:nil];

  task = [session downloadTaskWithURL:contentOKURL];
  PASS(nil != task, "%s Session created a valid download task", prefix);

  /* Setup Check Block */
  block = downloadCheckBlock(prefix, session, task);
  [mgr setCheckBlock:block];
  _Block_release(block);

  [task resume];

  return mgr;
}

static URLManager *
testDownloadTransferWithRedirect(NSURL *baseURL)
{
  NSURLSession              *session;
  NSURLSessionConfiguration *configuration;
  NSURLSessionDownloadTask  *task;
  URLManager                *mgr;
  URLManagerCheckBlock       block;
  const char                *prefix = "<DownloadTransferWithRedirect>";

  NSURL *contentOKURL;

  /* URL Delegate Setup */
  mgr = [URLManager new];
  mgr->numberOfExpectedTasksBeforeCheck = 1;
  expectedCountOfTasksToComplete += 1;

  /* URL Setup */
  contentOKURL = [baseURL URLByAppendingPathComponent:@"tmpRedirectToOK"];

  configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
  session = [NSURLSession sessionWithConfiguration:configuration
                                          delegate:mgr
                                     delegateQueue:nil];

  task = [session downloadTaskWithURL:contentOKURL];
  PASS(nil != task, "%s Session created a valid download task", prefix);

  /* Setup Check Block */
  block = downloadCheckBlock(prefix, session, task);
  [mgr setCheckBlock:block];
  _Block_release(block);

  [task resume];

  return mgr;
}

/* This should use the build in redirection system from libcurl */
static void
testDataTransferWithRedirectAndBlock(NSURL *baseURL)
{
  NSURLSession         *session;
  NSURLSessionDataTask *task;
  NSURL                *url;

  expectedCountOfTasksToComplete += 1;

  session = [NSURLSession sharedSession];
  url = [baseURL URLByAppendingPathComponent:@"tmpRedirectToOK"];
  task = [session
      dataTaskWithURL:url
    completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
      NSString   *string;
      const char *prefix = "<DataTransferWithRedirectAndBlock>";

      PASS(nil != data, "%s data in completion handler is not nil", prefix);
      PASS(nil != response, "%s response is not nil", prefix);
      PASS([response isKindOfClass:[NSHTTPURLResponse class]],
           "%s response is an NSHTTPURLResponse", prefix);
      PASS(nil == error, "%s error is nil", prefix);

      string = [[NSString alloc] initWithData:data
                                     encoding:NSASCIIStringEncoding];
      PASS_EQUAL(string, @"Hello World!", "%s received data is correct",
                 prefix);

      [string release];

      [countLock lock];
      currentCountOfCompletedTasks += 1;
      [countLock unlock];
    }];

  [task resume];
}

static void
testDataTransferWithCanceledRedirect(NSURL *baseURL)
{
  NSURLSession              *session;
  NSURLSessionConfiguration *configuration;
  NSURLSessionDataTask      *task;
  URLManager                *mgr;
  URLManagerCheckBlock       block;
  const char                *prefix = "<DataTransferWithCanceledRedirect>";

  NSURL *contentOKURL;

  /* URL Delegate Setup */
  mgr = [URLManager new];
  mgr->numberOfExpectedTasksBeforeCheck = 1;
  mgr->cancelRedirect = YES;
  expectedCountOfTasksToComplete += 1;

  /* URL Setup */
  contentOKURL = [baseURL URLByAppendingPathComponent:@"tmpRedirectToOK"];
  configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
  session = [NSURLSession sessionWithConfiguration:configuration
                                          delegate:mgr
                                     delegateQueue:nil];

  task = [session dataTaskWithURL:contentOKURL];
  PASS(nil != task, "%s Session created a valid download task", prefix);

  /* Setup Check Block */
  block = dataCheckBlockFailedRequest(prefix, session, task);
  [mgr setCheckBlock:block];
  _Block_release(block);

  [task resume];
}

static void
testDataTransferWithRelativeRedirect(NSURL *baseURL)
{
  NSURLSession              *session;
  NSURLSessionConfiguration *configuration;
  NSURLSessionDataTask      *task;
  NSURL                     *url;
  URLManager                *mgr;
  URLManagerCheckBlock       block;
  const char                *prefix = "<DataTransferWithRelativeRedirect>";

  /* URL Delegate Setup */
  mgr = [URLManager new];
  mgr->numberOfExpectedTasksBeforeCheck = 1;
  expectedCountOfTasksToComplete += 1;

  session = [NSURLSession sharedSession];
  url = [baseURL URLByAppendingPathComponent:@"tmpRelativeRedirectToOK"];
  configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
  session = [NSURLSession sessionWithConfiguration:configuration
                                          delegate:mgr
                                     delegateQueue:nil];

  task = [session dataTaskWithURL:url];
  PASS(nil != task, "%s Session created a valid download task", prefix);

  /* Setup Check Block */
  block = dataCheckBlock(prefix, session, task);
  [mgr setCheckBlock:block];
  _Block_release(block);

  [task resume];
}

static void
testDownloadTransferWithBlock(NSURL *baseURL)
{
  NSURLSession             *session;
  NSURLSessionDownloadTask *task;
  NSURL                    *url;

  expectedCountOfTasksToComplete += 1;

  session = [NSURLSession sharedSession];
  url = [baseURL URLByAppendingPathComponent:@"contentOK"];
  task = [session
    downloadTaskWithURL:url
      completionHandler:^(NSURL *location, NSURLResponse *response,
                          NSError *error) {
        NSFileManager *fm;
        NSData        *data;
        NSString      *string;

        const char *prefix;

        prefix = "<DownloadTransferWithBlock>";
        fm = [NSFileManager defaultManager];

        PASS(nil != location, "%s location is not nil", prefix);
        PASS(nil != response, "%s response is not nil", prefix);
        PASS(nil == error, "%s error is nil", prefix);

        data = [NSData dataWithContentsOfURL:location];
        PASS(nil != data, "%s data is not nil", prefix);

        string = [[NSString alloc] initWithData:data
                                       encoding:NSASCIIStringEncoding];
        PASS_EQUAL(string, @"Hello World!", "%s content is correct", prefix);

        [fm removeItemAtURL:location error:NULL];

        [countLock lock];
        currentCountOfCompletedTasks += 1;
        [countLock unlock];

        [string release];
      }];

  [task resume];
}

static URLManager *
testParallelDataTransfer(NSURL *baseURL)
{
  NSURLSession              *session;
  NSURLSessionConfiguration *configuration;
  URLManager                *mgr;
  NSURL                     *url;
  const char                *prefix = "<DataTransfer>";

  NSInteger numberOfParallelTasks = 10;

  /* URL Delegate Setup */
  mgr = [URLManager new];
  mgr->numberOfExpectedTasksBeforeCheck = numberOfParallelTasks;
  expectedCountOfTasksToComplete += numberOfParallelTasks;

  url = [baseURL URLByAppendingPathComponent:@"tmpRedirectToOK"];
  configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
  [configuration setHTTPMaximumConnectionsPerHost:0]; // Unlimited
  session = [NSURLSession sessionWithConfiguration:configuration
                                          delegate:mgr
                                     delegateQueue:nil];

  /* Setup Check Block */
  [mgr setCheckBlock:^(URLManager *mgr) {
    PASS_EQUAL(mgr->currentSession, session,
               "%s URLManager Session is equal to session", prefix);

    /* Check URLSession:didCreateTask: callback */
    PASS(mgr->didCreateTaskCount == numberOfParallelTasks,
         "%s didCreateTask: Count is correct", prefix);

    /* Check URLSession:task:didCompleteWithError: */
    PASS(nil == mgr->didCompleteError,
         "%s didCompleteWithError: No error occurred", prefix)
    PASS(mgr->didCompleteCount == numberOfParallelTasks,
         "%s didCompleteWithError: Count is correct", prefix);

    [countLock lock];
    currentCountOfCompletedTasks += numberOfParallelTasks;
    [countLock unlock];
  }];

  for (NSInteger i = 0; i < numberOfParallelTasks; i++)
    {
      NSURLSessionDataTask *task;

      task = [session dataTaskWithURL:url];
      [task resume];
    }

  return mgr;
}

static void
testDataTaskWithBlock(NSURL *baseURL)
{
  NSURLSession         *session;
  NSURLSessionDataTask *task;
  NSURL                *url;

  expectedCountOfTasksToComplete += 1;

  url = [baseURL URLByAppendingPathComponent:@"contentOK"];
  session = [NSURLSession sharedSession];
  task = [session
      dataTaskWithURL:url
    completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
      NSString   *string;
      const char *prefix = "<DataTaskWithBlock>";

      PASS(nil != data, "%s data in completion handler is not nil", prefix);
      PASS(nil != response, "%s response is not nil", prefix);
      PASS([response isKindOfClass:[NSHTTPURLResponse class]],
           "%s response is an NSHTTPURLResponse", prefix);
      PASS(nil == error, "%s error is nil", prefix);

      string = [[NSString alloc] initWithData:data
                                     encoding:NSASCIIStringEncoding];
      PASS_EQUAL(string, @"Hello World!", "%s received data is correct",
                 prefix);

      [string release];

      [countLock lock];
      currentCountOfCompletedTasks += 1;
      [countLock unlock];
    }];

  [task resume];
}

static void
testDataTaskWithCookies(NSURL *baseURL)
{
  NSURLSession              *session;
  NSURLSessionConfiguration *config;
  NSURLSessionDataTask      *task;
  NSURL                     *url;
  NSHTTPCookieStorage       *cookies;
  NSHTTPCookie              *requestCookie;

  expectedCountOfTasksToComplete += 1;

  url = [baseURL URLByAppendingPathComponent:@"setCookiesOK"];
  requestCookie = [NSHTTPCookie cookieWithProperties:requestCookieProperties];

  cookies = [NSHTTPCookieStorage new];
  [cookies setCookie:requestCookie];

  config = [NSURLSessionConfiguration new];
  [config setHTTPCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
  [config setHTTPCookieStorage:cookies];
  [config setHTTPShouldSetCookies:YES];

  session = [NSURLSession sessionWithConfiguration:config];
  task = [session
      dataTaskWithURL:url
    completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
      NSString                *string;
      NSArray<NSHTTPCookie *> *cookieArray;
      NSDate                  *date;
      const char              *prefix = "<DataTaskWithCookies>";

      PASS(nil != data, "%s data in completion handler is not nil", prefix);
      PASS(nil != response, "%s response is not nil", prefix);
      PASS([response isKindOfClass:[NSHTTPURLResponse class]],
           "%s response is an NSHTTPURLResponse", prefix);
      PASS(nil == error, "%s error is nil", prefix);

      string = [[NSString alloc] initWithData:data
                                     encoding:NSASCIIStringEncoding];
      PASS_EQUAL(string, @"Hello, world!", "%s received data is correct",
                 prefix);

      cookieArray = [cookies cookiesForURL:url];

      NSInteger count = 0;
      for (NSHTTPCookie *ck in cookieArray)
        {
          if ([[ck name] isEqualToString:@"RequestCookie"])
            {
              PASS_EQUAL(ck, requestCookie, "RequestCookie is correct");
              count += 1;
            }
          else if ([[ck name] isEqualToString:@"sessionId"])
            {
              date = [NSDate dateWithString:@"2100-06-09 10:18:14 +0000"];
              PASS_EQUAL([ck name], @"sessionId", "Cookie name is correct");
              PASS_EQUAL([ck value], @"abc123", "Cookie value is correct");
              PASS([ck version] == 0, "Correct cookie version");
              PASS([date isEqual:[ck expiresDate]],
                   "Cookie expiresDate is correct");
              count += 1;
            }
        }
      PASS(count == 2, "Found both cookies");

      [string release];

      [countLock lock];
      currentCountOfCompletedTasks += 1;
      [countLock unlock];
    }];

  [task resume];
}

/* Check if NSURLSessionTask correctly unfolds folded header lines */
static void
foldedHeaderDataTaskTest(NSURL *baseURL)
{
  NSURLSession         *session;
  NSURLSessionDataTask *task;
  NSURL                *url;

  expectedCountOfTasksToComplete += 1;

  url = [baseURL URLByAppendingPathComponent:@"foldedHeaders"];
  session = [NSURLSession sharedSession];
  task = [session
      dataTaskWithURL:url
    completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
      NSHTTPURLResponse *urlResponse = (NSHTTPURLResponse *) response;
      NSString          *string;
      NSDictionary      *headerDict;
      const char        *prefix = "<DataTaskWithFoldedHeaders>";

      headerDict = [urlResponse allHeaderFields];

      PASS(nil != data, "%s data in completion handler is not nil", prefix);
      PASS(nil != response, "%s response is not nil", prefix);
      PASS([response isKindOfClass:[NSHTTPURLResponse class]],
           "%s response is an NSHTTPURLResponse", prefix);
      PASS(nil == error, "%s error is nil", prefix);

      string = [[NSString alloc] initWithData:data
                                     encoding:NSASCIIStringEncoding];
      PASS_EQUAL(string, @"Hello World!", "%s received data is correct",
                 prefix);

      PASS_EQUAL([headerDict objectForKey:@"Folded-Header-SP"], @"Testing",
                 "Folded header with continuation space is parsed correctly");
      PASS_EQUAL([headerDict objectForKey:@"Folded-Header-TAB"], @"Testing",
                 "Folded header with continuation tab is parsed correctly");

      [string release];

      [countLock lock];
      currentCountOfCompletedTasks += 1;
      [countLock unlock];
    }];

  [task resume];
}

/* The disposition handler triggers transfer cancelation */
static void
testAbortAfterDidReceiveResponse(NSURL *baseURL)
{
  NSURLSession              *session;
  NSURLSessionConfiguration *configuration;
  NSURLSessionDataTask      *task;
  URLManager                *mgr;
  URLManagerCheckBlock       block;
  const char                *prefix = "<AbortAfterDidReceiveResponseTest>";

  NSURL *contentOKURL;

  /* URL Delegate Setup */
  mgr = [URLManager new];
  mgr->numberOfExpectedTasksBeforeCheck = 1;
  mgr->responseAnswer = NSURLSessionResponseCancel;
  expectedCountOfTasksToComplete += 1;

  /* URL Setup */
  contentOKURL = [baseURL URLByAppendingPathComponent:@"contentOK"];

  configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
  session = [NSURLSession sessionWithConfiguration:configuration
                                          delegate:mgr
                                     delegateQueue:nil];

  task = [session dataTaskWithURL:contentOKURL];
  PASS(nil != task, "%s Session created a valid download task", prefix);

  /* Setup Check Block */
  block = dataCheckBlockFailedRequest(prefix, session, task);
  [mgr setCheckBlock:block];
  _Block_release(block);

  [task resume];
}

int
main(int argc, char *argv[])
{
  @autoreleasepool
  {
    NSBundle      *bundle;
    NSString      *helperPath;
    NSURL         *baseURL;
    NSFileManager *fm;
    HTTPServer    *server;

    Class httpServerClass;
    Class routeClass;

    requestCookieProperties = @{
      NSHTTPCookieName : @"RequestCookie",
      NSHTTPCookieValue : @"1234",
      NSHTTPCookieDomain : @"127.0.0.1",
      NSHTTPCookiePath : @"/",
      NSHTTPCookieExpires :
        [NSDate dateWithString:@"2100-06-09 12:18:14 +0000"],
      NSHTTPCookieSecure : @NO,
    };

    fm = [NSFileManager defaultManager];
    helperPath = [[fm currentDirectoryPath]
      stringByAppendingString:@"/Helpers/HTTPServer.bundle"];
    countLock = [[NSLock alloc] init];

    bundle = [NSBundle bundleWithPath:helperPath];
    if (![bundle load])
      {
        [NSException raise:NSInternalInconsistencyException
                    format:@"failed to load HTTPServer.bundle"];
      }

    httpServerClass = [bundle principalClass];
    routeClass = [bundle classNamed:@"Route"];

    /* Bind to dynamic port. Set routes after initialisation. */
    server = [[httpServerClass alloc] initWithPort:0 routes:nil];
    if (!server)
      {
        [NSException raise:NSInternalInconsistencyException
                    format:@"failed to initialise HTTPServer"];
      }

    baseURL =
      [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%ld",
                                                      [server port]]];

    NSLog(@"Test Server: baseURL=%@", baseURL);

    [server setRoutes:createRoutes(routeClass, baseURL)];
    [server resume];

    // Call Test Functions here
    testSimpleDownloadTransfer(baseURL);
    testDownloadTransferWithBlock(baseURL);

    testParallelDataTransfer(baseURL);
    testDataTaskWithBlock(baseURL);
    testDataTaskWithCookies(baseURL);

    // Testing Header Line Unfolding
    foldedHeaderDataTaskTest(baseURL);

    // Redirects
    testDownloadTransferWithRedirect(baseURL);
    testDataTransferWithRedirectAndBlock(baseURL);
    testDataTransferWithCanceledRedirect(baseURL);
    testDataTransferWithRelativeRedirect(baseURL);

    /* Abort in Delegate */
    testAbortAfterDidReceiveResponse(baseURL);

    [[NSRunLoop currentRunLoop]
       runForSeconds:testTimeOut
      conditionBlock:^BOOL(void) {
        return expectedCountOfTasksToComplete != currentCountOfCompletedTasks;
      }];

    [server suspend];
    PASS(expectedCountOfTasksToComplete == currentCountOfCompletedTasks,
         "All transfers were completed before a timeout occurred");

    [server release];
    [countLock release];
  }
}

#else

int
main(int argc, char *argv[])
{
  return 0;
}

#endif /* GS_HAVE_NSURLSESSION */