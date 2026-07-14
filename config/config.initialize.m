/* Test whether Objective-C runtime +initialize support is thread-safe
 */

#include "objc-common.g"
#include <stdio.h>

#if !defined(_MSC_VER)
#include <unistd.h>
#endif

#if defined(_WIN32)

#include <process.h>
typedef unsigned thread_id_t;
#define CREATE_THREAD(threadId, start, arg) \
  _beginthreadex(NULL, 0, start, arg, 0, &threadId) != 0
#define	mySleep(X)	usleep(1000*(X))

#else

#include <pthread.h>
typedef pthread_t thread_id_t;
#define CREATE_THREAD(threadId, start, arg) \
  pthread_create(&threadId, 0, start, arg) == 0
#define	mySleep(X)	sleep(X)

#endif

#if _MSC_VER
// Windows MSVC does not have usleep() (only MinGW does), so we use our own
#include <windows.h>
#ifdef interface
#undef interface // this is defined in windows.h but will break @interface
#endif
void usleep(__int64 usec) {
  LARGE_INTEGER ft = {.QuadPart = -(10*usec)}; // convert to 100ns interval
  HANDLE timer = CreateWaitableTimer(NULL, TRUE, NULL); 
  SetWaitableTimer(timer, &ft, 0, NULL, NULL, 0); 
  WaitForSingleObject(timer, INFINITE); 
  CloseHandle(timer); 
}
#endif

/* Use volatile variables so compiler optimisation won't prevent one thread
 * from seeing changes made by another.
 */
static volatile unsigned	initialize_entered = 0;
static volatile unsigned	initialize_exited = 0;
static volatile unsigned	class_entered = 0;
static volatile BOOL		may_proceed = NO;

@interface	MyClass : NSObject
@end

@implementation	MyClass

+ (void) initialize
{
  initialize_entered++;
  while (NO == may_proceed)
    ;
  initialize_exited++;
}

+ (Class) class
{
  class_entered++;
  return self;
}

@end

static
#if defined(_WIN32)
unsigned int __stdcall
#else
void *
#endif
test(void *arg)
{
  [MyClass class];
  return 0;
}

int
main()
{
  thread_id_t t1;
  thread_id_t t2;
  unsigned  counter;

  if (CREATE_THREAD(t1, test, 0))
    {
      for (counter = 0; 0 == initialize_entered && counter < 5; counter++)
	{
	  mySleep(1);
	}

      if (0 == initialize_entered)
	{
	  fprintf(stderr, "Failed to initialize\n");
	  return 1;
	}

      if (CREATE_THREAD(t2, test, 0))
        {
          /* Wait long enough for t2 to  try calling +class
	   */
	  mySleep(1);

	  if (class_entered > 0)
	    {
	      fprintf(stderr, "class entered prematurely\n");
	      return 1;
	    }

	  /* Let t1 proceed and wait long enough for it to complete
	   * +initialize and for both threads to call +class
	   */
	  may_proceed = YES;
          for (counter = 0; 2 > class_entered && counter < 5; counter++)
	    {
	      mySleep(1);
	    }

	  if (2 == class_entered)
	    {
	      return 0; // OK
	    }
	  fprintf(stderr, "problem with initialize\n");
          return 1;
	}
      else
	{
	  fprintf(stderr, "failed to create t2\n");
	  return 1;
	}
    }
  else
    {
      fprintf(stderr, "failed to create t1\n");
      return 1;
    }
}

