#import "ObjectTesting.h"
#import <Foundation/NSThread.h>

#if defined(_WIN32)
#include <process.h>
#else
#include <pthread.h>
#endif

static NSThread *threadResult = nil;

#if defined(_WIN32)
unsigned int __stdcall
#else
void *
#endif
thread(void *ignored)
{
  threadResult = [NSThread currentThread];
  return 0;
}

int main(void)
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  
#if defined(_WIN32)
  HANDLE thr;
  thr = (HANDLE)_beginthreadex(NULL, 0, thread, NULL, 0, NULL);
  WaitForSingleObject(thr, INFINITE);
  CloseHandle(thr);
#else
  pthread_t thr;
  pthread_create(&thr, NULL, thread, NULL);
  pthread_join(thr, NULL);
#endif
  PASS(threadResult != 0, "NSThread lazily created from native thread");
  testHopeful = YES;
  PASS((threadResult != 0) && (threadResult != [NSThread mainThread]),
    "Spawned thread is not main thread");

#if defined(_WIN32)
  thr = (HANDLE)_beginthreadex(NULL, 0, thread, NULL, 0, NULL);
  WaitForSingleObject(thr, INFINITE);
  CloseHandle(thr);
#else
  pthread_create(&thr, NULL, thread, NULL);
  pthread_join(thr, NULL);
#endif
  PASS(threadResult != 0, "NSThread lazily created from native thread");
  PASS((threadResult != 0) && (threadResult != [NSThread mainThread]),
    "Spawned thread is not main thread");

  NSThread *t = [NSThread currentThread];
  [t setName: @"xxxtestxxx"];
  NSLog(@"Thread description is '%@'", t);
  NSRange r = [[t description] rangeOfString: @"name = xxxtestxxx"];
  PASS(r.length > 0, "thread description contains name");
  
  PASS([NSThread threadPriority] == 0.5, "default thread priority is 0.5");
  PASS([NSThread setThreadPriority:0.8], "change thread priority to 0.8");
  PASS([NSThread threadPriority] == 0.8, "thread priority was changed to 0.8");
  PASS([NSThread setThreadPriority:0.2], "change thread priority to 0.2");
  PASS([NSThread threadPriority] == 0.2, "thread priority was changed to 0.2");
  
  DESTROY(arp);
  return 0;
}

