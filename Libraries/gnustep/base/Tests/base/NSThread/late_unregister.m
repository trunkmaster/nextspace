#import "ObjectTesting.h"
#import <Foundation/NSThread.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSNotification.h>

#if defined(_WIN32)
int main(void)
{
  testHopeful = YES;
  START_SET("Late unregistering of NSThread")
  PASS(NO, "FIXME: Results in a deadlock in MinGW with Clang");
  END_SET("Late unregistering of NSThread")
  return 0;
}

#else

#if defined(_WIN32)
#include <process.h>
#else
#include <pthread.h>
#endif

@interface ThreadExpectation : NSObject
{
  NSThread *origThread;
  BOOL done;
  BOOL deallocated;
}

- (void) onThreadExit: (NSNotification*)n;
- (BOOL) isDone;
@end

@implementation ThreadExpectation

- (id) init
{
  if (nil == (self = [super init]))
    {
      return nil;
    }
  return self;
}



- (void) inThread: (NSThread*)thread
{
  NSNotificationCenter  *nc = [NSNotificationCenter defaultCenter];

  /* We explicitly don't retain this so that we can check that it actually says
   * alive until the notification is sent. That check is implicit since
   * PASS_EQUAL in the -onThreadExit method will throw or crash if that isn't
   * the case.
   */
  origThread = thread;
  [nc addObserver: self
         selector: @selector(onThreadExit:)
             name: NSThreadWillExitNotification
           object: thread];
}

- (void) onThreadExit: (NSNotification*)thr
{
  NSThread      *current = [NSThread currentThread];
  NSThread      *passed = [thr object];

  PASS_EQUAL(passed, origThread,
    "NSThreadWillExitNotification passes expected thread")
  PASS_EQUAL(origThread, current,
    "Correct thread reference can be obtained on exit")
  PASS([passed isExecuting],
    "exiting thread is still executing at point of notification")
  PASS(![passed isFinished],
    "exiting thread is not finished at point of notification")

  [[NSNotificationCenter defaultCenter] removeObserver: self];
  origThread = nil;
  done = YES;
}

- (BOOL) isDone
{
  return done;
}

@end

#if defined(_WIN32)
void __cdecl
#else
void *
#endif
thread(void *expectation)
{
  [(ThreadExpectation*)expectation inThread: [NSThread currentThread]];
#if !defined(_WIN32)
  return NULL;
#endif
}



/**
 * This test checks whether we can still obtain a reference to the NSThread
 * object of a thread that is in the process of exiting without an explicit
 * call to [NSThread exit]. To do this, we pass an expectation object to
 * a thread created purely using the pthreads API. We then wait on a condition
 * until the thread exits and posts the NSThreadWillExitNotification. If that
 * does not happen within 5 seconds, we flag the test as failed.
 */
int main(void)
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  ThreadExpectation *expectation = [ThreadExpectation new];
  
#if defined(_WIN32)
  _beginthread(thread, 0, expectation);
#else
  pthread_t thr;
  pthread_attr_t attr;
  pthread_attr_init(&attr);
  pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
  pthread_create(&thr, &attr, thread, expectation);
#endif

  int attempts = 10;
  while (![expectation isDone] && attempts > 0)
  {
    [NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1]];
    attempts -= 1;
  }
  PASS([expectation isDone], "Notification for thread exit was sent");
  DESTROY(expectation);
  DESTROY(arp);
  return 0;
}

#endif
